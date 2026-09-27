#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 OUTPUT_DIRECTORY" >&2
  exit 2
fi

OUTPUT_DIR="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
YT_DLP_TAG="${YT_DLP_TAG:-2026.08.19}"
DENO_TAG="${DENO_TAG:-v2.9.7}"
case "$(uname -m)" in
  arm64) DENO_ARCHIVE="deno-aarch64-apple-darwin.zip" ;;
  x86_64) DENO_ARCHIVE="deno-x86_64-apple-darwin.zip" ;;
  *) echo "Unsupported Mac architecture: $(uname -m)" >&2; exit 1 ;;
esac

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

download() {
  local url="$1"
  local destination="$2"
  local attempt
  if [[ "$url" == https://github.com/*/releases/download/* ]]; then
    "$ROOT_DIR/script/download_release_asset.sh" "$url" "$destination"
    return
  fi
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if curl -fL --retry 2 --silent --show-error -o "$destination" "$url"; then
      return 0
    fi
    echo "Download interrupted; resuming ($attempt/10): $url" >&2
  done
  echo "Failed to download: $url" >&2
  return 1
}

verify() {
  local file="$1"
  local sums="$2"
  local expected
  local actual
  expected="$(awk -v name="$(basename "$file")" '$2 == name {print $1}' "$sums")"
  [[ "$expected" =~ ^[a-fA-F0-9]{64}$ ]] || {
    echo "No SHA-256 entry for $(basename "$file") in $sums" >&2
    exit 1
  }
  actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || {
    echo "SHA-256 mismatch for $(basename "$file")" >&2
    exit 1
  }
}

YT_BASE="https://github.com/yt-dlp/yt-dlp/releases/download/$YT_DLP_TAG"
download "$YT_BASE/yt-dlp_macos" "$STAGING_DIR/yt-dlp_macos"
download "$YT_BASE/SHA2-256SUMS" "$STAGING_DIR/SHA2-256SUMS"
verify "$STAGING_DIR/yt-dlp_macos" "$STAGING_DIR/SHA2-256SUMS"

DENO_BASE="https://github.com/denoland/deno/releases/download/$DENO_TAG"
download "$DENO_BASE/$DENO_ARCHIVE" "$STAGING_DIR/$DENO_ARCHIVE"
download "$DENO_BASE/$DENO_ARCHIVE.sha256sum" "$STAGING_DIR/$DENO_ARCHIVE.sha256sum"
verify "$STAGING_DIR/$DENO_ARCHIVE" "$STAGING_DIR/$DENO_ARCHIVE.sha256sum"

mkdir -p "$STAGING_DIR/deno-unpacked" "$OUTPUT_DIR/Notices"
unzip -q "$STAGING_DIR/$DENO_ARCHIVE" -d "$STAGING_DIR/deno-unpacked"
[[ -f "$STAGING_DIR/deno-unpacked/deno" ]] || { echo "Deno archive has no deno executable" >&2; exit 1; }
cp "$STAGING_DIR/yt-dlp_macos" "$OUTPUT_DIR/yt-dlp"
cp "$STAGING_DIR/deno-unpacked/deno" "$OUTPUT_DIR/deno"
chmod +x "$OUTPUT_DIR/yt-dlp" "$OUTPUT_DIR/deno"

download "https://raw.githubusercontent.com/yt-dlp/yt-dlp/$YT_DLP_TAG/THIRD_PARTY_LICENSES.txt" \
  "$OUTPUT_DIR/Notices/yt-dlp-THIRD_PARTY_LICENSES.txt"
download "https://raw.githubusercontent.com/denoland/deno/$DENO_TAG/LICENSE.md" \
  "$OUTPUT_DIR/Notices/Deno-LICENSE.md"
{
  echo "yt-dlp $YT_DLP_TAG: $(shasum -a 256 "$OUTPUT_DIR/yt-dlp" | awk '{print $1}')"
  echo "Deno $DENO_TAG: $(shasum -a 256 "$OUTPUT_DIR/deno" | awk '{print $1}')"
} > "$OUTPUT_DIR/TOOL_VERSIONS.txt"
echo "Prepared yt-dlp and Deno in $OUTPUT_DIR"
