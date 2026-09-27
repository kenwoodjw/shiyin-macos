#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 GITHUB_RELEASE_ASSET_URL DESTINATION" >&2
  exit 2
fi

SOURCE_URL="$1"
DESTINATION="$2"
case "$SOURCE_URL" in
  https://github.com/*/releases/download/*) ;;
  *) echo "Expected a GitHub release asset URL" >&2; exit 2 ;;
esac

# GitHub's redirect points to a CDN that supports byte ranges. Small chunks
# avoid losing a large download when a connection drops mid-transfer.
ASSET_URL="$(curl -fsSI "$SOURCE_URL" | /usr/bin/awk 'tolower($1) == "location:" {print $2}' | /usr/bin/tr -d '\r')"
[[ "$ASSET_URL" == https://release-assets.githubusercontent.com/* ]] || {
  echo "GitHub did not return a release asset URL" >&2
  exit 1
}
TOTAL_BYTES="$(curl -fsSI "$ASSET_URL" | /usr/bin/awk 'tolower($1) == "content-length:" {print $2}' | /usr/bin/tr -d '\r')"
[[ "$TOTAL_BYTES" =~ ^[0-9]+$ && "$TOTAL_BYTES" -gt 0 ]] || {
  echo "Could not read release asset size" >&2
  exit 1
}

mkdir -p "$(dirname "$DESTINATION")"
touch "$DESTINATION"
CURRENT_BYTES="$(/usr/bin/wc -c < "$DESTINATION" | /usr/bin/tr -d ' ')"
[[ "$CURRENT_BYTES" -le "$TOTAL_BYTES" ]] || {
  echo "Existing file is larger than the release asset: $DESTINATION" >&2
  exit 1
}

CHUNK_FILE="$(mktemp)"
trap 'rm -f "$CHUNK_FILE"' EXIT
while [[ "$CURRENT_BYTES" -lt "$TOTAL_BYTES" ]]; do
  END_BYTE=$((CURRENT_BYTES + 2 * 1024 * 1024 - 1))
  if [[ "$END_BYTE" -ge "$TOTAL_BYTES" ]]; then END_BYTE=$((TOTAL_BYTES - 1)); fi
  EXPECTED_BYTES=$((END_BYTE - CURRENT_BYTES + 1))
  downloaded=false
  for attempt in 1 2 3 4 5; do
    status="$(curl -fsS --range "$CURRENT_BYTES-$END_BYTE" \
      --output "$CHUNK_FILE" --write-out '%{http_code}' "$ASSET_URL")" || continue
    actual_bytes="$(/usr/bin/wc -c < "$CHUNK_FILE" | /usr/bin/tr -d ' ')"
    if [[ "$status" == 206 && "$actual_bytes" -eq "$EXPECTED_BYTES" ]]; then
      cat "$CHUNK_FILE" >> "$DESTINATION"
      CURRENT_BYTES=$((CURRENT_BYTES + actual_bytes))
      downloaded=true
      echo "$(basename "$DESTINATION"): $CURRENT_BYTES / $TOTAL_BYTES bytes"
      break
    fi
  done
  [[ "$downloaded" == true ]] || { echo "Failed to fetch byte range $CURRENT_BYTES-$END_BYTE" >&2; exit 1; }
done
