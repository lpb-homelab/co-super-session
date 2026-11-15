#!/bin/sh
# Builds the script and publishes it as a GitHub Release with a ready-to-install download.
# Before running: bump scriptVersion in the script, add a CHANGELOG section for it, commit and push.
# Usage: ./release.sh        (run from this folder)
set -e
cd "$(dirname "$0")"

SRC="CO Super Session.applescript"
VERSION=$(sed -n 's/^property scriptVersion : "\([^"]*\)".*/\1/p' "$SRC")
TAG="v$VERSION"
ZIP="build/CO-Super-Session-$VERSION.zip"

[ -n "$VERSION" ] || { echo "No scriptVersion found in $SRC"; exit 1; }
git diff --quiet HEAD || { echo "Commit your changes first."; exit 1; }
grep -q "^## $VERSION " CHANGELOG.md || { echo "Add a '## $VERSION' section to CHANGELOG.md first."; exit 1; }

PKG="build/package"
rm -rf "$PKG" "$ZIP"
mkdir -p "$PKG"
osacompile -o "$PKG/CO Super Session.scpt" "$SRC"
cp LICENSE "$PKG/LICENSE.txt"
ditto -c -k --sequesterRsrc "$PKG" "$ZIP"

{
	echo "## Install"
	echo
	echo "1. Download **CO-Super-Session-$VERSION.zip** below and double-click it to unzip."
	echo "2. In Capture One, choose **Scripts › Open Scripts Folder** and drag **CO Super Session.scpt** into it. Replace the old copy if asked."
	echo "3. Choose **Scripts › Update Scripts Menu**, then **Scripts › CO Super Session**."
	echo
	echo "## What's new"
	awk -v v="$VERSION" '/^## /{p = index($0, "## " v " ") == 1; next} p' CHANGELOG.md
} > build/notes.md

git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || git tag -a "$TAG" -m "CO Super Session $VERSION"
git push -q origin "$TAG"
gh release create "$TAG" "$ZIP" --title "CO Super Session $VERSION" --notes-file build/notes.md
