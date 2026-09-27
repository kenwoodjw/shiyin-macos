#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONSET="$ROOT_DIR/.build/Shiyin.iconset"
mkdir -p "$ROOT_DIR/.build" "$ROOT_DIR/.cache/clang" "$ROOT_DIR/Resources" "$ICONSET"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.cache/clang"
export XDG_CACHE_HOME="$ROOT_DIR/.cache"

swift "$ROOT_DIR/script/generate_icon.swift" "$ICONSET/icon_512x512@2x.png"
for size in 16 32 128 256 512; do
  /usr/bin/sips -z "$size" "$size" "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  if [ "$size" -lt 512 ]; then
    doubled=$((size * 2))
    /usr/bin/sips -z "$doubled" "$doubled" "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  fi
done
python3 - "$ICONSET" "$ROOT_DIR/Resources/Shiyin.icns" <<'PY'
from pathlib import Path
import struct
import sys

source = Path(sys.argv[1])
output = Path(sys.argv[2])
entries = [
    ("icp4", "icon_16x16.png"),
    ("ic11", "icon_16x16@2x.png"),
    ("icp5", "icon_32x32.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"),
    ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"),
]
chunks = []
for kind, name in entries:
    data = (source / name).read_bytes()
    chunks.append(kind.encode("ascii") + struct.pack(">I", len(data) + 8) + data)
payload = b"".join(chunks)
output.write_bytes(b"icns" + struct.pack(">I", len(payload) + 8) + payload)
PY
echo "Created $ROOT_DIR/Resources/Shiyin.icns"
