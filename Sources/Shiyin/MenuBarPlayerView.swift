import AppKit
import SwiftUI

struct MenuBarPlayerView: View {
    @Bindable var store: MusicStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 11) {
                ArtworkView(title: store.currentTrack?.title ?? "拾音", size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.currentTrack?.title ?? "还没有播放曲目")
                        .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(store.currentTrack?.artist ?? "从资料库选择一首歌")
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Text(timeLabel(store.elapsed))
                Slider(value: Binding(get: { store.elapsed }, set: { store.seek(to: $0) }),
                       in: 0...max(store.totalDuration, 1))
                    .disabled(store.currentTrack == nil)
                Text(timeLabel(store.totalDuration))
            }
            .font(.system(size: 10)).foregroundStyle(.secondary)

            HStack(spacing: 18) {
                Spacer()
                Button { store.previous() } label: { Image(systemName: "backward.end.fill") }
                    .help("上一首")
                Button { store.togglePlay() } label: {
                    Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                }
                .help(store.isPlaying ? "暂停" : "播放")
                Button { store.next() } label: { Image(systemName: "forward.end.fill") }
                    .help("下一首")
                Spacer()
            }
            .buttonStyle(.plain)
            .disabled(store.tracks.isEmpty)

            Divider()
            HStack {
                Text("\(store.downloads.filter { $0.state == .waiting || $0.state == .downloading }.count) 项下载中")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button("打开拾音") { showMainWindow() }
                    .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "拾音" }) {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
    }
}
