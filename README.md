# CO SuperSession

A Capture One 16 script that sets up a complete, consistently named session from a single window.

Starting a shoot in Capture One usually means creating the session, renaming its folders, making a folder for every shot, setting the capture naming and adding copyright. CO Super Session does all of that at once. You enter the client, the job and how the shoot is organised, check the preview, and start capturing.

## What it does

- Names the session from the date, client and job, for example `2026-11-14_LUMARA_Night-Glow`
- Creates your own folder layout (RAW, selects, output, trash, documents) and points Capture One at it
- Builds capture folders for the shoot: a prelight folder, groups such as days or locations, and numbered shot folders
- Takes a pasted list of names, such as SKUs, looks or talent, one per line, so each shot folder carries its own name. It warns you if two folders would end up with the same name
- Sets the capture file naming so every image carries the job and shot it belongs to
- Adds the photographer's copyright to every capture
- Shows the resulting folder tree and a sample file name before anything is created, and flags problems such as a folder that already exists
- Remembers your choices for the next session

A two-day shoot for the lamp brand Lumara, with three key visuals (prefix KV) a day, might look like this:

```
2026-11-14_LUMARA_Night-Glow/
├── 00_RAW/
│   ├── _prelight/
│   ├── DAY1/
│   │   ├── KV01/
│   │   ├── KV02/
│   │   └── KV03/
│   └── DAY2/
│       ├── KV04/
│       ├── KV05/
│       └── KV06/
├── 01_SELECTS/
├── 02_OUTPUT/
├── 03_TRASH/
└── 04_DOCS/
```

A fashion shoot can go a level deeper. Here the brand Halden shoots its FW27 season. It uses two collections, NORDLYS and EMBER, as parent folders, with LOOKBOOK and EDITORIAL as subfolders. The lookbook shots use the prefix L and the editorial shots use SET, and numbering restarts in each folder. The lookbook rows also get a pasted list of SKU codes (Paste list, Append), so each look folder carries its SKU. The shot folders are named job_parent_shot, so each folder and every capture in it carries the client, job, collection and subfolder:

```
2027-02-15_HALDEN_FW27/
├── 00_RAW/
│   ├── _prelight/
│   ├── NORDLYS/
│   │   ├── LOOKBOOK/
│   │   │   ├── HALDEN_FW27_NORDLYS_LOOKBOOK_L01_NL4102/
│   │   │   ├── HALDEN_FW27_NORDLYS_LOOKBOOK_L02_NL4117/
│   │   │   ├── HALDEN_FW27_NORDLYS_LOOKBOOK_L03_NL4125/
│   │   │   └── HALDEN_FW27_NORDLYS_LOOKBOOK_L04_NL4139/
│   │   └── EDITORIAL/
│   │       ├── HALDEN_FW27_NORDLYS_EDITORIAL_SET01/
│   │       └── HALDEN_FW27_NORDLYS_EDITORIAL_SET02/
│   └── EMBER/
│       ├── LOOKBOOK/
│       │   ├── HALDEN_FW27_EMBER_LOOKBOOK_L01_EM5208/
│       │   ├── HALDEN_FW27_EMBER_LOOKBOOK_L02_EM5214/
│       │   ├── HALDEN_FW27_EMBER_LOOKBOOK_L03_EM5231/
│       │   └── HALDEN_FW27_EMBER_LOOKBOOK_L04_EM5246/
│       └── EDITORIAL/
│           ├── HALDEN_FW27_EMBER_EDITORIAL_SET01/
│           └── HALDEN_FW27_EMBER_EDITORIAL_SET02/
├── 01_SELECTS/
├── 02_OUTPUT/
├── 03_TRASH/
└── 04_DOCS/
```

A capture in the second Ember look could then be named `HALDEN_FW27_EMBER_LOOKBOOK_L02_EM5214_0001`.

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

## Using it

The window works from top to bottom, and the preview updates as you type. Hover over a field for a hint.

1. **Client, job and photographer.** These make up the session name and the copyright. **Location** is where the session folder is created. Use **Choose…** to change it.
2. **Session folders.** Name the RAW, selects, output, trash and documents folders.
3. **Date format and separators.** Set how the date is written (for example `YYYY-MM-DD` or `YYMMDD`) and which characters join the parts of each name.
4. **Prelight folder.** If you turn it on, a folder is created inside RAW and used as the first capture folder.
5. **Parent folders.** Add groups such as days, locations or collections. Turn on **Subfolders** to add a second level inside each one, for example `Studio/DAY1`.
6. **Shot folders.** Each row in the table is one group of shots. Click a cell to change its shot prefix or its number of shots. Type a number in **#** to use it for every row.
7. **Pasted lists.** Select one or more rows (⌘A selects all), then click **Paste list…** or the row's **List** cell. Paste one name per line and press ⌘Return. The number of names sets the number of shots for that row. **Remove list** goes back to plain numbering. Choose how the names are used:
   - **Append** keeps the number and adds the name: `SHOT01_NL4102`
   - **Replace** uses the name as the folder: `NL4102`
8. **Shot folder count.** Choose whether numbering restarts in each parent folder, continues per shot prefix, or continues across all parent folders.
9. **Shot folder naming and capture file naming.** Choose what each shot folder and capture file is called, and how many digits the numbers have.
10. **Check the preview.** The folder tree, a sample file name and any problems, such as a folder that already exists, appear before anything is created. Click **Create Session** to build it.

## Updating

1. Download the newer **CO-Super-Session** zip from the [Releases page](../../releases) and unzip it.
2. Close the script's window if it is open.
3. In Capture One, choose **Scripts › Open Scripts Folder**, drag the new **CO Super Session.scpt** into it and choose **Replace**. If Finder won't replace it, move the old file to the Bin first, then drag in the new one.
4. Choose **Scripts › Update Scripts Menu**, or restart Capture One.
5. Run the script and check that the window title shows the new version.

Your saved choices are kept, because they are stored separately from the script file.

If you installed from the source, get the latest source and run `./install.sh` from its folder in Terminal. It replaces the installed copy for you.

## What's new

See the [changelog](CHANGELOG.md) for what changed in each version, including changes not yet released.

## Customising

A few defaults live at the top of `CO Super Session.applescript`, including a session template to start from and a copyright style for users without Studio. To change them, download the source, edit the file and run `./install.sh` from its folder in Terminal. This builds the script and installs it in Capture One's Scripts folder.

## Credits

Originally written in 2019 as SuperSession by Louis-Philippe Beauduin. Rewritten in 2026 for Capture One 16 with the help of Claude Code.

## License

Copyright © 2026 Louis-Philippe Beauduin. CO Super Session is free software under the [GNU General Public License v3.0](LICENSE) or any later version. You can use, share and change it. If you share a changed version, you must release its source under the same licence.
