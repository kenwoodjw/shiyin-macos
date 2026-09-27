import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

expect((try? YouTubeClient.validatedURL("https://www.youtube.com/watch?v=abc123")) != nil, "watch URL")
expect((try? YouTubeClient.validatedURL("https://youtu.be/abc123")) != nil, "short URL")
expect((try? YouTubeClient.validatedURL("https://www.youtube.com/shorts/abc123")) != nil, "shorts URL")
expect((try? YouTubeClient.validatedURL("https://www.bilibili.com/video/BV13x41117TL?p=2")) != nil,
       "Bilibili BV part URL")
expect((try? YouTubeClient.validatedURL("https://www.bilibili.com/video/av1074402/")) != nil,
       "Bilibili av URL")
expect((try? YouTubeClient.validatedURL("https://www.bilibili.com/audio/au1003142")) != nil,
       "Bilibili audio URL")
expect((try? YouTubeClient.validatedURL("https://b23.tv/abc123")) != nil,
       "Bilibili short URL")
let bilibiliPart = "https://www.bilibili.com/video/BV1bK411W797?p=2"
expect(YouTubeClient.hasPlaylistID(bilibiliPart) && !YouTubeClient.isDirectPlaylistURL(bilibiliPart),
       "Bilibili video offers full multipart import")
expect((try? YouTubeClient.validatedPlaylistURL(bilibiliPart))?.absoluteString ==
       "https://www.bilibili.com/video/BV1bK411W797", "Bilibili multipart URL strips part selector")
let bilibiliCollection = "https://space.bilibili.com/2142762/lists/3662502"
expect(YouTubeClient.isDirectPlaylistURL(bilibiliCollection), "Bilibili collection detected")
expect((try? YouTubeClient.validatedPlaylistURL(bilibiliCollection))?.absoluteString == bilibiliCollection,
       "Bilibili collection accepted")
expect(YouTubeClient.isDirectPlaylistURL("https://space.bilibili.com/84912/favlist?fid=1103407912"),
       "Bilibili favorites detected")
expect(YouTubeClient.isDirectPlaylistURL("https://www.bilibili.com/audio/am10624"),
       "Bilibili audio album detected")
let playlistURL = "https://www.youtube.com/playlist?list=PL123"
expect(YouTubeClient.isDirectPlaylistURL(playlistURL), "direct playlist detected")
expect((try? YouTubeClient.validatedPlaylistURL(playlistURL))?.absoluteString == playlistURL, "playlist URL accepted")
let watchInPlaylist = "https://www.youtube.com/watch?v=abc123&list=PL123"
expect(YouTubeClient.hasPlaylistID(watchInPlaylist), "watch URL has playlist")
expect((try? YouTubeClient.validatedPlaylistURL(watchInPlaylist))?.absoluteString == playlistURL, "watch URL canonicalized to playlist")
expect((try? YouTubeClient.validatedURL(watchInPlaylist)) != nil, "watch URL still supports single video")
let mixWatchURL = "https://www.youtube.com/watch?v=mQReG_mBpqc&list=RDmQReG_mBpqc"
expect((try? YouTubeClient.validatedPlaylistURL(mixWatchURL))?.absoluteString == mixWatchURL,
       "Mix watch URL keeps its seed video")
expect((try? YouTubeClient.validatedPlaylistURL("https://www.youtube.com/playlist?list=RDmQReG_mBpqc"))?.absoluteString == mixWatchURL,
       "Mix playlist URL derives its seed video")
expect((try? YouTubeClient.validatedPlaylistURL("https://www.youtube.com/playlist?list=RDMMmQReG_mBpqc"))?.absoluteString ==
       "https://www.youtube.com/watch?v=mQReG_mBpqc&list=RDMMmQReG_mBpqc",
       "RDMM Mix playlist URL derives its seed video")
expect((try? YouTubeClient.validatedPlaylistURL("https://www.youtube.com/watch?v=otherSeed12&list=RDmQReG_mBpqc"))?.absoluteString ==
       "https://www.youtube.com/watch?v=otherSeed12&list=RDmQReG_mBpqc",
       "Mix watch URL keeps the actual video rather than guessing from the list ID")
expect((try? YouTubeClient.validatedPlaylistURL("https://youtube.com.evil.example/playlist?list=PL123")) == nil, "reject foreign playlist host")
for text in ["https://youtube.com.evil.example/watch?v=x", "https://www.youtube.com/playlist?list=x",
             "https://bilibili.com.evil.example/video/BV13x41117TL",
             "https://www.bilibili.com/video/not-a-video", "not-a-url", "file:///tmp/a"] {
    expect((try? YouTubeClient.validatedURL(text)) == nil, "reject \(text)")
}
let log = "[download]  12.2% of 10.00MiB\n[download]  89.4% of 10.00MiB\n"
expect(abs(YouTubeClient.progress(in: log) - 0.894) < 0.0001, "latest progress")
let toolsFixture = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: toolsFixture, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: toolsFixture) }
let bundledTool = toolsFixture.appendingPathComponent("yt-dlp")
let customTool = toolsFixture.appendingPathComponent("custom-yt-dlp")
for tool in [bundledTool, customTool] {
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: tool)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tool.path)
}
expect(YouTubeClient.executable(named: "yt-dlp", bundledDirectory: toolsFixture) == bundledTool,
       "bundled tool takes precedence over system locations")
expect(YouTubeClient.executable(named: "yt-dlp", override: customTool.path, bundledDirectory: toolsFixture) == customTool,
       "explicit custom path takes precedence over bundled tool")
let oldLibrary = #"{"tracks":[{"id":"00000000-0000-0000-0000-000000000001","title":"Old","artist":"Artist","filePath":"/tmp/old.m4a","sourceURL":"https://www.youtube.com/watch?v=old","videoID":"old","duration":60,"format":"M4A","addedAt":0,"isFavorite":false}],"playlists":[]}"#
let restoredLibrary = try JSONDecoder().decode(LibraryDocument.self, from: Data(oldLibrary.utf8))
expect(restoredLibrary.tracks.count == 1 && restoredLibrary.downloads.isEmpty,
       "existing library without download records still loads")
expect(restoredLibrary.tracks[0].downloadID == nil, "existing track without download metadata still loads")
print("Smoke tests passed")
