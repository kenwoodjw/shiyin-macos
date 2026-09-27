import Foundation
import MediaPlayer

@MainActor final class SystemPlaybackController {
    static let shared = SystemPlaybackController()

    private weak var store: MusicStore?
    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commands = MPRemoteCommandCenter.shared()

    private init() {
        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.store?.resume() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.store?.pause() }
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.store?.togglePlay() }
            return .success
        }
        commands.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.store?.next() }
            return .success
        }
        commands.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.store?.previous() }
            return .success
        }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor [weak self] in self?.store?.seek(to: position) }
            return .success
        }
    }

    func connect(_ store: MusicStore) {
        self.store = store
        refresh()
    }

    func refresh() {
        guard let store, let track = store.currentTrack else {
            infoCenter.nowPlayingInfo = nil
            infoCenter.playbackState = .stopped
            commands.playCommand.isEnabled = store?.tracks.isEmpty == false
            commands.pauseCommand.isEnabled = false
            commands.nextTrackCommand.isEnabled = false
            commands.previousTrackCommand.isEnabled = false
            commands.changePlaybackPositionCommand.isEnabled = false
            return
        }
        infoCenter.nowPlayingInfo = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyPlaybackDuration: store.totalDuration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: store.elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: store.isPlaying ? 1.0 : 0.0
        ]
        infoCenter.playbackState = store.isPlaying ? .playing : .paused
        commands.playCommand.isEnabled = true
        commands.pauseCommand.isEnabled = true
        commands.nextTrackCommand.isEnabled = true
        commands.previousTrackCommand.isEnabled = true
        commands.changePlaybackPositionCommand.isEnabled = true
    }
}
