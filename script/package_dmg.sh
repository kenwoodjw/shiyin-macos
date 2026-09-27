#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/Shiyin.app"
OUTPUT_DIR="$ROOT_DIR/dist"
SIGN_IDENTITY=""
NOTARY_PROFILE=""
LOCAL_ONLY=false
FORCE=false

usage() {
  echo "Usage: $0 [--app PATH] [--output-dir DIRECTORY] [--identity 'Developer ID Application: ...' --notary-profile PROFILE] [--local] [--force]" >&2
  exit 2
}

while (($#)); do
  case "$1" in
    --app)
      (($# >= 2)) || usage
      APP_BUNDLE="$2"
      shift 2
      ;;
    --output-dir)
      (($# >= 2)) || usage
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --identity)
      (($# >= 2)) || usage
      SIGN_IDENTITY="$2"
      shift 2
      ;;
    --notary-profile)
      (($# >= 2)) || usage
      NOTARY_PROFILE="$2"
      shift 2
      ;;
    --local)
      LOCAL_ONLY=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    *) usage ;;
  esac
done

[[ -d "$APP_BUNDLE" && -f "$APP_BUNDLE/Contents/Info.plist" ]] || {
  echo "App bundle not found: $APP_BUNDLE" >&2
  exit 1
}
for name in yt-dlp ffmpeg ffprobe deno; do
  [[ -x "$APP_BUNDLE/Contents/MacOS/Tools/$name" ]] || {
    echo "The app bundle is missing its built-in $name executable." >&2
    exit 1
  }
done
/usr/bin/codesign --verify --strict --deep "$APP_BUNDLE"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
minimum_macos="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP_BUNDLE/Contents/Info.plist")"
[[ "$version" =~ ^[0-9A-Za-z][0-9A-Za-z.+-]*$ ]] || {
  echo "Invalid app version in Info.plist: $version" >&2
  exit 1
}
archs="$(/usr/bin/lipo -archs "$APP_BUNDLE/Contents/MacOS/Shiyin")"
if [[ " $archs " == *" arm64 "* && " $archs " == *" x86_64 "* ]]; then
  architecture="universal"
else
  architecture="${archs// /-}"
fi

if [[ "$LOCAL_ONLY" == true ]]; then
  [[ -z "$SIGN_IDENTITY" && -z "$NOTARY_PROFILE" ]] || usage
  suffix="-LOCAL"
  echo "Creating a local test DMG. It is not notarized for public distribution."
else
  [[ -n "$SIGN_IDENTITY" && -n "$NOTARY_PROFILE" ]] || {
    echo "A public DMG requires --identity and --notary-profile. Use --local for a test DMG." >&2
    exit 2
  }
  for item in "$APP_BUNDLE" "$APP_BUNDLE/Contents/MacOS/Tools/yt-dlp" \
              "$APP_BUNDLE/Contents/MacOS/Tools/ffmpeg" \
              "$APP_BUNDLE/Contents/MacOS/Tools/ffprobe" \
              "$APP_BUNDLE/Contents/MacOS/Tools/deno"; do
    signing_info="$(/usr/bin/codesign -dv --verbose=4 "$item" 2>&1)"
    [[ "$signing_info" == *"Authority=Developer ID Application:"* &&
       "$signing_info" == *"(runtime)"* && "$signing_info" == *"Timestamp="* ]] || {
      echo "Developer ID, hardened runtime, or secure timestamp missing: $item" >&2
      exit 1
    }
  done
  for notice in FFmpeg-LGPL-2.1.txt Deno-LICENSE.md yt-dlp-THIRD_PARTY_LICENSES.txt \
                FFmpeg-BUILD.txt TOOL_VERSIONS.txt; do
    [[ -s "$APP_BUNDLE/Contents/Resources/ThirdPartyNotices/$notice" ]] || {
      echo "Missing third-party notice: $notice" >&2
      exit 1
    }
  done
  suffix=""
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
filename="Shiyin-${version}-macos-${architecture}${suffix}.dmg"
final_dmg="$OUTPUT_DIR/$filename"
if [[ -e "$final_dmg" && "$FORCE" != true ]]; then
  echo "DMG already exists: $final_dmg (pass --force to replace it)" >&2
  exit 1
fi

temporary="$(mktemp -d "$OUTPUT_DIR/.shiyin-dmg.XXXXXX")"
trap 'rm -rf "$temporary"' EXIT
mkdir -p "$temporary/stage"
/usr/bin/ditto "$APP_BUNDLE" "$temporary/stage/Shiyin.app"
ln -s /Applications "$temporary/stage/Applications"
candidate="$temporary/$filename"
/usr/bin/hdiutil create -srcfolder "$temporary/stage" -volname "拾音 $version" \
  -format UDZO "$candidate"
/usr/bin/hdiutil verify "$candidate"

if [[ "$LOCAL_ONLY" != true ]]; then
  /usr/bin/codesign --sign "$SIGN_IDENTITY" --timestamp "$candidate"
  /usr/bin/codesign --verify --strict "$candidate"
  xcrun notarytool submit "$candidate" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$candidate"
  xcrun stapler validate "$candidate"
  /usr/bin/hdiutil verify "$candidate"
fi

mv -f "$candidate" "$final_dmg"
(cd "$OUTPUT_DIR" && shasum -a 256 "$filename" > "$filename.sha256")
echo "DMG: $final_dmg"
echo "SHA-256: $final_dmg.sha256"
echo "Minimum macOS: $minimum_macos; architecture: $architecture"
