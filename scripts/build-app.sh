#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

[[ -d .vendor/whisper.xcframework ]] || "$ROOT_DIR/scripts/bootstrap.sh" --framework-only
swift build -c release --product PitchKiwi

APP_DIR="$ROOT_DIR/.build/PitchKiwi.app"
EXECUTABLE_DIR="$APP_DIR/Contents/MacOS"
FRAMEWORKS_DIR="$APP_DIR/Contents/Frameworks"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

rm -rf "$APP_DIR"
mkdir -p "$EXECUTABLE_DIR" "$FRAMEWORKS_DIR" "$RESOURCES_DIR/Models"
cp "$ROOT_DIR/.build/release/PitchKiwi" "$EXECUTABLE_DIR/PitchKiwi"
cp "$ROOT_DIR/Packaging/Info.plist" "$APP_DIR/Contents/Info.plist"
cp -R "$ROOT_DIR/.vendor/whisper.xcframework/macos-arm64_x86_64/whisper.framework" "$FRAMEWORKS_DIR/whisper.framework"

ICON_WORK_DIR="$(mktemp -d -t pitchkiwi-icon)"
ICONSET_DIR="$ICON_WORK_DIR/PitchKiwi.iconset"
mkdir -p "$ICONSET_DIR"
trap 'rm -rf "$ICON_WORK_DIR"' EXIT
for SIZE in 16 32 128 256 512; do
  sips -s format png -z "$SIZE" "$SIZE" "$ROOT_DIR/Assets/AppIcon.svg" --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE_SIZE=$((SIZE * 2))
  sips -s format png -z "$DOUBLE_SIZE" "$DOUBLE_SIZE" "$ROOT_DIR/Assets/AppIcon.svg" --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/PitchKiwi.icns"

RESOURCE_BUNDLE="$ROOT_DIR/.build/release/PitchKiwi_PitchKiwiApp.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/"
fi

if [[ -f "$ROOT_DIR/.models/ggml-base.en.bin" ]]; then
  cp "$ROOT_DIR/.models/ggml-base.en.bin" "$RESOURCES_DIR/Models/ggml-base.en.bin"
fi

codesign --force --sign - --timestamp=none "$FRAMEWORKS_DIR/whisper.framework"
codesign --force --sign - --timestamp=none --deep "$APP_DIR"

echo "$APP_DIR"
