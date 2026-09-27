#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 FFmpeg-source.tar.xz OUTPUT_DIRECTORY" >&2
  exit 2
fi

SOURCE_ARCHIVE="$1"
OUTPUT_DIR="$2"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$SOURCE_ARCHIVE" ]] || { echo "Source archive not found: $SOURCE_ARCHIVE" >&2; exit 1; }
SOURCE_ARCHIVE="$(cd "$(dirname "$SOURCE_ARCHIVE")" && pwd)/$(basename "$SOURCE_ARCHIVE")"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

LAME_PREFIX="${LAME_PREFIX:-}"
if [[ -z "$LAME_PREFIX" ]]; then
  for candidate in /opt/homebrew/opt/lame /usr/local/opt/lame; do
    if [[ -f "$candidate/lib/libmp3lame.a" ]]; then LAME_PREFIX="$candidate"; break; fi
  done
fi
[[ -f "$LAME_PREFIX/lib/libmp3lame.a" && -f "$LAME_PREFIX/include/lame/lame.h" ]] || {
  echo "A static LAME library and headers are required on the build Mac (brew install lame)." >&2
  exit 1
}
MPG123_PREFIX="${MPG123_PREFIX:-}"
if [[ -z "$MPG123_PREFIX" ]]; then
  for candidate in /opt/homebrew/opt/mpg123 /usr/local/opt/mpg123; do
    if [[ -f "$candidate/lib/libmpg123.a" ]]; then MPG123_PREFIX="$candidate"; break; fi
  done
fi
[[ -f "$MPG123_PREFIX/lib/libmpg123.a" ]] || {
  echo "A static mpg123 library is required on the build Mac (brew install mpg123)." >&2
  exit 1
}

MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-15.0}"
for archive in "$LAME_PREFIX/lib/libmp3lame.a" "$MPG123_PREFIX/lib/libmpg123.a"; do
  while IFS= read -r minimum_version; do
    if ! /usr/bin/awk -v required="$minimum_version" -v target="$MACOSX_DEPLOYMENT_TARGET" 'BEGIN {
      split(required, r, "."); split(target, t, ".");
      if (r[1] > t[1] || (r[1] == t[1] && r[2] > t[2])) exit 1;
    }'; then
      echo "$(basename "$archive") requires macOS $minimum_version; target is $MACOSX_DEPLOYMENT_TARGET" >&2
      exit 1
    fi
  done < <(/usr/bin/otool -l "$archive" | /usr/bin/awk '$1 == "minos" {print $2}' | /usr/bin/sort -u)
done

mkdir -p "$ROOT_DIR/.cache" "$OUTPUT_DIR"
BUILD_DIR="$(mktemp -d "$ROOT_DIR/.cache/ffmpeg-build.XXXXXX")"
echo "FFmpeg build directory: $BUILD_DIR"
tar -xf "$SOURCE_ARCHIVE" -C "$BUILD_DIR"
SOURCE_DIR="$(find "$BUILD_DIR" -mindepth 1 -maxdepth 1 -type d -name 'ffmpeg-*' -print -quit)"
[[ -n "$SOURCE_DIR" ]] || { echo "Archive does not contain an FFmpeg source directory" >&2; exit 1; }

# Make only the static LAME archive visible to the linker. Homebrew's dylib
# would make the release depend on /opt/homebrew or /usr/local.
mkdir -p "$BUILD_DIR/lame-lib"
cp "$LAME_PREFIX/lib/libmp3lame.a" "$BUILD_DIR/lame-lib/"
cp "$MPG123_PREFIX/lib/libmpg123.a" "$BUILD_DIR/lame-lib/"

cd "$SOURCE_DIR"
export MACOSX_DEPLOYMENT_TARGET
./configure \
  --disable-x86asm \
  --disable-autodetect \
  --disable-debug \
  --disable-doc \
  --disable-ffplay \
  --disable-shared \
  --enable-static \
  --enable-libmp3lame \
  --extra-cflags="-I$LAME_PREFIX/include" \
  --extra-ldflags="-L$BUILD_DIR/lame-lib" \
  --extra-libs=-lmpg123
make -j4 ffmpeg ffprobe

cp ffmpeg ffprobe "$OUTPUT_DIR/"
chmod +x "$OUTPUT_DIR/ffmpeg" "$OUTPUT_DIR/ffprobe"
mkdir -p "$OUTPUT_DIR/Notices"
cp COPYING.LGPLv2.1 "$OUTPUT_DIR/Notices/FFmpeg-LGPL-2.1.txt"
cat > "$OUTPUT_DIR/Notices/FFmpeg-BUILD.txt" <<NOTICE
FFmpeg source archive: $(basename "$SOURCE_ARCHIVE")
LAME static library version: $(basename "$(cd "$LAME_PREFIX" && pwd -P)")
mpg123 static library version: $(basename "$(cd "$MPG123_PREFIX" && pwd -P)")
Build target: macOS $MACOSX_DEPLOYMENT_TARGET
FFmpeg source and licensing: https://ffmpeg.org/download.html and https://ffmpeg.org/legal.html
LAME source and licensing: https://lame.sourceforge.io/
mpg123 source and licensing: https://www.mpg123.de/

Static library source, matching notices, and relinking materials must be
provided with a public distribution as required by their licenses.
NOTICE
cp ffbuild/config.log "$OUTPUT_DIR/FFmpeg-config.log"
shasum -a 256 "$SOURCE_ARCHIVE" "$OUTPUT_DIR/ffmpeg" "$OUTPUT_DIR/ffprobe" \
  > "$OUTPUT_DIR/FFmpeg-SHA256SUMS"
echo "Built portable FFmpeg tools in $OUTPUT_DIR"
