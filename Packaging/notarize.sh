#!/bin/bash
# Notarizes the DMG. Requires a Developer ID Application certificate and a stored
# notarytool profile:
#   xcrun notarytool store-credentials phonon-notary \
#     --apple-id you@example.com --team-id TEAMID --password app-specific-password
#
# Then:
#   CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" Packaging/build.sh
#   Packaging/make-dmg.sh
#   NOTARY_PROFILE=phonon-notary Packaging/notarize.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PROFILE="${NOTARY_PROFILE:-phonon-notary}"
VERSION=$(defaults read "$(pwd)/build-release/Build/Products/Release/Phonon Characters.app/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0")
DMG="dist/PhononCharacters-$VERSION.dmg"

[ -f "$DMG" ] || { echo "DMG not found: $DMG"; exit 1; }

echo "==> Submitting $DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait

echo "==> Stapling"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature -v "$DMG"

echo "Notarized: $DMG"
