#!/bin/bash
# Wraps the signed app in a distributable DMG with an Applications shortcut.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build-release/Build/Products/Release/Phonon Characters.app"
[ -d "$APP" ] || { echo "Run Packaging/build.sh first"; exit 1; }

VERSION=$(defaults read "$(pwd)/$APP/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0")
DMG="dist/PhononCharacters-$VERSION.dmg"
STAGE="build-release/dmg-stage"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE" dist
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> Creating $DMG"
hdiutil create \
  -volname "Phonon Characters" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG" >/dev/null

rm -rf "$STAGE"
echo "==> Mounting for a sanity check"
MOUNT=$(hdiutil attach "$DMG" -nobrowse -readonly | tail -1 | awk -F'\t' '{print $NF}')
ls "$MOUNT"
hdiutil detach "$MOUNT" >/dev/null

echo "Built: $DMG"
du -sh "$DMG"
