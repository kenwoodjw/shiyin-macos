import Foundation

@main struct AuthIntegration {
    static func main() async throws {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent("shiyin-auth-test-\(UUID().uuidString)")
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: directory) }

        let tool = directory.appendingPathComponent("fake-yt-dlp")
        let argumentsLog = directory.appendingPathComponent("arguments.txt")
        let copiedCookies = directory.appendingPathComponent("copied-cookies.txt")
        let sourceCookies = directory.appendingPathComponent("source-cookies.txt")
        let cookieContents = "# Netscape HTTP Cookie File\n.youtube.com\tTRUE\t/\tTRUE\t0\tTEST\tsecret\n"
        try cookieContents.write(to: sourceCookies, atomically: true, encoding: .utf8)
        try #"""
#!/bin/sh
set -eu
printf '%s\n' "$@" > "$SHIYIN_TEST_ARGS"
probe=0
playlist=0
output=
source_url=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --cookies) cp "$2" "$SHIYIN_TEST_COOKIES"; printf '# changed\n' >> "$2"; shift 2 ;;
    --dump-single-json) probe=1; shift ;;
    --flat-playlist) playlist=1; shift ;;
    --output) output="$2"; shift 2 ;;
    --*) shift ;;
    *) source_url="$1"; shift ;;
  esac
done
if [ "$probe" -eq 1 ]; then
  if [ "$playlist" -eq 1 ]; then
    printf '{"title":"My Mix","entries":[{"id":"abc123","title":"First","channel":"Artist A","duration":91},null,{"url":"https://www.youtube.com/watch?v=def456","title":"Second","uploader":"Artist B"}]}\n'
  elif [ "$source_url" = 'https://space.bilibili.com/2142762/lists/3662502' ]; then
    printf '{"id":"2142762_3662502","title":"B站合集","entries":[{"id":"BV13x41117TL","title":"第一首","uploader":"UP 主","duration":120,"webpage_url":"https://www.bilibili.com/video/BV13x41117TL"},null,{"id":"BV1bK411W797_p2","title":"第二首","webpage_url":"https://www.bilibili.com/video/BV1bK411W797?p=2"}]}\n'
  elif [ "$source_url" = 'https://www.bilibili.com/video/BV1bK411W797' ]; then
    printf '{"id":"BV1bK411W797","title":"分 P 视频","entries":[{"id":"BV1bK411W797_p1","title":"P1","webpage_url":"https://www.bilibili.com/video/BV1bK411W797?p=1"},{"id":"BV1bK411W797_p2","title":"P2","webpage_url":"https://www.bilibili.com/video/BV1bK411W797?p=2"}]}\n'
  else
    printf '{"id":"test","title":"Test"}\n'
  fi
else
  filepath=$(printf '%s' "$output" | sed 's/%(ext)s/m4a/')
  : > "$filepath"
