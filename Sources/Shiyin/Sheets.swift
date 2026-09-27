import AppKit
import SwiftUI

struct ImportSheet: View {
    @Environment(\.themePalette) private var theme
    let store: MusicStore
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var info: VideoInfo?
    @State private var format: AudioFormat = .m4a
    @State private var quality: AudioQuality = .best
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var playlist: PlaylistInfo?
    @State private var selectedEntryIDs: Set<Int> = []
    @State private var importEntirePlaylist = false
    @State private var importTask: Task<Void, Never>?

    private var isBilibiliInput: Bool {
        URL(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines))
            .map(YouTubeClient.isBilibiliURL) ?? false
    }

    private var isPlaylistMode: Bool {
        YouTubeClient.isDirectPlaylistURL(urlText) ||
            (importEntirePlaylist && YouTubeClient.hasPlaylistID(urlText))
    }

    private var hasOptionalPlaylist: Bool {
        YouTubeClient.hasPlaylistID(urlText) && !YouTubeClient.isDirectPlaylistURL(urlText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "link")
                .font(.system(size: 18)).foregroundStyle(theme.accentDark)
                .frame(width: 42, height: 42).background(theme.selected, in: RoundedRectangle(cornerRadius: 11))
                .padding(.bottom, 22)
            Text("ADD TO YOUR LIBRARY")
                .font(.system(size: 9, weight: .bold)).tracking(1.8).foregroundStyle(theme.accent)
            Text("从 YouTube 或 B 站导入音频")
                .font(.system(size: 24, weight: .semibold, design: .serif)).foregroundStyle(theme.text).padding(.top, 6)
            Text("粘贴视频或播放列表链接，选择格式和音质后加入资料库。")
                .font(.system(size: 12)).foregroundStyle(theme.muted).padding(.top, 8).padding(.bottom, 27)
            Text("视频、音频或列表链接").font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.text)
            HStack {
                Image(systemName: "link").foregroundStyle(theme.muted)
                TextField("粘贴 YouTube 或 B 站链接", text: $urlText)
                    .textFieldStyle(.plain).font(.system(size: 12))
                    .disabled(isLoading)
                    .onChange(of: urlText) { _, _ in
                        info = nil
                        playlist = nil
                        selectedEntryIDs.removeAll()
                        errorMessage = nil
                        importEntirePlaylist = false
                    }
                    .onSubmit { startImport() }
            }
            .padding(12).background(theme.sidebar, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.line))
            .padding(.top, 8)
            if hasOptionalPlaylist {
                Toggle(isBilibiliInput ? "导入全部分 P" : "导入整个播放列表", isOn: $importEntirePlaylist)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.text)
                    .padding(.top, 10)
                    .onChange(of: importEntirePlaylist) { _, _ in
                        playlist = nil
                        selectedEntryIDs.removeAll()
                        errorMessage = nil
                    }
            }
            if let errorMessage {
                CopyableErrorView(title: isPlaylistMode ? "读取播放列表失败" : "读取视频信息失败",
                                  message: errorMessage)
                    .padding(.top, 8)
                if errorMessage.localizedCaseInsensitiveContains("sign in to confirm") {
                    Text("网站要求登录验证。可关闭此窗口，在「外观与设置」中选择对应网站的登录来源后重试。")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.muted)
                        .padding(.top, 7)
                }
            }
            if let info {
                HStack(spacing: 11) {
                    ArtworkView(title: info.title, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(info.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.text).lineLimit(1)
                        Text("\(info.artist) · \(timeLabel(info.duration ?? 0))")
                            .font(.system(size: 10)).foregroundStyle(theme.muted)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.accent)
                }
                .padding(10).background(theme.sidebar, in: RoundedRectangle(cornerRadius: 8))
                .padding(.top, 12)
            }
            if let playlist {
                PlaylistPreviewView(playlist: playlist, selectedIDs: $selectedEntryIDs)
                    .padding(.top, 12)
            }
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("音频格式").font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.text)
                    Picker("", selection: $format) {
                        ForEach(AudioFormat.allCases) { item in Text(item == .m4a ? "M4A · 推荐" : "MP3 · 通用").tag(item) }
                    }.labelsHidden()
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("音质").font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.text)
                    Picker("", selection: $quality) {
                        ForEach(AudioQuality.allCases) { item in Text(item.rawValue).tag(item) }
                    }.labelsHidden()
                }
            }
            .padding(.top, 24)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle").padding(.top, 1)
                Text("仅导入你有权保存的内容。下载使用本机 yt-dlp 和 ffmpeg，音频保存在这台 Mac 上。")
            }
            .font(.system(size: 10)).foregroundStyle(theme.muted)
            .padding(.top, 22)
            HStack(spacing: 10) {
                Spacer()
                Button("取消") { dismiss() }
                Button {
                    startImport()
                } label: {
                    HStack(spacing: 7) {
                        if isLoading { ProgressView().controlSize(.small) }
                        Text(buttonTitle)
                        if !isLoading { Image(systemName: "arrow.right") }
                    }
                }
                .buttonStyle(SoftButtonStyle(filled: true))
                .disabled(isLoading || urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          (playlist != nil && selectedEntryIDs.isEmpty))
            }
            .padding(.top, 27)
        }
        .padding(29).frame(width: playlist == nil ? 478 : 540)
        .background(theme.canvas)
        .onDisappear { importTask?.cancel() }
    }

    private var buttonTitle: String {
        if isLoading { return isPlaylistMode ? "读取播放列表…" : "读取视频信息…" }
        if playlist != nil { return "下载所选 \(selectedEntryIDs.count) 首" }
        return isPlaylistMode ? "读取播放列表" : "加入资料库"
    }

    private func startImport() {
        guard !isLoading else { return }
        importTask = Task { await importURL() }
    }

    @MainActor private func importURL() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; importTask = nil }
        do {
            if isPlaylistMode {
                if let playlist {
                    let selected = playlist.entries.filter { selectedEntryIDs.contains($0.id) }
                    guard !selected.isEmpty else { return }
                    store.addPlaylistDownloads(selected, title: playlist.title, format: format,
                                               quality: quality)
                    dismiss()
                } else {
                    let url = try YouTubeClient.validatedPlaylistURL(urlText)
                    let result = try await YouTubeClient.probePlaylist(url,
                        auth: YouTubeClient.configuredAuth(for: url))
                    guard !Task.isCancelled else { return }
                    playlist = result
                    selectedEntryIDs = Set(result.entries.map(\.id))
                }
            } else {
                let url = try YouTubeClient.validatedURL(urlText)
                let video = try await YouTubeClient.probe(url,
                    auth: YouTubeClient.configuredAuth(for: url))
                guard !Task.isCancelled else { return }
                info = video
                store.addDownload(url: url, info: video, format: format, quality: quality)
                dismiss()
            }
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }
}

