-- CO Super Session
-- Every question in one window with a live preview. Creates a Capture One session with:
--   00_RAW/_prelight (first capture folder), optional parent folders (location, day,
--   scene, category) with numbered shot folders, 01_SELECTS, 02_OUTPUT, 03_TRASH, 04_DOCS.
-- Sets capture/selects/output/trash, capture file naming and optionally a copyright style.
-- Edit THIS file only. Build and install with ./install.sh.
--
-- Copyright (C) 2026 Louis-Philippe Beauduin
-- This program is free software: you can redistribute it and/or modify it under the terms
-- of the GNU General Public License as published by the Free Software Foundation, either
-- version 3 of the License, or (at your option) any later version. It is distributed
-- WITHOUT ANY WARRANTY; see the LICENSE file or <https://www.gnu.org/licenses/>.

use AppleScript version "2.7"
use framework "Foundation"
use framework "AppKit"
use scripting additions

property scriptVersion : "0.1.0" -- bump on every release, matching the git tag (vX.Y.Z)

---------- SETTINGS (edit to taste) ----------
property prefsDomain : "com.lpb.COSession"
property rawName : "00_RAW"
property prelightName : "_prelight" -- created inside RAW; set to "" to skip
property selectsName : "01_SELECTS"
property outputName : "02_OUTPUT"
property trashName : "03_TRASH"
property extraFolders : {"04_DOCS"} -- plain folders, not used by Capture One
property templateName : "" -- saved Capture One session template name, "" for none
-- Copyright without Studio: save a user style in Capture One that only holds your copyright
-- metadata, then put its exact name here. It's applied to every new capture. "" = off.
property copyrightStyle : ""
-- Ask for a photographer name and write it as copyright metadata (needs Capture One Studio)
property askPhotographer : true
-- [Name] is Capture One's "capture name", which the script sets to the job name
property captureFormats : {"[Destination Folder Name]_[4 Digit Counter]", "[Name]_[4 Digit Counter]", "[Name]_[Destination Folder Name]_[4 Digit Counter]", "[Document Name]_[Destination Folder Name]_[4 Digit Counter]", "[Name]_[Destination Folder Name]_[4 Digit Counter]", "[Document Name]_[4 Digit Counter]"} -- 5: [Name] is set to the date instead of the job; 6: [Document Name] is the session name (date_job)


---------- WINDOW STATE (filled at run time) ----------
property win : missing value
property fLocation : missing value
property fJob : missing value
property fClient : missing value
property rClientRaw : ""
property rJobRaw : ""
property fDateFmt : missing value
property fDate : missing value
property fPhotog : missing value
property parentScroll : missing value
property parentDoc : missing value
property parentList : {""} -- one item per parent folder field
property subList : {""} -- one item per subfolder field (second parent level)
property subOn : false
property cbSub : missing value
property rSubField : ""
property cbParents : missing value
property cbShots : missing value
property fAllCounts : missing value -- sets the number of shots for every table row
property cbPrelight : missing value
property fPrelight : missing value
property rPrelightField : ""
property rShotsOn : 1
property fFolders : {} -- session folder name fields, 00-04
property docsName : ""
property folderKeys : {"name_raw", "name_selects", "name_output", "name_trash", "name_docs"}
property folderRoles : {"RAW", "SELECTS", "OUTPUT", "TRASH", "DOCS"}
property folderTips : {" (captures)", " (Capture One selects)", " (Capture One output)", " (Capture One trash)", " (plain folder; empty = none)"}
property rParentsField : ""
property tbl : missing value
property pNumbering : missing value
property pMode : missing value
property pDigits : missing value
property pNaming : missing value
property pCounter : missing value
property rbSep : {} -- separator radio buttons
property previewView : missing value
property fFileName : missing value -- the resulting file name, shown large above the summary

-- separators: 1 ISO 8601 (dates with -, parts joined with _, spaces in names become -),
-- 2 all dashes, 3 all underscores, 4 the opposite of ISO 8601 (a joke: _ in dates and names, - between parts)
property sepStyle : 1
property partSep : "_" -- between date, job, parent, shot, counter
property innerSep : "-" -- replaces spaces inside a name
property otherSep : "_" -- the other character, also turned into innerSep inside names
property dateSep : "-" -- between date parts
property createBtn : missing value
property winH : 0
property cursorTop : 0

property parentPath : ""
property rowParents : {} -- shots table: one row per parent ("" = no parents)
property rowNames : {}
property rowCounts : {}
property rowLists : {} -- pasted folder names per table row ({} = none)
property rGroupLists : {} -- the pasted names of each shot group, parallel to rGroups
property rAppend : true -- true: SHOT01_name; false: the pasted names replace prefix + number
property rbAppend : missing value -- pasted names: Append (SHOT01_name) or Replace (name)
property rbReplace : missing value
property btnPaste : missing value
property pastePanel : missing value
property pasteView : missing value
property defPrefix : "SHOT_"
property defCount : "10"
property wantNumbering : 1 -- what the user picked; used whenever it's available
property wantMode : 1
property wantNaming : 1
property modeIds : {1} -- ids behind the current popup items
property numberingOrder : {2, 1, 3} -- shot numbering ids in menu order
property namingIds : {1}
property modalCode : 0

-- results of the last refresh, used by Create Session
property problem : ""
property rJob : ""
property rDateFmt : ""
property rDate : ""
property rSession : ""
property rPhotog : ""
property rParentsText : ""
property rGroups : {}
property rShotNames : {}
property rDigits : 2
property rCounter : 4
property rNumbering : 1
property rMode : 1
property rNaming : 1

on run
	try
		my main()
	on error errMsg number errNum
		my releaseWindow()
		if errNum is not -128 then display alert "Super Session failed" message errMsg as warning
	end try
end run

