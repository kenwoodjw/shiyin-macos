import Darwin
import Foundation

enum YouTubeError: LocalizedError {
    case invalidURL
    case invalidPlaylistURL
    case emptyPlaylist
    case missingTool
    case missingFFmpeg
    case missingCookiesFile
    case unreadableCookiesFile
    case failed(String)
    case missingOutput
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL: "请输入有效的 YouTube 或 B 站视频、音频链接。"
        case .invalidPlaylistURL: "请输入有效的 YouTube 播放列表或 B 站合集链接。"
        case .emptyPlaylist: "列表中没有可导入的视频或音频。"
        case .missingTool: "没有找到 yt-dlp。请使用包含下载工具的发行版，或在下载设置中选择 yt-dlp。"
        case .missingFFmpeg: "没有找到 ffmpeg。请使用包含下载工具的发行版，或安装 ffmpeg。"
        case .missingCookiesFile: "请先在设置中选择 cookies.txt 文件，或改用其他登录来源。"
        case .unreadableCookiesFile: "无法读取所选的 cookies.txt 文件，请检查文件是否仍存在且可读取。"
        case .failed(let message): message
        case .missingOutput: "下载已结束，但没有找到音频文件。"
        case .cancelled: "下载已取消。"
        }
    }
}

enum YouTubeAuth {
    case none
    case browser(String)
    case cookiesFile(String)
}

