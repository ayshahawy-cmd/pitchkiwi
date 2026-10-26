#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="${1:-$ROOT_DIR/.build/PitchKiwi.app}"
DMG="${2:-$ROOT_DIR/.build/PitchKiwi-macOS.dmg}"
[[ $# -le 2 && "$DMG" == *.dmg ]] || { echo "Usage: $0 [PitchKiwi.app] [output.dmg]" >&2; exit 2; }
"$ROOT_DIR/scripts/check-release.sh" "$APP_DIR"

STAGING_DIR="$(mktemp -d -t pitchkiwi-dmg)"
trap 'rm -rf "$STAGING_DIR"' EXIT
ditto "$APP_DIR" "$STAGING_DIR/PitchKiwi.app"
ln -s /Applications "$STAGING_DIR/Applications"
cat > "$STAGING_DIR/Install PitchKiwi.txt" <<'EOF'
Install PitchKiwi — free and open source

Requires an Apple Silicon Mac (M1 or newer) running macOS 14 or later.

1. Drag PitchKiwi.app onto the Applications shortcut in this window.
2. Eject the PitchKiwi disk image.
3. Open PitchKiwi from your Applications folder.
4. Follow onboarding to grant Microphone and Accessibility access.
5. Click a text field, hold Fn, speak, then release to insert.

The English speech model is included. Your speech is processed locally.
There is no signup, payment, account, or API key.

Source, help, and contributions: https://github.com/ayshahawy-cmd/pitchkiwi
License notices: PitchKiwi.app/Contents/Resources/Legal/
EOF
if ! xcrun stapler validate "$APP_DIR" >/dev/null 2>&1; then
  cat >> "$STAGING_DIR/Install PitchKiwi.txt" <<'EOF'

This developer/community build is not notarized. After checking its source
and checksum, follow Apple's per-app approval instructions if blocked:
https://support.apple.com/en-ca/102445
EOF
fi
mkdir -p "$(dirname "$DMG")"
hdiutil create -ov -volname PitchKiwi -srcfolder "$STAGING_DIR" -fs HFS+ -format UDZO "$DMG"
if [[ "${PITCHKIWI_SIGNING_IDENTITY:--}" != "-" ]]; then
  codesign --force --sign "$PITCHKIWI_SIGNING_IDENTITY" --timestamp "$DMG"
fi
echo "$DMG"
