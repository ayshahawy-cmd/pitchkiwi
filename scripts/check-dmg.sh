#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DMG="${1:-$ROOT_DIR/.build/PitchKiwi-macOS.dmg}"
[[ $# -le 1 && -s "$DMG" ]] || { echo "Usage: $0 [existing.dmg]" >&2; exit 2; }
hdiutil verify "$DMG"
MOUNT_DIR="$(mktemp -d -t pitchkiwi-dmg-check)"
MOUNTED=0
cleanup() {
  if [[ "$MOUNTED" == 1 ]]; then
    hdiutil detach "$MOUNT_DIR" >/dev/null || return 1
  fi
  rmdir "$MOUNT_DIR"
}
trap cleanup EXIT
hdiutil attach "$DMG" -readonly -nobrowse -noautoopen -mountpoint "$MOUNT_DIR" >/dev/null
MOUNTED=1
[[ -L "$MOUNT_DIR/Applications" && "$(readlink "$MOUNT_DIR/Applications")" == "/Applications" ]]
[[ -s "$MOUNT_DIR/Install PitchKiwi.txt" ]]
"$ROOT_DIR/scripts/check-release.sh" "$MOUNT_DIR/PitchKiwi.app"
if [[ "${PITCHKIWI_REQUIRE_NOTARIZATION:-0}" == 1 ]]; then
  xcrun stapler validate "$MOUNT_DIR/PitchKiwi.app"
  xcrun stapler validate "$DMG"
  spctl --assess --type execute --verbose=2 "$MOUNT_DIR/PitchKiwi.app"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
fi
echo "DMG verified: mountable read-only, complete app, Applications shortcut, and install guide."
