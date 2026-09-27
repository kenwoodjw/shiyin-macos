import AppKit
import AVFoundation
import Foundation
import Observation

private struct PendingDownload {
    let id: UUID
    let url: URL
    let info: VideoInfo
    let format: AudioFormat
    let quality: AudioQuality
    let destination: URL
    let playlistID: UUID?
    let playlistPosition: Int?
}

@MainActor @Observable final class MusicStore {
    var tracks: [Track] { didSet { persist() } }
    var playlists: [Playlist] { didSet { persist() } }
    var downloads: [DownloadItem] = []
    var currentTrackID: UUID?
    var queue: [UUID] = [] { didSet { persist() } }
    var contextIDs: [UUID] = []
    var contextIndex = -1
    var playedContextIDs: Set<UUID> = []
    var history: [UUID] = []
    var shuffleOrder: [UUID] = []
    var isPlaying = false
    var elapsed: TimeInterval = 0
    var volume: Double = 0.68 { didSet { player?.volume = Float(volume); persist() } }
    var shuffle = false { didSet { if shuffle { rebuildShuffleOrder() }; persist() } }
    var repeatOne = false { didSet { persist() } }
    var repeatAll = false { didSet { persist() } }
    var isImportPresented = false
    var isSettingsPresented = false
    var statusMessage: String?
    var audioDirectory: URL {
        didSet { UserDefaults.standard.set(audioDirectory.path, forKey: "audioDirectory") }
    }

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var jobs: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var pendingDownloads: [PendingDownload] = []
    @ObservationIgnored private var downloadWork: [UUID: PendingDownload] = [:]
    @ObservationIgnored private var activeDownloadID: UUID? = nil
    @ObservationIgnored private var systemPlayback: SystemPlaybackController?

    init() {
        let document = LibraryDisk.load()
        tracks = document.tracks
        playlists = document.playlists
        let validIDs = Set(document.tracks.map(\.id))
        let playback = document.playback
        currentTrackID = playback.currentTrackID.flatMap { validIDs.contains($0) ? $0 : nil }
        elapsed = max(0, playback.elapsed)
        volume = min(max(0, playback.volume), 1)
        queue = playback.queue.filter { validIDs.contains($0) }
        let restoredContextIDs = playback.contextIDs.filter { validIDs.contains($0) }
        contextIDs = restoredContextIDs
        contextIndex = max(-1, min(playback.contextIndex, restoredContextIDs.count - 1))
        playedContextIDs = Set(playback.playedContextIDs.filter { validIDs.contains($0) })
        history = playback.history.filter { validIDs.contains($0) }
        shuffleOrder = playback.shuffleOrder.filter { validIDs.contains($0) }
        shuffle = playback.shuffle
        repeatOne = playback.repeatOne
        repeatAll = playback.repeatAll
        downloads = document.downloads.compactMap { saved in
            guard !document.tracks.contains(where: { $0.downloadID == saved.id }) else { return nil }
            return DownloadItem(id: saved.id, url: saved.url, title: saved.info.title, progress: 0,
                                state: saved.failureMessage.map(DownloadState.failed) ?? .waiting)
        }
        if let path = UserDefaults.standard.string(forKey: "audioDirectory") {
            audioDirectory = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            audioDirectory = LibraryDisk.defaultAudioDirectory
        }
        for saved in document.downloads where downloads.contains(where: { $0.id == saved.id }) {
            let work = PendingDownload(id: saved.id, url: saved.url, info: saved.info,
                                       format: saved.format, quality: saved.quality,
                                       destination: saved.destination,
                                       playlistID: saved.playlistID, playlistPosition: saved.playlistPosition)
            downloadWork[work.id] = work
            if saved.failureMessage == nil { pendingDownloads.append(work) }
        }
        for playlistID in Set(tracks.compactMap(\.sourcePlaylistID)) { reconcilePlaylist(playlistID) }
        runNextDownload()
    }

    var currentTrack: Track? { tracks.first(where: { $0.id == currentTrackID }) }
    var upcomingTracks: [Track] { queue.compactMap { id in tracks.first(where: { $0.id == id }) } }
    var automaticUpcomingTracks: [Track] {
        let ids = shuffle ? shuffleOrder : Array(contextIDs.dropFirst(max(0, contextIndex + 1)))
            .filter { !playedContextIDs.contains($0) }
        return ids.filter { !queue.contains($0) }.compactMap { id in tracks.first(where: { $0.id == id }) }
    }
    var totalDuration: TimeInterval { player?.duration ?? currentTrack?.duration ?? 0 }

