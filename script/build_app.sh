#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Shiyin"
BUNDLE_ID="com.kenwoodchan.shiyin"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_BINARY="$APP_CONTENTS/MacOS/$APP_NAME"
TOOLS_DIR=""
SIGN_IDENTITY="-"
MINIMUM_MACOS="14.0"
BUILD_CONFIGURATION="debug"

while (($#)); do
  case "$1" in
    --tools-dir)
      [[ $# -ge 2 ]] || { echo "Missing value for --tools-dir" >&2; exit 2; }
      TOOLS_DIR="$2"
      shift 2
      ;;
    --sign-identity)
      [[ $# -ge 2 ]] || { echo "Missing value for --sign-identity" >&2; exit 2; }
      SIGN_IDENTITY="$2"
      shift 2
      ;;
    *) echo "Usage: $0 [--tools-dir DIRECTORY] [--sign-identity IDENTITY]" >&2; exit 2 ;;
  esac
done

if [[ -n "$TOOLS_DIR" ]]; then
  BUILD_CONFIGURATION="release"
  TOOLS_DIR="$(cd "$TOOLS_DIR" && pwd)"
  for name in yt-dlp ffmpeg ffprobe deno; do
    source_file="$TOOLS_DIR/$name"
    [[ -f "$source_file" && -x "$source_file" ]] || {
      echo "Missing executable: $source_file" >&2
      exit 1
    }
    /usr/bin/file -b "$source_file" | /usr/bin/grep -q 'Mach-O' || {
      echo "Expected a standalone macOS Mach-O executable: $source_file" >&2
      exit 1
    }
    minimum_versions="$(xcrun vtool -show-build "$source_file" | /usr/bin/awk '
      $1 == "cmd" {legacy = ($2 == "LC_VERSION_MIN_MACOSX")}
      $1 == "minos" {print $2}
      legacy && $1 == "version" {print $2; legacy = 0}
    ')"
    [[ -n "$minimum_versions" ]] || {
      echo "Could not read the minimum macOS version of $source_file" >&2
      exit 1
    }
    while IFS= read -r minimum_version; do
      MINIMUM_MACOS="$(/usr/bin/awk -v current="$MINIMUM_MACOS" -v candidate="$minimum_version" 'BEGIN {
        split(current, c, "."); split(candidate, n, ".");
        if (n[1] > c[1] || (n[1] == c[1] && n[2] > c[2])) print candidate;
        else print current;
      }')"
    done <<< "$minimum_versions"
    if [[ "$name" == ffmpeg || "$name" == ffprobe ]]; then
      version_flag="-version"
    else
      version_flag="--version"
    fi
    if ! version_output="$("$source_file" "$version_flag" 2>&1)"; then
      echo "$name failed its version check: $version_output" >&2
      exit 1
    fi
    case "$name:$version_output" in
      yt-dlp:20*|ffmpeg:"ffmpeg version "*|ffprobe:"ffprobe version "*|deno:"deno "*) ;;
      *) echo "$name returned an unexpected version response: $version_output" >&2; exit 1 ;;
    esac
    while IFS= read -r dependency; do
      case "$dependency" in
        /usr/lib/*|/System/Library/*) ;;
        *) echo "$name depends on a library outside macOS: $dependency" >&2; exit 1 ;;
      esac
    done < <(/usr/bin/otool -L "$source_file" | /usr/bin/awk '/^[[:space:]]/ && ($1 ~ /^\// || $1 ~ /^@/) {print $1}')
  done
fi

mkdir -p "$ROOT_DIR/.cache/clang"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.cache/clang"
export XDG_CACHE_HOME="$ROOT_DIR/.cache"

cd "$ROOT_DIR"
swift build --disable-sandbox --configuration "$BUILD_CONFIGURATION"
BUILD_BINARY="$(swift build --disable-sandbox --configuration "$BUILD_CONFIGURATION" --show-bin-path)/$APP_NAME"
APP_ARCHS="$(/usr/bin/lipo -archs "$BUILD_BINARY")"

if [[ -n "$TOOLS_DIR" ]]; then
  for name in yt-dlp ffmpeg ffprobe deno; do
    tool_archs="$(/usr/bin/lipo -archs "$TOOLS_DIR/$name")"
    compatible=false
    for app_arch in $APP_ARCHS; do
      if [[ " $tool_archs " == *" $app_arch "* ]]; then compatible=true; fi
    done
    [[ "$compatible" == true ]] || {
      echo "$name architecture ($tool_archs) does not match the app ($APP_ARCHS)" >&2
      exit 1
    }
  done
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_CONTENTS/MacOS" "$APP_CONTENTS/Resources"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$ROOT_DIR/Resources/Shiyin.icns" "$APP_CONTENTS/Resources/Shiyin.icns"

cat > "$APP_CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>拾音</string>
  <key>CFBundleDisplayName</key><string>拾音</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>Shiyin</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>$MINIMUM_MACOS</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

if [[ -n "$TOOLS_DIR" ]]; then
  mkdir -p "$APP_CONTENTS/MacOS/Tools"
  for name in yt-dlp ffmpeg ffprobe deno; do
    cp "$TOOLS_DIR/$name" "$APP_CONTENTS/MacOS/Tools/$name"
    chmod +x "$APP_CONTENTS/MacOS/Tools/$name"
  done
  mkdir -p "$APP_CONTENTS/Resources/ThirdPartyNotices"
  if [[ -d "$TOOLS_DIR/Notices" ]]; then
    cp -R "$TOOLS_DIR/Notices/." "$APP_CONTENTS/Resources/ThirdPartyNotices/"
  fi
  for manifest in TOOL_VERSIONS.txt FFmpeg-SHA256SUMS; do
    if [[ -f "$TOOLS_DIR/$manifest" ]]; then
      cp "$TOOLS_DIR/$manifest" "$APP_CONTENTS/Resources/ThirdPartyNotices/$manifest"
    fi
  done
fi

sign_file() {
  local target="$1"
  local entitlements="${2:-}"
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    /usr/bin/codesign --force --sign - "$target"
  elif [[ -n "$entitlements" ]]; then
    /usr/bin/codesign --force --options runtime --timestamp \
      --entitlements "$entitlements" --sign "$SIGN_IDENTITY" "$target"
  else
    /usr/bin/codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$target"
  fi
}

if [[ -n "$TOOLS_DIR" ]]; then
  for name in yt-dlp ffmpeg ffprobe deno; do
    if [[ "$name" == deno ]]; then
      sign_file "$APP_CONTENTS/MacOS/Tools/$name" "$ROOT_DIR/script/deno.entitlements"
    else
      sign_file "$APP_CONTENTS/MacOS/Tools/$name"
    fi
  done
  (cd "$APP_CONTENTS/MacOS/Tools" && shasum -a 256 yt-dlp ffmpeg ffprobe deno) \
    > "$APP_CONTENTS/Resources/ThirdPartyNotices/BUNDLED_SHA256SUMS"
fi
sign_file "$APP_BUNDLE"
/usr/bin/codesign --verify --strict --deep "$APP_BUNDLE"
echo "Built: $APP_BUNDLE"