fi
"""#.write(to: tool, atomically: true, encoding: .utf8)
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: tool.path)

        setenv("SHIYIN_TEST_ARGS", argumentsLog.path, 1)
        setenv("SHIYIN_TEST_COOKIES", copiedCookies.path, 1)
        defer { unsetenv("SHIYIN_TEST_ARGS"); unsetenv("SHIYIN_TEST_COOKIES") }

        let previousTool = UserDefaults.standard.string(forKey: "ytDLPPath")
        let previousYouTubeAuth = UserDefaults.standard.string(forKey: "youtubeAuthMode")
        let previousBilibiliAuth = UserDefaults.standard.string(forKey: "bilibiliAuthMode")
        UserDefaults.standard.set(tool.path, forKey: "ytDLPPath")
        defer {
            if let previousTool { UserDefaults.standard.set(previousTool, forKey: "ytDLPPath") }
            else { UserDefaults.standard.removeObject(forKey: "ytDLPPath") }
            if let previousYouTubeAuth { UserDefaults.standard.set(previousYouTubeAuth, forKey: "youtubeAuthMode") }
            else { UserDefaults.standard.removeObject(forKey: "youtubeAuthMode") }
            if let previousBilibiliAuth { UserDefaults.standard.set(previousBilibiliAuth, forKey: "bilibiliAuthMode") }
            else { UserDefaults.standard.removeObject(forKey: "bilibiliAuthMode") }
        }

        let url = URL(string: "https://www.youtube.com/watch?v=test")!
        let video = try await YouTubeClient.probe(url, auth: .cookiesFile(sourceCookies.path))
        expect(video.title == "Test", "probe returned video info")
        let fileArguments = try String(contentsOf: argumentsLog, encoding: .utf8)
        let lines = fileArguments.split(separator: "\n").map(String.init)
        guard let cookieIndex = lines.firstIndex(of: "--cookies"), cookieIndex + 1 < lines.count else {
            fail("probe passed --cookies")
        }
        let temporaryCookiePath = lines[cookieIndex + 1]
        expect(temporaryCookiePath != sourceCookies.path, "probe used a temporary copy")
        expect((try String(contentsOf: copiedCookies, encoding: .utf8)) == cookieContents, "yt-dlp received cookies")
        expect((try String(contentsOf: sourceCookies, encoding: .utf8)) == cookieContents, "original cookies were not changed")
        expect(!manager.fileExists(atPath: temporaryCookiePath), "temporary cookies were removed")

        _ = try await YouTubeClient.probe(url, auth: .browser("chrome"))
        let browserArguments = try String(contentsOf: argumentsLog, encoding: .utf8)
        expect(browserArguments.contains("--cookies-from-browser\nchrome\n"), "browser option passed")

        _ = try await YouTubeClient.probe(url, auth: .none)
        let plainArguments = try String(contentsOf: argumentsLog, encoding: .utf8)
        expect(!plainArguments.contains("--cookies"), "default request used no cookies")

        let playlistURL = try YouTubeClient.validatedPlaylistURL("https://www.youtube.com/playlist?list=PL123")
        let playlist = try await YouTubeClient.probePlaylist(playlistURL, auth: .none)
        expect(playlist.title == "My Mix", "playlist title parsed")
        expect(playlist.entries.count == 2, "unavailable playlist entry skipped")
        expect(playlist.totalCount == 3, "unavailable count retained")
        expect(playlist.entries.map(\.id) == [0, 2], "playlist order retained")
        expect(playlist.entries[0].video.artist == "Artist A", "playlist artist parsed")
        expect(playlist.entries[1].url.absoluteString == "https://www.youtube.com/watch?v=def456", "video URL canonicalized")
        let playlistArguments = try String(contentsOf: argumentsLog, encoding: .utf8)
        expect(playlistArguments.contains("--flat-playlist\n"), "playlist requested flat metadata")
        expect(!playlistArguments.contains("--no-playlist\n"), "playlist was not forced to one video")

        let mixURL = try YouTubeClient.validatedPlaylistURL(
            "https://www.youtube.com/playlist?list=RDmQReG_mBpqc")
        _ = try await YouTubeClient.probePlaylist(mixURL, auth: .none)
        let mixArguments = try String(contentsOf: argumentsLog, encoding: .utf8)
        expect(mixArguments.split(separator: "\n").last == Substring(
            "https://www.youtube.com/watch?v=mQReG_mBpqc&list=RDmQReG_mBpqc"),
            "yt-dlp received the Mix watch URL")

        let bilibiliURL = try YouTubeClient.validatedURL("https://www.bilibili.com/video/BV13x41117TL")
        UserDefaults.standard.set("chrome", forKey: "youtubeAuthMode")
        UserDefaults.standard.set("none", forKey: "bilibiliAuthMode")
        _ = try await YouTubeClient.probe(bilibiliURL,
                                         auth: YouTubeClient.configuredAuth(for: bilibiliURL))
        let bilibiliPlainArguments = try String(contentsOf: argumentsLog, encoding: .utf8)
        expect(!bilibiliPlainArguments.contains("--cookies-from-browser"),
               "YouTube browser authentication is not reused for Bilibili")
        UserDefaults.standard.set("chrome", forKey: "bilibiliAuthMode")
        _ = try await YouTubeClient.probe(bilibiliURL,
                                         auth: YouTubeClient.configuredAuth(for: bilibiliURL))
        let bilibiliBrowserArguments = try String(contentsOf: argumentsLog, encoding: .utf8)
        expect(bilibiliBrowserArguments.contains("--cookies-from-browser\nchrome\n"),
               "Bilibili browser authentication passed when selected")

        let bilibiliCollectionURL = try YouTubeClient.validatedPlaylistURL(
            "https://space.bilibili.com/2142762/lists/3662502")
        let bilibiliCollection = try await YouTubeClient.probePlaylist(bilibiliCollectionURL, auth: .none)
        expect(bilibiliCollection.entries.count == 2 && bilibiliCollection.totalCount == 3,
               "Bilibili collection parses usable entries")
        expect(bilibiliCollection.entries.map(\.id) == [0, 2], "Bilibili collection retains source positions")
        expect(bilibiliCollection.entries[0].video.artist == "UP 主", "Bilibili uploader parsed")
        expect(bilibiliCollection.entries[1].url.absoluteString ==
               "https://www.bilibili.com/video/BV1bK411W797?p=2", "Bilibili page number retained")
        let bilibiliListArguments = try String(contentsOf: argumentsLog, encoding: .utf8)
        expect(!bilibiliListArguments.contains("--flat-playlist") &&
               bilibiliListArguments.contains("--ignore-errors"), "Bilibili titles requested in full")

        let bilibiliMultipartURL = try YouTubeClient.validatedPlaylistURL(
            "https://www.bilibili.com/video/BV1bK411W797?p=2")
        let bilibiliMultipart = try await YouTubeClient.probePlaylist(bilibiliMultipartURL, auth: .none)
        expect(bilibiliMultipart.entries.map(\.video.title) == ["P1", "P2"],
               "Bilibili multipart pages preview separately")

        if YouTubeClient.ffmpegURL() != nil {
            let destination = directory.appendingPathComponent("audio")
            let output = try await YouTubeClient.download(url, id: UUID(), format: .m4a,
                                                          quality: .best, destination: destination,
                                                          auth: .cookiesFile(sourceCookies.path)) { _ in }
            expect(manager.fileExists(atPath: output.path), "download completed with cookies")
            let downloadArguments = try String(contentsOf: argumentsLog, encoding: .utf8)
            expect(downloadArguments.contains("--cookies\n"), "download passed --cookies")
        }
        print("Auth integration tests passed")
    }

    static func expect(_ condition: Bool, _ message: String) {
        if !condition { fail(message) }
    }

    static func fail(_ message: String) -> Never {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}