    func enableSystemPlayback() {
        systemPlayback = .shared
        systemPlayback?.connect(self)
    }

    func fileURL(for track: Track) -> URL { URL(fileURLWithPath: track.filePath) }

    func addDownload(url: URL, info: VideoInfo, format: AudioFormat, quality: AudioQuality) {
        let work = PendingDownload(id: UUID(), url: url, info: info, format: format,
                                   quality: quality, destination: audioDirectory,
                                   playlistID: nil, playlistPosition: nil)
        downloads.insert(DownloadItem(id: work.id, url: url, title: info.title, progress: 0, state: .waiting), at: 0)
        downloadWork[work.id] = work
        pendingDownloads.append(work)
        persist()
        runNextDownload()
    }

    func addPlaylistDownloads(_ entries: [PlaylistEntry], title: String,
                              format: AudioFormat, quality: AudioQuality) {
        guard !entries.isEmpty else { return }
        let playlistID = UUID()
        playlists.append(Playlist(id: playlistID, name: title, trackIDs: []))
        let work = entries.map { entry in
            PendingDownload(id: UUID(), url: entry.url, info: entry.video, format: format,
                            quality: quality, destination: audioDirectory,
                            playlistID: playlistID, playlistPosition: entry.id)
        }
        downloads.insert(contentsOf: work.map {
            DownloadItem(id: $0.id, url: $0.url, title: $0.info.title, progress: 0, state: .waiting)
        }, at: 0)
        for item in work { downloadWork[item.id] = item }
        pendingDownloads.append(contentsOf: work)
        persist()
        runNextDownload()
    }

    func cancelDownload(_ id: UUID) {
        if let index = pendingDownloads.firstIndex(where: { $0.id == id }) {
            pendingDownloads.remove(at: index)
            downloadWork[id] = nil
            updateDownload(id) { $0.state = .cancelled }
        } else {
            jobs[id]?.cancel()
        }
    }

    func retryDownload(_ id: UUID) {
        guard let work = downloadWork[id],
              let item = downloads.first(where: { $0.id == id }),
              case .failed = item.state else { return }
        pendingDownloads.append(work)
        updateDownload(id) { $0.state = .waiting; $0.progress = 0 }
        runNextDownload()
    }

    private func runNextDownload() {
        guard jobs.isEmpty, !pendingDownloads.isEmpty else { return }
        let work = pendingDownloads.removeFirst()
        activeDownloadID = work.id
        jobs[work.id] = Task { [weak self] in
            guard let self else { return }
            await performDownload(work)
            jobs[work.id] = nil
            activeDownloadID = nil
            runNextDownload()
        }
    }

    private func performDownload(_ work: PendingDownload) async {
        updateDownload(work.id) { $0.state = .downloading }
        do {
            let file = try await YouTubeClient.download(work.url, id: work.id, format: work.format,
                                                        quality: work.quality, destination: work.destination,
                                                        auth: YouTubeClient.configuredAuth(for: work.url)) { [weak self] progress in
                self?.updateDownload(work.id) { $0.progress = progress }
            }
            let duration = (try? AVAudioPlayer(contentsOf: file).duration) ?? work.info.duration ?? 0
            let track = Track(id: UUID(), title: work.info.title, artist: work.info.artist,
                              filePath: file.path, sourceURL: work.url.absoluteString,
                              videoID: work.info.id, duration: duration, format: work.format.rawValue,
                              addedAt: .now, isFavorite: false, downloadID: work.id,
                              sourcePlaylistID: work.playlistID, playlistPosition: work.playlistPosition)
            tracks.insert(track, at: 0)
            if let playlistID = work.playlistID { reconcilePlaylist(playlistID) }
            updateDownload(work.id) { $0.state = .finished; $0.progress = 1 }
            downloadWork[work.id] = nil
            if work.playlistID == nil {
                statusMessage = "已加入资料库：\(track.title)"
            }
        } catch {
            removePartialDownload(id: work.id, from: work.destination)
            if case YouTubeError.cancelled = error {
                downloadWork[work.id] = nil
                updateDownload(work.id) { $0.state = .cancelled }
            } else {
                updateDownload(work.id) { $0.state = .failed(error.localizedDescription) }
            }
        }
    }

