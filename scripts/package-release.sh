#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE="$ROOT_DIR/.build/PitchKiwi-macOS.zip"
CHECKSUM="$ARCHIVE.sha256"

# Download and verify the default model even when no prior developer setup exists.
"$ROOT_DIR/scripts/bootstrap.sh"
"$ROOT_DIR/scripts/build-app.sh"
"$ROOT_DIR/scripts/check-release.sh"
rm -f "$ARCHIVE" "$CHECKSUM"
ditto -c -k --sequesterRsrc --keepParent "$ROOT_DIR/.build/PitchKiwi.app" "$ARCHIVE"
(
  cd "$ROOT_DIR/.build"
  shasum -a 256 "$(basename "$ARCHIVE")" > "$(basename "$CHECKSUM")"
)

echo "$ARCHIVE"
echo "$CHECKSUM"