struct SettingsSheet: View {
    @Environment(\.themePalette) private var theme
    @Bindable var store: MusicStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearanceTheme") private var appearanceTheme = ThemeOption.morning.rawValue
    @AppStorage("playLaunchSound") private var playLaunchSound = true
    @AppStorage("youtubeAuthMode") private var youtubeAuthMode = "none"
    @AppStorage("youtubeCookiesFilePath") private var youtubeCookiesFilePath = ""
    @AppStorage("bilibiliAuthMode") private var bilibiliAuthMode = "none"
    @AppStorage("bilibiliCookiesFilePath") private var bilibiliCookiesFilePath = ""
    @State private var customToolPath = UserDefaults.standard.string(forKey: "ytDLPPath") ?? ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("外观与设置").font(.system(size: 23, weight: .semibold, design: .serif)).foregroundStyle(theme.text)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("播放器配色").font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.text)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(ThemeOption.allCases) { option in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.18)) { appearanceTheme = option.rawValue }
                                } label: {
                                    ThemePreviewCard(option: option, isSelected: appearanceTheme == option.rawValue)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(option.name)配色")
                                .accessibilityAddTraits(appearanceTheme == option.rawValue ? .isSelected : [])
                            }
                        }
                        Text("选择后立即应用，并在下次启动时保留。")
                            .font(.system(size: 10)).foregroundStyle(theme.muted)
                    }
                    Divider()
                    Toggle("播放启动音效", isOn: $playLaunchSound)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("新下载的保存位置").font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.text)
                        Text(store.audioDirectory.path).font(.system(size: 11)).foregroundStyle(theme.muted).textSelection(.enabled)
                        Button("选择文件夹…") { chooseFolder() }.buttonStyle(SoftButtonStyle())
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 7) {
                        Text("yt-dlp").font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.text)
                        Text(YouTubeClient.toolURL()?.path ?? "未找到，请选择 yt-dlp 可执行文件")
                            .font(.system(size: 11)).foregroundStyle(theme.muted).textSelection(.enabled)
                        Button("选择 yt-dlp…") { chooseTool() }.buttonStyle(SoftButtonStyle())
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YouTube 登录来源").font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.text)
                        Picker("登录来源", selection: $youtubeAuthMode) {
                            Text("不使用登录状态").tag("none")
                            Text("Chrome").tag("chrome")
                            Text("Safari").tag("safari")
                            Text("Firefox").tag("firefox")
                            Text("Edge").tag("edge")
                            Text("cookies.txt 文件").tag("file")
                        }
                        .labelsHidden()
                        if youtubeAuthMode == "file" {
                            Text(youtubeCookiesFilePath.isEmpty ? "尚未选择文件" : youtubeCookiesFilePath)
                                .font(.system(size: 10)).foregroundStyle(theme.muted).textSelection(.enabled)
                            Button("选择 cookies.txt…") { chooseCookiesFile(forBilibili: false) }
                                .buttonStyle(SoftButtonStyle())
                        }
                        if youtubeAuthMode != "none" {
                            Text(youtubeAuthMode == "file"
                                 ? "cookies.txt 可能包含其他网站的登录凭据；请勿分享。应用只会将它复制到临时文件供 yt-dlp 使用。"
                                 : "yt-dlp 会读取所选浏览器的 Cookie 数据，可能包含其他网站的登录凭据。仅在需要时启用。")
                                .font(.system(size: 10)).foregroundStyle(theme.muted)
                        }
                        Link("查看 yt-dlp 的 Cookie 使用说明", destination: URL(string: "https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp")!)
                            .font(.system(size: 10))
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("B 站登录来源").font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.text)
                        Picker("B 站登录来源", selection: $bilibiliAuthMode) {
                            Text("不使用登录状态").tag("none")
                            Text("Chrome").tag("chrome")
                            Text("Safari").tag("safari")
                            Text("Firefox").tag("firefox")
                            Text("Edge").tag("edge")
                            Text("cookies.txt 文件").tag("file")
                        }
                        .labelsHidden()
                        if bilibiliAuthMode == "file" {
                            Text(bilibiliCookiesFilePath.isEmpty ? "尚未选择文件" : bilibiliCookiesFilePath)
                                .font(.system(size: 10)).foregroundStyle(theme.muted).textSelection(.enabled)
                            Button("选择 cookies.txt…") { chooseCookiesFile(forBilibili: true) }
                                .buttonStyle(SoftButtonStyle())
                        }
                        Text("仅在 B 站需要登录时启用；浏览器 Cookie 和文件可能包含登录凭据。")
                            .font(.system(size: 10)).foregroundStyle(theme.muted)
                    }
                    Divider()
                    HStack {
                        Text("ffmpeg").font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.text)
                        Spacer()
                        Text(YouTubeClient.ffmpegURL() == nil ? "未找到" : "已就绪")
                            .font(.system(size: 11)).foregroundStyle(theme.muted)
                    }
                    HStack {
                        Text("JavaScript 运行时").font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.text)
                        Spacer()
                        Text(YouTubeClient.javascriptRuntime()?.name ?? "未找到，部分视频可能不可用")
                            .font(.system(size: 11)).foregroundStyle(theme.muted)
                    }
                }
                .padding(27)
            }
            Divider()
            HStack {
                Spacer()
                Button("完成") { dismiss() }.buttonStyle(SoftButtonStyle(filled: true))
            }
            .padding(.horizontal, 27)
            .padding(.vertical, 15)
        }
        .frame(width: 485, height: 700)
        .background(theme.canvas)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = store.audioDirectory
        if panel.runModal() == .OK, let url = panel.url { store.audioDirectory = url }
    }

    private func chooseTool() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url,
           FileManager.default.isExecutableFile(atPath: url.path) {
            customToolPath = url.path
            UserDefaults.standard.set(url.path, forKey: "ytDLPPath")
        }
    }

    private func chooseCookiesFile(forBilibili: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "选择 Netscape 格式的 cookies.txt 文件。文件可能包含登录凭据，请妥善保管。"
        if panel.runModal() == .OK, let url = panel.url {
            if forBilibili { bilibiliCookiesFilePath = url.path }
            else { youtubeCookiesFilePath = url.path }
        }
    }
}

private struct ThemePreviewCard: View {
    let option: ThemeOption
    let isSelected: Bool

    var body: some View {
        let palette = option.palette
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                Rectangle().fill(palette.sidebar).frame(width: 28)
                Rectangle().fill(LinearGradient(colors: palette.hero, startPoint: .leading, endPoint: .trailing))
                Rectangle().fill(palette.inspector).frame(width: 23)
            }
            .frame(height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            HStack(spacing: 7) {
                Circle().fill(palette.accent).frame(width: 9, height: 9)
                Text(option.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(palette.text)
                Spacer(minLength: 0)
                if isSelected { Image(systemName: "checkmark.circle.fill").foregroundStyle(palette.accentDark) }
            }
        }
        .padding(10)
        .background(palette.canvas, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(isSelected ? palette.accent : palette.line, lineWidth: isSelected ? 2 : 1))
    }
}