    private func reconcilePlaylist(_ playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        let imported = tracks.filter { $0.sourcePlaylistID == playlistID }
            .sorted { ($0.playlistPosition ?? .max) < ($1.playlistPosition ?? .max) }
        var orderedIDs = playlists[index].trackIDs
        for track in imported where !orderedIDs.contains(track.id) {
            let insertion = orderedIDs.firstIndex { existingID in
                guard let existing = tracks.first(where: { $0.id == existingID }),
                      existing.sourcePlaylistID == playlistID else { return false }
                return (existing.playlistPosition ?? .max) > (track.playlistPosition ?? .max)
            } ?? orderedIDs.count
            orderedIDs.insert(track.id, at: insertion)
        }
        if playlists[index].trackIDs != orderedIDs { playlists[index].trackIDs = orderedIDs }
    }

    private func updateDownload(_ id: UUID, _ update: (inout DownloadItem) -> Void) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        let previousState = downloads[index].state
        update(&downloads[index])
        if downloads[index].state != previousState { persist() }
    }

    private func removePartialDownload(id: UUID, from directory: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files where file.lastPathComponent.hasPrefix(id.uuidString + ".") {
            try? FileManager.default.removeItem(at: file)
        }
    }

    func play(_ track: Track, in context: [Track]? = nil) {
        guard FileManager.default.fileExists(atPath: track.filePath) else {
            statusMessage = "找不到音频文件：\(track.fileName)"
            return
        }
        let source = context ?? tracks
        setPlaybackContext(source.map(\.id), startingAt: track.id)
        startPlayback(track, at: 0, rememberPrevious: false)
    }

    func setPlaybackContext(_ ids: [UUID], startingAt id: UUID) {
        contextIDs = ids.filter { candidate in tracks.contains(where: { $0.id == candidate }) }
        contextIndex = contextIDs.firstIndex(of: id) ?? -1
        playedContextIDs = Set(contextIDs.prefix(max(0, contextIndex + 1)))
        history = []
        queue = []
        rebuildShuffleOrder()
        persist()
    }

    func playUpcoming(_ track: Track) {
        guard FileManager.default.fileExists(atPath: track.filePath) else {
            statusMessage = "找不到音频文件：\(track.fileName)"
            return
        }
        if let index = queue.firstIndex(of: track.id) {
            queue.removeFirst(index + 1)
            playedContextIDs.insert(track.id)
        } else if let index = contextIDs.firstIndex(of: track.id) {
            contextIndex = index
            playedContextIDs.formUnion(contextIDs.prefix(index + 1))
            shuffleOrder.removeAll(where: { $0 == track.id })
        }
        startPlayback(track)
    }

    @discardableResult private func startPlayback(_ track: Track, at position: TimeInterval = 0,
                                                   rememberPrevious: Bool = true) -> Bool {
        let url = fileURL(for: track)
        guard FileManager.default.fileExists(atPath: url.path) else {
            statusMessage = "找不到音频文件：\(track.fileName)"
            return false
        }
        do {
            player?.stop()
            ticker?.invalidate()
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.volume = Float(volume)
            newPlayer.prepareToPlay()
            newPlayer.currentTime = min(max(0, position), max(0, newPlayer.duration - 0.1))
            guard newPlayer.play() else { throw YouTubeError.failed("无法播放这首曲目。") }
            if rememberPrevious, let previous = currentTrackID, previous != track.id {
                history.append(previous)
            }
            player = newPlayer
            currentTrackID = track.id
            isPlaying = true
            elapsed = newPlayer.currentTime
            ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.tick() }
            }
            systemPlayback?.refresh()
            persist()
            return true
        } catch {
            player = nil
            isPlaying = false
            statusMessage = error.localizedDescription
            systemPlayback?.refresh()
            return false
        }
    }

    func togglePlay() {
        guard let player else {
            if let track = currentTrack { startPlayback(track, at: elapsed, rememberPrevious: false) }
            else if let track = tracks.first { play(track) }
            return
        }
        if isPlaying { player.pause(); isPlaying = false }
        else { player.play(); isPlaying = true }
        systemPlayback?.refresh()
        persist()
    }

    func resume() { if !isPlaying { togglePlay() } }

    func pause() { if isPlaying { togglePlay() } }

    func seek(to value: TimeInterval) {
        guard let player else { return }
        player.currentTime = min(max(0, value), player.duration)
        elapsed = player.currentTime
        systemPlayback?.refresh()
        persist()
    }

    func next() {
        if repeatOne, let player {
            player.currentTime = 0
            player.play()
            elapsed = 0
            isPlaying = true
            systemPlayback?.refresh()
            persist()
            return
        }
        for _ in 0..<(tracks.count + queue.count + 1) {
            guard let id = dequeueNextTrackID() else { break }
            guard let track = tracks.first(where: { $0.id == id }) else { continue }
            guard FileManager.default.fileExists(atPath: track.filePath) else {
                statusMessage = "找不到音频文件：\(track.fileName)"
                continue
            }
            if startPlayback(track) { return }
        }
        player?.stop(); player = nil; ticker?.invalidate(); isPlaying = false; elapsed = 0
        systemPlayback?.refresh()
        persist()
    }

    func dequeueNextTrackID() -> UUID? {
        if !queue.isEmpty {
            let id = queue.removeFirst()
            playedContextIDs.insert(id)
            shuffleOrder.removeAll(where: { $0 == id })
            persist()
            return id
        }
        if shuffle && shuffleOrder.isEmpty && repeatAll {
            playedContextIDs.removeAll()
            if let currentTrackID { playedContextIDs.insert(currentTrackID) }
            rebuildShuffleOrder()
            if shuffleOrder.isEmpty {
                playedContextIDs.removeAll()
                rebuildShuffleOrder()
            }
        }
        let nextID: UUID?
        if shuffle { nextID = shuffleOrder.first }
        else {
            nextID = contextIDs.dropFirst(max(0, contextIndex + 1))
                .first(where: { !playedContextIDs.contains($0) })
                ?? (repeatAll ? contextIDs.first : nil)
        }
        guard let id = nextID else { return nil }
        if repeatAll && !shuffle && contextIDs.first == id { playedContextIDs.removeAll() }
        if let index = contextIDs.firstIndex(of: id) { contextIndex = index }
        playedContextIDs.insert(id)
        shuffleOrder.removeAll(where: { $0 == id })
        persist()
        return id
    }

    func previous() {
        if elapsed > 3 { seek(to: 0); return }
        guard let id = history.popLast(), let track = tracks.first(where: { $0.id == id }) else {
            seek(to: 0); return
        }
        if let currentTrackID { queue.insert(currentTrackID, at: 0) }
        if let index = contextIDs.firstIndex(of: id) { contextIndex = index }
        startPlayback(track, rememberPrevious: false)
    }

    func addToQueue(_ track: Track) {
        guard !queue.contains(track.id) else {
            statusMessage = "这首歌已在播放队列中"
            return
        }
        queue.append(track.id)
        statusMessage = "已加入播放队列"
    }

    func playNext(_ track: Track) {
        queue.removeAll(where: { $0 == track.id })
        queue.insert(track.id, at: 0)
    }

    func moveQueue(_ id: UUID, before target: UUID) {
        guard id != target, let from = queue.firstIndex(of: id),
              let destination = queue.firstIndex(of: target) else { return }
        queue.remove(at: from)
        queue.insert(id, at: from < destination ? destination - 1 : destination)
    }

    func removeFromQueue(_ id: UUID) { queue.removeAll(where: { $0 == id }) }

    func clearQueue() { queue.removeAll() }

    func cycleRepeat() {
        if repeatOne { repeatOne = false; repeatAll = false }
        else if repeatAll { repeatOne = true; repeatAll = false }
        else { repeatAll = true }
    }

    private func rebuildShuffleOrder() {
        shuffleOrder = contextIDs.filter { !playedContextIDs.contains($0) }.shuffled()
    }

    func toggleFavorite(_ id: UUID) {
        guard let index = tracks.firstIndex(where: { $0.id == id }) else { return }
        tracks[index].isFavorite.toggle()
    }

    func createPlaylist(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        playlists.append(Playlist(id: UUID(), name: trimmed, trackIDs: []))
    }

    func renamePlaylist(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[index].name = trimmed
    }

    func deletePlaylist(_ id: UUID) {
        playlists.removeAll(where: { $0.id == id })
        for index in tracks.indices where tracks[index].sourcePlaylistID == id {
            tracks[index].sourcePlaylistID = nil
            tracks[index].playlistPosition = nil
        }
    }

    func moveInPlaylist(_ trackID: UUID, before targetID: UUID, playlistID: UUID) {
        guard trackID != targetID, let index = playlists.firstIndex(where: { $0.id == playlistID }),
              let from = playlists[index].trackIDs.firstIndex(of: trackID),
              let destination = playlists[index].trackIDs.firstIndex(of: targetID) else { return }
        playlists[index].trackIDs.remove(at: from)
        playlists[index].trackIDs.insert(trackID, at: from < destination ? destination - 1 : destination)
    }

    func removeFromPlaylist(_ ids: Set<UUID>, playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[index].trackIDs.removeAll(where: { ids.contains($0) })
        for trackIndex in tracks.indices where ids.contains(tracks[trackIndex].id)
            && tracks[trackIndex].sourcePlaylistID == playlistID {
            tracks[trackIndex].sourcePlaylistID = nil
            tracks[trackIndex].playlistPosition = nil
        }
    }

    func addToPlaylist(_ ids: Set<UUID>, playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        for track in tracks where ids.contains(track.id) && !playlists[index].trackIDs.contains(track.id) {
            playlists[index].trackIDs.append(track.id)
        }
    }

    func add(_ track: Track, to playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        if !playlists[index].trackIDs.contains(track.id) { playlists[index].trackIDs.append(track.id) }
    }

    func remove(_ track: Track) {
        guard tracks.contains(where: { $0.id == track.id }) else { return }
        if currentTrackID == track.id {
            player?.stop(); player = nil; currentTrackID = nil; isPlaying = false; elapsed = 0
            systemPlayback?.refresh()
        }
        queue.removeAll(where: { $0 == track.id })
        if let removedIndex = contextIDs.firstIndex(of: track.id), removedIndex <= contextIndex {
            contextIndex -= 1
        }
        contextIDs.removeAll(where: { $0 == track.id })
        contextIndex = max(-1, min(contextIndex, contextIDs.count - 1))
        playedContextIDs.remove(track.id)
        history.removeAll(where: { $0 == track.id })
        shuffleOrder.removeAll(where: { $0 == track.id })
        for index in playlists.indices { playlists[index].trackIDs.removeAll(where: { $0 == track.id }) }
        tracks.removeAll(where: { $0.id == track.id })
    }

    func removeIncludingFile(_ track: Track,
                             trash: (URL) throws -> Void = { url in
                                 _ = try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                             }) {
        guard tracks.contains(where: { $0.id == track.id }) else { return }
        let file = fileURL(for: track)
        let path = file.standardizedFileURL.path
        guard !tracks.contains(where: { $0.id != track.id && fileURL(for: $0).standardizedFileURL.path == path }) else {
            statusMessage = "其他曲目仍在使用这个音频文件，请先移除它们。"
            return
        }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
            guard !isDirectory.boolValue else {
                statusMessage = "曲目路径指向文件夹，无法移到废纸篓。"
                return
            }
            do { try trash(file) }
            catch {
                statusMessage = "无法将音频移到废纸篓：\(error.localizedDescription)"
                return
            }
        }
        remove(track)
    }

    private func tick() {
        guard let player else { return }
        let previousSecond = Int(elapsed)
        elapsed = player.currentTime
        if Int(elapsed) != previousSecond { systemPlayback?.refresh() }
        if Int(elapsed) / 5 != previousSecond / 5 { persist() }
        if isPlaying && !player.isPlaying && player.currentTime >= player.duration - 0.5 { next() }
    }

    private func persist() {
        let orderedIDs = [activeDownloadID].compactMap { $0 } + pendingDownloads.map(\.id) + downloads.map(\.id)
        var seen = Set<UUID>()
        let saved = orderedIDs.compactMap { id -> SavedDownload? in
            guard seen.insert(id).inserted,
                  let work = downloadWork[id],
                  let item = downloads.first(where: { $0.id == id }) else { return nil }
            let failureMessage: String?
            switch item.state {
            case .failed(let message): failureMessage = message
            case .waiting, .downloading: failureMessage = nil
            case .finished, .cancelled: return nil
            }
            return SavedDownload(id: work.id, url: work.url, info: work.info,
                                 format: work.format, quality: work.quality,
                                 destination: work.destination, playlistID: work.playlistID,
                                 playlistPosition: work.playlistPosition, failureMessage: failureMessage)
        }
        let playback = PlaybackSnapshot(currentTrackID: currentTrackID, elapsed: elapsed,
                                        volume: volume, queue: queue, contextIDs: contextIDs,
                                        contextIndex: contextIndex,
                                        playedContextIDs: Array(playedContextIDs), history: history,
                                        shuffleOrder: shuffleOrder, shuffle: shuffle,
                                        repeatOne: repeatOne, repeatAll: repeatAll)
        do { try LibraryDisk.save(LibraryDocument(tracks: tracks, playlists: playlists,
                                                   downloads: saved, playback: playback)) }
        catch { statusMessage = "资料库保存失败：\(error.localizedDescription)" }
    }
}
