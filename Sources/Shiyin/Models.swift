import Foundation

struct Track: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var artist: String
    var filePath: String
    var sourceURL: String
    var videoID: String
    var duration: TimeInterval
    var format: String
    var addedAt: Date
    var isFavorite: Bool
    var downloadID: UUID? = nil
    var sourcePlaylistID: UUID? = nil
    var playlistPosition: Int? = nil

    var fileName: String { URL(fileURLWithPath: filePath).lastPathComponent }
}

struct Playlist: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var trackIDs: [UUID]
}

struct LibraryDocument: Codable {
    var tracks: [Track] = []
    var playlists: [Playlist] = []
    var downloads: [SavedDownload] = []
    var playback: PlaybackSnapshot = PlaybackSnapshot()

    init(tracks: [Track] = [], playlists: [Playlist] = [], downloads: [SavedDownload] = [],
         playback: PlaybackSnapshot = PlaybackSnapshot()) {
        self.tracks = tracks
        self.playlists = playlists
        self.downloads = downloads
        self.playback = playback
    }

    private enum CodingKeys: String, CodingKey { case tracks, playlists, downloads, playback }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        tracks = try values.decodeIfPresent([Track].self, forKey: .tracks) ?? []
        playlists = try values.decodeIfPresent([Playlist].self, forKey: .playlists) ?? []
        downloads = try values.decodeIfPresent([SavedDownload].self, forKey: .downloads) ?? []
        playback = try values.decodeIfPresent(PlaybackSnapshot.self, forKey: .playback) ?? PlaybackSnapshot()
    }
}

struct PlaybackSnapshot: Codable {
    var currentTrackID: UUID? = nil
    var elapsed: TimeInterval = 0
    var volume: Double = 0.68
    var queue: [UUID] = []
    var contextIDs: [UUID] = []
    var contextIndex: Int = -1
    var playedContextIDs: [UUID] = []
    var history: [UUID] = []
    var shuffleOrder: [UUID] = []
    var shuffle = false
    var repeatOne = false
    var repeatAll = false
}

struct SavedDownload: Codable {
    let id: UUID
    let url: URL
    let info: VideoInfo
    let format: AudioFormat
    let quality: AudioQuality
    let destination: URL
    let playlistID: UUID?
    let playlistPosition: Int?
    let failureMessage: String?
}

struct VideoInfo: Codable {
    let id: String
    let title: String
    let uploader: String?
    let channel: String?
    let duration: Double?

    var artist: String { uploader ?? channel ?? "未知艺术家" }
}

struct PlaylistEntry: Identifiable {
    let id: Int
    let url: URL
    let video: VideoInfo
}

struct PlaylistInfo {
    let title: String
    let entries: [PlaylistEntry]
    let totalCount: Int
}

enum AudioFormat: String, CaseIterable, Identifiable, Codable {
    case m4a = "M4A"
    case mp3 = "MP3"
    var id: String { rawValue }
    var argument: String { rawValue.lowercased() }
}

enum AudioQuality: String, CaseIterable, Identifiable, Codable {
    case best = "最高可用"
    case standard = "标准音质"
    var id: String { rawValue }
    var argument: String { self == .best ? "0" : "5" }
}

enum DownloadState: Equatable {
    case waiting, downloading, finished, failed(String), cancelled
}

struct DownloadItem: Identifiable {
    let id: UUID
    let url: URL
    var title: String
    var progress: Double
    var state: DownloadState
}

enum LibrarySection: Hashable {
    case home, all, downloads, favorites, playlist(UUID)
}

func timeLabel(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let value = Int(seconds)
    return String(format: "%d:%02d", value / 60, value % 60)
}
