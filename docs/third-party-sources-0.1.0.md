# Third-party sources for Shiyin 0.1.0 test build

This archive accompanies `Shiyin-0.1.0-macos-arm64-LOCAL.dmg`. Its FFmpeg and ffprobe executables were built from FFmpeg 9.0.2 with static LAME 4.0 and mpg123 1.33.7 libraries on arm64 macOS 15. The app launches these executables as separate processes; it does not link FFmpeg into the Swift application.

| Archive | SHA-256 | License |
| --- | --- | --- |
| `ffmpeg-9.0.2.tar.xz` | `8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e` | LGPL 2.1 or later for this build |
| `lame-4.0.tar.gz` | `3df5124d5ad3a98312ffd7ba6a9b36230e4f8a3e66d3ce0f425e336c32d216eb` | LGPL; see `COPYING` in the archive |
| `mpg123-1.33.7.tar.bz2` | `31d0e35a4ca567ec9b5ebda6c3062bb4435d6d3eacd6ef0d95cadd7854dc03ee` | LGPL; see `COPYING` in the archive |

The release also includes `build_portable_ffmpeg.sh`, the exact build script, and `FFmpeg-BUILD.txt` with the selected source and build target. The script does not patch these source archives. To rebuild or relink, install static LAME and mpg123 libraries from the versions above, set `LAME_PREFIX` and `MPG123_PREFIX` to their installation prefixes if needed, then run:

```bash
./build_portable_ffmpeg.sh ./ffmpeg-9.0.2.tar.xz ./output
```

The script uses `MACOSX_DEPLOYMENT_TARGET=15.0` by default. The source archives include their license texts. Other bundled tools are official [yt-dlp](https://github.com/yt-dlp/yt-dlp/releases) and [Deno](https://github.com/denoland/deno/releases) executables; their versions and checksums are recorded in the app at `Contents/Resources/ThirdPartyNotices/TOOL_VERSIONS.txt`, alongside their license notices. See [FFmpeg's license guidance](https://ffmpeg.org/legal.html) for distribution details.
