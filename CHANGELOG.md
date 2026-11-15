# Changelog

All notable changes to CO Super Session are listed here. Versions follow [Semantic Versioning](https://semver.org).

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
