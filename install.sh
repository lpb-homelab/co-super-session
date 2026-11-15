#!/bin/sh
# Compiles the script and installs it in Capture One's Scripts menu.
# Usage: ./install.sh        (run from this folder)
set -e
cd "$(dirname "$0")"
DEST="$HOME/Library/Scripts/Capture One Scripts"
mkdir -p build "$DEST"
for SRC in "CO SuperSession.applescript"; do
	NAME="${SRC%.applescript}"
	osacompile -o "build/$NAME.scpt" "$SRC"
	# Read-only so a copy left running in Capture One can't save itself back over this one
	# (settings live in defaults, not in the script file).
	rm -f "$DEST/$NAME.scpt"
	cp "build/$NAME.scpt" "$DEST/"
	chmod a-w "$DEST/$NAME.scpt"
	echo "Installed: $DEST/$NAME.scpt"
done
echo "If it isn't in Capture One's Scripts menu yet, choose Scripts > Update Scripts Menu or restart Capture One."
