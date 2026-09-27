import Foundation

enum LibraryDisk {
    static var document = LibraryDocument()
    static var defaultAudioDirectory = FileManager.default.temporaryDirectory
    static func load() -> LibraryDocument { document }
    static func save(_ value: LibraryDocument) throws { document = value }
}

@main struct PlaylistQueueIntegration {
    @MainActor static func main() async throws {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent("shiyin-queue-test-\(UUID().uuidString)")
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: directory) }
        LibraryDisk.defaultAudioDirectory = directory

        let fakeTool = directory.appendingPathComponent("fake-yt-dlp")
        try #"""
#!/bin/sh
output=
browser=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --output) output="$2"; shift 2 ;;
    --cookies-from-browser) browser="$2"; shift 2 ;;
    *) shift ;;
  esac
done
if [ "${SHIYIN_TEST_REQUIRE_CHROME:-0}" = 1 ] && [ "$browser" != chrome ]; then
  printf 'ERROR: [youtube] test: Sign in to confirm you’re not a bot. Use --cookies-from-browser or --cookies for the authentication.\n' >&2
  exit 1
fi
if [ "${SHIYIN_TEST_FAIL:-0}" = 1 ]; then
  printf 'ERROR: simulated download failure\n' >&2
  exit 1
fi
sleep 0.2
filepath=$(printf '%s' "$output" | sed 's/%(ext)s/m4a/')
: > "$filepath"
"""#.write(to: fakeTool, atomically: true, encoding: .utf8)
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeTool.path)

        let previousTool = UserDefaults.standard.string(forKey: "ytDLPPath")
        let previousDirectory = UserDefaults.standard.string(forKey: "audioDirectory")
        let previousAuthMode = UserDefaults.standard.string(forKey: "youtubeAuthMode")
        UserDefaults.standard.set(fakeTool.path, forKey: "ytDLPPath")
        UserDefaults.standard.set(directory.path, forKey: "audioDirectory")
        UserDefaults.standard.set("none", forKey: "youtubeAuthMode")
        defer {
            restore(previousTool, key: "ytDLPPath")
            restore(previousDirectory, key: "audioDirectory")
            restore(previousAuthMode, key: "youtubeAuthMode")
        }

        guard YouTubeClient.ffmpegURL() != nil else {
            print("Playlist queue test skipped: ffmpeg unavailable")
            return
        }

        let store = MusicStore()
        let entries = ["First", "Second", "Third"].enumerated().map { index, title in
            let videoID = "test\(index)"
            return PlaylistEntry(id: index,
                                 url: URL(string: "https://www.youtube.com/watch?v=\(videoID)")!,
                                 video: VideoInfo(id: videoID, title: title, uploader: "Tester",
                                                  channel: nil, duration: 60))
        }
        store.addPlaylistDownloads(entries, title: "Test Playlist", format: .m4a,
                                   quality: .best)
        expect(store.downloads.count == 3, "all playlist items queued")
        await waitForDownloads(store)
        expect(store.downloads.allSatisfy { $0.state == .finished }, "all items finished")
        expect(store.playlists.count == 1, "one local playlist created")
        let orderedTitles = store.playlists[0].trackIDs.compactMap { id in
            store.tracks.first(where: { $0.id == id })?.title
        }
        expect(orderedTitles == ["First", "Second", "Third"], "local playlist kept source order")

        store.addPlaylistDownloads(entries, title: "Cancellation Test", format: .m4a,
                                   quality: .best)
        guard let second = store.downloads.first(where: { $0.title == "Second" && $0.state == .waiting }) else {
            fail("second batch item was waiting")
        }
        store.cancelDownload(second.id)
        await waitForDownloads(store)
        let cancellationTitles = store.playlists[1].trackIDs.compactMap { id in
            store.tracks.first(where: { $0.id == id })?.title
        }
        expect(cancellationTitles == ["First", "Third"], "cancelled item omitted from playlist")

        store.addPlaylistDownloads([entries[0], entries[2]], title: "Selected Items", format: .m4a,
                                   quality: .best)
        expect(store.downloads.filter { $0.state == .waiting || $0.state == .downloading }.count == 2,
               "only selected playlist items queued")
        await waitForDownloads(store)
        let selectedTitles = store.playlists[2].trackIDs.compactMap { id in
            store.tracks.first(where: { $0.id == id })?.title
        }
        expect(selectedTitles == ["First", "Third"], "selected items kept their playlist order")

        let restoredPlaylistID = UUID()
        let middleTrack = Track(id: UUID(), title: "Second", artist: "Tester",
                                filePath: directory.appendingPathComponent("middle.m4a").path,
                                sourceURL: entries[1].url.absoluteString, videoID: "test1",
                                duration: 60, format: "M4A", addedAt: .now, isFavorite: false,
                                sourcePlaylistID: restoredPlaylistID, playlistPosition: 1)
        let restoredJobs = [entries[0], entries[2]].map { entry in
            SavedDownload(id: UUID(), url: entry.url, info: entry.video, format: .m4a,
                          quality: .best, destination: directory, playlistID: restoredPlaylistID,
                          playlistPosition: entry.id, failureMessage: nil)
        }
        LibraryDisk.document = LibraryDocument(tracks: [middleTrack],
                                               playlists: [Playlist(id: restoredPlaylistID, name: "Resumed",
                                                                    trackIDs: [middleTrack.id])],
                                               downloads: restoredJobs)
        let restoredStore = MusicStore()
        expect(restoredStore.downloads.count == 2, "pending downloads restored on launch")
        await waitForDownloads(restoredStore)
        expect(restoredStore.downloads.allSatisfy { $0.state == .finished }, "restored downloads completed")
        let resumedTitles = restoredStore.playlists[0].trackIDs.compactMap { id in
            restoredStore.tracks.first(where: { $0.id == id })?.title
        }
        expect(resumedTitles == ["First", "Second", "Third"], "restored playlist kept original order")
        expect(LibraryDisk.document.downloads.isEmpty, "finished jobs removed from saved queue")
        let firstImportedID = restoredStore.playlists[0].trackIDs[0]
        restoredStore.removeFromPlaylist([firstImportedID], playlistID: restoredPlaylistID)
        let playlistAfterRemoval = MusicStore()
        expect(!playlistAfterRemoval.playlists[0].trackIDs.contains(firstImportedID),
               "removed imported track does not return to playlist after relaunch")

        let failedJob = SavedDownload(id: UUID(), url: entries[0].url, info: entries[0].video,
                                      format: .m4a, quality: .best, destination: directory,
                                      playlistID: nil, playlistPosition: nil, failureMessage: nil)
        LibraryDisk.document = LibraryDocument(downloads: [failedJob])
        setenv("SHIYIN_TEST_FAIL", "1", 1)
        let retryStore = MusicStore()
        await waitForDownloads(retryStore)
        expect(retryStore.downloads.first?.state == .failed("ERROR: simulated download failure"),
               "failed download retained for retry")
        expect(LibraryDisk.document.downloads.first?.failureMessage != nil, "failure saved across restarts")
        unsetenv("SHIYIN_TEST_FAIL")
        let relaunchedStore = MusicStore()
        expect(relaunchedStore.downloads.first?.state == .failed("ERROR: simulated download failure"),
               "failed state restored after relaunch")
        relaunchedStore.retryDownload(failedJob.id)
        await waitForDownloads(relaunchedStore)
        expect(relaunchedStore.downloads.first?.state == .finished && relaunchedStore.tracks.count == 1,
               "retry after relaunch completed without duplicating tracks")

        LibraryDisk.document = LibraryDocument()
        let changedAuthStore = MusicStore()
        setenv("SHIYIN_TEST_REQUIRE_CHROME", "1", 1)
        changedAuthStore.addDownload(url: entries[0].url, info: entries[0].video,
                                     format: .m4a, quality: .best)
        UserDefaults.standard.set("chrome", forKey: "youtubeAuthMode")
        await waitForDownloads(changedAuthStore)
        expect(changedAuthStore.downloads.first?.state == .finished,
               "queued download uses current browser authentication")
        unsetenv("SHIYIN_TEST_REQUIRE_CHROME")

        let downloaded = relaunchedStore.tracks[0]
        let shared = Track(id: UUID(), title: "Shared", artist: "Tester", filePath: downloaded.filePath,
                           sourceURL: downloaded.sourceURL, videoID: downloaded.videoID,
                           duration: downloaded.duration, format: downloaded.format,
                           addedAt: .now, isFavorite: false)
        relaunchedStore.tracks.append(shared)
        relaunchedStore.removeIncludingFile(downloaded) { _ in fail("shared audio must not be trashed") }
        expect(relaunchedStore.tracks.count == 2 && manager.fileExists(atPath: downloaded.filePath),
               "shared audio stays in library and on disk")
        relaunchedStore.remove(shared)

        relaunchedStore.removeIncludingFile(downloaded) { _ in
            throw NSError(domain: "ShiyinDeleteTest", code: 1)
        }
        expect(relaunchedStore.tracks.count == 1 && manager.fileExists(atPath: downloaded.filePath),
               "failed trash operation keeps the track and file")
        relaunchedStore.removeIncludingFile(downloaded) { url in try manager.removeItem(at: url) }
        expect(relaunchedStore.tracks.isEmpty && !manager.fileExists(atPath: downloaded.filePath),
               "successful file removal also removes the library track")
        print("Playlist queue integration tests passed")
    }

    @MainActor static func waitForDownloads(_ store: MusicStore) async {
        for _ in 0..<80 {
            if !store.downloads.contains(where: { $0.state == .waiting || $0.state == .downloading }) { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        fail("download queue did not finish")
    }

    static func restore(_ value: String?, key: String) {
        if let value { UserDefaults.standard.set(value, forKey: key) }
        else { UserDefaults.standard.removeObject(forKey: key) }
    }

    static func expect(_ condition: Bool, _ message: String) {
        if !condition { fail(message) }
    }

    static func fail(_ message: String) -> Never {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}
