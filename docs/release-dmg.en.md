# Creating a macOS DMG release

`script/package_dmg.sh` places the app with bundled tools in a read-only DMG alongside an `/Applications` shortcut. Release mode requires Developer ID signatures and Apple notarization. `--local` makes a test image that requires a manual launch override.

## Prepare the tools

Follow the [bundled tool guide](bundled-tools.md) to prepare standalone `yt-dlp`, `ffmpeg`, `ffprobe`, and `deno` binaries for the same architecture, plus license notices and build records. Before publishing binaries, check the licensing and source-availability obligations for FFmpeg, LAME, mpg123, and other included components.

The current build is **arm64 and requires macOS 15 or later**. Rebuild and validate every bundled tool before claiming another architecture or minimum macOS version.

## Configure signing and notarization

Install a `Developer ID Application` certificate for your Apple Developer team in Keychain, then verify it and store notarization credentials interactively:

```bash
security find-identity -v -p codesigning
xcrun notarytool store-credentials shiyin-notary
```

Do not commit passwords or API private keys. Without a certificate, use the test flow below. If shared, clearly label the image as unnotarized, explain the manual launch steps, and mark the GitHub Release as a prerelease.

## Build and package

From the repository root, replace the tool directory and certificate identity:

```bash
./script/test.sh
./script/build_app.sh \
  --tools-dir /path/to/portable-tools \
  --sign-identity 'Developer ID Application: Your Name (TEAMID)' \
  --version 0.1.0 --build-number 1
./script/package_dmg.sh \
  --identity 'Developer ID Application: Your Name (TEAMID)' \
  --notary-profile shiyin-notary
```

The packaging script verifies the app and bundled tool signatures, hardened runtime, secure timestamps, and essential notices; creates and verifies the DMG; submits it to Apple; staples its ticket; and writes a SHA-256 file. It will not publish a release-named DMG if notarization fails. Test the resulting DMG on a clean Mac with the target OS and architecture.

To verify DMG creation without Developer ID signing:

```bash
./script/package_dmg.sh --local
```

The output has `-LOCAL` in its name and is **not** a regular distribution package. Before sharing a test image, check third-party license and source materials. Testing installation and playback on a clean target Mac is recommended; disclose any testing still outstanding in the prerelease notes.

After those checks, upload the test image and corresponding source as a prerelease. Use the [test release notes](releases/v0.1.0-beta.1.md) to explain the manual launch steps:

```bash
git tag -a v0.1.0-beta.1 -m 'Shiyin 0.1.0 beta 1'
git push origin main v0.1.0-beta.1
gh release create v0.1.0-beta.1 \
  dist/Shiyin-0.1.0-macos-arm64-LOCAL.dmg \
  dist/Shiyin-0.1.0-macos-arm64-LOCAL.dmg.sha256 \
  dist/Shiyin-0.1.0-third-party-sources.tar.gz \
  --title 'Shiyin 0.1.0 beta' \
  --notes-file docs/releases/v0.1.0-beta.1.md \
  --prerelease --verify-tag
```

## Upload a GitHub Release

Once notarization, third-party license materials, and version alignment are complete:

```bash
git tag -a v0.1.0 -m 'Shiyin 0.1.0'
git push origin main v0.1.0
gh release create v0.1.0 \
  dist/Shiyin-0.1.0-macos-arm64.dmg \
  dist/Shiyin-0.1.0-macos-arm64.dmg.sha256 \
  --title 'Shiyin 0.1.0' --generate-notes --verify-tag
```

Use the filename reported by the packaging script if you build a Universal app. The DMG becomes a downloadable Release asset; `dist/` remains ignored by Git.
