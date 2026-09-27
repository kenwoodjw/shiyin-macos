import SwiftUI

struct PlayerBar: View {
    @Environment(\.themePalette) private var theme
    @Bindable var store: MusicStore
    @Binding var inspectorVisible: Bool

    var body: some View {
        HStack(spacing: 18) {
            HStack(spacing: 11) {
                ArtworkView(title: store.currentTrack?.title ?? "拾音", size: 43)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.currentTrack?.title ?? "还没有播放曲目")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.text).lineLimit(1)
                    Text(store.currentTrack?.artist ?? "从资料库开始聆听")
                        .font(.system(size: 10)).foregroundStyle(theme.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                if let track = store.currentTrack {
                    Button { store.toggleFavorite(track.id) } label: {
                        Image(systemName: track.isFavorite ? "heart.fill" : "heart")
                    }
                    .buttonStyle(.plain).foregroundStyle(theme.accent)
                }
            }
            .frame(width: 240)
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                HStack(spacing: 22) {
                    transport("shuffle", active: store.shuffle) { store.shuffle.toggle() }
                    transport("backward.end.fill") { store.previous() }
                    Button { store.togglePlay() } label: {
                        Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.onAccent)
                            .frame(width: 34, height: 34)
                            .background(theme.accentDark, in: Circle())
                    }.buttonStyle(.plain).help(store.isPlaying ? "暂停" : "播放")
                    transport("forward.end.fill") { store.next() }
                    transport(store.repeatOne ? "repeat.1" : "repeat", active: store.repeatOne || store.repeatAll) {
                        store.cycleRepeat()
                    }
                    .help(store.repeatOne ? "单曲循环，点击关闭" : store.repeatAll ? "列表循环，点击切换单曲循环" : "循环关闭，点击开启列表循环")
                }
                HStack(spacing: 9) {
                    Text(timeLabel(store.elapsed)).frame(width: 31, alignment: .trailing)
                    Slider(value: Binding(get: { store.elapsed }, set: { store.seek(to: $0) }), in: 0...max(store.totalDuration, 1))
                        .tint(theme.accent)
                    Text(timeLabel(store.totalDuration)).frame(width: 31, alignment: .leading)
                }
                .font(.system(size: 9)).foregroundStyle(theme.muted)
            }
            .frame(maxWidth: 420)
            Spacer(minLength: 0)
            HStack(spacing: 9) {
                Image(systemName: "speaker.wave.2").font(.system(size: 12)).foregroundStyle(theme.muted)
                Slider(value: $store.volume, in: 0...1).tint(theme.accent).frame(width: 86)
                Button { inspectorVisible.toggle() } label: {
                    Image(systemName: "sidebar.right").font(.system(size: 13))
                }
                .buttonStyle(.plain).foregroundStyle(inspectorVisible ? theme.accentDark : theme.muted)
                .help(inspectorVisible ? "隐藏播放信息" : "显示播放信息")
            }
            .frame(width: 170)
        }
        .padding(.horizontal, 21)
        .background(theme.player)
    }

    private func transport(_ symbol: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 12)) }
            .buttonStyle(.plain).foregroundStyle(active ? theme.accentDark : theme.muted)
    }
}
