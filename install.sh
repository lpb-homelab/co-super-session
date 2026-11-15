#!/bin/sh
# Compiles the script and installs it in Capture One's Scripts menu.
# Usage: ./install.sh        (run from this folder)
set -e
cd "$(dirname "$0")"
DEST="$HOME/Library/Scripts/Capture One Scripts"
mkdir -p build "$DEST"
for SRC in "CO Super Session.applescript"; do
	NAME="${SRC%.applescript}"
	osacompile -o "build/$NAME.scpt" "$SRC"
	cp "build/$NAME.scpt" "$DEST/"
	echo "Installed: $DEST/$NAME.scpt"
done
echo "If it isn't in Capture One's Scripts menu yet, choose Scripts > Update Scripts Menu or restart Capture One."
