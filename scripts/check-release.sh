#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="${1:-$ROOT_DIR/.build/PitchKiwi.app}"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

for REQUIRED in \
  Contents/Info.plist \
  Contents/MacOS/PitchKiwi \
  Contents/Frameworks/whisper.framework/whisper \
  Contents/Resources/Models/ggml-base.en.bin \
  Contents/Resources/PitchKiwi.icns \
  Contents/Resources/PitchKiwi_PitchKiwiApp.bundle/PrivacyInfo.xcprivacy \
  Contents/Resources/Legal/LICENSE \
  Contents/Resources/Legal/THIRD_PARTY_NOTICES.md \
  Contents/Resources/Legal/ThirdParty/whisper.cpp-LICENSE.txt \
  Contents/Resources/Legal/ThirdParty/whisper-LICENSE.txt; do
  [[ -s "$APP_DIR/$REQUIRED" ]] || { echo "Missing release file: $REQUIRED" >&2; exit 1; }
done

plutil -lint "$APP_DIR/Contents/Info.plist"
codesign --verify --deep --strict "$APP_DIR"
lipo "$APP_DIR/Contents/MacOS/PitchKiwi" -verify_arch arm64
MODEL_SHA="a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002"
echo "$MODEL_SHA  $RESOURCES_DIR/Models/ggml-base.en.bin" | shasum -a 256 -c -
cmp "$ROOT_DIR/LICENSE" "$RESOURCES_DIR/Legal/LICENSE"
cmp "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$RESOURCES_DIR/Legal/THIRD_PARTY_NOTICES.md"
echo "Release bundle verified: Apple Silicon executable, signed bundle, model, privacy manifest, icon, and licenses."
