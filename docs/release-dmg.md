# 发布 macOS DMG

`script/package_dmg.sh` 把带内置工具的 `Shiyin.app` 放进只读 DMG，并附上指向 `/Applications` 的快捷方式。正式模式要求 Developer ID 签名、公证和票据装订；`--local` 生成需手动放行的测试包。

## 1. 准备内置工具

按 [内置工具说明](bundled-tools.md) 准备同一架构的 `yt-dlp`、`ffmpeg`、`ffprobe` 和 `deno`，以及第三方许可证和构建记录。**发布二进制前还要核对 FFmpeg、LAME、mpg123 等组件的许可证义务，并提供相应源码或获取方式。** 不要把 Homebrew 的动态链接程序直接放进发行包。

当前构建机生成的是 **arm64、macOS 15 起**的应用包。只有重建并验证所有内置工具后，才能更改对外标注的架构或最低系统版本；打包脚本会从实际应用包读取这两项。

## 2. 配置 Apple 签名与公证

在钥匙串中安装与你的 Apple Developer 团队对应的 `Developer ID Application` 证书，然后检查：

```bash
security find-identity -v -p codesigning
xcrun notarytool store-credentials shiyin-notary
```

第二个命令交互式保存公证凭据，不要把密码或 API 私钥写入仓库。没有证书时可以使用下面的测试流程；分享测试包时，应标注未公证及手动打开步骤，并将 GitHub Release 标为预发布版本。

## 3. 构建、打包与验证

在仓库根目录执行，替换工具目录和证书名称：

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

打包脚本会检查应用和内置工具的 Developer ID、Hardened Runtime、时间戳与基本许可文件，生成 DMG，提交 Apple 公证，装订票据，并输出 SHA-256 文件。任何公证或验证失败都会阻止正式文件名的 DMG 出现在 `dist/`。发布前仍须在一台干净的目标 Mac 上从 DMG 安装并测试下载、播放和系统控制。

仅验证 DMG 制作流程时，可使用当前已构建的应用包：

```bash
./script/package_dmg.sh --local
```

测试包名会带 `-LOCAL`；它未经过 Apple 公证，不能代替正式发行包。上传测试版之前，仍须完成第三方许可证及源码材料核对；建议在干净的目标 Mac 上验证安装与播放，未完成的测试要在预发布说明中列明。

经核对后，可将测试包与对应源码一起作为预发布版本上传，并使用[测试版说明](releases/v0.1.0-beta.1.md)明确写出手动打开步骤：

```bash
git tag -a v0.1.0-beta.1 -m 'Shiyin 0.1.0 beta 1'
git push origin main v0.1.0-beta.1
gh release create v0.1.0-beta.1 \
  dist/Shiyin-0.1.0-macos-arm64-LOCAL.dmg \
  dist/Shiyin-0.1.0-macos-arm64-LOCAL.dmg.sha256 \
  dist/Shiyin-0.1.0-third-party-sources.tar.gz \
  --title '拾音 0.1.0 测试版' \
  --notes-file docs/releases/v0.1.0-beta.1.md \
  --prerelease --verify-tag
```

## 4. 上传 GitHub Release

确认 DMG 已公证、第三方许可材料齐备且版本号与 Git tag 一致后：

```bash
git tag -a v0.1.0 -m 'Shiyin 0.1.0'
git push origin main v0.1.0
gh release create v0.1.0 \
  dist/Shiyin-0.1.0-macos-arm64.dmg \
  dist/Shiyin-0.1.0-macos-arm64.dmg.sha256 \
  --title '拾音 0.1.0' --generate-notes --verify-tag
```

如果实际构建为 Universal，文件名会包含 `universal`；以打包脚本输出为准。GitHub Release 的 DMG 是可下载的安装包，`dist/` 本身仍被 `.gitignore` 排除。
