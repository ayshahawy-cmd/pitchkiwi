#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/.vendor"
MODEL_DIR="$ROOT_DIR/.models"
FRAMEWORK_URL="https://github.com/ggml-org/whisper.cpp/releases/download/b5130/whisper-b5130-xcframework.zip"
FRAMEWORK_SHA="033a43b0174e8cf9b366f72e4a428cdcf126f93ad1c87d3fa119a96bed6f231a"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
MODEL_SHA="a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002"
FRAMEWORK_ONLY="${1:-}"
if [[ $# -gt 1 || ( -n "$FRAMEWORK_ONLY" && "$FRAMEWORK_ONLY" != "--framework-only" ) ]]; then
  echo "Usage: $0 [--framework-only]" >&2
  exit 2
fi
TEMP_PATHS=()

cleanup() {
  for PATH_TO_REMOVE in "${TEMP_PATHS[@]}"; do
    rm -rf "$PATH_TO_REMOVE"
  done
}
trap cleanup EXIT

mkdir -p "$VENDOR_DIR" "$MODEL_DIR"

if [[ ! -d "$VENDOR_DIR/whisper.xcframework" ]]; then
  ARCHIVE="$(mktemp -t pitchkiwi-whisper).zip"
  EXTRACT_DIR="$(mktemp -d -t pitchkiwi-whisper)"
  TEMP_PATHS+=("$ARCHIVE" "$EXTRACT_DIR")
  curl -fL "$FRAMEWORK_URL" -o "$ARCHIVE"
  echo "$FRAMEWORK_SHA  $ARCHIVE" | shasum -a 256 -c -
  unzip -q "$ARCHIVE" -d "$EXTRACT_DIR"
  cp -R "$EXTRACT_DIR/build-apple/whisper.xcframework" "$VENDOR_DIR/whisper.xcframework"
fi

if [[ "$FRAMEWORK_ONLY" != "--framework-only" && ! -f "$MODEL_DIR/ggml-base.en.bin" ]]; then
  MODEL_TEMP="$(mktemp -t pitchkiwi-model).bin"
  TEMP_PATHS+=("$MODEL_TEMP")
  curl -fL "$MODEL_URL" -o "$MODEL_TEMP"
  echo "$MODEL_SHA  $MODEL_TEMP" | shasum -a 256 -c -
  mv "$MODEL_TEMP" "$MODEL_DIR/ggml-base.en.bin"
  chmod 600 "$MODEL_DIR/ggml-base.en.bin"
fi

if [[ "$FRAMEWORK_ONLY" != "--framework-only" ]]; then
  echo "$MODEL_SHA  $MODEL_DIR/ggml-base.en.bin" | shasum -a 256 -c -
fi

echo "PitchKiwi dependencies are ready."
