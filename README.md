# 拾音 Shiyin

[简体中文](README.md) · [English](README.en.md)

一款原生 SwiftUI macOS 音乐播放器。粘贴 YouTube 或 B 站的视频、音频与列表链接，使用 [yt-dlp](https://github.com/yt-dlp/yt-dlp) 和 [FFmpeg](https://ffmpeg.org/) 提取音频，下载后在本地整理和播放。

## 界面预览

以下截图使用演示曲目，不包含真实资料库数据。

### 聆听空间 · 晨光唱片

![晨光唱片配色的资料库与播放队列](docs/screenshots/library.jpg)

### 自定义歌单 · 夜色黑胶

![夜色黑胶配色的自定义歌单](docs/screenshots/playlist.jpg)

### 导入音频链接

<img src="docs/screenshots/import.jpg" alt="导入音频的设置窗口" width="478">

## 功能

- **按需导入**：支持 YouTube 视频与播放列表，以及 B 站 BV/av 视频、分 P、音频、合集、收藏夹和音频专辑。导入列表前可以预览、全选、取消全选，或逐项选择；可选 M4A、MP3 和音质。
- **管理下载**：查看进度、取消和重试任务。未完成的任务在下次启动时重新排队；失败信息可以复制。
- **本地播放**：搜索资料库、调整队列顺序、随机播放、列表循环和单曲循环。重启后恢复歌曲、进度、队列和音量，并保持暂停状态。
- **融入 macOS**：关闭或最小化主窗口后继续播放；支持菜单栏控制和系统媒体控制。
- **整理资料库**：收藏歌曲、创建和整理歌单；移除曲目时可保留音频文件，或将文件移到废纸篓。
- **切换外观**：提供「晨光唱片」「夜色黑胶」「深海电台」「复古工作室」四套配色。
- **启动动画**：启动时播放唱片动画和一段短提示音；可跳过动画，并在设置中关闭启动音效。

## 环境要求

- macOS 14 或更新版本
- 从源码构建需要 Swift 6 工具链（Xcode 或 Xcode Command Line Tools）
- 使用普通开发构建时，需要本机安装 `yt-dlp`、`ffmpeg`；推荐安装 Deno
- 使用包含下载工具的应用包时，无须单独安装这三个工具

发行包的最低 macOS 版本取决于所内置工具的构建目标；打包脚本会把它写入应用包。当前构建机上的静态 LAME、mpg123 库要求 macOS 15。

如果使用 Homebrew，可以安装命令行依赖：

```bash
brew install yt-dlp ffmpeg deno
```

## 从源码运行

在仓库根目录执行：

```bash
./script/build_and_run.sh
```

脚本会编译 SwiftPM 项目，生成 `dist/Shiyin.app` 并启动应用。它使用本机临时签名，供本地开发运行；当前仓库没有提供经过公证的发行版。每次运行脚本会先关闭正在运行的「拾音」。

## 构建内置工具的应用包

准备同一目标架构的四个独立 macOS 可执行文件，命名为 `yt-dlp`、`ffmpeg`、`ffprobe`、`deno`，放在一个目录中，然后执行：

```bash
./script/build_app.sh --tools-dir /path/to/portable-tools
```

生成的 `dist/Shiyin.app` 会将它们放在 `Contents/MacOS/Tools`，运行时优先使用包内工具。若用户在设置中手动选择了 yt-dlp 路径，则优先使用该路径。打包脚本会拒绝仍引用 Homebrew 或其他非系统动态库的工具，因此不能直接复制 `brew install ffmpeg` 产生的程序。工具来源、许可和发布检查见 [内置工具说明](docs/bundled-tools.md)。如有 Developer ID 证书，可添加 `--sign-identity "Developer ID Application: ..."`；公开分发仍需完成公证。

仓库提供 `script/fetch_release_tools.sh` 下载并校验官方 yt-dlp、Deno，以及 `script/build_portable_ffmpeg.sh` 从源码和构建机上的静态 LAME、mpg123 库生成独立的 `ffmpeg`、`ffprobe`；具体命令见内置工具说明。

## 如何使用

1. 点击「导入链接」，粘贴 YouTube 或 B 站链接。B 站单个 BV 视频默认下载当前分 P；勾选「导入全部分 P」可预览全部分 P。
2. 导入播放列表、B 站合集或收藏夹时，预览并勾选想下载的曲目；选择格式、音质和保存位置。
3. 下载完成后，在资料库或歌单中播放；可将歌曲加入播放队列，或通过菜单栏控制播放。

默认音频目录是 `~/Music/拾音`，可在设置中更改后续下载的保存位置。资料库记录保存在 `~/Library/Application Support/Shiyin/library.json`。

### 遇到登录验证

如果 yt-dlp 提示 `Sign in to confirm you’re not a bot`，可以在「外观与设置」中按需选择浏览器 Cookie 或 `cookies.txt`，再重试下载。默认不会读取登录信息。Cookie 可能包含登录凭据，请勿上传到仓库或分享给他人。相关说明见 [yt-dlp Cookie FAQ](https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp)。

部分播放列表可能需要登录，或被 YouTube 标记为不可查看；这类链接无法保证导入成功。下载可用性也会随 YouTube 和 yt-dlp 的变化而变化，遇到提取错误时可先更新 yt-dlp。

B 站登录来源在设置中单独选择，默认不使用浏览器 Cookie。私有收藏夹等内容需要对应账号的登录状态。B 站列表为了显示每项标题会逐条读取元数据，大型合集可能需要较长时间；读取时可关闭导入窗口取消。

## 开发与测试

```bash
./script/test.sh
```

该脚本运行项目中的基础、认证参数、歌单与队列、播放逻辑检查。应用入口和界面代码位于 `Sources/Shiyin/`，构建脚本位于 `script/`。

## 使用范围

请仅下载和使用你有权保存的内容。本项目与 YouTube、哔哩哔哩、Apple Music 无关联。

## 许可证

本项目代码与自有资源采用 [MIT 许可证](LICENSE)。yt-dlp、FFmpeg、Deno 等第三方工具遵循各自的许可证；打包说明见[内置工具说明](docs/bundled-tools.md)。