enum YouTubeClient {
    static func isBilibiliURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return ["bilibili.com", "www.bilibili.com", "m.bilibili.com", "space.bilibili.com",
                "b23.tv", "www.b23.tv"].contains(host)
    }

    static func configuredAuth(for url: URL? = nil) -> YouTubeAuth {
        let isBilibili = url.map(isBilibiliURL) ?? false
        let modeKey = isBilibili ? "bilibiliAuthMode" : "youtubeAuthMode"
        let fileKey = isBilibili ? "bilibiliCookiesFilePath" : "youtubeCookiesFilePath"
        let mode = UserDefaults.standard.string(forKey: modeKey) ?? "none"
        switch mode {
        case "chrome", "safari", "firefox", "edge":
            return .browser(mode)
        case "file":
            return .cookiesFile(UserDefaults.standard.string(forKey: fileKey) ?? "")
        default:
            return .none
        }
    }

    static func validatedURL(_ text: String) throws -> URL {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https" || url.scheme == "http",
              let host = url.host?.lowercased()
        else { throw YouTubeError.invalidURL }
        if isBilibiliURL(url) {
            let path = url.pathComponents
            if ["b23.tv", "www.b23.tv"].contains(host), path.count > 1 { return url }
            if ["bilibili.com", "www.bilibili.com", "m.bilibili.com"].contains(host),
               path.count >= 3, path[1] == "video",
               isBilibiliVideoID(path[2]) { return url }
            if ["bilibili.com", "www.bilibili.com"].contains(host),
               path.count >= 3, path[1] == "audio", isBilibiliAudioID(path[2], prefix: "au") { return url }
            throw YouTubeError.invalidURL
        }
        guard ["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com",
               "youtu.be", "www.youtu.be"].contains(host) else { throw YouTubeError.invalidURL }
        if host.hasSuffix("youtu.be") {
            guard url.pathComponents.count > 1 else { throw YouTubeError.invalidURL }
        } else {
            let hasVideoID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.contains(where: { $0.name == "v" && !($0.value ?? "").isEmpty }) == true
            guard hasVideoID || url.path.hasPrefix("/shorts/") || url.path.hasPrefix("/live/") else {
                throw YouTubeError.invalidURL
            }
        }
        return url
    }

    static func hasPlaylistID(_ text: String) -> Bool {
        playlistID(in: text) != nil || isBilibiliVideoURL(text)
    }

    static func isDirectPlaylistURL(_ text: String) -> Bool {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return (url.path == "/playlist" && playlistID(in: text) != nil) || isBilibiliListURL(url)
    }

    static func validatedPlaylistURL(_ text: String) throws -> URL {
        if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
           url.scheme == "https" || url.scheme == "http", isBilibiliURL(url) {
            if isBilibiliListURL(url) { return url }
            if isBilibiliVideoURL(text) {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.queryItems = nil
                components?.fragment = nil
                if let cleanURL = components?.url { return cleanURL }
            }
            throw YouTubeError.invalidPlaylistURL
        }
        guard let id = playlistID(in: text),
              let source = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines))
        else { throw YouTubeError.invalidPlaylistURL }
        let sourceItems = URLComponents(url: source, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let isMix = id.hasPrefix("RD")
        let videoID = sourceItems.first(where: { $0.name == "v" })?.value
        let seed = isMix && source.path == "/watch" && isVideoID(videoID)
            ? videoID
            : (isMix && source.path == "/playlist" ? mixSeedVideoID(from: id) : nil)
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.youtube.com"
        components.path = seed == nil ? "/playlist" : "/watch"
        components.queryItems = (seed.map { [URLQueryItem(name: "v", value: $0)] } ?? []) +
            [URLQueryItem(name: "list", value: id)]
        guard let url = components.url else { throw YouTubeError.invalidPlaylistURL }
        return url
    }

    private static func isBilibiliVideoID(_ text: String) -> Bool {
        if text.hasPrefix("BV"), text.count == 12 {
            return text.dropFirst(2).allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
        }
        return text.hasPrefix("av") && !text.dropFirst(2).isEmpty &&
            text.dropFirst(2).allSatisfy(\.isNumber)
    }

    private static func isBilibiliAudioID(_ text: String, prefix: String) -> Bool {
        text.hasPrefix(prefix) && !text.dropFirst(prefix.count).isEmpty &&
            text.dropFirst(prefix.count).allSatisfy(\.isNumber)
    }

    private static func isBilibiliVideoURL(_ text: String) -> Bool {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              isBilibiliURL(url),
              ["bilibili.com", "www.bilibili.com", "m.bilibili.com"].contains(url.host?.lowercased() ?? "")
        else { return false }
        let path = url.pathComponents
        return path.count >= 3 && path[1] == "video" && isBilibiliVideoID(path[2])
    }

    private static func isBilibiliListURL(_ url: URL) -> Bool {
        guard url.scheme == "https" || url.scheme == "http" else { return false }
        let host = url.host?.lowercased() ?? ""
        let path = url.pathComponents
        if host == "space.bilibili.com", path.count >= 3,
           !path[1].isEmpty, path[1].allSatisfy(\.isNumber) {
            if path[2] == "lists", path.count >= 4,
               !path[3].isEmpty, path[3].allSatisfy(\.isNumber) { return true }
            if path[2] == "favlist" ||
                (path[2] == "channel" && path.count >= 4 && path[3] == "collectiondetail") {
                let key = path[2] == "favlist" ? "fid" : "sid"
                return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                    .contains(where: { $0.name == key && !($0.value ?? "").isEmpty }) == true
            }
        }
        if ["bilibili.com", "www.bilibili.com"].contains(host) {
            if path.count >= 3, path[1] == "list", !path[2].isEmpty { return true }
            if path.count >= 4, path[1] == "medialist",
               ["play", "detail"].contains(path[2]), !path[3].isEmpty { return true }
            if path.count >= 3, path[1] == "audio", isBilibiliAudioID(path[2], prefix: "am") { return true }
            if url.path == "/watchlater" || url.path == "/watchlater/" { return true }
        }
        return false
    }

    private static func mixSeedVideoID(from playlistID: String) -> String? {
        for prefix in ["RDMM", "RD"] where playlistID.hasPrefix(prefix) {
            let candidate = String(playlistID.dropFirst(prefix.count))
            if isVideoID(candidate) { return candidate }
        }
        return nil
    }

    private static func isVideoID(_ text: String?) -> Bool {
        guard let text, text.count == 11 else { return false }
        return text.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
    }

    private static func playlistID(in text: String) -> String? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https" || url.scheme == "http",
              let host = url.host?.lowercased(),
              ["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com"].contains(host),
              url.path == "/playlist" || url.path == "/watch",
              let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "list" })?.value,
              !id.isEmpty
        else { return nil }
        return id
    }

    static var bundledToolsDirectory: URL? {
        Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("Tools", isDirectory: true)
    }

    static func executable(named name: String, override: String? = nil, bundledDirectory: URL? = nil) -> URL? {
        let toolsDirectory = bundledDirectory ?? bundledToolsDirectory
        let candidates = [override, toolsDirectory?.appendingPathComponent(name).path,
                          "/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)", "/usr/bin/\(name)"]
            .compactMap { $0 }
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map(URL.init(fileURLWithPath:))
    }

    static func toolURL() -> URL? {
        executable(named: "yt-dlp", override: UserDefaults.standard.string(forKey: "ytDLPPath"))
    }

    static func ffmpegURL() -> URL? { executable(named: "ffmpeg") }

    static func javascriptRuntime() -> (name: String, url: URL)? {
        if let deno = executable(named: "deno") { return ("Deno", deno) }
        if let node = executable(named: "node") { return ("Node.js", node) }
        return nil
    }

    private static var javascriptArguments: [String] {
        guard let runtime = javascriptRuntime() else { return [] }
        let name = runtime.name == "Deno" ? "deno" : "node"
        return ["--js-runtimes", "\(name):\(runtime.url.path)"]
    }

    static func probe(_ url: URL, auth: YouTubeAuth) async throws -> VideoInfo {
        guard let tool = toolURL() else { throw YouTubeError.missingTool }
        let result = try await run(tool: tool, arguments: [
            "--no-config", "--no-playlist", "--dump-single-json", "--skip-download"
        ] + javascriptArguments + [url.absoluteString], auth: auth)
        guard result.exitCode == 0 else { throw YouTubeError.failed(result.errorMessage) }
        guard let data = result.stdout.data(using: .utf8),
              let info = try? JSONDecoder().decode(VideoInfo.self, from: data)
        else { throw YouTubeError.failed("无法读取视频信息。") }
        return info
    }

    static func probePlaylist(_ url: URL, auth: YouTubeAuth) async throws -> PlaylistInfo {
        guard let tool = toolURL() else { throw YouTubeError.missingTool }
        let isBilibili = isBilibiliURL(url)
        let listingOptions = isBilibili ? ["--ignore-errors"] : ["--flat-playlist"]
        let result = try await run(tool: tool, arguments: ["--no-config"] + listingOptions + [
            "--dump-single-json", "--skip-download"
        ] + javascriptArguments + [url.absoluteString], auth: auth)
        guard result.exitCode == 0 else {
            let detail = result.errorMessage
            if detail.localizedCaseInsensitiveContains("This playlist type is unviewable"),
               URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                .contains(where: { $0.name == "list" && ($0.value ?? "").hasPrefix("RD") }) == true {
                throw YouTubeError.failed("\(detail)\n请复制 YouTube 正在播放此 Mix 时的完整链接（同时含 v 和 list）后重试。")
            }
            throw YouTubeError.failed(detail)
        }
        guard let data = result.stdout.data(using: .utf8),
              let raw = try? JSONDecoder().decode(RawPlaylist.self, from: data)
        else { throw YouTubeError.failed("无法读取播放列表信息。") }

        let listedEntries = raw.entries ?? (isBilibili ? [RawPlaylistEntry(
            id: raw.id, url: url.absoluteString, webpageURL: url.absoluteString,
            title: raw.title, uploader: raw.uploader, channel: raw.channel, duration: raw.duration)] : [])
        let entries = listedEntries.enumerated().compactMap { index, entry -> PlaylistEntry? in
            guard let entry else { return nil }
            let videoURL: URL
            let id: String
            if isBilibili {
                guard let page = entry.webpageURL ?? entry.url,
                      let validated = try? validatedURL(page) else { return nil }
                videoURL = validated
                id = entry.id ?? validated.lastPathComponent
            } else {
                guard let youtubeID = entry.id ?? videoID(from: entry.url), !youtubeID.isEmpty,
                      youtubeID.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") })
                else { return nil }
                var components = URLComponents()
                components.scheme = "https"
                components.host = "www.youtube.com"
                components.path = "/watch"
                components.queryItems = [URLQueryItem(name: "v", value: youtubeID)]
                guard let canonicalURL = components.url else { return nil }
                videoURL = canonicalURL
                id = youtubeID
            }
            let title = entry.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let info = VideoInfo(id: id, title: title.flatMap { $0.isEmpty ? nil : $0 } ?? "未命名视频 \(index + 1)",
                                 uploader: entry.uploader, channel: entry.channel, duration: entry.duration)
            return PlaylistEntry(id: index, url: videoURL, video: info)
        }
        guard !entries.isEmpty else { throw YouTubeError.emptyPlaylist }
        let title = raw.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return PlaylistInfo(title: title.flatMap { $0.isEmpty ? nil : $0 } ??
                            (isBilibili ? "B 站合集" : "YouTube 播放列表"),
                            entries: entries, totalCount: listedEntries.count)
    }

    private struct RawPlaylist: Decodable {
        let id: String?
        let title: String?
        let uploader: String?
        let channel: String?
        let duration: Double?
        let entries: [RawPlaylistEntry?]?
    }

    private struct RawPlaylistEntry: Decodable {
        let id: String?
        let url: String?
        let webpageURL: String?
        let title: String?
        let uploader: String?
        let channel: String?
        let duration: Double?

        private enum CodingKeys: String, CodingKey {
            case id, url, title, uploader, channel, duration
            case webpageURL = "webpage_url"
        }
    }

    private static func videoID(from text: String?) -> String? {
        guard let text else { return nil }
        if let components = URLComponents(string: text), components.host != nil {
            return components.queryItems?.first(where: { $0.name == "v" })?.value
        }
        return text
    }

    static func download(
        _ url: URL,
        id: UUID,
        format: AudioFormat,
        quality: AudioQuality,
        destination: URL,
        auth: YouTubeAuth,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws -> URL {
        guard let tool = toolURL() else { throw YouTubeError.missingTool }
        guard let ffmpeg = ffmpegURL() else { throw YouTubeError.missingFFmpeg }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let template = destination.appendingPathComponent("\(id.uuidString).%(ext)s").path
        let result = try await run(tool: tool, arguments: [
            "--no-config", "--no-playlist", "--newline", "--extract-audio",
            "--audio-format", format.argument, "--audio-quality", quality.argument,
            "--ffmpeg-location", ffmpeg.deletingLastPathComponent().path,
            "--output", template
        ] + javascriptArguments + [url.absoluteString], auth: auth, onProgress: onProgress)
        guard result.exitCode == 0 else { throw YouTubeError.failed(result.errorMessage) }
        let files = try FileManager.default.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil)
        guard let file = files.first(where: {
            $0.lastPathComponent.hasPrefix(id.uuidString + ".") && $0.pathExtension.lowercased() == format.argument
        }) else { throw YouTubeError.missingOutput }
        return file
    }

    private struct ProcessResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String

        var errorMessage: String {
            let lines = stderr.split(separator: "\n").map(String.init)
            return lines.last(where: { $0.contains("ERROR:") })
                ?? (lines.isEmpty ? "yt-dlp 执行失败（状态码 \(exitCode)）。" : lines.suffix(3).joined(separator: "\n"))
        }
    }

    private static func run(
        tool: URL,
        arguments: [String],
        auth: YouTubeAuth,
        onProgress: (@MainActor (Double) -> Void)? = nil
    ) async throws -> ProcessResult {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("shiyin-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: temp) }
        let authArguments: [String]
        switch auth {
        case .none:
            authArguments = []
        case .browser(let browser):
            authArguments = ["--cookies-from-browser", browser]
        case .cookiesFile(let path):
            guard !path.isEmpty else { throw YouTubeError.missingCookiesFile }
            guard FileManager.default.isReadableFile(atPath: path) else {
                throw YouTubeError.unreadableCookiesFile
            }
            let copy = temp.appendingPathComponent("cookies.txt")
            do {
                try FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: copy)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: copy.path)
            } catch {
                throw YouTubeError.unreadableCookiesFile
            }
            authArguments = ["--cookies", copy.path]
        }
        let outURL = temp.appendingPathComponent("stdout.log")
        let errURL = temp.appendingPathComponent("stderr.log")
        FileManager.default.createFile(atPath: outURL.path, contents: nil)
        FileManager.default.createFile(atPath: errURL.path, contents: nil)
        let out = try FileHandle(forWritingTo: outURL)
        let err = try FileHandle(forWritingTo: errURL)
        defer { try? out.close(); try? err.close() }

        let process = Process()
        process.executableURL = tool
        process.arguments = authArguments + arguments
        process.standardOutput = out
        process.standardError = err
        var environment = ProcessInfo.processInfo.environment
        let bundledPath = bundledToolsDirectory.map { $0.path + ":" } ?? ""
        environment["PATH"] = bundledPath + "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
        process.environment = environment
        try process.run()

        while process.isRunning {
            if Task.isCancelled {
                process.terminate()
                for _ in 0..<20 where process.isRunning {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                if process.isRunning { _ = Darwin.kill(process.processIdentifier, SIGKILL) }
                throw YouTubeError.cancelled
            }
            if let onProgress {
                let log = (try? String(contentsOf: outURL, encoding: .utf8)) ?? ""
                let value = progress(in: log)
                await onProgress(value)
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        let stdout = (try? String(contentsOf: outURL, encoding: .utf8)) ?? ""
        let stderr = (try? String(contentsOf: errURL, encoding: .utf8)) ?? ""
        return ProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    static func progress(in log: String) -> Double {
        guard let regex = try? NSRegularExpression(pattern: #"\[download\]\s+([0-9]+(?:\.[0-9]+)?)%"#) else { return 0 }
        let range = NSRange(log.startIndex..<log.endIndex, in: log)
        guard let match = regex.matches(in: log, range: range).last,
              let valueRange = Range(match.range(at: 1), in: log),
              let value = Double(log[valueRange]) else { return 0 }
        return min(value / 100, 1)
    }
}
