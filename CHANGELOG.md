# Changelog

All notable changes to CO SuperSession are listed here. Versions follow [Semantic Versioning](https://semver.org).

## v0.3.1 – 2026-11-19

- Parent folders and subfolders are now called Level 1 and Level 2 folders; Subfolders now means only the shot subfolders. Saved settings for these fields (Parent folders, Subfolders, table sort) reset once
- Folder and file naming redesigned: one Folder naming choice (Simple, Balanced, Dense) with Client + job and Date prefix checkboxes (Date always includes Client + job, so file names never get the job before the date) replaces the Shot folder naming and Capture file naming popups
- Three file naming choices: Simple (file prefix + counter, prefix defaults to client + job), job + levels + shot + counter, or the same with the date in front. The script sets Capture One's [Name] to whatever the capture folder name is missing, so the job is never repeated
- Shot prefix renamed to Shot folder prefix, to keep it apart from the new file prefix
- With Simple folder naming, file names keep the level 1 and level 2 folders all capture folders share, and a note names the ones left out
- Earlier naming choices carry over to the new settings the first time
- Global # and Global prefix renamed to Shots per folder (all rows) and Shot folder prefix (all rows), with the name above each field; they start at 10 and SHOT, then at the last values used
- Paste list…, Append and Replace stay at the bottom of the shot folder table when it grows

## v0.3.0 – 2026-11-16

- Shot folder table: click the Level 1 or Level 2 header to group the rows by that column (remembered); folders are still created and numbered in level 1 order
- The folder tree preview moved to its own large, resizable window, opened with Preview file tree… (⌘P) under the file name; problems and notes now show in a line above the buttons
- The file tree preview lists every shot folder and shot subfolder instead of a range (SHOT01 … SHOT10), inside the session folder with Selects, Output, Trash and any extra folder on their own lines beside RAW
- More space between the capture naming popups and the file name
- Shot folder table: the # field is now labelled Global #
- Shot folder table: a Global prefix field; it sets every row's prefix except the ones typed in the table (clear a row's prefix to make it follow again)
- Parent, subfolder and session folder fields widen with the window
- Shot folder table: with Subfolders on, one row per parent and subfolder pair (Studio/DAY1, Rooftop/DAY1…), each with its own prefix, count and list, shown in separate Parent and Subfolder columns
- Shot folder table grows to show every row without scrolling, and can be dragged taller still from the window's top or bottom edge; that height is remembered
- Widening the window now widens the form's fields and the shot folder table instead of only adding margins; with two parent levels the window widens itself so the Parent column fits

## v0.2.1 – 2026-11-15

- Renamed to CO SuperSession (script file, window title and release zip). When updating, move the old CO Super Session.scpt to the Bin
- Shot folders off with subfolders: Shot folder naming now offers parent_subfolder (KV1/KV1_main), so the parent folder can appear in capture file names
- Shot subfolders: a short comma-separated list (main, plates) creates unnumbered folders inside every shot folder, each named after its shot (SHOT01/SHOT01_main)
- Shot folder table: new Subfolders column with a checkbox per row; only checked rows get the shot subfolders
- Resizable window width: drag either side edge to widen or narrow the window symmetrically (min 640); the file name and preview stretch, the form stays centred, and the width is remembered
- Fixed: parent_subfolder created KV1/main/KV1_main instead of KV1/KV1_main
- Fixed: accented characters in remembered settings (Zoë, Café) came back garbled on the next run
- Fixed: folder names differing only in capitals (RAW and raw, Studio and studio) are now reported as duplicates, and a session folder named output, selects or trash is no longer removed as a Capture One default
- Fixed: with more than five parent or subfolder rows, the list opened scrolled to the bottom
- Fixed: removing a parent folder no longer hands its shot prefix, count and pasted list to the next parent
- Fixed: the chosen file naming, shot folder naming, numbering and shot count are remembered even when a session couldn't use them
- Errors while building or updating the window are now shown instead of failing silently

## v0.2.0 – 2026-11-15

- Paste list: paste folder names (one per line) for the selected shot folder rows (⌘A for all), from the Paste list button or the new List column
- Shot folder table columns size themselves to fit their content
- Append / Replace: Append gives SHOT01_name, Replace uses the pasted names as the shot folders (folder naming still adds job, date and parent)
- Summary shortens shot ranges again when pasted names follow the number, keeping the prefix (… SHOT05_pool)

## v0.1.0 – 2026-11-15

First release of the Capture One 16 rewrite.

- Sets up a whole session from one window, with a live preview of the folder tree and capture file name
- Session name built from the date, client and job, with a choice of date formats and separators
- Custom RAW, selects, output, trash and documents folders
- Optional prelight folder, parent folders with subfolders, and numbered shot folders
- Capture file naming and copyright, with or without Capture One Studio
- Remembers your choices between runs
- Licensed under the GNU General Public License v3.0 or later
