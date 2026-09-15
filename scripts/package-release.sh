#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE="$ROOT_DIR/.build/VibeFlow-macOS.zip"
CHECKSUM="$ARCHIVE.sha256"

"$ROOT_DIR/scripts/build-app.sh"
rm -f "$ARCHIVE" "$CHECKSUM"
ditto -c -k --sequesterRsrc --keepParent "$ROOT_DIR/.build/VibeFlow.app" "$ARCHIVE"
(
  cd "$ROOT_DIR/.build"
  shasum -a 256 "$(basename "$ARCHIVE")" > "$(basename "$CHECKSUM")"
)

echo "$ARCHIVE"
echo "$CHECKSUM"
