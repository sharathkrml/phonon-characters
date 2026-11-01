#!/bin/bash
# Builds a signed, runnable Phonon Characters.app. No model weights are included.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${CODESIGN_IDENTITY:--}"
CONFIG="${CONFIG:-Release}"

echo "==> Generating project"
xcodegen generate >/dev/null

echo "==> Building ($CONFIG)"
xcodebuild \
  -project PhononCharacters.xcodeproj \
  -scheme PhononCharacters \
  -configuration "$CONFIG" \
  -derivedDataPath build-release \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  build

APP="build-release/Build/Products/$CONFIG/Phonon Characters.app"
[ -d "$APP" ] || { echo "App not found at $APP"; exit 1; }

echo "==> Signing nested binaries"
SIGN_FLAGS=(--force --options runtime --sign "$IDENTITY")
if [ "$IDENTITY" != "-" ]; then
  SIGN_FLAGS+=(--timestamp)
fi

while IFS= read -r -d '' file; do
  codesign "${SIGN_FLAGS[@]}" "$file" >/dev/null
done < <(find "$APP/Contents/Resources/llama" -type f -name "*.dylib" -print0)

# The helper loads its own dylibs; ad-hoc signatures have no Team ID, so the process
# needs library validation disabled or dyld refuses them.
codesign "${SIGN_FLAGS[@]}" \
  --entitlements Packaging/llama.entitlements \
  "$APP/Contents/Resources/llama/llama" >/dev/null

if [ -d "$APP/Contents/Frameworks" ]; then
  while IFS= read -r -d '' bundle; do
    codesign "${SIGN_FLAGS[@]}" "$bundle" >/dev/null
  done < <(find "$APP/Contents/Frameworks" -type d -name "*.framework" -print0)
fi

echo "==> Signing app"
codesign "${SIGN_FLAGS[@]}" \
  --entitlements Resources/PhononCharacters.entitlements \
  "$APP"

echo "==> Verifying"
codesign --verify --deep --strict --verbose=1 "$APP"
echo "Built: $APP"
du -sh "$APP"