on main()
	set parentPath to my readPref("path", POSIX path of (path to desktop folder))
	if not my pathExists(parentPath) then set parentPath to POSIX path of (path to desktop folder)
	set defPrefix to my readPref("prefix", "SHOT")
	set defCount to my readPref("subnumber", "10")
	set wantNumbering to my clampInt(my prefInt("numbering", 2), 1, 3)
	my setSeparators(my clampInt(my prefInt("separators", 1), 1, 4))
	set wantMode to my prefInt("mode", 1)
	set wantNaming to my prefInt("filenaming", 3) -- fresh start: job_folder_counter
	set rowParents to {}
	set rowNames to {}
	set rowCounts to {}
	set rowLists to {}
	set modalCode to 0

	-- Capture One runs scripts in a background osascript process; Cocoa UI must run on the main thread
	if (current application's NSThread's isMainThread()) as boolean then
		my showWindow:(missing value)
	else
		my performSelectorOnMainThread:"showWindow:" withObject:(missing value) waitUntilDone:true
	end if
	my releaseWindow()
	if modalCode is not 1 then return

	if prelightName is not "" then
		set firstFolder to prelightName
	else if rShotNames is {} then
		set firstFolder to rawName
	else
		set firstFolder to my lastComponent(item 1 of rShotNames)
	end if
	set captureFormat to my replaceText(my replaceText(item rNaming of captureFormats, "[4 Digit Counter]", "[" & rCounter & " Digit Counter]"), "]_[", "]" & partSep & "[")
	-- [Name] (Capture One's capture name) is the job, or the date for date_folder_counter
	set captureName to rJob
	if rNaming is 5 then set captureName to rDate
	set copyrightNote to my buildSession((POSIX file parentPath) as alias, rSession, captureName, rPhotog, rShotNames, captureFormat)

	---------- REMEMBER SETTINGS ----------
	my writePref("path", parentPath)
	my writePref("job", rJob) -- client + job combined
	my writePref("client", rClientRaw)
	my writePref("jobname", rJobRaw)
	my writePref("dateformat", rDateFmt)
	if askPhotographer then my writePref("photographer", rPhotog)
	my writePref("parents", rParentsText) -- "" when the checkbox is off
	my writePref("parentstext", rParentsField)
	my writePref("subtext", rSubField)
	if subOn then
		my writePref("subfolders", "1")
	else
		my writePref("subfolders", "0")
	end if
	my writePref("filenaming", rNaming as text)
	my writePref("counterdigits", rCounter as text)
	my writePref("separators", sepStyle as text)
	my writePref("shotfolders", rShotsOn as text)
	if rAppend then
		my writePref("appendlist", "1")
	else
		my writePref("appendlist", "0")
	end if
	if prelightName is "" then
		my writePref("prelight", "0")
	else
		my writePref("prelight", "1")
	end if
	my writePref("prelightname", rPrelightField)
	set fnames to {rawName, selectsName, outputName, trashName, ""}
	if extraFolders is not {} then set item 5 of fnames to item 1 of extraFolders
	repeat with i from 1 to 5
		my writePref(item i of folderKeys, item i of fnames)
	end repeat
	if (count of rGroups) > 0 then
		set {x, lastPrefix, lastCount} to last item of rGroups
		my writePref("prefix", lastPrefix)
		my writePref("subnumber", lastCount as text)
		my writePref("digits", rDigits as text)
		my writePref("mode", rMode as text)
		if (count of rGroups) > 1 then my writePref("numbering", rNumbering as text)
	else
		my writePref("subnumber", "0")
	end if

	set the clipboard to rSession
	display notification "Capture into " & firstFolder & copyrightNote with title "Session " & rSession & " ready"
end main

---------- WINDOW ----------
on showWindow:arg
	set nsApp to current application's NSApplication's sharedApplication()
	-- accessory: the background osascript process may own windows and come to the front
	nsApp's setActivationPolicy:1
	my loadParentList()
	set winH to 818 + ((my visibleParentRows()) - 1) * 30
	if askPhotographer then set winH to winH + 32
	set cursorTop to 20
	set w to current application's NSWindow's alloc()'s initWithContentRect:{{0, 0}, {640, winH}} styleMask:3 backing:2 defer:false
	w's setTitle:("New Super Session " & scriptVersion)
	w's setReleasedWhenClosed:false
	w's setDelegate:me
	w's setLevel:3 -- floating, stays above Capture One
	w's setAutorecalculatesKeyViewLoop:true -- Tab also reaches parent fields added later
	set win to w
	set v to w's contentView()

	-- client first (the broader one), then the job; together they form the job part of the names
	set y to my nextRow(24)
	my addLabel(v, "Client:", y)
	set fClient to my addField(v, my readPref("client", ""), 165, y, 455)
	fClient's setPlaceholderString:"e.g. Nike"

	set y to my nextRow(24)
	my addLabel(v, "Job name:", y)
	set fJob to my addField(v, my readPref("jobname", my readPref("job", "")), 165, y, 455)
	fJob's setPlaceholderString:"e.g. Air Max campaign"

	if askPhotographer then
		set y to my nextRow(24)
		my addLabel(v, "Photographer:", y)
		set fPhotog to my addField(v, my readPref("photographer", ""), 165, y, 455)
		fPhotog's setPlaceholderString:"for copyright metadata (needs Capture One Studio; empty = skip)"
	end if

	set y to my nextRow(24)
	my addLabel(v, "Location:", y)
	set fLocation to current application's NSTextField's labelWithString:""
	fLocation's setFrame:{{165, y + 3}, {345, 20}}
	fLocation's setLineBreakMode:5 -- truncate in the middle
	v's addSubview:fLocation
	set b to current application's NSButton's buttonWithTitle:"Choose…" target:me action:"chooseLocation:"
	b's setFrame:{{515, y - 4}, {110, 32}}
	v's addSubview:b
	my showLocation()

	-- session folder names; the settings at the top of the script are the defaults
	set y to my nextRow(24)
	my addLabel(v, "Session folders:", y)
	set fFolders to {}
	set defaultNames to {rawName, selectsName, outputName, trashName, ""}
	if extraFolders is not {} then set item 5 of defaultNames to item 1 of extraFolders
	repeat with i from 1 to 5
		set f to my addField(v, my readPref(item i of folderKeys, item i of defaultNames), 165 + (i - 1) * 92, y, 87)
		(f's setPlaceholderString:(item i of defaultNames))
		(f's setToolTip:((item i of folderRoles) & " folder" & item i of folderTips))
		set end of fFolders to f
	end repeat

	set y to my nextRow(24)
	my addLabel(v, "Date format:", y)
	set fmt to my readPref("dateformat", "YYYY-MM-DD")
	set fDateFmt to my addField(v, fmt, 165, y, 130)
	fDateFmt's setToolTip:"Tokens: YYYY  YY  MMM (Jan)  MM  DD — e.g. YYMMDD, YYYY-MM-DD. Any separator becomes the date separator chosen below"
	my addLabelAt(v, "Date:", 315, y, 45)
	set fDate to my addField(v, my formatToday(my dashOnly(fmt)), 360, y, 140)

	set y to my nextRow(24)
	my addLabel(v, "Separator logic:", y)
	set rbSep to {}
	set sepTitles to {"ISO 8601", "All dashes", "All underscores", "ISO 8601"}
	repeat with i from 1 to 4
		set rb to (current application's NSButton's radioButtonWithTitle:(item i of sepTitles) target:me action:"sepChanged:")
		(rb's setFrame:{{item i of {165, 265, 370, 505}, y + 1}, {item i of {95, 100, 130, 110}, 22}})
		if i is 4 then
			-- upside down, as it should be; circle drawn on the right so the turn puts it on the left
			(rb's setImagePosition:3)
			rb's sizeToFit()
			set {{fx0, fy0}, {bw, bh}} to rb's frame()
			(rb's setFrame:{{505, y + 1}, {bw, 22}})
			(rb's setFrameCenterRotation:180)
		end if
		(rb's setTag:i)
		if i is sepStyle then (rb's setState:1)
		(v's addSubview:rb)
		set end of rbSep to rb
	end repeat

	-- prelight: a first capture folder inside RAW; the setting at the top is the default name
	set y to my nextRow(24)
	set cbPrelight to current application's NSButton's checkboxWithTitle:"Prelight folder:" target:me action:"prelightToggled:"
	cbPrelight's setFrame:{{18, y + 1}, {145, 22}}
	set defPrelight to prelightName
	if defPrelight is "" then set defPrelight to "_prelight"
	set onPref to my readPref("prelight", "")
	if onPref is "1" or (onPref is "" and prelightName is not "") then cbPrelight's setState:1
	v's addSubview:cbPrelight
	set fPrelight to my addField(v, my readPref("prelightname", defPrelight), 165, y, 200)
	fPrelight's setPlaceholderString:defPrelight
	fPrelight's setToolTip:"Created inside RAW and used as the first capture folder"
	fPrelight's setEnabled:((cbPrelight's state()) as integer is 1)

	-- everything above the parent folders stays pinned to the top when the window grows
	repeat with sub in (v's subviews() as list)
		(sub's setAutoresizingMask:8)
	end repeat

	-- parent folders: one field per folder, + adds one below, − removes it.
	-- The area grows the window up to 5 rows, then scrolls.
	set vis to my visibleParentRows()
	set y to my nextRow(24 + (vis - 1) * 30)
	set cbParents to current application's NSButton's checkboxWithTitle:"Parent folders:" target:me action:"parentsToggled:"
	cbParents's setFrame:{{18, y + (vis - 1) * 30 + 1}, {145, 22}}
	cbParents's setAutoresizingMask:8
	if my readPref("parents", "") is not "" then cbParents's setState:1
	v's addSubview:cbParents
	set parentScroll to current application's NSScrollView's alloc()'s initWithFrame:{{162, y - 3}, {463, vis * 30}}
	parentScroll's setDrawsBackground:false
	parentScroll's setBorderType:0
	parentScroll's setHasVerticalScroller:true
	parentScroll's setAutohidesScrollers:true
	parentScroll's setAutoresizingMask:16 -- grows with the window
	set parentDoc to current application's NSView's alloc()'s initWithFrame:{{0, 0}, {455, vis * 30}}
	parentScroll's setDocumentView:parentDoc
	v's addSubview:parentScroll
	my rebuildParentRows(0)

	set y to my nextRow(130)
	set cbShots to current application's NSButton's checkboxWithTitle:"Shot folders:" target:me action:"shotsToggled:"
	cbShots's setFrame:{{18, y + 104}, {145, 22}}
	if my readPref("shotfolders", "") is "" then
		-- no saved choice yet: 0 shots = no shot folders
		if defCount is not "0" then cbShots's setState:1
	else if my readPref("shotfolders", "") is "1" then
		cbShots's setState:1
	end if
	v's addSubview:cbShots
	-- one number for every row, applied as you type
	set allLbl to my addLabelAt(v, "#", 86, y + 71, 12)
	allLbl's setFont:(current application's NSFont's systemFontOfSize:11)
	set fAllCounts to my addField(v, "", 98, y + 71, 45)
	fAllCounts's setTag:300
	fAllCounts's setToolTip:"Number of shots for every row in the table"
	-- a pasted list of folder names for the selected row
	set btnPaste to current application's NSButton's buttonWithTitle:"Paste list…" target:me action:"pasteList:"
	btnPaste's setFrame:{{12, y + 34}, {145, 32}}
	btnPaste's setToolTip:"Paste folder names, one per line, for the selected row"
	v's addSubview:btnPaste
	-- radio buttons sharing a superview and an action work as one group
	set rbAppend to current application's NSButton's radioButtonWithTitle:"Append" target:me action:"shotsToggled:"
	rbAppend's setFrame:{{18, y + 12}, {70, 18}}
	rbAppend's setToolTip:"Pasted names go after the shot number: SHOT01_name"
	set rbReplace to current application's NSButton's radioButtonWithTitle:"Replace" target:me action:"shotsToggled:"
	rbReplace's setFrame:{{88, y + 12}, {75, 18}}
	rbReplace's setToolTip:"Pasted names are the shot folders: no prefix, no number"
	repeat with rb in {rbAppend, rbReplace}
		((contents of rb)'s setControlSize:1)
		((contents of rb)'s setFont:(current application's NSFont's systemFontOfSize:11))
		(v's addSubview:(contents of rb))
	end repeat
	if my readPref("appendlist", "1") is "1" then
		rbAppend's setState:1
	else
		rbReplace's setState:1
	end if
	set sv to current application's NSScrollView's alloc()'s initWithFrame:{{165, y}, {455, 130}}
	sv's setHasVerticalScroller:true
	sv's setBorderType:2
	set tbl to current application's NSTableView's alloc()'s initWithFrame:{{0, 0}, {455, 130}}
	repeat with c in {{"parent", "Parent", 130, false}, {"name", "Shot prefix", 165, true}, {"count", "Shots", 60, true}, {"list", "List", 75, false}}
		set {cid, ctitle, cw, ced} to contents of c
		set col to (current application's NSTableColumn's alloc()'s initWithIdentifier:cid)
		(col's headerCell()'s setStringValue:ctitle)
		(col's setWidth:cw)
		(col's setEditable:ced)
		(tbl's addTableColumn:col)
	end repeat
	tbl's setAllowsColumnReordering:false
	tbl's setAllowsMultipleSelection:true -- ⌘A or ⌘/⇧-click: paste one list into several rows
	tbl's setColumnAutoresizingStyle:0 -- sizeColumns fits them to their content
	tbl's setUsesAlternatingRowBackgroundColors:true
	tbl's setDataSource:me
	tbl's setDelegate:me
	tbl's setTarget:me
	tbl's setAction:"tableClicked:"
	sv's setDocumentView:tbl
	v's addSubview:sv

	set y to my nextRow(16)
	set hint to my addLabelAt(v, "Click a cell to edit, or select one or more rows to add a pasted list.", 165, y - 3, 455)
	hint's setFont:(current application's NSFont's systemFontOfSize:10)
	hint's setTextColor:(current application's NSColor's secondaryLabelColor())

	set y to my nextRow(26)
	my addLabel(v, "Shot folder count:", y)
	set pNumbering to my addPopup(v, 165, y, 455)

	set y to my nextRow(26)
	my addLabel(v, "Shot folder naming:", y)
	set pMode to my addPopup(v, 165, y, 320)
	my addLabelAt(v, "digits:", 495, y, 50)
	set pDigits to my addPopup(v, 545, y, 75)
	pDigits's addItemsWithTitles:{"1", "2", "3"}
	pDigits's selectItemAtIndex:((my clampInt(my prefInt("digits", 2), 1, 3)) - 1)

	set y to my nextRow(26)
	my addLabel(v, "Capture file naming:", y)
	set pNaming to my addPopup(v, 165, y, 320)
	my addLabelAt(v, "digits:", 495, y, 50)
	set pCounter to my addPopup(v, 545, y, 75)
	pCounter's addItemsWithTitles:{"1", "2", "3", "4", "5", "6"}
	pCounter's selectItemAtIndex:((my clampInt(my prefInt("counterdigits", 4), 1, 6)) - 1)

	-- the end result: what the files will be called
	set y to my nextRow(32)
	set fFileName to current application's NSTextField's labelWithString:""
	fFileName's setFrame:{{20, y}, {600, 30}}
	fFileName's setAlignment:(current application's NSTextAlignmentCenter)
	fFileName's setFont:(current application's NSFont's monospacedSystemFontOfSize:17 weight:0.4)
	fFileName's setTextColor:(current application's NSColor's controlAccentColor())
	fFileName's setSelectable:true
	fFileName's setLineBreakMode:5
	v's addSubview:fFileName

	-- live preview fills the space down to the buttons
	set ph to winH - cursorTop - 60
	set psv to current application's NSScrollView's alloc()'s initWithFrame:{{20, 60}, {600, ph}}
	psv's setHasVerticalScroller:true
	psv's setBorderType:2
	set previewView to current application's NSTextView's alloc()'s initWithFrame:{{0, 0}, {590, ph}}
	previewView's setEditable:false
	previewView's setFont:(current application's NSFont's monospacedSystemFontOfSize:11 weight:0)
	previewView's setTextContainerInset:{8, 8}
	-- long folder names scroll sideways instead of wrapping
	previewView's textContainer()'s setWidthTracksTextView:false
	previewView's textContainer()'s setContainerSize:{10000, 10000}
	previewView's setHorizontallyResizable:true
	previewView's setMaxSize:{10000, 10000}
	psv's setHasHorizontalScroller:true
	psv's setDocumentView:previewView
	v's addSubview:psv

	set cancelBtn to my addButton(v, "Cancel", 395, 100, 0)
	cancelBtn's setKeyEquivalent:(character id 27)
	set createBtn to my addButton(v, "Create Session", 495, 130, 1)
	createBtn's setKeyEquivalent:return

	my syncRows()
	my refresh()
	w's |center|()
	nsApp's activateIgnoringOtherApps:true
	w's makeKeyAndOrderFront:me
	w's orderFrontRegardless()
	w's makeFirstResponder:fClient
	nsApp's runModalForWindow:w
	w's orderOut:me
end showWindow:

-- Every edit lands here; recomputes names, checks for problems, updates popups and preview.
on refresh()
	set problem to ""
	-- session name part: client and job, joined like any other part; either may be empty
	set rClientRaw to my trim((fClient's stringValue()) as text)
	set rJobRaw to my trim((fJob's stringValue()) as text)
	set cl to my spacesToDashes(rClientRaw)
	set jb to my spacesToDashes(rJobRaw)
	if cl is "" then
		set rJob to jb
	else if jb is "" then
		set rJob to cl
	else
		set rJob to cl & partSep & jb
	end if
	set rDateFmt to my dashOnly((fDateFmt's stringValue()) as text)
	set rDate to my dashOnly((fDate's stringValue()) as text)
	set rSession to rDate & partSep & rJob
	if askPhotographer then
		set rPhotog to my trim((fPhotog's stringValue()) as text)
	else
		set rPhotog to ""
	end if
	set rParentsField to my joinedList(parentList)
	set rSubField to my joinedList(subList)
	set rParentsText to my activeParentsText()
	set rDigits to ((pDigits's indexOfSelectedItem()) as integer) + 1
	set rCounter to ((pCounter's indexOfSelectedItem()) as integer) + 1

	if not my pathExists(parentPath) then my addProblem("The location folder doesn't exist any more. Choose another.")
	if rJob is "" then
		my addProblem("Enter a client or a job name.")
		-- until one is typed, examples show a stand-in (Create Session stays off)
		set rJob to "client" & partSep & "job"
		set rSession to rDate & partSep & rJob
	end if
	if rJob contains "/" or rJob contains ":" then my addProblem("Please don't use / or : in the client or job name.")
	if rDateFmt is "" then my addProblem("Enter a date format.")
	if rDate is "" then my addProblem("Enter a date.")
	-- session folder names (00-04); the script's properties are what buildSession uses
	set fnames to {}
	repeat with f in fFolders
		set end of fnames to my trim(((contents of f)'s stringValue()) as text)
	end repeat
	set {rawName, selectsName, outputName, trashName, docsName} to fnames
	set rPrelightField to my trim((fPrelight's stringValue()) as text)
	if (cbPrelight's state()) as integer is 1 then
		set prelightName to rPrelightField
		if prelightName is "" then my addProblem("Enter a name for the prelight folder, or turn it off.")
		if prelightName contains "/" or prelightName contains ":" then my addProblem("Please don't use / or : in the prelight folder name.")
	else
		set prelightName to ""
	end if
	if docsName is "" then
		set extraFolders to {}
	else
		set extraFolders to {docsName}
	end if
	set seen to {}
	repeat with i from 1 to 5
		set nm to item i of fnames
		if nm is "" and i < 5 then my addProblem("The " & item i of folderRoles & " folder needs a name.")
		if nm contains "/" or nm contains ":" then my addProblem("Please don't use / or : in folder names.")
		considering case
			if nm is not "" and {nm} is in seen then my addProblem("Two session folders are both named “" & nm & "”.")
		end considering
		set end of seen to nm
	end repeat

	if rJob is not "" and rDate is not "" then
		if my pathExists(parentPath & rSession & "/") then my addProblem("A folder named “" & rSession & "” already exists there. Change the date or the job name.")
	end if

	-- shot groups {parent, shot name, count} from the table
	set parentNames to {}
	try
		set parentNames to my activeParentPaths()
	on error msg
		my addProblem(msg)
	end try
	set n to count of parentNames
	set rGroups to {}
	set rGroupLists to {}
	set rAppend to ((rbAppend's state()) as integer is 1)
	set shotsOn to ((cbShots's state()) as integer is 1)
	if shotsOn then
		set rShotsOn to 1
	else
		set rShotsOn to 0
	end if
	tbl's setEnabled:shotsOn
	fAllCounts's setEnabled:shotsOn
	btnPaste's setEnabled:(shotsOn and (tbl's numberOfSelectedRows()) as integer > 0)
	set anyList to false
	repeat with L in rowLists
		if contents of L is not {} then set anyList to true
	end repeat
	rbAppend's setEnabled:(shotsOn and anyList)
	rbReplace's setEnabled:(shotsOn and anyList)
	if not shotsOn then
		-- no numbered shot folders
	else if n is 0 then
		if (count of rowNames) > 0 then
			set nm to my trim(item 1 of rowNames)
			set L to my cleanList(item 1 of rowLists)
			if L is {} then
				set c to my parseCount(item 1 of rowCounts, 1, "Number of shots must be a whole number from 1 to 999.")
			else
				set c to count of L
			end if
			if nm contains "/" or nm contains ":" then my addProblem("Please don't use / or : in the shot prefix.")
			set rGroups to {{"", nm, c}}
			set rGroupLists to {L}
		end if
	else
		-- one table row per direct parent (with subfolders: per subfolder, shared by every parent)
		repeat with i from 1 to n
			set p to item i of parentNames
			set r to my posOfText(my lastComponent(p), rowParents)
			if r > 0 and r ≤ (count of rowNames) then
				set nm to my trim(item r of rowNames)
				set L to my cleanList(item r of rowLists)
				if L is {} then
					set c to my parseCount(item r of rowCounts, 1, my lastComponent(p) & ": number of shots must be a whole number from 1 to 999.")
				else
					set c to count of L
				end if
				if nm contains "/" or nm contains ":" then my addProblem(my lastComponent(p) & ": please don't use / or : in the shot prefix.")
				set end of rGroups to {p, nm, c}
				set end of rGroupLists to L
			end if
		end repeat
	end if
	set ng to count of rGroups

	-- shot numbering (only matters with 2+ parents). Menu order: restart (2), per shot name (1),
	-- across all (3); the ids are what numberGroups and the saved setting use
	set numTitles to {"Restart in each parent folder", "Continue per shot prefix", "Continue across all parent folders"}
	if ng > 1 then
		set rNumbering to wantNumbering
		set titles to {}
		repeat with k from 1 to 3
			set end of titles to item k of numTitles & "  (" & my rangePreview(my numberGroups(my numberInput(rGroups), item k of numberingOrder), rDigits) & ")"
		end repeat
	else
		set rNumbering to 2
		set titles to numTitles
	end if
	my fillPopup(pNumbering, titles, my posOf(rNumbering, numberingOrder))
	pNumbering's setEnabled:(ng > 1)

	-- shot folder naming; mode ids: 1 shot, 2 job_shot, 3 parent_shot, 4 job_parent_shot, 5 date_job_parent_shot, 6 date_job_shot
	if ng > 0 then
		set {p1, n1, s1, c1} to item 1 of my numberGroups(my numberInput(rGroups), rNumbering)
		set L1 to item 1 of rGroupLists
		if L1 is {} then
			set firstShot to n1 & my pad(s1, rDigits)
		else if rAppend then
			set firstShot to n1 & my pad(s1, rDigits) & partSep & item 1 of L1
		else
			set firstShot to item 1 of L1
		end if
		set ids to {1, 2}
		set labels to {"shot  (" & firstShot & ")", "job_shot  (" & rJob & partSep & firstShot & ")"}
		if n > 0 then
			set ids to ids & {3, 4, 5, 6}
			set labels to labels & {"parent_shot  (" & my pName(p1) & partSep & firstShot & ")", ¬
				"job_parent_shot  (" & rJob & partSep & my pName(p1) & partSep & firstShot & ")", ¬
				"date_job_parent_shot  (" & rDate & partSep & rJob & partSep & my pName(p1) & partSep & firstShot & ")", ¬
				"date_job_shot  (" & rDate & partSep & rJob & partSep & firstShot & ")"}
		else
			set end of ids to 6
			set end of labels to "date_job_shot  (" & rDate & partSep & rJob & partSep & firstShot & ")"
		end if
	else
		set ids to {1}
		set labels to {"(no numbered shot folders)"}
	end if
	set modeIds to ids
	set rMode to my pickId(wantMode, ids)
	my fillPopup(pMode, labels, my posOf(rMode, ids))
	pMode's setEnabled:(ng > 0)
	pDigits's setEnabled:(ng > 0)

	if ng > 0 then
		set rShotNames to my makeShotNames(rGroups, rDigits, rNumbering, rMode, rJob, rSession)
		-- pasted names can repeat; two folders with the same path would merge
		set seen to {}
		set dupes to {}
		considering case
			repeat with x in rShotNames
				set x to contents of x
				if {x} is in seen then
					if {x} is not in dupes then set end of dupes to x
				else
					set end of seen to x
				end if
			end repeat
		end considering
		repeat with x in dupes
			my addProblem("Two shot folders would both be named “" & x & "”. Check the pasted list.")
		end repeat
	else
		-- shot folders off: capture into the parent folders, or straight into RAW
		set rShotNames to parentNames
	end if

	-- capture file naming, previewed with the first numbered folder; hides options that would
	-- repeat the job (and date) already in the shot folder name
	if rShotNames is {} then
		set previewFolder to rawName
	else
		set previewFolder to my lastComponent(item 1 of rShotNames)
	end if
	set firstCounter to my pad(1, rCounter)
	set ids to {1, 2, 6}
	set labels to {"folder  (" & previewFolder & partSep & firstCounter & ")", ¬
		"job  (" & rJob & partSep & firstCounter & ")", ¬
		"date_job  (" & rSession & partSep & firstCounter & ")"}
	if not (ng > 0 and rMode is in {2, 4, 5, 6}) then
		set ids to ids & {3, 4}
		set labels to labels & {"job_folder  (" & rJob & partSep & previewFolder & partSep & firstCounter & ")", ¬
			"date_job_folder  (" & rSession & partSep & previewFolder & partSep & firstCounter & ")"}
	end if
	-- date in front of the folder name, unless the shot folder name already starts with the date
	if not (ng > 0 and rMode is in {5, 6}) then
		set end of ids to 5
		set end of labels to "date_folder  (" & rDate & partSep & previewFolder & partSep & firstCounter & ")"
	end if
	set namingIds to ids
	set rNaming to my pickId(wantNaming, ids)
	my fillPopup(pNaming, labels, my posOf(rNaming, ids))

	-- the file name, large: first capture in the first shot folder
	if rShotNames is {} then
		set ffShot to rawName
	else
		set ffShot to my lastComponent(item 1 of rShotNames)
	end if
	set ffC to my pad(1, rCounter)
	set ffName to item rNaming of {ffShot & partSep & ffC, rJob & partSep & ffC, rJob & partSep & ffShot & partSep & ffC, rSession & partSep & ffShot & partSep & ffC, rDate & partSep & ffShot & partSep & ffC, rSession & partSep & ffC}
	fFileName's setStringValue:ffName
	fFileName's setToolTip:ffName
	my fitWidth()

	if problem is "" then
		my setPreviewWrap(false)
		set summ to my summaryText(rSession, parentPath, rShotNames, rNaming, rJob, rCounter, rPhotog)
		set warn to my sameNameWarning()
		if warn is "" then
			previewView's setString:summ
			previewView's setTextColor:(current application's NSColor's labelColor())
		else
			-- a note, not a problem: Create Session stays available
			previewView's setString:(warn & return & return & summ)
			previewView's setTextColor:(current application's NSColor's labelColor())
			set summLen to ((current application's NSString's stringWithString:summ)'s |length|()) as integer
			set warnLen to ((current application's NSString's stringWithString:warn)'s |length|()) as integer
			previewView's setTextColor:(current application's NSColor's systemOrangeColor()) range:{0, warnLen}
		end if
	else
		my setPreviewWrap(true) -- problem messages wrap; the folder tree scrolls sideways
		previewView's setString:problem
		previewView's setTextColor:(current application's NSColor's systemRedColor())
	end if
	createBtn's setEnabled:(problem is "")
	if (tbl's editedRow()) as integer < 0 then my sizeColumns() -- not while a cell is being typed in
	my fitPreview()
	my updateSepTips()
end refresh

-- Separator tooltips: a fixed example file name (today's date, client, job name, DAY01,
-- SHOT01, 0001) written with each separator style
on updateSepTips()
	if (count of rbSep) < 4 then return
	set keep to sepStyle
	repeat with s from 1 to 4
		my setSeparators(s)
		set t to my dashOnly(my formatToday("YYYY-MM-DD")) & partSep & "client" & partSep & my spacesToDashes("job name") & partSep & "DAY01" & partSep & "SHOT01" & partSep & "0001"
		set t to t & linefeed & item s of {"By the book.", "At least you're consistent.", "Acceptable.", "Yes, I am judging you."}
		-- keep it on one line: macOS wraps tooltips at spaces and hyphens, so use the
		-- non-breaking versions (they look the same)
		set t to my replaceText(my replaceText(t, space, character id 160), "-", character id 8209)
		((item s of rbSep)'s setToolTip:t)
	end repeat
	my setSeparators(keep)
end updateSepTips

on setSeparators(style)
	set sepStyle to style
	if style is 1 then
		set {partSep, innerSep, otherSep, dateSep} to {"_", "-", "_", "-"}
	else if style is 2 then
		set {partSep, innerSep, otherSep, dateSep} to {"-", "-", "_", "-"}
	else if style is 3 then
		set {partSep, innerSep, otherSep, dateSep} to {"_", "_", "-", "_"}
	else
		set {partSep, innerSep, otherSep, dateSep} to {"-", "_", "-", "_"}
	end if
end setSeparators

on sepChanged:sender
	my setSeparators((sender's tag()) as integer)
	if sepStyle is 1 then
		-- ISO 8601 also means an ISO date format; the date entered is kept, converted to
		-- YYYY-MM-DD (today if it can't be read)
		set iso to my isoFromDate((fDate's stringValue()) as text, (fDateFmt's stringValue()) as text)
		if iso is "" then set iso to my formatToday("YYYY-MM-DD")
		fDateFmt's setStringValue:"YYYY-MM-DD"
		fDate's setStringValue:iso
	else
		-- keep the date format's order, but use this style's date separator in it and in the date
		fDateFmt's setStringValue:(my dashOnly((fDateFmt's stringValue()) as text))
		fDate's setStringValue:(my dashOnly((fDate's stringValue()) as text))
	end if
	my refresh()
end sepChanged:

-- the level 1 parent folder list, or "" while the checkbox is off
on activeParentsText()
	if (cbParents's state()) as integer is 1 then return my joinedList(parentList)
	return ""
end activeParentsText

-- Relative parent paths inside RAW: {"Studio", "Rooftop"}, or with subfolders every
-- combination {"Studio/DAY1", "Studio/DAY2", "Rooftop/DAY1", ...}. Errors on invalid names.
on activeParentPaths()
	set l1 to my splitParents(my activeParentsText())
	if l1 is {} or not subOn then return l1
	set l2 to my splitParents(my joinedList(subList))
	if l2 is {} then return l1
	set out to {}
	repeat with a in l1
		repeat with b in l2
			set end of out to (contents of a) & "/" & (contents of b)
		end repeat
	end repeat
	return out
end activeParentPaths

-- "Studio/DAY1" as it appears inside a folder or file name: "Studio_DAY1"
on pName(p)
	return my replaceText(p, "/", partSep)
end pName

-- "Studio, Rooftop" from a list of fields, empty ones left out
on joinedList(theList)
	set out to {}
	repeat with x in theList
		set x to my trim(contents of x)
		if x is not "" then set end of out to x
	end repeat
	set AppleScript's text item delimiters to ", "
	set t to out as text
	set AppleScript's text item delimiters to ""
	return t
end joinedList

on splitSaved(t)
	set AppleScript's text item delimiters to ","
	set parts to text items of t
	set AppleScript's text item delimiters to ""
	set out to {}
	repeat with x in parts
		set x to my trim(contents of x)
		if x is not "" then set end of out to x
	end repeat
	if out is {} then set out to {""}
	return out
end splitSaved

-- parent and subfolder lists from the saved comma text (kept while the checkboxes are off)
on loadParentList()
	set parentList to my splitSaved(my readPref("parentstext", my readPref("parents", "")))
	set subList to my splitSaved(my readPref("subtext", ""))
	set subOn to (my readPref("subfolders", "0") is "1")
end loadParentList

-- rows in the parent area: level 1 fields on the left; on the right the Subfolders
-- checkbox with the level 2 fields below it
on parentRows()
	set n1 to count of parentList
	set n2 to 1
	if subOn then set n2 to 1 + (count of subList)
	if n2 > n1 then return n2
	return n1
end parentRows

on visibleParentRows()
	set n to my parentRows()
	if n > 5 then return 5
	return n
end visibleParentRows

-- Redraws both parent columns, resizing the window to fit;
-- focusTag > 0 puts the cursor in that field (101… level 1, 201… level 2)
on rebuildParentRows(focusTag)
	win's makeFirstResponder:(missing value) -- finish any typing in a field about to be removed
	set areaH to (my visibleParentRows()) * 30
	set {{sx, sy}, {sw, sh}} to parentScroll's frame()
	set delta to areaH - sh
	if delta is not 0 then
		set {{fx, fy}, {fw, fh}} to win's frame()
		win's setFrame:{{fx, fy - delta}, {fw, fh + delta}} display:true
	end if
	set isOn to ((cbParents's state()) as integer is 1)
	set docH to (my parentRows()) * 30
	if docH < areaH then set docH to areaH
	parentDoc's setSubviews:{}
	parentDoc's setFrameSize:{460, docH}

	-- left column: level 1
	set n to count of parentList
	repeat with i from 1 to n
		my addFolderRow(item i of parentList, 3, docH - 27 - (i - 1) * 30, 100 + i, i, n, isOn, "addParent:", "removeParent:", "e.g. Studio, Day 1")
	end repeat

	-- right column: Subfolders checkbox, then level 2
	set cbSub to current application's NSButton's checkboxWithTitle:"Subfolders" target:me action:"subToggled:"
	cbSub's setFrame:{{234, docH - 26}, {200, 22}}
	if subOn then cbSub's setState:1
	cbSub's setEnabled:isOn
	cbSub's setToolTip:"A second folder level inside every parent folder, e.g. Studio/DAY1"
	parentDoc's addSubview:cbSub
	if subOn then
		set n to count of subList
		repeat with i from 1 to n
			my addFolderRow(item i of subList, 235, docH - 27 - i * 30, 200 + i, i, n, isOn, "addSub:", "removeSub:", "e.g. DAY1, Look 1")
		end repeat
	end if

	if focusTag > 0 and isOn then
		set f to parentDoc's viewWithTag:focusTag
		if f is not missing value then
			f's scrollRectToVisible:(f's |bounds|())
			win's makeFirstResponder:f
		end if
	end if
end rebuildParentRows

-- one field with + and − (− only when there is more than one row)
on addFolderRow(t, x, ry, fieldTag, i, n, isOn, addAction, removeAction, hint)
	set f to current application's NSTextField's textFieldWithString:t
	f's setFrame:{{x, ry}, {165, 24}}
	f's setTag:fieldTag
	f's setDelegate:me
	-- (no placeholder text in parent and subfolder fields)
	f's setEnabled:isOn
	parentDoc's addSubview:f
	set b to current application's NSButton's buttonWithImage:(current application's NSImage's imageNamed:"NSAddTemplate") target:me action:addAction
	b's setBezelStyle:10
	b's setFrame:{{x + 170, ry}, {24, 24}}
	b's setTag:i
	b's setEnabled:isOn
	b's setToolTip:"Add a folder below"
	parentDoc's addSubview:b
	if n > 1 then
		set b to current application's NSButton's buttonWithImage:(current application's NSImage's imageNamed:"NSRemoveTemplate") target:me action:removeAction
		b's setBezelStyle:10
		b's setFrame:{{x + 197, ry}, {24, 24}}
		b's setTag:i
		b's setEnabled:isOn
		b's setToolTip:"Remove this folder"
		parentDoc's addSubview:b
	end if
end addFolderRow

on insertAfter(theList, i)
	if i ≥ (count of theList) then return theList & {""}
	return (items 1 thru i of theList) & {""} & (items (i + 1) thru -1 of theList)
end insertAfter

on removeAt(theList, i)
	set n to count of theList
	if n < 2 then return theList
	if i is 1 then return items 2 thru -1 of theList
	if i is n then return items 1 thru -2 of theList
	return (items 1 thru (i - 1) of theList) & (items (i + 1) thru -1 of theList)
end removeAt

on parentsChanged(focusTag)
	my rebuildParentRows(focusTag)
	my syncRows()
	my refresh()
end parentsChanged

on addParent:sender
	set i to (sender's tag()) as integer
	set parentList to my insertAfter(parentList, i)
	my parentsChanged(101 + i)
end addParent:

on removeParent:sender
	set parentList to my removeAt(parentList, (sender's tag()) as integer)
	my parentsChanged(0)
end removeParent:

on addSub:sender
	set i to (sender's tag()) as integer
	set subList to my insertAfter(subList, i)
	my parentsChanged(201 + i)
end addSub:

on removeSub:sender
	set subList to my removeAt(subList, (sender's tag()) as integer)
	my parentsChanged(0)
end removeSub:

on subToggled:sender
	set subOn to ((sender's state()) as integer is 1)
	if subOn then
		my parentsChanged(201)
	else
		my parentsChanged(0)
	end if
end subToggled:

on prelightToggled:sender
	set isOn to ((cbPrelight's state()) as integer is 1)
	fPrelight's setEnabled:isOn
	if isOn then win's makeFirstResponder:fPrelight
	my refresh()
end prelightToggled:

on shotsToggled:sender
	my refresh()
end shotsToggled:

on parentsToggled:sender
	if (cbParents's state()) as integer is 1 then
		my parentsChanged(101)
	else
		my parentsChanged(0)
	end if
end parentsToggled:

-- Rebuilds the table rows when the parent folders change; keeps what was typed per row
on syncRows()
	try
		set names to my activeParentPaths()
	on error
		return -- invalid names: refresh shows the problem, keep the rows
	end try
	-- table rows are keyed by the direct parent; with subfolders that is each subfolder once
	set keys to {}
	repeat with p in names
		set k to my lastComponent(contents of p)
		if my posOfText(k, keys) is 0 then set end of keys to k
	end repeat
	set names to keys
	if (count of names) is 0 then set names to {""}
	considering case
		if names is rowParents then return
	end considering
	set newNames to {}
	set newCounts to {}
	set newLists to {}
	repeat with i from 1 to count of names
		-- a pasted list belongs to its row only; new rows start without one
		if i ≤ (count of rowLists) then
			set end of newLists to item i of rowLists
		else
			set end of newLists to {}
		end if
		if i ≤ (count of rowNames) then
			set nm to item i of rowNames
			set c to item i of rowCounts
		else if i > 1 then
			set nm to item (i - 1) of newNames
			set c to item (i - 1) of newCounts
		else
			set nm to defPrefix
			set c to defCount
		end if
		-- new rows follow the All rows number when one is set
		if i > (count of rowNames) and fAllCounts is not missing value then
			set allT to my trim((fAllCounts's stringValue()) as text)
			if allT is not "" then set c to allT
		end if
		if c is "0" then set c to "10" -- shot folders need at least one shot
		set end of newNames to nm
		set end of newCounts to c
	end repeat
	set rowParents to names
	set rowNames to newNames
	set rowCounts to newCounts
	set rowLists to newLists
	tbl's reloadData()
end syncRows

---------- WINDOW EVENTS ----------
on controlTextDidChange:aNotification
	set obj to aNotification's object()
	if (obj's isEqual:tbl) as boolean then
		-- typing in a table cell: update the preview before the cell is committed
		try
			set r to (tbl's editedRow()) as integer
			set c to (tbl's editedColumn()) as integer
			set t to ((aNotification's userInfo()'s objectForKey:"NSFieldEditor")'s |string|()) as text
			if r ≥ 0 and r < (count of rowNames) then
				if c is 1 then set item (r + 1) of rowNames to t
				if c is 2 then set item (r + 1) of rowCounts to t
			end if
		end try
	else if (obj's isEqual:fDateFmt) as boolean then
		fDate's setStringValue:(my formatToday(my dashOnly((fDateFmt's stringValue()) as text)))
	else if (obj's tag()) as integer is 300 then
		-- number of shots for all rows
		set t to my trim((obj's stringValue()) as text)
		if t is not "" then
			repeat with k from 1 to count of rowCounts
				set item k of rowCounts to t
			end repeat
			tbl's reloadData()
		end if
	else if (obj's tag()) as integer > 200 then
		-- a subfolder field
		set i to ((obj's tag()) as integer) - 200
		if i ≤ (count of subList) then set item i of subList to (obj's stringValue()) as text
		my syncRows()
	else if (obj's tag()) as integer > 100 then
		-- a parent folder field
		set i to ((obj's tag()) as integer) - 100
		if i ≤ (count of parentList) then set item i of parentList to (obj's stringValue()) as text
		my syncRows()
	end if
	my refresh()
end controlTextDidChange:

on popupChanged:sender
	set i to ((sender's indexOfSelectedItem()) as integer) + 1
	if (sender's isEqual:pNumbering) as boolean then set wantNumbering to item i of numberingOrder
	if (sender's isEqual:pMode) as boolean then set wantMode to item i of modeIds
	if (sender's isEqual:pNaming) as boolean then set wantNaming to item i of namingIds
	my refresh()
end popupChanged:

on chooseLocation:sender
	set op to current application's NSOpenPanel's openPanel()
	op's setCanChooseDirectories:true
	op's setCanChooseFiles:false
	op's setCanCreateDirectories:true
	op's setPrompt:"Choose"
	op's setMessage:"Where should the session be created?"
	op's setDirectoryURL:(current application's NSURL's fileURLWithPath:parentPath)
	win's setLevel:0 -- let the panel come in front
	set r to (op's runModal()) as integer
	win's setLevel:3
	if r is 1 then
		set p to (op's |URL|()'s |path|()) as text
		if p does not end with "/" then set p to p & "/"
		set parentPath to p
		my showLocation()
		my refresh()
	end if
end chooseLocation:

-- single click starts editing (cell-based tables normally need a double click)
on tableClicked:sender
	set c to (tbl's clickedColumn()) as integer
	set r to (tbl's clickedRow()) as integer
	if c < 0 or r < 0 then return
	-- ⌘ or ⇧ click: only change the selection
	set flags to (current application's NSApplication's sharedApplication()'s currentEvent()'s modifierFlags()) as integer
	if (flags div 1048576) mod 2 is 1 or (flags div 131072) mod 2 is 1 then return
	set col to item (c + 1) of (tbl's tableColumns() as list)
	if (col's identifier()) as text is "list" then
		-- a click inside a multiple selection pastes into all of it
		set rows to my selectedRows()
		if (r + 1) is not in rows then set rows to {r + 1}
		my openPaste(rows)
	else if c > 0 and my canEdit(col, r + 1) then
		tbl's editColumn:c row:r withEvent:(missing value) |select|:true
	end if
end tableClicked:

-- Fits Parent, Shots and List to their widest text; Shot prefix gets the rest of the width
on sizeColumns()
	set cols to tbl's tableColumns() as list
	set avail to ((tbl's enclosingScrollView()'s contentSize())'s width) as real
	set gap to ((tbl's intercellSpacing())'s width) as real
	set wants to {}
	repeat with col in cols
		set f to (col's dataCell()'s |font|())
		set attrs to (current application's NSDictionary's dictionaryWithObject:f forKey:(current application's NSFontAttributeName))
		set w to ((((current application's NSString's stringWithString:((col's headerCell()'s stringValue()) as text))'s sizeWithAttributes:attrs)'s width) as real) + 12
		repeat with r from 0 to (count of rowNames) - 1
			set t to (my tableView:tbl objectValueForTableColumn:col row:r) as text
			set cw to ((((current application's NSString's stringWithString:t)'s sizeWithAttributes:attrs)'s width) as real) + 10
			if cw > w then set w to cw
		end repeat
		set end of wants to w
	end repeat
	set {wP, wN, wC, wL} to wants
	set wC to my clampInt(wC, 50, 90)
	set wL to my clampInt(wL, 60, 100)
	set spare to avail - wC - wL - 4 * gap
	-- the parent gets what it needs, but leaves the prefix at least 120
	if wP > spare - 120 then set wP to spare - 120
	if wP < 70 then set wP to 70
	set wN to spare - wP
	repeat with k from 1 to 4
		((item k of cols)'s setWidth:(item k of {wP, wN, wC, wL}))
	end repeat
end sizeColumns

-- with a pasted list the count comes from the list, and in replace mode the prefix isn't used
on canEdit(col, i)
	if i > (count of rowLists) then return true
	if item i of rowLists is {} then return true
	set cid to (col's identifier()) as text
	if cid is "count" then return false
	if cid is "name" and not rAppend then return false
	return true
end canEdit

on tableView:tv shouldEditTableColumn:col row:r
	return my canEdit(col, (r as integer) + 1)
end tableView:shouldEditTableColumn:row:

on tableView:tv willDisplayCell:cell forTableColumn:col row:r
	if my canEdit(col, (r as integer) + 1) then
		cell's setTextColor:(current application's NSColor's labelColor())
	else
		cell's setTextColor:(current application's NSColor's tertiaryLabelColor())
	end if
end tableView:willDisplayCell:forTableColumn:row:

on tableViewSelectionDidChange:aNotification
	if btnPaste is missing value then return
	set shotsOn to ((cbShots's state()) as integer is 1)
	btnPaste's setEnabled:(shotsOn and (tbl's numberOfSelectedRows()) as integer > 0)
end tableViewSelectionDidChange:

on numberOfRowsInTableView:tv
	return count of rowNames
end numberOfRowsInTableView:

on tableView:tv objectValueForTableColumn:col row:r
	set i to (r as integer) + 1
	if i > (count of rowNames) then return ""
	set cid to (col's identifier()) as text
	if cid is "parent" then
		set p to item i of rowParents
		if p is "" then return rawName -- no parent folders: shots go straight into RAW
		return my lastComponent(p) -- direct parent only; the full path is in the preview
	else if cid is "name" then
		return item i of rowNames
	end if
	set L to {}
	if i ≤ (count of rowLists) then set L to my cleanList(item i of rowLists)
	if cid is "list" then
		if L is {} then return "–"
		if (count of L) is 1 then return "1 name"
		return ((count of L) as text) & " names"
	end if
	if L is not {} then return (count of L) as text
	return item i of rowCounts
end tableView:objectValueForTableColumn:row:

on tableView:tv setObjectValue:val forTableColumn:col row:r
	set i to (r as integer) + 1
	if i > (count of rowNames) then return
	set t to ""
	if val is not missing value then set t to val as text
	set cid to (col's identifier()) as text
	if cid is "name" then set item i of rowNames to t
	if cid is "count" then set item i of rowCounts to t
	my refresh()
end tableView:setObjectValue:forTableColumn:row:

---------- PASTE LIST ----------
on pasteList:sender
	my openPaste(my selectedRows())
end pasteList:

-- selected table rows, 1-based
on selectedRows()
	set out to {}
	set idx to tbl's selectedRowIndexes()
	repeat with k from 0 to (count of rowNames) - 1
		if (idx's containsIndex:k) as boolean then set end of out to k + 1
	end repeat
	return out
end selectedRows

-- A small window on top: one folder name per line, for one or more table rows
on openPaste(rows)
	if rows is {} then return
	if (cbShots's state()) as integer is not 1 then return
	set i to item 1 of rows
	if i > (count of rowNames) then return
	set anyList to false
	repeat with k in rows
		if item k of rowLists is not {} then set anyList to true
	end repeat
	win's makeFirstResponder:(missing value) -- commits a table cell still being edited
	set nsApp to current application's NSApplication's sharedApplication()
	set pp to item i of rowParents
	if pp is "" then
		set pp to rawName
	else
		set pp to my lastComponent(pp)
	end if
	set pw to current application's NSPanel's alloc()'s initWithContentRect:{{0, 0}, {440, 380}} styleMask:1 backing:2 defer:false
	if (count of rows) is (count of rowNames) and (count of rows) > 1 then
		set pp to "all " & (count of rows) & " rows"
	else if (count of rows) > 1 then
		set pp to (count of rows) & " rows"
	end if
	pw's setTitle:("Shot folder names: " & pp)
	pw's setReleasedWhenClosed:false
	pw's setLevel:8 -- above the main window
	set pastePanel to pw
	set v to pw's contentView()
	set l to current application's NSTextField's wrappingLabelWithString:"One folder name per line, in shot order. Spaces become dashes; / and : are removed."
	l's setFrame:{{20, 330}, {400, 34}}
	v's addSubview:l
	set sv to current application's NSScrollView's alloc()'s initWithFrame:{{20, 60}, {400, 262}}
	sv's setHasVerticalScroller:true
	sv's setBorderType:2
	set tv to current application's NSTextView's alloc()'s initWithFrame:{{0, 0}, {385, 262}}
	tv's setRichText:false
	tv's setAllowsUndo:true
	tv's setFont:(current application's NSFont's monospacedSystemFontOfSize:12 weight:0)
	tv's setAutomaticQuoteSubstitutionEnabled:false
	tv's setAutomaticDashSubstitutionEnabled:false
	tv's setAutomaticTextReplacementEnabled:false
	tv's setAutomaticSpellingCorrectionEnabled:false
	tv's setTextContainerInset:{4, 6}
	set AppleScript's text item delimiters to linefeed
	tv's setString:((item i of rowLists) as text)
	set AppleScript's text item delimiters to ""
	sv's setDocumentView:tv
	v's addSubview:sv
	set pasteView to tv
	set b to current application's NSButton's buttonWithTitle:"Remove list" target:me action:"pasteButton:"
	b's setFrame:{{14, 13}, {120, 32}}
	b's setTag:2
	b's setEnabled:anyList
	v's addSubview:b
	set b to current application's NSButton's buttonWithTitle:"Cancel" target:me action:"pasteButton:"
	b's setFrame:{{220, 13}, {100, 32}}
	b's setTag:0
	b's setKeyEquivalent:(character id 27)
	v's addSubview:b
	set b to current application's NSButton's buttonWithTitle:"OK" target:me action:"pasteButton:"
	b's setFrame:{{320, 13}, {106, 32}}
	b's setTag:1
	-- ⌘Return: a plain Return adds a new line
	b's setKeyEquivalent:return
	b's setKeyEquivalentModifierMask:(current application's NSEventModifierFlagCommand)
	b's setToolTip:"⌘Return"
	v's addSubview:b
	pw's |center|()
	pw's makeKeyAndOrderFront:me
	pw's makeFirstResponder:tv
	tv's selectAll:me
	set code to (nsApp's runModalForWindow:pw) as integer
	set t to (tv's |string|()) as text
	pw's orderOut:me
	set {pastePanel, pasteView} to {missing value, missing value}
	if code is 0 then return
	set newList to {}
	if code is 1 then
		set parts to ((current application's NSString's stringWithString:t)'s componentsSeparatedByCharactersInSet:(current application's NSCharacterSet's newlineCharacterSet())) as list
		repeat with x in parts
			set x to my trim(my regexReplace(contents of x, "\t+", " "))
			if x is not "" then set end of newList to x
		end repeat
	end if
	repeat with k in rows
		set item k of rowLists to newList
	end repeat
	tbl's reloadData()
	win's makeKeyWindow()
	my refresh()
end openPaste

on pasteButton:sender
	current application's NSApplication's sharedApplication()'s stopModalWithCode:((sender's tag()) as integer)
end pasteButton:

on buttonClicked:sender
	set code to (sender's tag()) as integer
	if code is 1 then
		win's makeFirstResponder:(missing value) -- commits a table cell still being edited
		my refresh()
		if problem is not "" then return
	end if
	set modalCode to code
	current application's NSApplication's sharedApplication()'s stopModalWithCode:code
end buttonClicked:

-- closing with the red button counts as Cancel
on windowWillClose:aNotification
	current application's NSApplication's sharedApplication()'s stopModalWithCode:0
end windowWillClose:

on releaseWindow()
	try
		if tbl is not missing value then
			tbl's setDataSource:(missing value)
			tbl's setDelegate:(missing value)
		end if
		if win is not missing value then win's setDelegate:(missing value)
	end try
	set {win, cbParents} to {missing value, missing value}
	set tbl to missing value
	set {rbAppend, rbReplace} to {missing value, missing value}
	set {btnPaste, pastePanel, pasteView} to {missing value, missing value, missing value}
	set {fClient, cbSub, fAllCounts, fFileName} to {missing value, missing value, missing value, missing value}
	set {fLocation, fJob, fDateFmt, fDate, fPhotog, parentScroll, parentDoc} to {missing value, missing value, missing value, missing value, missing value, missing value, missing value}
	set {rbSep, fFolders, cbShots, cbPrelight, fPrelight} to {{}, {}, missing value, missing value, missing value}
	set {pNumbering, pMode, pDigits, pNaming, pCounter, previewView, createBtn} to {missing value, missing value, missing value, missing value, missing value, missing value, missing value}
end releaseWindow

---------- WINDOW HELPERS ----------
-- y (from the bottom, as Cocoa wants) for the next row of height h, top to bottom
on nextRow(h)
	set y to winH - cursorTop - h
	set cursorTop to cursorTop + h + 8
	return y
end nextRow

on addLabel(v, t, y)
	return my addLabelAt(v, t, 20, y, 140)
end addLabel

on addLabelAt(v, t, x, y, wd)
	set l to current application's NSTextField's labelWithString:t
	l's setFrame:{{x, y + 3}, {wd, 20}}
	v's addSubview:l
	return l
end addLabelAt

on addField(v, t, x, y, wd)
	set f to current application's NSTextField's textFieldWithString:t
	f's setFrame:{{x, y}, {wd, 24}}
	f's setDelegate:me
	v's addSubview:f
	return f
end addField

on addPopup(v, x, y, wd)
	set p to current application's NSPopUpButton's alloc()'s initWithFrame:{{x - 3, y - 1}, {wd + 6, 26}} pullsDown:false
	p's setTarget:me
	p's setAction:"popupChanged:"
	v's addSubview:p
	return p
end addPopup

on addButton(v, t, x, wd, tg)
	set b to current application's NSButton's buttonWithTitle:t target:me action:"buttonClicked:"
	b's setFrame:{{x, 13}, {wd, 32}}
	b's setTag:tg
	v's addSubview:b
	return b
end addButton

on fillPopup(pop, titles, pos)
	pop's removeAllItems()
	pop's addItemsWithTitles:titles
	pop's selectItemAtIndex:(pos - 1)
end fillPopup

on showLocation()
	fLocation's setStringValue:(((current application's NSString's stringWithString:parentPath)'s stringByAbbreviatingWithTildeInPath()) as text)
	fLocation's setToolTip:parentPath
end showLocation

on addProblem(msg)
	if problem is "" then
		set problem to msg
	else
		set problem to problem & return & msg
	end if
end addProblem

-- whole number in minV..999, else records the problem and returns 0
on parseCount(t, minV, msg)
	set t to my trim(t)
	set ok to (t is not "") and ((length of t) ≤ 3)
	repeat with ch in characters of t
		if "0123456789" does not contain ch then set ok to false
	end repeat
	if ok then
		set c to t as integer
		if c ≥ minV then return c
	end if
	my addProblem(msg)
	return 0
end parseCount

on pickId(wanted, ids)
	if wanted is in ids then return wanted
	return item 1 of ids
end pickId

on posOf(x, theList)
	repeat with i from 1 to count of theList
		if item i of theList is x then return i
	end repeat
	return 1
end posOf

on clampInt(n, lo, hi)
	if n < lo then return lo
	if n > hi then return hi
	return n
end clampInt

-- Fast (no shell) versions of the text helpers, since they run on every keystroke
on regexReplace(t, pat, rep)
	set s to current application's NSString's stringWithString:t
	return (s's stringByReplacingOccurrencesOfString:pat withString:rep options:1024 range:{0, s's |length|()}) as text
end regexReplace

-- Spaces and underscores inside a name become single dashes: "Nike Air_Max" -> "Nike-Air-Max"
on spacesToDashes(t)
	return my regexReplace(my regexReplace(t, "[\\s" & otherSep & "]+", innerSep), "^[-_]+|[-_]+$", "")
end spacesToDashes

-- Collapses any run of separators (. / space _ etc.) into a single dash: "14.11 / 26" -> "14-11-26"
on dashOnly(t)
	return my regexReplace(my regexReplace(t, "[^A-Za-z0-9]+", dateSep), "^[-_]+|[-_]+$", "")
end dashOnly

on trim(t)
	return my regexReplace(t, "^\\s+|\\s+$", "")
end trim

-- Turns a token format (YYYY YY MMM MM DD) into today's date, e.g. "YYYY-MM-DD" -> "2026-11-15"
on formatToday(fmt)
	set d to current date
	set yr to (year of d) as text
	set m to (month of d) as integer
	set f to my replaceText(fmt, "YYYY", yr)
	set f to my replaceText(f, "YY", text 3 thru 4 of yr)
	set f to my replaceText(f, "MMM", item m of {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"})
	set f to my replaceText(f, "MM", my pad(m, 2))
	set f to my replaceText(f, "DD", my pad(day of d, 2))
	return f
end formatToday

on pathExists(p)
	return (current application's NSFileManager's defaultManager()'s fileExistsAtPath:p) as boolean
end pathExists

-- Relative folder paths inside RAW, e.g. {"Studio/LOOK_01", "Studio/LOOK_02", "Rooftop/S03"}
on makeShotNames(groups, digits, numberingMode, modeIndex, jobName, sessionName)
	set out to {}
	set gi to 0
	repeat with g in my numberGroups(my numberInput(groups), numberingMode)
		set gi to gi + 1
		set {p, n, s, c} to contents of g
		set L to {}
		if gi ≤ (count of rGroupLists) then set L to item gi of rGroupLists
		-- sessionName is date_job; modes 3-5 only exist when there are parents
		if p is "" then
			set pp to ""
		else
			set pp to my pName(p) & partSep
		end if
		-- pre: what comes before the shot prefix
		if modeIndex is 2 then
			set pre to jobName & partSep
		else if modeIndex is 3 then
			set pre to pp
		else if modeIndex is 4 then
			set pre to jobName & partSep & pp
		else if modeIndex is 5 then
			set pre to sessionName & partSep & pp
		else if modeIndex is 6 then
			set pre to sessionName & partSep
		else
			set pre to ""
		end if
		set leaves to {}
		if L is not {} and not rAppend then
			-- the pasted names replace prefix + number
			repeat with x in L
				set end of leaves to pre & (contents of x)
			end repeat
		else
			repeat with i from s to s + c - 1
				set leaf to pre & n & my pad(i, digits)
				if L is not {} then set leaf to leaf & partSep & item (i - s + 1) of L
				set end of leaves to leaf
			end repeat
		end if
		repeat with leaf in leaves
			if p is "" then
				set end of out to contents of leaf
			else
				set end of out to p & "/" & (contents of leaf)
			end if
		end repeat
	end repeat
	return out
end makeShotNames

---------- SESSION BUILDER (no dialogs; also used by tests) ----------
on buildSession(parentFolder, sessionName, jobName, photographer, shotNames, captureFormat)
	set sessionPath to (POSIX path of parentFolder) & sessionName & "/"
	set copyrightNote to ""
	---------- 2. CREATE SESSION ----------
	tell application "Capture One"
		activate
		if templateName is "" then
			set newDoc to make new document with properties {kind:session, name:sessionName, path:parentFolder}
		else
			set newDoc to make new document with properties {kind:session, name:sessionName, path:parentFolder, template:templateName}
		end if
	end tell

	-- wait (max 10 s) until Capture One has written the session folder
	repeat 50 times
		if my pathExists(sessionPath) then exit repeat
		delay 0.2
	end repeat
	if not my pathExists(sessionPath) then error "Capture One did not create the session folder."

	---------- 3. CREATE FOLDERS (one shell call) ----------
	set rawPath to sessionPath & rawName & "/"
	set allDirs to {rawPath, sessionPath & selectsName, sessionPath & outputName, sessionPath & trashName}
	repeat with f in extraFolders
		set end of allDirs to sessionPath & f
	end repeat
	if prelightName is not "" then set end of allDirs to rawPath & prelightName
	repeat with n in shotNames
		set end of allDirs to rawPath & n
	end repeat
	set cmd to "mkdir -p"
	repeat with d in allDirs
		set cmd to cmd & space & quoted form of (d as text)
	end repeat
	do shell script cmd

	-- aliases are resolved outside the Capture One tell block on purpose
	set selectsAlias to (POSIX file (sessionPath & selectsName)) as alias
	set outputAlias to (POSIX file (sessionPath & outputName)) as alias
	set trashAlias to (POSIX file (sessionPath & trashName)) as alias
	-- capture into the prelight folder first; fall back to the first shot folder
	if prelightName is not "" then
		set firstCapturePath to rawPath & prelightName
	else if shotNames is {} then
		set firstCapturePath to rawPath -- no parent or shot folders: capture straight into RAW
	else
		set firstCapturePath to rawPath & (item 1 of shotNames)
	end if
	set firstCaptureAlias to (POSIX file firstCapturePath) as alias

	---------- 4. POINT CAPTURE ONE AT THE NEW FOLDERS ----------
	tell application "Capture One"
		set captures of newDoc to firstCaptureAlias
		set selects of newDoc to selectsAlias
		set output of newDoc to outputAlias
		set trash of newDoc to trashAlias
		set capture name of newDoc to jobName
		set capture name format of newDoc to captureFormat
	end tell

	if photographer is not "" then set copyrightNote to my setCopyright(newDoc, photographer)
	if copyrightStyle is not "" then
		try
			tell application "Capture One" to set apply styles of next capture settings of newDoc to {copyrightStyle}
		on error
			set copyrightNote to copyrightNote & " (style “" & copyrightStyle & "” not found)"
		end try
	end if

	tell application "Capture One" to browse newDoc to path firstCapturePath

	-- remove Capture One's default folders; rmdir only removes them if empty
	-- (skipping any default name the user chose for one of their own folders)
	set defaults to {}
	repeat with d in {"Capture", "Selects", "Output", "Trash"}
		considering case
			if {contents of d} is not in ({rawName, selectsName, outputName, trashName} & extraFolders) then set end of defaults to quoted form of (contents of d)
		end considering
	end repeat
	if defaults is not {} then
		set AppleScript's text item delimiters to space
		set dlist to defaults as text
		set AppleScript's text item delimiters to ""
		do shell script "cd " & quoted form of sessionPath & " && rmdir " & dlist & " 2>/dev/null; true"
	end if
	return copyrightNote
end buildSession

---------- CAPTURE ONE HELPERS ----------
on setCopyright(theDoc, photographer)
	set yr to year of (current date) as text
	try
		tell application "Capture One"
			tell next capture settings of theDoc
				set capture metadata to document values
				set contact creator to photographer
				set status copyright notice to "© " & yr & " " & photographer
			end tell
		end tell
		return ""
	on error
		return " (copyright not set: needs Capture One Studio)"
	end try
end setCopyright
---------- UTILITIES ----------
-- Text for the final check dialog: where, which folders, example file name
on summaryText(sessionName, parentPath, shotNames, namingIndex, jobName, counterDigits, photographer)
	if shotNames is {} then
		set firstShot to rawName
	else
		set firstShot to my lastComponent(item 1 of shotNames)
	end if
	set c to my pad(1, counterDigits)
	set examples to {firstShot & partSep & c, jobName & partSep & c, jobName & partSep & firstShot & partSep & c, sessionName & partSep & firstShot & partSep & c, rDate & partSep & firstShot & partSep & c, sessionName & partSep & c}
	set t to "Create session “" & sessionName & "”" & return & "in " & parentPath & return & return
	set t to t & rawName & "/" & return
	if prelightName is not "" then set t to t & "   " & prelightName & "/" & return
	-- folder tree inside RAW: each parent / subfolder on its own indented line, then the
	-- shot folders under it as first … last (count); with shot folders off, every folder
	set printed to {} -- parent path components already printed, by level
	set i to 1
	set n to count of shotNames
	repeat while i ≤ n
		set p to my parentOf(item i of shotNames)
		set j to i
		repeat while j < n
			if my parentOf(item (j + 1) of shotNames) is not p then exit repeat
			set j to j + 1
		end repeat
		-- print the parent levels that changed since the previous group
		if p is "" then
			set comps to {}
		else
			set AppleScript's text item delimiters to "/"
			set comps to text items of p
			set AppleScript's text item delimiters to ""
		end if
		set same to true
		repeat with k from 1 to count of comps
			if same and k ≤ (count of printed) then
				if item k of printed is not item k of comps then set same to false
			else
				set same to false
			end if
			if not same then set t to t & my indent(k) & item k of comps & "/" & return
		end repeat
		set printed to comps
		set ind to my indent((count of comps) + 1)
		if rShotsOn is 0 then
			repeat with k from i to j
				set t to t & ind & my lastComponent(item k of shotNames) & "/" & return
			end repeat
		else if j > i then
			set t to t & ind & my lastComponent(item i of shotNames) & " … " & my shortLast(my lastComponent(item i of shotNames), my lastComponent(item j of shotNames)) & "   (" & (j - i + 1) & ")" & return
		else
			set t to t & ind & my lastComponent(item i of shotNames) & return
		end if
		set i to j + 1
	end repeat
	set t to t & selectsName & ",  " & outputName & ",  " & trashName
	repeat with f in extraFolders
		set t to t & ",  " & f
	end repeat
	-- (the file name is shown large above the summary)
	if photographer is not "" then set t to t & return & "Copyright:  " & photographer
	if copyrightStyle is not "" then set t to t & return & "Copyright style:  " & copyrightStyle
	return t
end summaryText

-- "Job_SHOT01", "Job_SHOT15" -> "15": just the trailing number when both names share the same
-- text before it; otherwise the full last name
-- also with a pasted name after the number: "Job_SHOT01_beach" … "Job_SHOT05_pool" -> "SHOT05_pool"
on shortLast(firstName, lastName)
	set n1 to length of firstName
	set n2 to length of lastName
	-- length of the common prefix
	set k to 0
	repeat while k < n1 and k < n2
		if (character (k + 1) of firstName) is not (character (k + 1) of lastName) then exit repeat
		set k to k + 1
	end repeat
	-- never cut inside a number: back off to the start of its digits
	repeat while k > 0
		if "0123456789" does not contain (character k of lastName) then exit repeat
		set k to k - 1
	end repeat
	if k = 0 or k ≥ n2 then return lastName
	if "0123456789" does not contain (character (k + 1) of lastName) then return lastName
	-- keep the prefix in front of the number ("SHOT05_pool", not "05_pool")
	repeat while k > 0
		if "_- ." contains (character k of lastName) then exit repeat
		set k to k - 1
	end repeat
	if k = 0 then return lastName
	return text (k + 1) thru -1 of lastName
end shortLast

on parentOf(relPath)
	-- everything before the last /: "Studio/DAY1/SHOT01" -> "Studio/DAY1"
	if relPath does not contain "/" then return ""
	set oldTID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "/"
	set r to (text items 1 thru -2 of relPath) as text
	set AppleScript's text item delimiters to oldTID
	return r
end parentOf

-- "Studio, Day 1,, Roof top" -> {"Studio", "Day-1", "Roof-top"}
on splitParents(t)
	set oldTID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to ","
	set parts to text items of t
	set AppleScript's text item delimiters to oldTID
	set out to {}
	repeat with x in parts
		set x to my spacesToDashes(my trim(contents of x))
		if x contains "/" or x contains ":" then error "Parent folder names can't contain / or :"
		if x is not "" then set end of out to x
	end repeat
	return out
end splitParents

-- Groups whose pasted names replace prefix + number take no shot numbers (count 0)
on numberInput(groups)
	set out to {}
	repeat with i from 1 to count of groups
		set {p, nm, c} to item i of groups
		if not rAppend and i ≤ (count of rGroupLists) then
			if item i of rGroupLists is not {} then set c to 0
		end if
		set end of out to {p, nm, c}
	end repeat
	return out
end numberInput

-- Pasted lines -> folder names: / and : dropped, spaces and the other separator become dashes
on cleanList(pasted)
	set out to {}
	repeat with x in pasted
		set nm to my spacesToDashes(my regexReplace(contents of x, "[/:]+", " "))
		if nm is not "" then set end of out to nm
	end repeat
	return out
end cleanList

-- Adds the first number to each {parent, name, count} group -> {parent, name, first, count}.
-- numberingMode 1: parents sharing a shot name continue its count; a different shot name starts at 1
--               2: every parent starts at 1
--               3: one counter across all parents, whatever the shot name
on numberGroups(groups, numberingMode)
	set nextGlobal to 1
	set seenNames to {}
	set seenNext to {}
	set out to {}
	repeat with g in groups
		set {p, nm, c} to contents of g
		set startN to 1
		set found to 0
		repeat with i from 1 to count of seenNames
			if item i of seenNames is nm then set found to i
		end repeat
		if numberingMode is 3 then
			set startN to nextGlobal
		else if found > 0 and numberingMode is 1 then
			set startN to item found of seenNext
		end if
		set nextGlobal to startN + c
		if found > 0 then
			set item found of seenNext to startN + c
		else
			set end of seenNames to nm
			set end of seenNext to startN + c
		end if
		set end of out to {p, nm, startN, c}
	end repeat
	return out
end numberGroups

-- "Studio/S01-03, Rooftop/S04-05, …" for the first four groups
on rangePreview(numbered, digits)
	set out to {}
	set more to false
	repeat with i from 1 to (count of numbered)
		set {p, n, s, c} to item i of numbered
		if c > 0 then
			if (count of out) is 4 then
				set more to true
				exit repeat
			end if
			set end of out to p & "/" & n & my pad(s, digits) & "-" & my pad(s + c - 1, digits)
		end if
	end repeat
	if more then set end of out to "…"
	set oldTID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to ", "
	set r to out as text
	set AppleScript's text item delimiters to oldTID
	return r
end rangePreview

-- zero-padded number; never cuts digits off (100 stays 100 with 2 digits)
on pad(n, digits)
	set t to n as text
	if (length of t) ≥ digits then return t
	return text -digits thru -1 of ("000000" & t)
end pad

on lastComponent(relPath)
	set oldTID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "/"
	set r to last text item of relPath
	set AppleScript's text item delimiters to oldTID
	return r
end lastComponent


on replaceText(t, findText, replaceWith)
	set oldTID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to findText
	set parts to text items of t
	set AppleScript's text item delimiters to replaceWith
	set t to parts as text
	set AppleScript's text item delimiters to oldTID
	return t
end replaceText

on prefInt(k, fallback)
	try
		return (my readPref(k, fallback as text)) as integer
	on error
		return fallback
	end try
end prefInt

on readPref(k, fallback)
	try
		return do shell script "defaults read " & prefsDomain & space & quoted form of k
	on error
		return fallback
	end try
end readPref

on writePref(k, v)
	do shell script "defaults write " & prefsDomain & space & quoted form of k & " -string " & quoted form of (v as text)
end writePref

on setPreviewWrap(doWrap)
	set tc to previewView's textContainer()
	if doWrap then
		set {{px, py}, {pw, ph}} to (previewView's enclosingScrollView()'s contentView()'s frame())
		previewView's setFrameSize:{pw, ph}
		tc's setContainerSize:{pw, 10000}
		tc's setWidthTracksTextView:true
	else
		tc's setWidthTracksTextView:false
		tc's setContainerSize:{10000, 10000}
	end if
end setPreviewWrap

on indent(level)
	set s to ""
	repeat level times
		set s to s & "   "
	end repeat
	return s
end indent

-- Capture folders in different places with the same name (PD/lookbook and MJ/lookbook) give
-- file names that don't say which one they came from. Returns a note, or "".
on sameNameWarning()
	if rNaming is in {2, 6} then return "" -- job_counter, date_job_counter: no folder name in them
	set seen to {}
	set dupes to {}
	repeat with x in rShotNames
		set leaf to my lastComponent(contents of x)
		considering case
			if {leaf} is in seen then
				if {leaf} is not in dupes then set end of dupes to leaf
			else
				set end of seen to leaf
			end if
		end considering
	end repeat
	if dupes is {} then return ""
	set AppleScript's text item delimiters to ", "
	set d to dupes as text
	set AppleScript's text item delimiters to ""
	return "Note: more than one capture folder is named " & d & "." & return & "File names won't show which parent folder they came from," & return & "and if the counter is reset when switching folders, names will repeat." & return & "To fix: turn on Shot folders and pick a naming with parent in it."
end sameNameWarning

-- Grows or shrinks the window so the whole summary fits without scrolling (up to the
-- height of the screen); everything above the summary moves with the top edge
on fitPreview()
	set psv to previewView's enclosingScrollView()
	set lm to previewView's layoutManager()
	set tc to previewView's textContainer()
	lm's ensureLayoutForTextContainer:tc
	set {{ux, uy}, {uw, uh}} to lm's usedRectForTextContainer:tc
	set needH to uh + 16 + 20 -- text inset top + bottom, room for the sideways scroller
	if needH < 100 then set needH to 100
	set {{px, py}, {pw, ph}} to psv's frame()
	set delta to needH - ph
	set {{fx, fy}, {fw, fh}} to win's frame()
	set {{vx, vy}, {vw, vh}} to win's screen()'s visibleFrame()
	if fh + delta > vh then set delta to vh - fh
	if delta > -2 and delta < 2 then return
	set cv to win's contentView()
	cv's setAutoresizesSubviews:false
	set newY to fy - delta
	if newY < vy then set newY to vy
	win's setFrame:{{fx, newY}, {fw, fh + delta}} display:false
	repeat with sv in (cv's subviews() as list)
		set {{sx, sy}, {sw, sh}} to sv's frame()
		if (sv's isEqual:psv) as boolean then
			(sv's setFrame:{{sx, sy}, {sw, sh + delta}})
		else if sy ≥ py + ph - 1 then
			(sv's setFrameOrigin:{sx, sy + delta})
		end if
	end repeat
	cv's setAutoresizesSubviews:true
	cv's setNeedsDisplay:true
end fitPreview

-- position of text in a list, case-sensitive; 0 if not there
on posOfText(x, theList)
	considering case
		repeat with i from 1 to count of theList
			if item i of theList is x then return i
		end repeat
	end considering
	return 0
end posOfText

-- Reads a date written in a token format (YYYY YY MMM MM DD, anything else one separator
-- character) and returns it as YYYY-MM-DD, or "" if it doesn't match the format
on isoFromDate(d, fmt)
	set {yr, mo, dy} to {"", "", ""}
	set mons to {"jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"}
	set i to 1
	set j to 1
	set fLen to length of fmt
	set dLen to length of d
	try
		repeat while i ≤ fLen
			set fmtLeft to text i thru -1 of fmt
			if fmtLeft starts with "YYYY" then
				set yr to my digitsAt(d, j, 4)
				set {i, j} to {i + 4, j + 4}
			else if fmtLeft starts with "YY" then
				set yr to "20" & my digitsAt(d, j, 2)
				set {i, j} to {i + 2, j + 2}
			else if fmtLeft starts with "MMM" then
				set m to text j thru (j + 2) of d
				set mo to ""
				repeat with k from 1 to 12
					if m is item k of mons then set mo to my pad(k, 2)
				end repeat
				if mo is "" then error "no month"
				set {i, j} to {i + 3, j + 3}
			else if fmtLeft starts with "MM" then
				set mo to my digitsAt(d, j, 2)
				set {i, j} to {i + 2, j + 2}
			else if fmtLeft starts with "DD" then
				set dy to my digitsAt(d, j, 2)
				set {i, j} to {i + 2, j + 2}
			else
				set {i, j} to {i + 1, j + 1}
			end if
		end repeat
	on error
		return ""
	end try
	if yr is "" or mo is "" or dy is "" or j ≤ dLen then return ""
	return yr & "-" & mo & "-" & dy
end isoFromDate

-- n digits of t starting at position i, or an error
on digitsAt(t, i, n)
	set s to text i thru (i + n - 1) of t
	repeat with ch in characters of s
		if "0123456789" does not contain ch then error "not a number"
	end repeat
	return s
end digitsAt

-- Widens the window (evenly on both sides) when the file name doesn't fit, and narrows it
-- back to the normal 640 when it does; the form stays centred
on fitWidth()
	set sz to fFileName's attributedStringValue()'s |size|()
	set needW to ((width of sz) as integer) + 60
	if needW < 640 then set needW to 640
	set cv to win's contentView()
	set {{cx, cy}, {cw, ch}} to cv's frame()
	set {{vx, vy}, {vw, vh}} to win's screen()'s visibleFrame()
	if needW > vw then set needW to vw as integer
	set half to (needW - cw) div 2
	if half is 0 then return
	set delta to half * 2
	set {{fx, fy}, {fw, fh}} to win's frame()
	cv's setAutoresizesSubviews:false
	win's setFrame:{{fx - half, fy}, {fw + delta, fh}} display:false
	repeat with sv in (cv's subviews() as list)
		set {{sx, sy}, {sw, sh}} to sv's frame()
		if (sv's isEqual:fFileName) as boolean then
			(sv's setFrame:{{20, sy}, {cw + delta - 40, sh}})
		else
			(sv's setFrameOrigin:{sx + half, sy})
		end if
	end repeat
	cv's setAutoresizesSubviews:true
	cv's setNeedsDisplay:true
end fitWidth
