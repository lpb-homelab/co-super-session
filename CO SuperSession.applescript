-- CO SuperSession
-- Every question in one window with a live preview. Creates a Capture One session with:
--   00_RAW/_prelight (first capture folder), optional level folders (location, day,
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

property scriptVersion : "0.3.1" -- bump on every release, matching the git tag (vX.Y.Z)

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
-- File names are [Name]_[Destination Folder Name]_[Counter]. Capture One only knows the name
-- of the folder captured into (it has no level folder token for capture naming), so [Name],
-- its one session-wide "capture name", holds whatever that folder name is missing: the date,
-- the job and, with simple folder names, the level folders every capture folder shares.


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
property level1Scroll : missing value
property level1Doc : missing value
property pdFieldW : 165 -- width of each level folder and level 2 field (layoutLevelDoc)
property pdRightX : 235 -- x of the level 2 column
property level1List : {""} -- one item per level 1 field
property level2List : {""} -- one item per level 2 field (second level)
property level2On : false
property cbLevel2 : missing value
property rLevel2Field : ""
property cbLevel1 : missing value
property cbShots : missing value
property fAllCounts : missing value -- sets the number of shots for every table row
property fAllPrefix : missing value -- sets the shot folder prefix of every row not typed in the table
property rowSort : "level1" -- table order with two levels: "level1" (by level 1, then level 2) or "level2"
property rowOwnName : {} -- per table row: true once its prefix was typed in the table (the global prefix leaves it alone)
property cbPrelight : missing value
property fPrelight : missing value
property rPrelightField : ""
property rShotsOn : 1
property fShotSubs : missing value -- unnumbered folders inside every shot folder: "main, plates"
property rShotSubsField : ""
property rShotSubs : {} -- the cleaned names; {} when off
property fFolders : {} -- session folder name fields, 00-04
property docsName : ""
property folderKeys : {"name_raw", "name_selects", "name_output", "name_trash", "name_docs"}
property folderRoles : {"RAW", "SELECTS", "OUTPUT", "TRASH", "DOCS"}
property folderTips : {" (captures)", " (Capture One selects)", " (Capture One output)", " (Capture One trash)", " (plain folder; empty = none)"}
property rLevel1Field : ""
property tbl : missing value
property pNumbering : missing value
property pFolderMode : missing value -- folder naming: simple, balanced, dense
property cbFolderJob : missing value -- client + job in front of the prefixed folder names
property cbFolderDate : missing value -- date in front of the prefixed folder names
property pFileMode : missing value -- file naming: simple, all levels, date + all levels
property fFilePrefix : missing value -- file prefix of the simple file naming; empty follows client + job
property fileModeIds : {1, 2, 3}
property pDigits : missing value
property pCounter : missing value
property rbSep : {} -- separator radio buttons
property previewView : missing value -- the folder tree, in the Preview window
property previewPanel : missing value -- the Preview window (opened with Preview file tree…)
property fStatus : missing value -- problems and notes, above the buttons
property fShotName : missing value -- the resulting shot folder name, above the file name
property fFileName : missing value -- the resulting file name, shown large above the summary
property formView : missing value -- the form; its wide fields and the shots table stretch with the window
property userW : 640 -- window width the user dragged to (remembered between runs)
property dragStart : missing value -- {mouse x, frame x, frame width, edge sign} while the user drags an edge
property inSymResize : false -- guards windowDidResize against its own setFrame

-- separators: 1 standard (ISO 8601 dates with -, parts joined with _, spaces in names become -),
-- 2 all dashes, 3 all underscores, 4 the opposite of standard (a joke: _ in dates and names, - between parts)
property sepStyle : 1
property partSep : "_" -- between date, job, level folders, shot, counter
property innerSep : "-" -- replaces spaces inside a name
property otherSep : "_" -- the other character, also turned into innerSep inside names
property dateSep : "-" -- between date parts
property createBtn : missing value
property winH : 0
property cursorTop : 0

property basePath : ""
property rowLevelPaths : {} -- shots table: one row per level path ("" = no level folders; "Studio/DAY1" with level 2)
property rowLevel1 : "" -- with two levels: the level 1 folders ("Studio, Rooftop"), else ""
property tblScroll : missing value -- the shots table's scroll view, the part that grows when the window is made taller
property tblBase : 154 -- the shots table's normal height (room for the controls beside it)
property tblExtra : 0 -- how much taller than tblBase the table is now
property tblFit : 0 -- extra height the table needs to show every row without scrolling
property tblUser : 0 -- extra height the user dragged the table to (remembered between runs)
property dragStartH : 0 -- window content height when a drag started
property tblNeedW : 0 -- window content width at which the level 1 folders fit in the table (0 = no need)
property rowNames : {}
property rowCounts : {}
property rowLists : {} -- pasted folder names per table row ({} = none)
property rowSubs : {} -- Subfolders checkbox per table row: true = its shots get the shot subfolders
property savedRows : {} -- the table rows saved last time: {level path, prefix, shots, own prefix, subfolders, list}
property rAllPrefix : "" -- the "all rows" prefix and number of shots, read when the window closes
property rAllCount : ""
property rGroupSubs : {} -- the Subfolders checkbox of each shot group, parallel to rGroups
property rShotBase : {} -- the shot folders before their subfolders were added
property rShotSubFlags : {} -- per shot folder in rShotBase: true = it has the shot subfolders
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
property wantFolderMode : 2 -- 1 simple, 2 balanced, 3 dense
property wantFolderJob : true
property wantFolderDate : false
property wantFileMode : 2 -- 1 simple (file prefix + counter), 2 all levels, 3 date + all levels
property wantFilePrefix : "" -- typed file prefix; empty = client + job
property folderModeIds : {1} -- ids behind the current folder naming popup items
property numberingOrder : {2, 1, 3} -- shot numbering ids in menu order
property modalCode : 0
property uiError : "" -- an error while building the window; Cocoa would swallow it, main reports it

-- results of the last refresh, used by Create Session
property problem : ""
property rJob : ""
property rDateFmt : ""
property rDate : ""
property rSession : ""
property rPhotog : ""
property rLevel1Text : ""
property rGroups : {}
property rShotNames : {}
property rDigits : 2
property rCounter : 4
property rNumbering : 1
-- folder naming: 1 simple (no folder carries the folders above it), 2 balanced (only the
-- folder captured into carries them all), 3 dense (every folder carries the ones above it)
property rFolderMode : 1
property rPre : "" -- date and/or job in front of the prefixed folder names ("2026-11-17_ACME_"), or ""
property rFileMode : 2
property rFilePrefix : ""
property rCaptureName : "" -- Capture One's [Name]: what the capture folder names are missing
property rCaptureFormat : ""
property rLostNote : "" -- simple naming: the level 1 folders file names leave out, as a note

on run
	try
		my main()
	on error errMsg number errNum
		my releaseWindow()
		if errNum is not -128 then display alert "SuperSession failed" message errMsg as warning
	end try
end run

on main()
	set basePath to my readPref("path", POSIX path of (path to desktop folder))
	if not my pathExists(basePath) then set basePath to POSIX path of (path to desktop folder)
	set defPrefix to my readPref("prefix", "SHOT")
	set defCount to my readPref("subnumber", "10")
	set wantNumbering to my clampInt(my prefInt("numbering", 2), 1, 3)
	my setSeparators(my clampInt(my prefInt("separators", 1), 1, 4))
	my readNamingPrefs()
	set rowLevelPaths to {}
	set rowNames to {}
	set rowCounts to {}
	set rowLists to {}
	set rowSubs to {}
	set rowOwnName to {}
	set savedRows to my readSavedRows()
	set modalCode to 0
	set uiError to ""

	-- Capture One runs scripts in a background osascript process; Cocoa UI must run on the main thread
	if (current application's NSThread's isMainThread()) as boolean then
		my showWindow:(missing value)
	else
		my performSelectorOnMainThread:"showWindow:" withObject:(missing value) waitUntilDone:true
	end if
	my releaseWindow()
	if uiError is not "" then error uiError
	if modalCode is not 1 then return

	if prelightName is not "" then
		set firstFolder to prelightName
	else if rShotNames is {} then
		set firstFolder to rawName
	else
		set firstFolder to my lastComponent(item 1 of rShotNames)
	end if
	-- with nothing missing from the folder names, [Name] isn't in the format; it still holds the job
	set captureName to rCaptureName
	if captureName is "" then set captureName to rJob
	set copyrightNote to my buildSession((POSIX file basePath) as alias, rSession, captureName, rPhotog, rShotNames, rCaptureFormat)

	---------- REMEMBER SETTINGS ----------
	my writePref("path", basePath)
	my writePref("job", rJob) -- client + job combined
	my writePref("client", rClientRaw)
	my writePref("jobname", rJobRaw)
	my writePref("dateformat", rDateFmt)
	if askPhotographer then my writePref("photographer", rPhotog)
	my writePref("level1", rLevel1Text) -- "" when the checkbox is off
	my writePref("level1text", rLevel1Field)
	my writePref("level2text", rLevel2Field)
	if level2On then
		my writePref("level2", "1")
	else
		my writePref("level2", "0")
	end if
	-- the choices the user picked, not the stand-ins shown when one isn't available this time
	my writePref("foldernaming", wantFolderMode as text)
	my writePref("folderjob", my boolText(wantFolderJob))
	my writePref("folderdate", my boolText(wantFolderDate))
	my writePref("filemode", wantFileMode as text)
	my writePref("fileprefix", wantFilePrefix)
	my writePref("numbering", wantNumbering as text)
	my writePref("counterdigits", rCounter as text)
	my writePref("separators", sepStyle as text)
	my writePref("shotfolders", rShotsOn as text)
	my writePref("shotsubs", rShotSubsField)
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
	-- the "all rows" fields as they were, not the last row of the table
	if rAllPrefix is not "" then my writePref("prefix", rAllPrefix)
	if rAllCount is not "" then my writePref("subnumber", rAllCount)
	if (count of rGroups) > 0 then my writePref("digits", rDigits as text)
	my writePref("shotrows", my rowsText())

	set the clipboard to rSession
	display notification "Capture into " & firstFolder & copyrightNote with title "Session " & rSession & " ready"
end main

---------- WINDOW ----------
-- Errors in a handler called by Cocoa vanish silently, so catch them here for main to report
on showWindow:arg
	try
		my buildWindow()
	on error errMsg
		set uiError to errMsg
		try
			if win is not missing value then win's orderOut:me
		end try
	end try
end showWindow:

on buildWindow()
	set nsApp to current application's NSApplication's sharedApplication()
	-- accessory: the background osascript process may own windows and come to the front
	nsApp's setActivationPolicy:1
	my installEditMenu(nsApp)
	my loadLevelLists()
	set winH to 956 + ((my visibleLevelRows()) - 1) * 30
	if askPhotographer then set winH to winH + 32
	set cursorTop to 20
	set userW to my prefInt("winwidth", 640)
	-- titled, closable, resizable: the width can be dragged, the height is locked (lockHeight)
	set w to current application's NSWindow's alloc()'s initWithContentRect:{{0, 0}, {640, winH}} styleMask:11 backing:2 defer:false
	w's setTitle:("CO SuperSession v" & scriptVersion)
	w's setReleasedWhenClosed:false
	w's setDelegate:me
	w's setLevel:3 -- floating, stays above Capture One
	w's setAutorecalculatesKeyViewLoop:true -- Tab also reaches level 1 fields added later
	set win to w
	set cv to w's contentView()
	-- the form follows the window's size: labels stay on the left, the wide fields and the shots
	-- table stretch, the controls at the right edge move with it (setHorizontalMasks)
	set v to current application's NSView's alloc()'s initWithFrame:{{0, 0}, {640, winH}}
	v's setAutoresizingMask:18
	cv's addSubview:v
	set formView to v

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
	set chooseBtn to b
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
	set sepTitles to {"Standard", "All dashes", "All underscores", "Standard"}
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

	-- everything above the level folders stays pinned to the top when the window grows
	repeat with sub in (v's subviews() as list)
		(sub's setAutoresizingMask:8)
	end repeat

	-- level folders: one field per folder, + adds one below, − removes it.
	-- The area grows the window up to 5 rows, then scrolls.
	set vis to my visibleLevelRows()
	set y to my nextRow(24 + (vis - 1) * 30)
	set cbLevel1 to current application's NSButton's checkboxWithTitle:"Level 1 folders:" target:me action:"level1Toggled:"
	cbLevel1's setFrame:{{18, y + (vis - 1) * 30 + 1}, {145, 22}}
	cbLevel1's setAutoresizingMask:8
	if my readPref("level1", "") is not "" then cbLevel1's setState:1
	v's addSubview:cbLevel1
	set level1Scroll to current application's NSScrollView's alloc()'s initWithFrame:{{162, y - 3}, {463, vis * 30}}
	level1Scroll's setDrawsBackground:false
	level1Scroll's setBorderType:0
	level1Scroll's setHasVerticalScroller:true
	level1Scroll's setAutohidesScrollers:true
	level1Scroll's setAutoresizingMask:16 -- grows with the window
	set level1Doc to current application's NSView's alloc()'s initWithFrame:{{0, 0}, {455, vis * 30}}
	level1Scroll's setDocumentView:level1Doc
	v's addSubview:level1Scroll
	my rebuildLevelRows(0)

	set y to my nextRow(tblBase)
	set cbShots to current application's NSButton's checkboxWithTitle:"Shot folders:" target:me action:"shotsToggled:"
	cbShots's setFrame:{{18, y + 130}, {145, 22}}
	if my readPref("shotfolders", "") is "" then
		-- no saved choice yet: 0 shots = no shot folders
		if defCount is not "0" then cbShots's setState:1
	else if my readPref("shotfolders", "") is "1" then
		cbShots's setState:1
	end if
	v's addSubview:cbShots
	-- values for every row: one number, applied as you type, and one prefix
	set allLbl to my addLabelAt(v, "Shots per folder (all rows)", 18, y + 92, 145)
	allLbl's setFrame:{{18, y + 116}, {145, 14}}
	allLbl's setFont:(current application's NSFont's systemFontOfSize:10)
	allLbl's setTextColor:(current application's NSColor's secondaryLabelColor)
	-- starts at the last used number (10 the first time; never 0)
	set allCount to defCount
	if allCount is "0" or allCount is "" then set allCount to "10"
	set fAllCounts to my addField(v, allCount, 18, y + 92, 145)
	fAllCounts's setFrame:{{18, y + 92}, {44, 22}} -- sized for up to 3 digits
	fAllCounts's setTag:300
	fAllCounts's setToolTip:"Number of shots for every row in the table"
	-- the prefix: a prefix typed in the table wins over it
	set preLbl to my addLabelAt(v, "Shot folder prefix (all rows)", 18, y + 52, 145)
	preLbl's setFrame:{{18, y + 76}, {145, 14}}
	preLbl's setFont:(current application's NSFont's systemFontOfSize:10)
	preLbl's setTextColor:(current application's NSColor's secondaryLabelColor)
	-- starts at the last used prefix (SHOT the first time)
	set allPrefix to defPrefix
	if allPrefix is "" then set allPrefix to "SHOT"
	set fAllPrefix to my addField(v, allPrefix, 18, y + 52, 145)
	fAllPrefix's setFrame:{{18, y + 52}, {145, 22}}
	fAllPrefix's setTag:301
	fAllPrefix's setToolTip:"Shot folder prefix for every row in the table, except rows whose prefix you typed in the table." & linefeed & "Clear a row's prefix in the table to give it this one again."
	-- a pasted list of folder names for the selected row
	set btnPaste to current application's NSButton's buttonWithTitle:"Paste list…" target:me action:"pasteList:"
	btnPaste's setFrame:{{12, y + 18}, {145, 32}}
	btnPaste's setToolTip:"Paste folder names, one per line, for the selected row"
	v's addSubview:btnPaste
	-- radio buttons sharing a superview and an action work as one group
	set rbAppend to current application's NSButton's radioButtonWithTitle:"Append" target:me action:"shotsToggled:"
	rbAppend's setFrame:{{18, y}, {70, 18}}
	rbAppend's setToolTip:"Pasted names go after the shot number: SHOT01_name"
	set rbReplace to current application's NSButton's radioButtonWithTitle:"Replace" target:me action:"shotsToggled:"
	rbReplace's setFrame:{{88, y}, {75, 18}}
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
	set sv to current application's NSScrollView's alloc()'s initWithFrame:{{165, y}, {455, tblBase}}
	sv's setHasVerticalScroller:true
	sv's setBorderType:2
	set tbl to current application's NSTableView's alloc()'s initWithFrame:{{0, 0}, {455, tblBase}}
	repeat with c in {{"level1", "Level 1", 100, false}, {"level2", "Level 2", 130, false}, {"name", "Shot folder prefix", 165, true}, {"count", "Shots", 60, true}, {"list", "List", 75, false}}
		set {cid, ctitle, cw, ced} to contents of c
		set col to (current application's NSTableColumn's alloc()'s initWithIdentifier:cid)
		(col's headerCell()'s setStringValue:ctitle)
		(col's setWidth:cw)
		(col's setEditable:ced)
		(col's dataCell()'s setLineBreakMode:4) -- … at the end when it doesn't fit
		(tbl's addTableColumn:col)
	end repeat
	-- level 1 folders: only shown with two levels (rows are then per level 2)
	set col to tbl's tableColumnWithIdentifier:"level1"
	col's setHidden:true
	col's setHeaderToolTip:"The level 1 folders each level 2 row is created in"
	-- Subfolders: a checkbox per row; only checked rows get the shot subfolders
	set col to current application's NSTableColumn's alloc()'s initWithIdentifier:"subs"
	col's headerCell()'s setStringValue:"Subfolders"
	col's setWidth:75
	col's setEditable:true
	set chk to current application's NSButtonCell's alloc()'s init()
	chk's setButtonType:3 -- checkbox
	chk's setTitle:""
	chk's setImagePosition:1 -- image only, centred
	chk's setControlSize:1
	col's setDataCell:chk
	col's setHeaderToolTip:"Checked rows get the Shot subfolders inside each of their shot folders"
	tbl's addTableColumn:col
	tbl's setAllowsColumnReordering:false
	tbl's setAllowsColumnSelection:false -- a header click sorts (Level 1, Level 2) instead
	set rowSort to my readPref("tablesort", "level1")
	tbl's setAllowsMultipleSelection:true -- ⌘A or ⌘/⇧-click: paste one list into several rows
	tbl's setColumnAutoresizingStyle:0 -- sizeColumns fits them to their content
	tbl's setUsesAlternatingRowBackgroundColors:true
	tbl's setDataSource:me
	tbl's setDelegate:me
	tbl's setTarget:me
	tbl's setAction:"tableClicked:"
	sv's setDocumentView:tbl
	v's addSubview:sv
	set tblScroll to sv
	set tblExtra to 0
	set tblFit to 0
	set tblUser to my prefInt("tableextra", 0)

	set y to my nextRow(16)
	set hint to my addLabelAt(v, "Click a cell to edit, or select one or more rows to add a pasted list.", 165, y - 3, 455)
	hint's setFont:(current application's NSFont's systemFontOfSize:10)
	hint's setTextColor:(current application's NSColor's secondaryLabelColor())

	set y to my nextRow(26)
	my addLabel(v, "Shot subfolders:", y)
	set fShotSubs to my addField(v, my readPref("shotsubs", ""), 165, y, 455)
	fShotSubs's setPlaceholderString:"inside every shot folder, e.g. main, plates (empty = none)"
	fShotSubs's setToolTip:"Unnumbered folders inside every shot folder, separated by commas." & linefeed & "Each is named after its shot (SHOT01_main), so the shot stays in the file name."

	set y to my nextRow(26)
	my addLabel(v, "Shot folder count:", y)
	set pNumbering to my addPopup(v, 165, y, 455)

	set y to my nextRow(26)
	my addLabel(v, "Folder naming:", y)
	set pFolderMode to my addPopup(v, 165, y, 320)
	pFolderMode's setToolTip:"Simple: no folder name repeats the folders above it." & linefeed & "Balanced: only the folder captured into carries all the folders above it." & linefeed & "Dense: every folder carries the folders above it." & linefeed & "File names always get the job and the level 1 and level 2 folders (simple: the ones every capture folder shares)."
	set digitsLbl1 to my addLabelAt(v, "digits:", 495, y, 50)
	set pDigits to my addPopup(v, 545, y, 75)
	pDigits's addItemsWithTitles:{"1", "2", "3"}
	pDigits's selectItemAtIndex:((my clampInt(my prefInt("digits", 2), 1, 3)) - 1)
	pDigits's setToolTip:"Digits of the shot number"

	set y to my nextRow(24)
	my addLabel(v, "Shot folder prefix:", y)
	set cbFolderJob to my addCheck(v, "Client + job", 165, y, 120, wantFolderJob)
	cbFolderJob's setToolTip:"Client and job name in front of every folder name that carries the folders above it"
	set cbFolderDate to my addCheck(v, "Date", 290, y, 80, wantFolderDate)
	cbFolderDate's setToolTip:"Date in front of every folder name that carries the folders above it, always with the client + job." & linefeed & "File names then always start with the date too."

	set y to my nextRow(26)
	my addLabel(v, "File names:", y)
	set pFileMode to my addPopup(v, 165, y, 200)
	pFileMode's addItemsWithTitles:{"Simple: prefix + counter", "Job, levels, shot + counter", "Date, job, levels, shot + counter"}
	pFileMode's selectItemAtIndex:(wantFileMode - 1)
	pFileMode's setToolTip:"Simple: file prefix + counter (ACME_job_0001)." & linefeed & "Job, levels, shot + counter: the job, the level folders and the shot folder in every file name." & linefeed & "Date, job, levels, shot + counter: the same, starting with the date (always, when the folder names have the date)." & linefeed & "Level folders only show up in file names through the folder names: pick Balanced or Dense folder naming to get them all."
	set fFilePrefix to my addField(v, wantFilePrefix, 372, y, 113)
	fFilePrefix's setTag:302
	fFilePrefix's setToolTip:"File prefix for the simple file names. Empty: client + job."
	set digitsLbl2 to my addLabelAt(v, "digits:", 495, y, 50)
	set pCounter to my addPopup(v, 545, y, 75)
	pCounter's addItemsWithTitles:{"1", "2", "3", "4", "5", "6"}
	pCounter's selectItemAtIndex:((my clampInt(my prefInt("counterdigits", 4), 1, 6)) - 1)
	pCounter's setToolTip:"Digits of the file counter"

	-- the end result: what the files will be called
	set v to cv
	set cursorTop to cursorTop + 14 -- breathing room below the popups
	-- the shot folder name, then the file name, each with a small caption
	set y to my nextRow(14)
	set cap to my addLabelAt(v, "Shot folder name:", 20, y - 3, 600)
	cap's setFont:(current application's NSFont's systemFontOfSize:11)
	cap's setTextColor:(current application's NSColor's secondaryLabelColor())
	cap's setAlignment:(current application's NSTextAlignmentCenter)
	cap's setAutoresizingMask:2
	set y to my nextRow(26)
	set fShotName to current application's NSTextField's labelWithString:""
	fShotName's setFrame:{{20, y}, {600, 26}}
	fShotName's setAutoresizingMask:2
	fShotName's setAlignment:(current application's NSTextAlignmentCenter)
	fShotName's setFont:(current application's NSFont's monospacedSystemFontOfSize:15 weight:0.4)
	fShotName's setTextColor:(current application's NSColor's controlAccentColor())
	fShotName's setSelectable:true
	fShotName's setLineBreakMode:5
	v's addSubview:fShotName
	set y to my nextRow(14)
	set cap to my addLabelAt(v, "File name:", 20, y - 3, 600)
	cap's setFont:(current application's NSFont's systemFontOfSize:11)
	cap's setTextColor:(current application's NSColor's secondaryLabelColor())
	cap's setAlignment:(current application's NSTextAlignmentCenter)
	cap's setAutoresizingMask:2
	set y to my nextRow(32)
	set fFileName to current application's NSTextField's labelWithString:""
	fFileName's setFrame:{{20, y}, {600, 30}}
	fFileName's setAutoresizingMask:2 -- wider with the window
	fFileName's setAlignment:(current application's NSTextAlignmentCenter)
	fFileName's setFont:(current application's NSFont's monospacedSystemFontOfSize:17 weight:0.4)
	fFileName's setTextColor:(current application's NSColor's controlAccentColor())
	fFileName's setSelectable:true
	fFileName's setLineBreakMode:5
	v's addSubview:fFileName

	-- the whole folder tree opens in its own window
	set y to my nextRow(24)
	set b to current application's NSButton's buttonWithTitle:"Preview file tree…" target:me action:"showPreview:"
	b's sizeToFit()
	set {{bfx, bfy}, {bw, bh}} to b's frame()
	set bw to bw + 24
	b's setFrame:{{(640 - bw) div 2, y - 4}, {bw, 32}}
	b's setAutoresizingMask:5 -- stays centred
	b's setKeyEquivalent:"p"
	b's setKeyEquivalentModifierMask:(current application's NSEventModifierFlagCommand)
	b's setToolTip:"⌘P"
	v's addSubview:b
	my buildPreviewPanel()

	-- problems (red) and notes (orange); empty when all is well
	set y to my nextRow(30)
	set fStatus to current application's NSTextField's wrappingLabelWithString:""
	fStatus's setFrame:{{20, y}, {600, 30}}
	fStatus's setAutoresizingMask:2
	fStatus's setFont:(current application's NSFont's systemFontOfSize:11)
	fStatus's setAlignment:(current application's NSTextAlignmentCenter)
	fStatus's setMaximumNumberOfLines:2
	fStatus's cell()'s setTruncatesLastVisibleLine:true
	v's addSubview:fStatus

	-- the window was sized for the old preview: take out the space left above the buttons
	my shrinkAboveButtons(y - 55)

	set cancelBtn to my addButton(v, "Cancel", 395, 100, 0)
	cancelBtn's setKeyEquivalent:(character id 27)
	set createBtn to my addButton(v, "Create Session", 495, 130, 1)
	createBtn's setKeyEquivalent:return
	cancelBtn's setAutoresizingMask:1 -- buttons stay at the right edge
	createBtn's setAutoresizingMask:1

	set stretchy to {fClient, fJob, fLocation, level1Scroll, tblScroll, hint, fShotSubs, pNumbering, pFolderMode}
	if askPhotographer then set end of stretchy to fPhotog
	repeat with x in stretchy
		my setHMask(contents of x, 2)
	end repeat
	repeat with x in {chooseBtn, digitsLbl1, pDigits, digitsLbl2, pCounter}
		my setHMask(contents of x, 1)
	end repeat

	my syncRows()
	my refresh()
	my lockHeight()
	my fitTable()
	w's |center|()
	nsApp's activateIgnoringOtherApps:true
	w's makeKeyAndOrderFront:me
	w's orderFrontRegardless()
	w's makeFirstResponder:fClient
	nsApp's runModalForWindow:w
	w's orderOut:me
	previewPanel's orderOut:me
end buildWindow

-- The Preview window: the folder tree in a large, resizable window that stays usable
-- while the main window is modal; it follows every edit
on buildPreviewPanel()
	set {{vx, vy}, {vw, vh}} to current application's NSScreen's mainScreen()'s visibleFrame()
	set ph to (vh - 80) as integer
	if ph > 1000 then set ph to 1000
	set p to current application's NSPanel's alloc()'s initWithContentRect:{{0, 0}, {760, ph}} styleMask:11 backing:2 defer:false
	p's setTitle:"File tree preview"
	p's setReleasedWhenClosed:false
	p's setWorksWhenModal:true
	p's setHidesOnDeactivate:false
	p's setLevel:3 -- floating, like the main window
	p's setContentMinSize:{400, 200}
	set psv to current application's NSScrollView's alloc()'s initWithFrame:{{0, 0}, {760, ph}}
	psv's setAutoresizingMask:18
	psv's setBorderType:0
	psv's setHasVerticalScroller:true
	psv's setHasHorizontalScroller:true
	set previewView to current application's NSTextView's alloc()'s initWithFrame:{{0, 0}, {760, ph}}
	previewView's setAutoresizingMask:2
	previewView's setEditable:false
	previewView's setFont:(current application's NSFont's monospacedSystemFontOfSize:12 weight:0)
	previewView's setTextContainerInset:{12, 12}
	-- long folder names scroll sideways instead of wrapping
	previewView's textContainer()'s setWidthTracksTextView:false
	previewView's textContainer()'s setContainerSize:{10000, 10000}
	previewView's setHorizontallyResizable:true
	previewView's setMaxSize:{10000, 10000}
	psv's setDocumentView:previewView
	p's contentView()'s addSubview:psv
	set previewPanel to p
end buildPreviewPanel

-- opens the Preview window beside the main window (or over its right side when there's no room)
on showPreview:sender
	win's makeFirstResponder:(missing value) -- commits a table cell still being edited
	my refresh()
	if not ((previewPanel's isVisible()) as boolean) then
		set {{fx, fy}, {fw, fh}} to win's frame()
		set {{px, py}, {pw, ph}} to previewPanel's frame()
		set {{vx, vy}, {vw, vh}} to win's screen()'s visibleFrame()
		set x to fx + fw + 12
		if x + pw > vx + vw then set x to vx + vw - pw
		set y to fy + fh - ph
		if y < vy then set y to vy
		previewPanel's setFrameOrigin:{x, y}
	end if
	previewPanel's makeKeyAndOrderFront:me
end showPreview:

-- Lowers the window's top by gap: everything but the bottom buttons moves down with it
on shrinkAboveButtons(gap)
	if gap < 1 then return
	set cv to win's contentView()
	cv's setAutoresizesSubviews:false
	set {{fx, fy}, {fw, fh}} to win's frame()
	win's setFrame:{{fx, fy + gap}, {fw, fh - gap}} display:false
	repeat with sv in (cv's subviews() as list)
		set {{sx, sy}, {sw, sh}} to sv's frame()
		if (sv's isEqual:formView) as boolean or sy > 50 then (sv's setFrameOrigin:{sx, sy - gap})
	end repeat
	cv's setAutoresizesSubviews:true
end shrinkAboveButtons

-- Every edit lands here; recomputes names, checks for problems, updates popups and preview.
-- An error in it is shown in the preview (and blocks Create Session) instead of vanishing.
on refresh()
	try
		my refreshBody()
	on error errMsg
		set problem to "Something went wrong while updating the preview:" & return & errMsg
		try
			previewView's setString:problem
			previewView's setTextColor:(current application's NSColor's systemRedColor())
			my setStatus(problem, current application's NSColor's systemRedColor())
			createBtn's setEnabled:false
		end try
	end try
end refresh

on refreshBody()
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
	set rLevel1Field to my joinedList(level1List)
	set rLevel2Field to my joinedList(level2List)
	set rLevel1Text to my activeLevel1Text()
	set rDigits to ((pDigits's indexOfSelectedItem()) as integer) + 1
	set rCounter to ((pCounter's indexOfSelectedItem()) as integer) + 1

	if not my pathExists(basePath) then my addProblem("The location folder doesn't exist any more. Choose another.")
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
		-- compared ignoring case, like the disk: RAW and raw are one folder
		if nm is not "" and {nm} is in seen then my addProblem("Two session folders are both named “" & nm & "”.")
		set end of seen to nm
	end repeat

	if rJob is not "" and rDate is not "" then
		if my pathExists(basePath & rSession & "/") then my addProblem("A folder named “" & rSession & "” already exists there. Change the date or the job name.")
	end if

	-- shot groups {level folder, shot name, count} from the table
	set levelPaths to {}
	try
		set levelPaths to my activeLevelPaths()
	on error msg
		my addProblem(msg)
	end try
	-- the same level folder twice (ignoring case, like the disk) would merge into one folder
	set seenP to {}
	repeat with p in levelPaths
		if {contents of p} is in seenP then
			my addProblem("Two folders are both named “" & (contents of p) & "”.")
			exit repeat
		end if
		set end of seenP to contents of p
	end repeat
	set n to count of levelPaths
	set rGroups to {}
	set rGroupLists to {}
	set rGroupSubs to {}
	set rAppend to ((rbAppend's state()) as integer is 1)
	set shotsOn to ((cbShots's state()) as integer is 1)
	if shotsOn then
		set rShotsOn to 1
	else
		set rShotsOn to 0
	end if
	tbl's setEnabled:shotsOn
	fAllCounts's setEnabled:shotsOn
	fAllPrefix's setEnabled:shotsOn
	btnPaste's setEnabled:(shotsOn and (tbl's numberOfSelectedRows()) as integer > 0)
	set anyList to false
	repeat with L in rowLists
		if contents of L is not {} then set anyList to true
	end repeat
	rbAppend's setEnabled:(shotsOn and anyList)
	rbReplace's setEnabled:(shotsOn and anyList)
	fShotSubs's setEnabled:shotsOn
	set rShotSubsField to my trim((fShotSubs's stringValue()) as text)
	set rAllPrefix to my trim((fAllPrefix's stringValue()) as text)
	set rAllCount to my trim((fAllCounts's stringValue()) as text)
	set rShotSubs to {}
	if shotsOn and rShotSubsField is not "" then
		try
			repeat with x in my splitList(rShotSubsField)
				if {contents of x} is not in rShotSubs then set end of rShotSubs to contents of x
			end repeat
		on error
			my addProblem("Please don't use / or : in shot subfolder names.")
		end try
	end if
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
			if nm contains "/" or nm contains ":" then my addProblem("Please don't use / or : in the shot folder prefix.")
			set rGroups to {{"", nm, c}}
			set rGroupLists to {L}
			set rGroupSubs to {my rowHasSubs(1)}
		end if
	else
		-- one table row per level path (with level 2: per level 1 and level 2 pair)
		repeat with i from 1 to n
			set p to item i of levelPaths
			set r to my posOfText(p, rowLevelPaths)
			if r > 0 and r ≤ (count of rowNames) then
				set nm to my trim(item r of rowNames)
				set L to my cleanList(item r of rowLists)
				if L is {} then
					set c to my parseCount(item r of rowCounts, 1, p & ": number of shots must be a whole number from 1 to 999.")
				else
					set c to count of L
				end if
				if nm contains "/" or nm contains ":" then my addProblem(p & ": please don't use / or : in the shot folder prefix.")
				set end of rGroups to {p, nm, c}
				set end of rGroupLists to L
				set end of rGroupSubs to my rowHasSubs(r)
			end if
		end repeat
	end if
	set ng to count of rGroups

	-- shot numbering (only matters with 2+ level folders). Menu order: restart (2), per shot name (1),
	-- across all (3); the ids are what numberGroups and the saved setting use
	set numTitles to {"Restart in each folder", "Continue per shot prefix", "Continue across all folders"}
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

	-- folder naming. levels: how many folder levels lead down to a capture folder (level folders, then shots)
	set levels to 0
	if n > 0 then
		set levels to 1
		if (item 1 of levelPaths) contains "/" then set levels to 2
		set p1 to item 1 of levelPaths
	else
		set p1 to ""
	end if
	set firstShot to ""
	if ng > 0 then
		set levels to levels + 1
		set {p1, n1, s1, c1} to item 1 of my numberGroups(my numberInput(rGroups), rNumbering)
		set L1 to item 1 of rGroupLists
		if L1 is {} then
			set firstShot to n1 & my pad(s1, rDigits)
		else if rAppend then
			set firstShot to n1 & my pad(s1, rDigits) & partSep & item 1 of L1
		else
			set firstShot to item 1 of L1
		end if
	end if
	-- each choice shows the first capture folder's path, with the prefix ticked now
	set examplePre to ""
	if wantFolderDate then set examplePre to rDate & partSep
	if wantFolderJob or wantFolderDate then set examplePre to examplePre & rJob & partSep
	if levels is 0 then
		set folderModeIds to {1}
		set titles to {"(no folders to name)"}
	else
		set folderModeIds to {1, 2, 3}
		if levels is 1 then set folderModeIds to {1, 2} -- one level: dense is the same as balanced
		set titles to {}
		repeat with m in folderModeIds
			set end of titles to item m of {"Simple", "Balanced", "Dense"} & "  (" & my examplePath(p1, firstShot, ng > 0, contents of m, examplePre) & ")"
		end repeat
	end if
	set rFolderMode to my pickId(wantFolderMode, folderModeIds)
	my fillPopup(pFolderMode, titles, my posOf(rFolderMode, folderModeIds))
	pFolderMode's setEnabled:(levels > 0)
	-- the prefix only goes on folders that carry the folders above them, so not with simple naming
	set prefixed to (rFolderMode > 1)
	-- the date only goes in front of folder names together with the job: without it, file names
	-- would get the job ([Name], always first) before the folder's date
	set folderDateOn to (prefixed and wantFolderDate)
	set folderJobOn to (prefixed and (wantFolderJob or wantFolderDate))
	cbFolderJob's setEnabled:(prefixed and not wantFolderDate)
	cbFolderDate's setEnabled:prefixed
	if wantFolderJob or wantFolderDate then
		cbFolderJob's setState:1
	else
		cbFolderJob's setState:0
	end if
	set rPre to ""
	if folderDateOn then set rPre to rDate & partSep
	if folderJobOn then set rPre to rPre & rJob & partSep
	pDigits's setEnabled:(ng > 0)

	if ng > 0 then
		set rShotNames to my makeShotNames(rGroups, rDigits, rNumbering)
		-- pasted names can repeat; two folders with the same path would merge
		set seen to {}
		set dupes to {}
		repeat with x in rShotNames
			set x to contents of x
			if {x} is in seen then
				if {x} is not in dupes then set end of dupes to x
			else
				set end of seen to x
			end if
		end repeat
		repeat with x in dupes
			my addProblem("Two shot folders would both be named “" & x & "”. Check the pasted list.")
		end repeat
		-- shot subfolders: SHOT01/SHOT01_main, SHOT01/SHOT01_plates. Capture One only puts the
		-- folder captured into in the file name, so each subfolder carries its shot folder's name
		-- Only the rows with Subfolders checked get them; each group made as many folders as its count
		set rShotBase to rShotNames
		set rShotSubFlags to {}
		repeat with gi from 1 to ng
			repeat (item 3 of item gi of rGroups) times
				set end of rShotSubFlags to (rShotSubs is not {} and item gi of rGroupSubs)
			end repeat
		end repeat
		if rShotSubFlags contains true and (count of rShotSubFlags) is (count of rShotNames) then
			set subPaths to {}
			repeat with i from 1 to count of rShotNames
				set x to item i of rShotNames
				if item i of rShotSubFlags then
					repeat with sName in rShotSubs
						set end of subPaths to x & "/" & my lastComponent(x) & partSep & (contents of sName)
					end repeat
				else
					set end of subPaths to x
				end if
			end repeat
			set rShotNames to subPaths
		else
			set rShotSubFlags to {}
		end if
	else
		set rShotBase to {}
		set rShotSubFlags to {}
		-- shot folders off: capture into the (last level) level folders, or straight into RAW
		set rShotNames to {}
		repeat with p in levelPaths
			set end of rShotNames to my diskFolder(contents of p, true, rFolderMode, rPre)
		end repeat
	end if

	-- file names: [Name]_[Destination Folder Name]_[Counter]. Capture One only sees the name of
	-- the folder captured into, so [Name] holds what that name is missing: date, job, level folders
	set rFileMode to wantFileMode
	if rFileMode is 2 and folderDateOn then set rFileMode to 3 -- a date in the folder name is in the file name too
	-- file prefix: typed, or client + job
	set rFilePrefix to my spacesToDashes(my trim(wantFilePrefix))
	if rFilePrefix is "" then set rFilePrefix to rJob
	fFilePrefix's setPlaceholderString:rJob
	fFilePrefix's setHidden:(wantFileMode is not 1)
	if wantFileMode is 1 and (rFilePrefix contains "/" or rFilePrefix contains ":") then my addProblem("Please don't use / or : in the file prefix.")
	set nameParts to {}
	set rLostNote to ""
	if rFileMode is 1 then
		set end of nameParts to rFilePrefix
		if (count of rShotNames) > 1 then set rLostNote to "Note: simple file names are only unique when the counter isn't reset when switching folders." & return & "Check this in Capture One's capture naming."
	else
		if rFileMode is 3 and not folderDateOn then set end of nameParts to rDate
		if not folderJobOn then set end of nameParts to rJob
		if rFolderMode is 1 and n > 0 then
			-- simple: the level folders above each capture folder; [Name] can only hold the ones all share
			set ups to {}
			if ng > 0 then
				repeat with g in rGroups
					set end of ups to item 1 of g
				end repeat
			else
				repeat with p in levelPaths
					set end of ups to my level1Of(contents of p)
				end repeat
			end if
			set {common, lost} to my commonLevel1(ups)
			if common is not "" then set end of nameParts to my pName(common)
			if lost is not "" then set rLostNote to "Note: with simple folder naming, file names leave out the level 1 folders " & lost & "." & return & "Pick Balanced or Dense folder naming to keep them in."
		end if
	end if
	set oldTID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to partSep
	set rCaptureName to nameParts as text
	set AppleScript's text item delimiters to oldTID
	set cnt to "[" & rCounter & " Digit Counter]"
	if rFileMode is 1 then
		set rCaptureFormat to "[Name]" & partSep & cnt
	else if rCaptureName is "" then
		set rCaptureFormat to "[Destination Folder Name]" & partSep & cnt
	else
		set rCaptureFormat to "[Name]" & partSep & "[Destination Folder Name]" & partSep & cnt
	end if

	-- the file name, large: first capture in the first shot folder
	if rShotNames is {} then
		set ffShot to rawName
	else
		set ffShot to my lastComponent(item 1 of rShotNames)
	end if
	set ffName to ffShot & partSep & my pad(1, rCounter)
	if rFileMode is 1 then set ffName to my pad(1, rCounter)
	if rCaptureName is not "" then set ffName to rCaptureName & partSep & ffName
	fShotName's setStringValue:ffShot
	fShotName's setToolTip:ffShot
	fFileName's setStringValue:ffName
	fFileName's setToolTip:ffName
	my fitWidth()

	if problem is "" then
		my setPreviewWrap(false)
		set summ to my summaryText(rSession, basePath, rShotNames, rPhotog)
		set warn to my sameNameWarning()
		if warn is "" then
			previewView's setString:summ
			previewView's setTextColor:(current application's NSColor's labelColor())
			my setStatus("", missing value)
		else
			my setStatus(warn, current application's NSColor's systemOrangeColor())
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
		my setStatus(problem, current application's NSColor's systemRedColor())
	end if
	createBtn's setEnabled:(problem is "")
	if (tbl's editedRow()) as integer < 0 then
		my sizeColumns() -- not while a cell is being typed in
		my fitWidth() -- the level 1 folders may need a wider table (it refits the columns)
	end if
	my updateSepTips()
end refreshBody

-- the problem or note above the buttons (two lines at most; the full text is its tooltip)
on setStatus(t, col)
	if fStatus is missing value then return
	fStatus's setStringValue:t
	fStatus's setToolTip:t
	if col is not missing value then fStatus's setTextColor:col
end setStatus

-- Separator tooltips: a fixed example file name (today's date, client, job name, DAY01,
-- SHOT01, 0001) written with each separator style
on updateSepTips()
	if (count of rbSep) < 4 then return
	set keep to sepStyle
	repeat with s from 1 to 4
		my setSeparators(s)
		set t to my dashOnly(my formatToday("YYYY-MM-DD")) & partSep & "client" & partSep & my spacesToDashes("job name") & partSep & "DAY01" & partSep & "SHOT01" & partSep & "0001"
		set t to t & linefeed & item s of {"ISO 8601 for dates" & linefeed & "_ separates parts" & linefeed & "- joins words", "At least you're consistent.", "Acceptable.", "Yes, I am judging you."}
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

-- the level 1 folder list, or "" while the checkbox is off
on activeLevel1Text()
	if (cbLevel1's state()) as integer is 1 then return my joinedList(level1List)
	return ""
end activeLevel1Text

-- Relative level paths inside RAW: {"Studio", "Rooftop"}, or with level 2 every
-- combination {"Studio/DAY1", "Studio/DAY2", "Rooftop/DAY1", ...}. Errors on invalid names.
on activeLevelPaths()
	set l1 to my splitList(my activeLevel1Text())
	if l1 is {} or not level2On then return l1
	set l2 to my splitList(my joinedList(level2List))
	if l2 is {} then return l1
	set out to {}
	repeat with a in l1
		repeat with b in l2
			set end of out to (contents of a) & "/" & (contents of b)
		end repeat
	end repeat
	return out
end activeLevelPaths

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

-- level folder and level 2 lists from the saved comma text (kept while the checkboxes are off)
on loadLevelLists()
	set level1List to my splitSaved(my readPref("level1text", my readPref("level1", "")))
	set level2List to my splitSaved(my readPref("level2text", ""))
	set level2On to (my readPref("level2", "0") is "1")
end loadLevelLists

-- rows in the folder area: level 1 fields on the left; on the right the Level 2
-- checkbox with the level 2 fields below it
on levelRows()
	set n1 to count of level1List
	set n2 to 1
	if level2On then set n2 to 1 + (count of level2List)
	if n2 > n1 then return n2
	return n1
end levelRows

on visibleLevelRows()
	set n to my levelRows()
	if n > 5 then return 5
	return n
end visibleLevelRows

-- Redraws both level folder columns, resizing the window to fit;
-- focusTag > 0 puts the cursor in that field (101… level 1, 201… level 2)
on rebuildLevelRows(focusTag)
	win's makeFirstResponder:(missing value) -- finish any typing in a field about to be removed
	-- how far the list is scrolled down from its top, to put it back there afterwards
	-- (the view isn't flipped, so left alone it would show the bottom rows)
	set {{bx, |by|}, {bw, bh}} to level1Scroll's contentView()'s |bounds|()
	set {{dx, dy}, {dw, oldDocH}} to level1Doc's frame()
	set topOff to oldDocH - (|by| + bh)
	if topOff < 0 then set topOff to 0
	set areaH to (my visibleLevelRows()) * 30
	set {{sx, sy}, {sw, sh}} to level1Scroll's frame()
	set delta to areaH - sh
	if delta is not 0 then
		set {{fx, fy}, {fw, fh}} to win's frame()
		win's setFrame:{{fx, fy - delta}, {fw, fh + delta}} display:true
		my lockHeight()
	end if
	set isOn to ((cbLevel1's state()) as integer is 1)
	set docH to (my levelRows()) * 30
	if docH < areaH then set docH to areaH
	level1Doc's setSubviews:{}
	my levelColumns()
	level1Doc's setFrameSize:{(level1Scroll's contentSize()'s width) as integer, docH}

	-- left column: level 1
	set n to count of level1List
	repeat with i from 1 to n
		my addFolderRow(item i of level1List, 3, docH - 27 - (i - 1) * 30, 100 + i, i, n, isOn, "addLevel1:", "removeLevel1:", "e.g. Studio, Day 1")
	end repeat

	-- right column: Level 2 checkbox, then level 2
	set cbLevel2 to current application's NSButton's checkboxWithTitle:"Level 2 folders" target:me action:"level2Toggled:"
	cbLevel2's setFrame:{{pdRightX - 1, docH - 26}, {200, 22}}
	if level2On then cbLevel2's setState:1
	cbLevel2's setEnabled:isOn
	cbLevel2's setToolTip:"A second folder level inside every level 1 folder, e.g. Studio/DAY1"
	level1Doc's addSubview:cbLevel2
	if level2On then
		set n to count of level2List
		repeat with i from 1 to n
			my addFolderRow(item i of level2List, pdRightX, docH - 27 - i * 30, 200 + i, i, n, isOn, "addLevel2:", "removeLevel2:", "e.g. DAY1, Look 1")
		end repeat
	end if

	set scrollY to docH - areaH - topOff
	if scrollY < 0 then set scrollY to 0
	level1Doc's scrollPoint:{0, scrollY}

	if focusTag > 0 and isOn then
		set f to level1Doc's viewWithTag:focusTag
		if f is not missing value then
			f's scrollRectToVisible:(f's |bounds|())
			win's makeFirstResponder:f
		end if
	end if
end rebuildLevelRows

-- Spreads the five session folder fields over the form's width, equally wide
on layoutFolders()
	if fFolders is {} or formView is missing value then return
	set {{fx, fy}, {fw, fh}} to formView's frame()
	set w to ((fw - 20 - 165 - 4 * 5) / 5) as integer
	repeat with i from 1 to count of fFolders
		set f to item i of fFolders
		set {{x, y}, {ww, hh}} to f's frame()
		(f's setFrame:{{165 + (i - 1) * (w + 5), y}, {w, hh}})
	end repeat
end layoutFolders

-- Splits the folder area's width into the level folder and level 2 columns:
-- each a field (up to 360 wide) with its + and − buttons
on levelColumns()
	set w to (level1Scroll's contentSize()'s width) as integer
	set colW to (w - 14) div 2
	set fw to colW - 56
	if fw < 120 then set fw to 120
	if fw > 360 then set fw to 360
	set pdFieldW to fw
	set pdRightX to 3 + fw + 56 + 11
end levelColumns

-- After a width change: moves and widens the fields and buttons already there,
-- without rebuilding them (that would end any typing in them)
on layoutLevelDoc()
	if level1Doc is missing value then return
	set {oldW, oldX} to {pdFieldW, pdRightX}
	my levelColumns()
	set {{dx, dy}, {dw, dh}} to level1Doc's frame()
	level1Doc's setFrameSize:{(level1Scroll's contentSize()'s width) as integer, dh}
	if oldW is pdFieldW and oldX is pdRightX then return
	repeat with sub in (level1Doc's subviews() as list)
		set {{sx, sy}, {sw, sh}} to (contents of sub)'s frame()
		if sx < oldX - 5 then
			set {colOld, colNew} to {3, 3}
		else
			set {colOld, colNew} to {oldX, pdRightX}
		end if
		set off to sx - colOld
		if off > oldW then set off to off - oldW + pdFieldW -- a + or − button after the field
		((contents of sub)'s setFrameOrigin:{colNew + off, sy})
		if ((contents of sub)'s isKindOfClass:(current application's NSTextField's |class|())) as boolean then
			((contents of sub)'s setFrameSize:{pdFieldW, sh})
		end if
	end repeat
end layoutLevelDoc

-- one field with + and − (− only when there is more than one row)
on addFolderRow(t, x, ry, fieldTag, i, n, isOn, addAction, removeAction, hint)
	set f to current application's NSTextField's textFieldWithString:t
	f's setFrame:{{x, ry}, {pdFieldW, 24}}
	f's setTag:fieldTag
	f's setDelegate:me
	-- (no placeholder text in level folder and level 2 fields)
	f's setEnabled:isOn
	level1Doc's addSubview:f
	set b to current application's NSButton's buttonWithImage:(current application's NSImage's imageNamed:"NSAddTemplate") target:me action:addAction
	b's setBezelStyle:10
	b's setFrame:{{x + pdFieldW + 5, ry}, {24, 24}}
	b's setTag:i
	b's setEnabled:isOn
	b's setToolTip:"Add a folder below"
	level1Doc's addSubview:b
	if n > 1 then
		set b to current application's NSButton's buttonWithImage:(current application's NSImage's imageNamed:"NSRemoveTemplate") target:me action:removeAction
		b's setBezelStyle:10
		b's setFrame:{{x + pdFieldW + 32, ry}, {24, 24}}
		b's setTag:i
		b's setEnabled:isOn
		b's setToolTip:"Remove this folder"
		level1Doc's addSubview:b
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

on levelsChanged(focusTag)
	my rebuildLevelRows(focusTag)
	my syncRows()
	my refresh()
end levelsChanged

on addLevel1:sender
	set i to (sender's tag()) as integer
	set level1List to my insertAfter(level1List, i)
	my levelsChanged(101 + i)
end addLevel1:

on removeLevel1:sender
	set level1List to my removeAt(level1List, (sender's tag()) as integer)
	my levelsChanged(0)
end removeLevel1:

on addLevel2:sender
	set i to (sender's tag()) as integer
	set level2List to my insertAfter(level2List, i)
	my levelsChanged(201 + i)
end addLevel2:

on removeLevel2:sender
	set level2List to my removeAt(level2List, (sender's tag()) as integer)
	my levelsChanged(0)
end removeLevel2:

on level2Toggled:sender
	set level2On to ((sender's state()) as integer is 1)
	if level2On then
		my levelsChanged(201)
	else
		my levelsChanged(0)
	end if
end level2Toggled:

on prelightToggled:sender
	set isOn to ((cbPrelight's state()) as integer is 1)
	fPrelight's setEnabled:isOn
	if isOn then win's makeFirstResponder:fPrelight
	my refresh()
end prelightToggled:

on shotsToggled:sender
	my refresh()
end shotsToggled:

on level1Toggled:sender
	if (cbLevel1's state()) as integer is 1 then
		my levelsChanged(101)
	else
		my levelsChanged(0)
	end if
end level1Toggled:

-- Rebuilds the table rows when the level folders change; keeps what was typed per row
on syncRows()
	try
		set names to my activeLevelPaths()
	on error
		return -- invalid names: refresh shows the problem, keep the rows
	end try
	my syncTop(names)
	set names to my sortedRows(names)
	-- table rows are keyed by the level path: "Studio", or "Studio/DAY1" with level 2
	if (count of names) is 0 then set names to {""}
	considering case
		if names is rowLevelPaths then return
	end considering
	set newNames to {}
	set newCounts to {}
	set newLists to {}
	set newSubs to {}
	set newOwn to {}
	-- each row keeps the data of the old row with the same level folder, so removing a level folder
	-- doesn't hand its prefix and pasted list to the next one. src: old row per new row, 0 = new
	set oldN to count of rowNames
	set src to {}
	set claimed to {}
	repeat with i from 1 to count of names
		set r to my posOfText(item i of names, rowLevelPaths)
		if r > oldN or r is in claimed then set r to 0
		set end of src to r
		if r > 0 then set end of claimed to r
	end repeat
	-- no old row with that name: the level folder was renamed (every keystroke does this) or the
	-- checkbox was switched, so it keeps the row at its position unless another level folder owns it
	repeat with i from 1 to count of names
		if item i of src is 0 and i ≤ oldN and i is not in claimed then
			set item i of src to i
			set end of claimed to i
		end if
	end repeat
	repeat with i from 1 to count of names
		set r to item i of src
		-- a pasted list belongs to its row only; new rows start without one, Subfolders checked
		if r > 0 then
			set end of newSubs to my rowHasSubs(r)
			set end of newOwn to my rowIsOwn(r)
			if r ≤ (count of rowLists) then
				set end of newLists to item r of rowLists
			else
				set end of newLists to {}
			end if
			set nm to item r of rowNames
			set c to item r of rowCounts
		else
			set sv to my savedRowFor(item i of names)
			if sv is not missing value then
				-- a row of the last session: its prefix, shots, list and Subfolders come back as they were
				set {x, nm, c, ownB, subsB, L} to sv
				set end of newSubs to subsB
				set end of newOwn to ownB
				set end of newLists to L
				set r to -1 -- so the global prefix and number don't replace them
			else
				set end of newSubs to true
				set end of newOwn to false
				set end of newLists to {}
				if i > 1 then
					set nm to item (i - 1) of newNames
					set c to item (i - 1) of newCounts
				else
					set nm to defPrefix
					set c to defCount
				end if
			end if
		end if
		-- new rows follow the global prefix and number when they are set
		if r is 0 and fAllPrefix is not missing value then
			set allP to my trim((fAllPrefix's stringValue()) as text)
			if allP is not "" then set nm to allP
		end if
		if r is 0 and fAllCounts is not missing value then
			set allT to my trim((fAllCounts's stringValue()) as text)
			if allT is not "" then set c to allT
		end if
		if c is "0" then set c to "10" -- shot folders need at least one shot
		set end of newNames to nm
		set end of newCounts to c
	end repeat
	set rowLevelPaths to names
	set rowNames to newNames
	set rowCounts to newCounts
	set rowLists to newLists
	set rowSubs to newSubs
	set rowOwnName to newOwn
	tbl's reloadData()
	my fitTable() -- taller or shorter, so every row shows
end syncRows

-- With two levels, shows the level 1 folder of each row in its own column
-- and calls the level 2 column Level 2; with one level that column is hidden
on syncTop(paths)
	set tops to {}
	repeat with p in paths
		set k to my level1Of(contents of p)
		if k is not "" and my posOfText(k, tops) is 0 then set end of tops to k
	end repeat
	set oldTID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to ", "
	set t to tops as text
	set AppleScript's text item delimiters to oldTID
	considering case
		if t is rowLevel1 then return
	end considering
	set rowLevel1 to t
	(tbl's tableColumnWithIdentifier:"level1")'s setHidden:(t is "")
	if t is "" then
		(tbl's tableColumnWithIdentifier:"level2")'s headerCell()'s setStringValue:"Level 1"
	else
		(tbl's tableColumnWithIdentifier:"level2")'s headerCell()'s setStringValue:"Level 2"
	end if
	my showSortIndicator()
	tbl's headerView()'s setNeedsDisplay:true
	tbl's reloadData()
end syncTop

-- The table's row order: by level folder (as the level folders are listed), or with "level2" by level 2,
-- each level 2's level folders in their listed order. Only the table; folders are made in level folder order.
on sortedRows(paths)
	if rowSort is not "level2" or rowLevel1 is "" then return paths
	set keys to {}
	repeat with p in paths
		set k to my lastComponent(contents of p)
		if my posOfText(k, keys) is 0 then set end of keys to k
	end repeat
	set out to {}
	repeat with k in keys
		repeat with p in paths
			if my lastComponent(contents of p) is (contents of k) then set end of out to contents of p
		end repeat
	end repeat
	return out
end sortedRows

-- the arrow in the header of the column the rows are sorted by (with two levels only)
on showSortIndicator()
	set colLevel1 to tbl's tableColumnWithIdentifier:"level1"
	set colLevel2 to tbl's tableColumnWithIdentifier:"level2"
	tbl's setIndicatorImage:(missing value) inTableColumn:colLevel1
	tbl's setIndicatorImage:(missing value) inTableColumn:colLevel2
	if rowLevel1 is "" then return
	set img to current application's NSImage's imageNamed:"NSAscendingSortIndicator"
	if rowSort is "level2" then
		tbl's setIndicatorImage:img inTableColumn:colLevel2
	else
		tbl's setIndicatorImage:img inTableColumn:colLevel1
	end if
end showSortIndicator

-- clicking the Level 1 or Level 2 header sorts the rows by that column
on tableView:tv didClickTableColumn:col
	if rowLevel1 is "" then return -- one level: nothing to sort by
	set cid to (col's identifier()) as text
	if cid is "level1" then
		set newSort to "level1"
	else if cid is "level2" then
		set newSort to "level2"
	else
		return
	end if
	if newSort is rowSort then return
	win's makeFirstResponder:(missing value) -- commits a table cell still being edited
	tbl's deselectAll:me
	set rowSort to newSort
	my writePref("tablesort", rowSort)
	my syncRows()
	my showSortIndicator()
	my refresh()
end tableView:didClickTableColumn:

-- true when row i's prefix was typed in the table, so the global prefix doesn't change it
on rowIsOwn(i)
	if i > (count of rowOwnName) then return false
	return item i of rowOwnName
end rowIsOwn

-- The table rows as one pref: a line per row, tab between its fields
-- (level path, prefix, shots, own prefix 1/0, subfolders 1/0, list), the list's names joined by
-- character id 31; folder names come from single-line fields, so none of these can be in them
on rowsText()
	set us to character id 31
	set lines_ to {}
	set oldTID to AppleScript's text item delimiters
	repeat with i from 1 to count of rowLevelPaths
		set L to {}
		if i ≤ (count of rowLists) then set L to item i of rowLists
		set AppleScript's text item delimiters to us
		set lt to L as text
		set f to {item i of rowLevelPaths, item i of rowNames, item i of rowCounts, my boolText(my rowIsOwn(i)), my boolText(my rowHasSubs(i)), lt}
		set AppleScript's text item delimiters to tab
		set end of lines_ to f as text
	end repeat
	set AppleScript's text item delimiters to linefeed
	set t to lines_ as text
	set AppleScript's text item delimiters to oldTID
	return t
end rowsText

on readSavedRows()
	set out to {}
	set oldTID to AppleScript's text item delimiters
	try
		set AppleScript's text item delimiters to linefeed
		set lines_ to text items of (my readPref("shotrows", ""))
		repeat with ln in lines_
			set AppleScript's text item delimiters to tab
			set f to text items of (contents of ln)
			if (count of f) is 6 then
				set AppleScript's text item delimiters to character id 31
				set L to {}
				if item 6 of f is not "" then set L to text items of (item 6 of f)
				set end of out to {item 1 of f, item 2 of f, item 3 of f, (item 4 of f is "1"), (item 5 of f is "1"), L}
			end if
		end repeat
	end try
	set AppleScript's text item delimiters to oldTID
	return out
end readSavedRows

-- the saved row for a level path (case-sensitive, like the table), or missing value
on savedRowFor(p)
	considering case
		repeat with sr in savedRows
			if item 1 of sr is p then return contents of sr
		end repeat
	end considering
	return missing value
end savedRowFor

-- the Subfolders checkbox of table row i (1-based); checked unless it was turned off
on rowHasSubs(i)
	if i > (count of rowSubs) then return true
	return item i of rowSubs
end rowHasSubs

---------- WINDOW EVENTS ----------
on controlTextDidChange:aNotification
	set obj to aNotification's object()
	if (obj's isEqual:tbl) as boolean then
		-- typing in a table cell: update the preview before the cell is committed
		try
			set r to (tbl's editedRow()) as integer
			set c to (tbl's editedColumn()) as integer
			set t to ((aNotification's userInfo()'s objectForKey:"NSFieldEditor")'s |string|()) as text
			set cid to ((item (c + 1) of (tbl's tableColumns() as list))'s identifier()) as text
			if r ≥ 0 and r < (count of rowNames) then
				if cid is "name" then set item (r + 1) of rowNames to t
				if cid is "count" then set item (r + 1) of rowCounts to t
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
	else if (obj's tag()) as integer is 302 then
		set wantFilePrefix to (obj's stringValue()) as text
	else if (obj's tag()) as integer is 301 then
		-- shot prefix for every row the table hasn't given its own
		set t to my trim((obj's stringValue()) as text)
		if t is not "" then
			repeat with k from 1 to count of rowNames
				if not my rowIsOwn(k) then set item k of rowNames to t
			end repeat
			tbl's reloadData()
		end if
	else if (obj's tag()) as integer > 200 then
		-- a level 2 field
		set i to ((obj's tag()) as integer) - 200
		if i ≤ (count of level2List) then set item i of level2List to (obj's stringValue()) as text
		my syncRows()
	else if (obj's tag()) as integer > 100 then
		-- a level folder field
		set i to ((obj's tag()) as integer) - 100
		if i ≤ (count of level1List) then set item i of level1List to (obj's stringValue()) as text
		my syncRows()
	end if
	my refresh()
end controlTextDidChange:

on popupChanged:sender
	set i to ((sender's indexOfSelectedItem()) as integer) + 1
	if (sender's isEqual:pNumbering) as boolean then set wantNumbering to item i of numberingOrder
	if (sender's isEqual:pFolderMode) as boolean then set wantFolderMode to item i of folderModeIds
	if (sender's isEqual:pFileMode) as boolean then set wantFileMode to i
	my refresh()
end popupChanged:

-- the folder prefix checkboxes
on namingToggled:sender
	set isOn to ((sender's state()) as integer is 1)
	if (sender's isEqual:cbFolderJob) as boolean then set wantFolderJob to isOn
	if (sender's isEqual:cbFolderDate) as boolean then set wantFolderDate to isOn
	my refresh()
end namingToggled:

on chooseLocation:sender
	set op to current application's NSOpenPanel's openPanel()
	op's setCanChooseDirectories:true
	op's setCanChooseFiles:false
	op's setCanCreateDirectories:true
	op's setPrompt:"Choose"
	op's setMessage:"Where should the session be created?"
	op's setDirectoryURL:(current application's NSURL's fileURLWithPath:basePath)
	win's setLevel:0 -- let the panel come in front
	set r to (op's runModal()) as integer
	win's setLevel:3
	if r is 1 then
		set p to (op's |URL|()'s |path|()) as text
		if p does not end with "/" then set p to p & "/"
		set basePath to p
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
	if (col's identifier()) as text is "subs" then return -- the checkbox handles its own click
	if (col's identifier()) as text is "list" then
		-- a click inside a multiple selection pastes into all of it
		set rows to my selectedRows()
		if (r + 1) is not in rows then set rows to {r + 1}
		my openPaste(rows)
	else if (col's identifier()) as text is not in {"level1", "level2"} and my canEdit(col, r + 1) then
		tbl's editColumn:c row:r withEvent:(missing value) |select|:true
	end if
end tableClicked:

-- Fits the level folder columns, Shots and List to their widest text; Shot folder prefix gets the rest of the width
on sizeColumns()
	set cols to tbl's tableColumns() as list
	set avail to ((tbl's enclosingScrollView()'s contentSize())'s width) as real
	set gap to ((tbl's intercellSpacing())'s width) as real
	set level1On to (rowLevel1 is not "")
	set wants to {}
	repeat with col in items 1 thru 5 of cols
		set f to (col's dataCell()'s |font|())
		set attrs to (current application's NSDictionary's dictionaryWithObject:f forKey:(current application's NSFontAttributeName))
		set w to ((((current application's NSString's stringWithString:((col's headerCell()'s stringValue()) as text))'s sizeWithAttributes:attrs)'s width) as real) + 12
		-- the sortable Level 1 and Level 2 headers also hold the sort arrow
		if level1On and (col's identifier()) as text is in {"level1", "level2"} then set w to w + 16
		repeat with r from 0 to (count of rowNames) - 1
			set t to (my tableView:tbl objectValueForTableColumn:col row:r) as text
			set cw to ((((current application's NSString's stringWithString:t)'s sizeWithAttributes:attrs)'s width) as real) + 10
			if cw > w then set w to cw
		end repeat
		set end of wants to w
	end repeat
	set {wT, wP, wN, wC, wL} to wants
	set wC to my clampInt(wC, 50, 90)
	set wL to my clampInt(wL, 60, 100)
	set wS to 75 -- Subfolders: fixed, fits its header
	set nGaps to 5
	if level1On then set nGaps to 6
	set spare to avail - wC - wL - wS - nGaps * gap
	-- the window width at which the level 1 folders (up to 300) fit beside a 120 prefix
	set tblNeedW to 0
	if level1On then
		set wantT to wT
		if wantT > 300 then set wantT to 300
		set wantP to wP
		if wantP < 50 then set wantP to 50
		set {{cx, cy}, {cw, ch}} to win's contentView()'s frame()
		set tblNeedW to (cw + (wantT + wantP + 120 - spare)) as integer
	end if
	-- the level folders get what they need, but leave the prefix at least 120 (80 with two levels);
	-- with two levels the level 2 comes first and the level 1 list, the same on every row,
	-- takes what is left (it ends in … when it doesn't fit)
	if level1On then
		if wP > spare / 3 then set wP to spare / 3
		if wP < 50 then set wP to 50
		set room to spare - wP - 80
		if wT > room then set wT to room
		if wT < 40 then set wT to 40
	else
		set wT to 0
		if wP > spare - 120 then set wP to spare - 120
		if wP < 70 then set wP to 70
	end if
	set wN to spare - wP - wT
	repeat with k from 1 to 6
		((item k of cols)'s setWidth:(item k of {wT, wP, wN, wC, wL, wS}))
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
	if (col's identifier()) as text is in {"level1", "level2"} then return false
	return my canEdit(col, (r as integer) + 1)
end tableView:shouldEditTableColumn:row:

on tableView:tv willDisplayCell:cell forTableColumn:col row:r
	if (col's identifier()) as text is "subs" then return -- a checkbox, no text colour
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
	if cid is "level1" then return my level1Of(item i of rowLevelPaths)
	if cid is "level2" then
		set p to item i of rowLevelPaths
		if p is "" then return rawName -- no level folders: shots go straight into RAW
		return my lastComponent(p) -- direct level folder only; the level 1 folder has its own column
	else if cid is "name" then
		return item i of rowNames
	else if cid is "subs" then
		if my rowHasSubs(i) then return 1
		return 0
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
	set cid to (col's identifier()) as text
	if cid is "subs" then
		repeat while (count of rowSubs) < i
			set end of rowSubs to true
		end repeat
		set item i of rowSubs to ((val's integerValue()) as integer is 1)
		my refresh()
		return
	end if
	set t to ""
	if val is not missing value then set t to val as text
	if cid is "name" then
		repeat while (count of rowOwnName) < i
			set end of rowOwnName to false
		end repeat
		set allP to my trim((fAllPrefix's stringValue()) as text)
		if my trim(t) is "" and allP is not "" then
			-- cleared: the row follows the global prefix again
			set t to allP
			set item i of rowOwnName to false
		else
			set item i of rowOwnName to (t is not allP)
		end if
		set item i of rowNames to t
	end if
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
	set pp to item i of rowLevelPaths -- "Studio/DAY1" with level 2
	if pp is "" then set pp to rawName
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
	set {win, cbLevel1, formView} to {missing value, missing value, missing value}
	set {tbl, tblScroll, rowLevel1} to {missing value, missing value, ""}
	set {rbAppend, rbReplace} to {missing value, missing value}
	set {btnPaste, pastePanel, pasteView} to {missing value, missing value, missing value}
	set {fClient, cbLevel2, fAllCounts, fFileName, fShotName} to {missing value, missing value, missing value, missing value, missing value}
	set fAllPrefix to missing value
	set {pdFieldW, pdRightX} to {165, 235}
	set {fLocation, fJob, fDateFmt, fDate, fPhotog, level1Scroll, level1Doc} to {missing value, missing value, missing value, missing value, missing value, missing value, missing value}
	set {rbSep, fFolders, cbShots, cbPrelight, fPrelight, fShotSubs} to {{}, {}, missing value, missing value, missing value, missing value}
	try
		if previewPanel is not missing value then previewPanel's orderOut:(missing value)
	end try
	set {previewPanel, fStatus} to {missing value, missing value}
	set {pNumbering, pFolderMode, pDigits, pCounter, previewView, createBtn} to {missing value, missing value, missing value, missing value, missing value, missing value}
	set {cbFolderJob, cbFolderDate, pFileMode, fFilePrefix} to {missing value, missing value, missing value, missing value}
end releaseWindow

---------- WINDOW HELPERS ----------
-- osascript has no menu bar, so ⌘C/⌘V/⌘X/⌘A/⌘Z do nothing in text fields;
-- an Edit menu (never shown for an accessory app) gives the keys somewhere to go
on installEditMenu(nsApp)
	if nsApp's mainMenu() is not missing value then return
	set menuBar to current application's NSMenu's alloc()'s initWithTitle:""
	set appItem to current application's NSMenuItem's alloc()'s initWithTitle:"" action:(missing value) keyEquivalent:""
	appItem's setSubmenu:(current application's NSMenu's alloc()'s initWithTitle:"")
	menuBar's addItem:appItem
	set editMenu to current application's NSMenu's alloc()'s initWithTitle:"Edit"
	repeat with spec in {{"Undo", "undo:", "z"}, {"Redo", "redo:", "Z"}, {"Cut", "cut:", "x"}, {"Copy", "copy:", "c"}, {"Paste", "paste:", "v"}, {"Select All", "selectAll:", "a"}}
		(editMenu's addItemWithTitle:(item 1 of spec) action:(item 2 of spec) keyEquivalent:(item 3 of spec))
	end repeat
	set editItem to current application's NSMenuItem's alloc()'s initWithTitle:"Edit" action:(missing value) keyEquivalent:""
	editItem's setSubmenu:editMenu
	menuBar's addItem:editItem
	nsApp's setMainMenu:menuBar
end installEditMenu

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

on addCheck(v, t, x, y, wd, isOn)
	set b to current application's NSButton's checkboxWithTitle:t target:me action:"namingToggled:"
	b's setFrame:{{x, y + 1}, {wd, 22}}
	if isOn then b's setState:1
	v's addSubview:b
	return b
end addCheck

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
	fLocation's setStringValue:(((current application's NSString's stringWithString:basePath)'s stringByAbbreviatingWithTildeInPath()) as text)
	fLocation's setToolTip:basePath
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
-- Shot folder paths inside RAW, with the folder naming (rFolderMode, rPre) applied
on makeShotNames(groups, digits, numberingMode)
	set out to {}
	set gi to 0
	repeat with g in my numberGroups(my numberInput(groups), numberingMode)
		set gi to gi + 1
		set {p, n, s, c} to contents of g
		set L to {}
		if gi ≤ (count of rGroupLists) then set L to item gi of rGroupLists
		-- pre: what comes before the shot prefix
		set pre to my shotPre(p, rFolderMode, rPre)
		set p to my diskFolder(p, false, rFolderMode, rPre)
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

-- What goes in front of a shot folder's prefix: with balanced and dense naming the date and/or
-- job (pre) and every level folder ("ACME_Studio_DAY1_"); with simple naming nothing
on shotPre(p, m, pre)
	if m is 1 then return ""
	if p is "" then return pre
	return pre & my pName(p) & partSep
end shotPre

-- Where a level path ("Studio/DAY1") is on disk inside RAW with folder naming m:
-- simple and balanced Studio/DAY1, dense ACME_Studio/ACME_Studio_DAY1. isCapture: the last
-- level is captured into (shot folders off), so with balanced it carries the others too
on diskFolder(p, isCapture, m, pre)
	if p is "" or m is 1 then return p
	set oldTID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "/"
	set comps to text items of p
	set out to {}
	set chain to ""
	repeat with k from 1 to count of comps
		set c to item k of comps
		if k is 1 then
			set chain to c
		else
			set chain to chain & partSep & c
		end if
		if m is 3 or (isCapture and k is (count of comps)) then
			set end of out to pre & chain
		else
			set end of out to c
		end if
	end repeat
	set r to out as text
	set AppleScript's text item delimiters to oldTID
	return r
end diskFolder

-- The first capture folder's path for the folder naming popup
on examplePath(p, shot, hasShots, m, pre)
	if not hasShots then return my diskFolder(p, true, m, pre)
	set leaf to my shotPre(p, m, pre) & shot
	if p is "" then return leaf
	return my diskFolder(p, false, m, pre) & "/" & leaf
end examplePath

-- Of the level paths above the capture folders: {the leading part they all share ("Studio"),
-- the rest that differs, as text ("DAY1, DAY2"; levels split by " / ")}
on commonLevel1(ups)
	if ups is {} then return {"", ""}
	set oldTID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "/"
	set compLists to {}
	set maxN to 0
	repeat with u in ups
		if (contents of u) is "" then
			set end of compLists to {}
		else
			set end of compLists to text items of (contents of u)
		end if
		if (count of last item of compLists) > maxN then set maxN to count of last item of compLists
	end repeat
	set common to {}
	repeat with k from 1 to maxN
		set firstL to item 1 of compLists
		if (count of firstL) < k then exit repeat
		set same to true
		repeat with cl in compLists
			if (count of cl) < k then
				set same to false
			else if item k of cl is not item k of firstL then
				set same to false
			end if
		end repeat
		if not same then exit repeat
		set end of common to item k of item 1 of compLists
	end repeat
	set commonText to common as text
	-- every level below the shared part, each value once
	set lostLevels to {}
	repeat with k from (count of common) + 1 to maxN
		set vals to {}
		repeat with cl in compLists
			if (count of cl) ≥ k then
				if my posOfText(item k of cl, vals) is 0 then set end of vals to item k of cl
			end if
		end repeat
		set AppleScript's text item delimiters to ", "
		set end of lostLevels to vals as text
	end repeat
	set AppleScript's text item delimiters to " / "
	set lostText to lostLevels as text
	set AppleScript's text item delimiters to oldTID
	return {commonText, lostText}
end commonLevel1

---------- SESSION BUILDER (no dialogs; also used by tests) ----------
on buildSession(baseFolder, sessionName, jobName, photographer, shotNames, captureFormat)
	set sessionPath to (POSIX path of baseFolder) & sessionName & "/"
	set copyrightNote to ""
	---------- 2. CREATE SESSION ----------
	tell application "Capture One"
		activate
		if templateName is "" then
			set newDoc to make new document with properties {kind:session, name:sessionName, path:baseFolder}
		else
			set newDoc to make new document with properties {kind:session, name:sessionName, path:baseFolder, template:templateName}
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
		set firstCapturePath to rawPath -- no level folder or shot folders: capture straight into RAW
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
		-- ignoring case, like the disk: a folder named "output" IS Capture One's "Output"
		if {contents of d} is not in ({rawName, selectsName, outputName, trashName} & extraFolders) then set end of defaults to quoted form of (contents of d)
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
on summaryText(sessionName, basePath, shotNames, photographer)
	set t to "Create session “" & sessionName & "”" & return & "in " & basePath & return & return
	-- the session folder, with RAW (and everything captured into) first
	set t to t & sessionName & "/" & return
	set t to t & my indent(1) & rawName & "/" & return
	if prelightName is not "" then set t to t & my indent(2) & prelightName & "/" & return
	-- folder tree inside RAW: every level 1 folder, level 2 folder, shot folder and shot subfolder on its own
	-- indented line, each level printed once where it changes
	set printed to {} -- path components of the previous line, by level
	set oldTID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "/"
	repeat with sp in shotNames
		set comps to text items of (contents of sp)
		set same to true
		repeat with k from 1 to count of comps
			if same and k ≤ (count of printed) then
				if item k of printed is not item k of comps then set same to false
			else
				set same to false
			end if
			if not same then set t to t & my indent(k + 1) & item k of comps & "/" & return
		end repeat
		set printed to comps
	end repeat
	set AppleScript's text item delimiters to oldTID
	-- then the other session folders, each on its own line beside RAW
	repeat with f in {selectsName, outputName, trashName} & extraFolders
		if (contents of f) is not "" then set t to t & my indent(1) & (contents of f) & "/" & return
	end repeat
	set t to text 1 thru -2 of t -- no empty line at the end
	-- (the file name is shown large above the summary)
	if photographer is not "" then set t to t & return & "Copyright:  " & photographer
	if copyrightStyle is not "" then set t to t & return & "Copyright style:  " & copyrightStyle
	return t
end summaryText

on level1Of(relPath)
	-- everything before the last /: "Studio/DAY1/SHOT01" -> "Studio/DAY1"
	if relPath does not contain "/" then return ""
	set oldTID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "/"
	set r to (text items 1 thru -2 of relPath) as text
	set AppleScript's text item delimiters to oldTID
	return r
end level1Of

-- "Studio, Day 1,, Roof top" -> {"Studio", "Day-1", "Roof-top"}
on splitList(t)
	set oldTID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to ","
	set parts to text items of t
	set AppleScript's text item delimiters to oldTID
	set out to {}
	repeat with x in parts
		set x to my spacesToDashes(my trim(contents of x))
		if x contains "/" or x contains ":" then error "Folder names can't contain / or :"
		if x is not "" then set end of out to x
	end repeat
	return out
end splitList

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

-- Adds the first number to each {level folder, name, count} group -> {level folder, name, first, count}.
-- numberingMode 1: level folders sharing a shot name continue its count; a different shot name starts at 1
--               2: every level folder starts at 1
--               3: one counter across all level folders, whatever the shot name
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

-- NSUserDefaults rather than the defaults command: `defaults read` escapes accented
-- characters (Zoë comes back as Zo\353), and this needs no shell
on readPref(k, fallback)
	try
		set v to (current application's NSUserDefaults's alloc()'s initWithSuiteName:prefsDomain)'s stringForKey:k
		if v is missing value then return fallback
		return v as text
	on error
		return fallback
	end try
end readPref

on writePref(k, v)
	set d to current application's NSUserDefaults's alloc()'s initWithSuiteName:prefsDomain
	d's setObject:(v as text) forKey:k
	d's synchronize()
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
	-- simple naming: unique folder names still lose the level folder (SHOT01 doesn't say it was shot in Studio)
	if dupes is {} then return rLostNote
	set AppleScript's text item delimiters to ", "
	set d to dupes as text
	set AppleScript's text item delimiters to ""
	set t to "Note: more than one capture folder is named " & d & "." & return & "If the counter is reset when switching folders, file names will repeat."
	if rLostNote is not "" then set t to rLostNote & return & t
	return t
end sameNameWarning

-- The folder and file naming choices; older versions saved one shot folder naming ("mode",
-- 1 shot, 2 job_shot, 3 level_shot, 4 job_level_shot, 5 date_job_level_shot, 6 date_job_shot)
-- and one capture file naming ("filenaming", 4-6 had the date): carried over the first time
on readNamingPrefs()
	set oldMode to my readPref("mode", "")
	set oldFile to my readPref("filenaming", "")
	set defMode to 2
	set defJob to "1"
	set defDate to "0"
	set defFileDate to 0
	if oldMode is not "" then
		if oldMode is not in {"3", "4", "5"} then set defMode to 1
		if oldMode is not in {"2", "4", "5", "6"} then set defJob to "0"
		if oldMode is in {"5", "6"} then set defDate to "1"
	end if
	if oldFile is in {"4", "5", "6"} or my readPref("filedate", "0") is "1" then set defFileDate to 1
	set wantFolderMode to my clampInt(my prefInt("foldernaming", defMode), 1, 3)
	set wantFolderJob to (my readPref("folderjob", defJob) is "1")
	set wantFolderDate to (my readPref("folderdate", defDate) is "1")
	set wantFileMode to my clampInt(my prefInt("filemode", 2 + (defFileDate as integer)), 1, 3)
	set wantFilePrefix to my readPref("fileprefix", "")
end readNamingPrefs

on boolText(b)
	if b then return "1"
	return "0"
end boolText

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

-- Widens the window (evenly on both sides) when the file name or the level 1 folders in the
-- shots table don't fit, and narrows it back to the width the user chose (640 at least) when they do
on fitWidth()
	set sz to fFileName's attributedStringValue()'s |size|()
	set needW to ((width of sz) as integer) + 60
	if needW < userW then set needW to userW
	if needW < tblNeedW then set needW to tblNeedW -- the level 1 folders fit in the table
	if needW < 640 then set needW to 640
	set {{cx, cy}, {cw, ch}} to win's contentView()'s frame()
	set {{vx, vy}, {vw, vh}} to win's screen()'s visibleFrame()
	if needW > vw then set needW to vw as integer
	set half to (needW - cw) div 2
	if half is 0 then return
	set {{fx, fy}, {fw, fh}} to win's frame()
	win's setFrame:{{fx - half, fy}, {fw + half * 2, fh}} display:true
end fitWidth

-- The window can't be made narrower than 640, nor shorter than with the table at its
-- normal height; dragging it taller only grows the shots table (tableGrows)
on lockHeight()
	set {{cx, cy}, {cw, ch}} to win's contentView()'s frame()
	set keep to tblFit -- the window can't be dragged short enough to hide a row
	if keep > tblExtra then set keep to tblExtra
	win's setContentMinSize:{640, ch - tblExtra + keep}
	win's setContentMaxSize:{100000, 100000}
end lockHeight

-- Which part of the form takes a change of window height: the shots table while the user
-- drags (true), the level folder area when rows are added or removed (false).
-- Everything above the growing part stays pinned to the top, everything below to the bottom.
on tableGrows(flag)
	if flag then
		set {{gx, gy}, {gw, gh}} to tblScroll's frame()
		set grower to tblScroll
	else
		set {{gx, gy}, {gw, gh}} to level1Scroll's frame()
		set grower to level1Scroll
	end if
	repeat with sub in (formView's subviews() as list)
		set {{sx, sy}, {sw, sh}} to (contents of sub)'s frame()
		set h to ((contents of sub)'s autoresizingMask() as integer) mod 8 -- keep the horizontal part
		if ((contents of sub)'s isEqual:grower) as boolean then
			((contents of sub)'s setAutoresizingMask:(h + 16))
		else if flag and (((contents of sub)'s isEqual:btnPaste) as boolean or ((contents of sub)'s isEqual:rbAppend) as boolean or ((contents of sub)'s isEqual:rbReplace) as boolean) then
			((contents of sub)'s setAutoresizingMask:h) -- beside the table's bottom edge: follows it down
		else if (flag and sy + sh > gy + 1) or (not flag and sy ≥ gy) then
			((contents of sub)'s setAutoresizingMask:(h + 8)) -- beside or above it: stays at the top
		else
			((contents of sub)'s setAutoresizingMask:h)
		end if
	end repeat
end tableGrows

-- the horizontal part of a form view's autoresizing: 1 moves with the right edge, 2 stretches
on setHMask(x, h)
	set m to (x's autoresizingMask()) as integer
	x's setAutoresizingMask:(m - (m mod 8) + h)
end setHMask

-- Sizes the table to show every row without scrolling, or to the height the user dragged
-- it to when that is taller; as far as the screen allows
on fitTable()
	if tblScroll is missing value or win is missing value then return
	set n to count of rowNames
	set rowsH to n * (((tbl's rowHeight()) as real) + ((tbl's intercellSpacing())'s height as real))
	tblScroll's tile() -- lays out header and clip view now (before the window is shown they aren't yet)
	set {{cx, cy}, {cw, clipH}} to tblScroll's contentView()'s frame()
	set {{sx, sy}, {sw, svH}} to tblScroll's frame()
	-- the frame the rows need: their height plus the header and border around them
	-- (the clip view may still cover the header area before the window is on screen)
	set {{hx, hy}, {hw, headerH}} to tbl's headerView()'s frame()
	set chrome to svH - clipH
	if chrome < headerH + 2 then set chrome to headerH + 2
	set tblFit to ((rowsH + chrome - tblBase) + 0.999) div 1
	if tblFit < 0 then set tblFit to 0
	set target to tblUser
	if tblFit > target then set target to tblFit
	my setTableExtra(target)
end fitTable

-- makes the table target taller than tblBase, growing or shrinking the window below its top edge
on setTableExtra(target)
	set d to target - tblExtra
	set {{fx, fy}, {fw, fh}} to win's frame()
	set {{vx, vy}, {vw, vh}} to win's screen()'s visibleFrame()
	if d > 0 and fh + d > vh then set d to (vh - fh) as integer -- no room: the table scrolls
	if d is 0 then
		my lockHeight()
		return
	end if
	set newY to fy - d
	if newY < vy then set newY to vy
	my tableGrows(true)
	win's setFrame:{{fx, newY}, {fw, fh + d}} display:true
	my tableGrows(false)
	set tblExtra to tblExtra + d
	my lockHeight()
end setTableExtra

-- Dragging either side edge widens or narrows the window on both sides at once
on windowWillStartLiveResize:aNotification
	set mx to (x of (current application's NSEvent's mouseLocation())) as real
	set {{fx, fy}, {fw, fh}} to win's frame()
	set edgeSign to 0 -- top or bottom edge: only the height changes
	if mx < fx + 12 then set edgeSign to -1 -- the left edge (or a left corner)
	if mx > fx + fw - 12 then set edgeSign to 1 -- the right edge
	set dragStart to {mx, fx as real, fw as real, edgeSign}
	set {{cx, cy}, {cw, ch}} to win's contentView()'s frame()
	set dragStartH to ch
	my tableGrows(true)
end windowWillStartLiveResize:

on windowDidResize:aNotification
	if formView is missing value then return
	if dragStart is not missing value and item 4 of dragStart is not 0 and not inSymResize and (win's inLiveResize()) as boolean then
		-- the new width comes from the mouse alone, so AppKit's own frame each step doesn't add up
		set {mx0, fx0, fw0, edgeSign} to dragStart
		set mx to (x of (current application's NSEvent's mouseLocation())) as real
		set newW to fw0 + 2 * edgeSign * (mx - mx0)
		set {{cx, cy}, {cw, ch}} to win's contentView()'s frame()
		set {{fx, fy}, {fw, fh}} to win's frame()
		set minW to 640 + (fw - cw) -- frame width for the 640 content minimum
		if newW < minW then set newW to minW
		set {{vx, vy}, {vw, vh}} to win's screen()'s visibleFrame()
		if newW > vw then set newW to vw
		set newW to newW as integer
		set newX to (fx0 + (fw0 - newW) / 2) as integer
		set inSymResize to true
		win's setFrame:{{newX, fy}, {newW, fh}} display:true
		set inSymResize to false
	end if
	my layoutLevelDoc()
	my layoutFolders()
	-- the table is wider or narrower: refit its columns (not while a cell is being typed in)
	if tbl is not missing value then
		if (tbl's editedRow()) as integer < 0 then my sizeColumns()
	end if
end windowDidResize:

-- a width dragged by hand is kept for the rest of this run and the next ones
on windowDidEndLiveResize:aNotification
	set dragStart to missing value
	my tableGrows(false)
	set {{tx, ty}, {tw, tblH}} to tblScroll's frame()
	set tblExtra to (tblH - tblBase) as integer
	if tblExtra < 0 then set tblExtra to 0
	set {{cx, cy}, {cw, ch}} to win's contentView()'s frame()
	if ch is not dragStartH then
		-- dragged taller than the rows need: kept; down to the rows: the table follows them again
		set tblUser to tblExtra
		if tblUser ≤ tblFit then set tblUser to 0
		my writePref("tableextra", tblUser)
	end if
	set userW to cw as integer
	my writePref("winwidth", userW)
	my fitWidth() -- a file name wider than the chosen width still fits
end windowDidEndLiveResize:
