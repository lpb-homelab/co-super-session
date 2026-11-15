# Changelog

All notable changes to CO SuperSession are listed here. Versions follow [Semantic Versioning](https://semver.org).

## Unreleased

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

## 0.2.0 – 2026-11-15

- Paste list: paste folder names (one per line) for the selected shot folder rows (⌘A for all), from the Paste list button or the new List column
- Shot folder table columns size themselves to fit their content
- Append / Replace: Append gives SHOT01_name, Replace uses the pasted names as the shot folders (folder naming still adds job, date and parent)
- Summary shortens shot ranges again when pasted names follow the number, keeping the prefix (… SHOT05_pool)

## 0.1.0 – 2026-11-15

First release of the Capture One 16 rewrite.

- Sets up a whole session from one window, with a live preview of the folder tree and capture file name
- Session name built from the date, client and job, with a choice of date formats and separators
- Custom RAW, selects, output, trash and documents folders
- Optional prelight folder, parent folders with subfolders, and numbered shot folders
- Capture file naming and copyright, with or without Capture One Studio
- Remembers your choices between runs
- Licensed under the GNU General Public License v3.0 or later
