# CO Super Session

A Capture One 16 script that sets up a complete, consistently named session from a single window.

Starting a shoot in Capture One usually means creating the session, renaming its folders, making a folder for every shot, setting the capture naming and adding copyright. CO Super Session does all of that at once. You enter the client, the job and how the shoot is organised, check the preview, and start capturing.

## What it does

- Names the session from the date, client and job, for example `2026-11-14_ACME_Spring-Campaign`
- Creates your own folder layout (RAW, selects, output, trash, documents) and points Capture One at it
- Builds capture folders for the shoot: a prelight folder, groups such as days or locations, and numbered shot folders
- Sets the capture file naming so every image carries the job and shot it belongs to
- Adds the photographer's copyright to every capture
- Shows the resulting folder tree and a sample file name before anything is created, and flags problems such as a folder that already exists
- Remembers your choices for the next session

A two-day shoot with five shots a day might look like this:

```
2026-11-14_ACME_Spring-Campaign/
├── 00_RAW/
│   ├── _prelight/
│   ├── DAY1/
│   │   ├── SHOT01/
│   │   ├── SHOT02/
│   │   ├── SHOT03/
│   │   ├── SHOT04/
│   │   └── SHOT05/
│   └── DAY2/
│       ├── SHOT06/
│       ├── SHOT07/
│       ├── SHOT08/
│       ├── SHOT09/
│       └── SHOT10/
├── 01_SELECTS/
├── 02_OUTPUT/
├── 03_TRASH/
└── 04_DOCS/
```

A fashion shoot can go a level deeper. Here the brand Halden shoots its FW27 season. It uses two collections, NORDLYS and EMBER, as parent folders, with LOOKBOOK and EDITORIAL as subfolders. The lookbook shots use the prefix LOOK and the editorial shots use SET, numbering restarts in each folder, and the shot folders are named job_parent_shot so each folder and every capture in it carries the client, job, collection and subfolder:

```
2027-02-15_HALDEN_FW27/
├── 00_RAW/
│   ├── _prelight/
│   ├── NORDLYS/
│   │   ├── LOOKBOOK/
│   │   │   ├── HALDEN_FW27_NORDLYS_LOOKBOOK_LOOK01/
│   │   │   ├── HALDEN_FW27_NORDLYS_LOOKBOOK_LOOK02/
│   │   │   ├── HALDEN_FW27_NORDLYS_LOOKBOOK_LOOK03/
│   │   │   └── HALDEN_FW27_NORDLYS_LOOKBOOK_LOOK04/
│   │   └── EDITORIAL/
│   │       ├── HALDEN_FW27_NORDLYS_EDITORIAL_SET01/
│   │       └── HALDEN_FW27_NORDLYS_EDITORIAL_SET02/
│   └── EMBER/
│       ├── LOOKBOOK/
│       │   ├── HALDEN_FW27_EMBER_LOOKBOOK_LOOK01/
│       │   ├── HALDEN_FW27_EMBER_LOOKBOOK_LOOK02/
│       │   ├── HALDEN_FW27_EMBER_LOOKBOOK_LOOK03/
│       │   └── HALDEN_FW27_EMBER_LOOKBOOK_LOOK04/
│       └── EDITORIAL/
│           ├── HALDEN_FW27_EMBER_EDITORIAL_SET01/
│           └── HALDEN_FW27_EMBER_EDITORIAL_SET02/
├── 01_SELECTS/
├── 02_OUTPUT/
├── 03_TRASH/
└── 04_DOCS/
```

A capture in the second Ember look could then be named `HALDEN_FW27_EMBER_LOOKBOOK_LOOK02_0001`.

When the session is ready, Capture One opens on the first capture folder.

## Requirements

- macOS
- Capture One 16

Writing copyright directly needs Capture One Studio. Without Studio, the script can apply a saved metadata style instead.

> [!CAUTION]
> Updates within Capture One 16 are fine. After a major upgrade (17 or later), test the script on a throwaway session before a real shoot. A new version may not be found by the script, or may change the scripting commands it relies on. If the script asks where Capture One is, open **CO Super Session.scpt** in Script Editor, choose Capture One when asked, and save. If you have the source, you can run `./install.sh` again instead. Having two major versions installed at once can make the script open the wrong one.

## Installation

1. Download the latest **CO-Super-Session** zip from the [Releases page](../../releases) and double-click it to unzip.
2. In Capture One, choose **Scripts › Open Scripts Folder** and drag **CO Super Session.scpt** into the folder that opens.
3. Choose **Scripts › Update Scripts Menu**, then **Scripts › CO Super Session**.

To update, do the same with the newer version and replace the old file. The version you have is shown in the script's window title.

## Customising

A few defaults live at the top of `CO Super Session.applescript`, including a session template to start from and a copyright style for users without Studio. To change them, download the source, edit the file and run `./install.sh` from its folder in Terminal. This builds the script and installs it in Capture One's Scripts folder.

## Credits

Originally written in 2019 as SuperSession by Louis-Philippe Beauduin. Rewritten in 2026 for Capture One 16 with the help of Claude Code.

## License

Copyright © 2026 Louis-Philippe Beauduin. CO Super Session is free software under the [GNU General Public License v3.0](LICENSE) or any later version. You can use, share and change it. If you share a changed version, you must release its source under the same licence.
