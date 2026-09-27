# Bundled tool checklist

The app can use standalone `yt-dlp`, `ffmpeg`, `ffprobe`, and `deno` from `Shiyin.app/Contents/MacOS/Tools`. `script/build_app.sh --tools-dir DIRECTORY` builds Shiyin with Swift's release configuration and checks each tool's executable bit, Mach-O format, minimum macOS version, architecture, command-line startup, and linked libraries before copying and signing it. The script does not download tools or license them on your behalf.

| Tool | Suggested source | License and distribution notes |
| --- | --- | --- |
| yt-dlp | Official `yt-dlp_macos` release from [yt-dlp](https://github.com/yt-dlp/yt-dlp/releases), renamed to `yt-dlp` | [Unlicense](https://github.com/yt-dlp/yt-dlp/blob/master/LICENSE). Record the release tag and checksum. |
| Deno | Official `deno-aarch64-apple-darwin.zip` or `deno-x86_64-apple-darwin.zip` from [Deno releases](https://github.com/denoland/deno/releases) | [MIT](https://github.com/denoland/deno/blob/main/LICENSE.md). Record the release tag and checksum. |
| FFmpeg and ffprobe | Portable binaries built from [FFmpeg source](https://ffmpeg.org/download.html) with the codecs needed by Shiyin | Follow [FFmpeg's legal and license guidance](https://ffmpeg.org/legal.html). Include the exact source, build configuration, license notices, and any changes for the actual binaries you distribute. GPL options change the obligations. |

To fetch the pinned official yt-dlp and Deno releases and verify their published SHA-256 checksums:

```bash
./script/fetch_release_tools.sh /path/to/portable-tools
```

Set `YT_DLP_TAG` or `DENO_TAG` to use newer upstream tags. The script records the selected tags and checksums in `TOOL_VERSIONS.txt`.

For a native build of FFmpeg and ffprobe, download a verified FFmpeg source archive, install LAME and mpg123 on the build Mac, and run:

```bash
./script/build_portable_ffmpeg.sh /path/to/ffmpeg-source.tar.xz /path/to/portable-tools
```

This script links the static LAME and mpg123 archives rather than Homebrew's dylibs, and writes its build log and checksums beside the binaries. It does not replace the need to package the source and notices for FFmpeg, LAME, and mpg123 with an actual release. Before uploading a release, record the exact versions and checksums of all four tools, validate their signatures or upstream checksums, and include the applicable licenses and source materials.

The FFmpeg build defaults to a macOS 15 deployment target because current Homebrew static LAME and mpg123 archives on the build Mac target macOS 15. Set `MACOSX_DEPLOYMENT_TARGET=14.0` only with static archives built for macOS 14. The app packaging script sets its minimum macOS version to the highest minimum reported by its bundled executables.

Place license text files in `portable-tools/Notices` before building the app. The packaging script copies that directory to `Shiyin.app/Contents/Resources/ThirdPartyNotices`.
It also writes `BUNDLED_SHA256SUMS` after signing the nested tools. Checksums in upstream manifests describe the downloaded or locally built inputs; signing changes executable bytes.

Do not copy Homebrew's `ffmpeg` and `ffprobe` binaries into a release. They may depend on libraries in `/opt/homebrew` or `/usr/local` that are absent on users' Macs. The build rejects such dependencies, but a successful link check alone does not prove that a binary's runtime data, minimum macOS version, security requirements, or license package is complete.

For a public GitHub release, test the app on a clean Mac of each supported architecture, sign the nested tools and the app with a Developer ID identity, notarize the final distribution artifact, and staple its ticket. The default ad hoc signature is intended only for local development.
