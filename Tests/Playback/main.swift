import Foundation

enum LibraryDisk {
    static var document = LibraryDocument()
    static var defaultAudioDirectory = FileManager.default.temporaryDirectory
    static func load() -> LibraryDocument { document }
    static func save(_ value: LibraryDocument) throws { document = value }
}

@main struct PlaybackIntegration {
    @MainActor static func main() {
        let tracks = ["First", "Second", "Outside"].map { title -> Track in
            return Track(id: UUID(), title: title, artist: "Test", filePath: "/tmp/\(title).wav",
                         sourceURL: "", videoID: title, duration: 4, format: "WAV",
                         addedAt: .now, isFavorite: false)
        }
        let playlistID = UUID()
        LibraryDisk.document = LibraryDocument(tracks: tracks,
            playlists: [Playlist(id: playlistID, name: "Original", trackIDs: [tracks[0].id, tracks[1].id])])
        let store = MusicStore()
        store.volume = 0
        store.setPlaybackContext([tracks[0].id, tracks[1].id], startingAt: tracks[1].id)
        expect(store.dequeueNextTrackID() == nil,
               "playlist playback stops without leaving its context")
        store.repeatAll = true
        expect(store.dequeueNextTrackID() == tracks[0].id, "repeat all wraps inside playlist")

        store.repeatAll = false
        store.setPlaybackContext([tracks[0].id, tracks[1].id], startingAt: tracks[0].id)
        store.addToQueue(tracks[2])
        store.addToQueue(tracks[1])
        store.moveQueue(tracks[1].id, before: tracks[2].id)
        expect(store.queue == [tracks[1].id, tracks[2].id], "manual queue can be reordered")
        store.removeFromQueue(tracks[1].id)
        store.playNext(tracks[2])
        expect(store.dequeueNextTrackID() == tracks[2].id, "play next has priority")
        expect(store.dequeueNextTrackID() == tracks[1].id, "playlist resumes after inserted song")

        store.shuffle = true
        store.setPlaybackContext([tracks[0].id, tracks[1].id], startingAt: tracks[0].id)
        expect(store.dequeueNextTrackID() == tracks[1].id && store.dequeueNextTrackID() == nil,
               "shuffle stays in selected playlist")
        store.currentTrackID = tracks[1].id
        store.elapsed = 1.25
        store.playNext(tracks[2])
        let restored = MusicStore()
        expect(restored.currentTrackID == tracks[1].id && !restored.isPlaying,
               "relaunch restores paused track")
        expect(abs(restored.elapsed - 1.25) < 0.2 && restored.shuffle && restored.volume == 0,
               "relaunch restores progress and playback settings")
        expect(restored.queue == [tracks[2].id], "relaunch restores manual queue")

        restored.moveInPlaylist(tracks[1].id, before: tracks[0].id, playlistID: playlistID)
        restored.renamePlaylist(playlistID, to: "Renamed")
        expect(restored.playlists[0].trackIDs == [tracks[1].id, tracks[0].id]
               && restored.playlists[0].name == "Renamed", "playlist order and name updated")
        restored.addToPlaylist([tracks[2].id], playlistID: playlistID)
        restored.removeFromPlaylist([tracks[0].id], playlistID: playlistID)
        expect(restored.playlists[0].trackIDs == [tracks[1].id, tracks[2].id]
               && restored.tracks.count == 3, "playlist edits preserve library tracks")
        let afterEdit = MusicStore()
        expect(afterEdit.playlists[0].trackIDs == [tracks[1].id, tracks[2].id],
               "playlist edits survive relaunch")
        afterEdit.deletePlaylist(playlistID)
        expect(afterEdit.playlists.isEmpty && afterEdit.tracks.count == 3,
               "deleting playlist preserves tracks")
        print("Playback integration tests passed")
    }

    static func expect(_ condition: Bool, _ message: String) {
        guard condition else { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }
}
