#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE="$ROOT_DIR/.build/PitchKiwi-macOS.zip"
CHECKSUM="$ARCHIVE.sha256"
APP_DIR="$ROOT_DIR/.build/PitchKiwi.app"
DMG="$ROOT_DIR/.build/PitchKiwi-macOS.dmg"
NOTARY_PROFILE="${PITCHKIWI_NOTARY_PROFILE:-}"

if [[ -n "$NOTARY_PROFILE" && "${PITCHKIWI_SIGNING_IDENTITY:--}" == "-" ]]; then
  echo "Notarization requires PITCHKIWI_SIGNING_IDENTITY to name a Developer ID Application identity." >&2
  exit 2
fi

notarize() {
  local TARGET="$1"
  local REPORT="$2"
  xcrun notarytool submit "$TARGET" --keychain-profile "$NOTARY_PROFILE" \
    --wait --timeout 20m --output-format json > "$REPORT"
  if [[ "$(plutil -extract status raw -o - "$REPORT")" != "Accepted" ]]; then
    echo "Apple did not accept this submission. Review $REPORT before publishing." >&2
    return 1
  fi
}

# Download and verify the default model even when no prior developer setup exists.
"$ROOT_DIR/scripts/bootstrap.sh"
"$ROOT_DIR/scripts/build-app.sh"
"$ROOT_DIR/scripts/check-release.sh"
if [[ -n "$NOTARY_PROFILE" ]]; then
  NOTARY_ARCHIVE="$ROOT_DIR/.build/PitchKiwi-notary.zip"
  rm -f "$NOTARY_ARCHIVE"
  ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$NOTARY_ARCHIVE"
  notarize "$NOTARY_ARCHIVE" "$ROOT_DIR/.build/notarization-app.json"
  xcrun stapler staple "$APP_DIR"
  xcrun stapler validate "$APP_DIR"
  spctl --assess --type execute --verbose=2 "$APP_DIR"
fi
rm -f "$ARCHIVE" "$CHECKSUM"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE"
"$ROOT_DIR/scripts/package-dmg.sh" "$APP_DIR" "$DMG"
if [[ -n "$NOTARY_PROFILE" ]]; then
  notarize "$DMG" "$ROOT_DIR/.build/notarization-dmg.json"
  xcrun stapler staple "$DMG"
  PITCHKIWI_REQUIRE_NOTARIZATION=1 "$ROOT_DIR/scripts/check-dmg.sh" "$DMG"
else
  "$ROOT_DIR/scripts/check-dmg.sh" "$DMG"
fi
(
  cd "$ROOT_DIR/.build"
  shasum -a 256 "$(basename "$ARCHIVE")" > "$(basename "$CHECKSUM")"
  shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256"
)

echo "$ARCHIVE"
echo "$CHECKSUM"
echo "$DMG"
echo "$DMG.sha256"
