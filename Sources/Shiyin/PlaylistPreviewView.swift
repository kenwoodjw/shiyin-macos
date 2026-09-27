import SwiftUI

struct PlaylistPreviewView: View {
    @Environment(\.themePalette) private var theme
    let playlist: PlaylistInfo
    @Binding var selectedIDs: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(2)
                    Text("\(playlist.entries.count) 首可导入 · 已选 \(selectedIDs.count) 首" +
                         (playlist.totalCount > playlist.entries.count
                          ? " · \(playlist.totalCount - playlist.entries.count) 首不可用" : ""))
                        .font(.system(size: 10))
                        .foregroundStyle(theme.muted)
                }
                Spacer()
                Button("全选下载") { selectedIDs = Set(playlist.entries.map(\.id)) }
                    .disabled(selectedIDs.count == playlist.entries.count)
                Button("取消全选") { selectedIDs.removeAll() }
                    .disabled(selectedIDs.isEmpty)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(theme.accentDark)

            Text("可逐首取消或勾选；只下载已勾选的歌曲，并按原顺序加入同名本地歌单。")
                .font(.system(size: 10))
                .foregroundStyle(theme.muted)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(playlist.entries) { entry in
                        Toggle(isOn: Binding(
                            get: { selectedIDs.contains(entry.id) },
                            set: { selected in
                                if selected { selectedIDs.insert(entry.id) }
                                else { selectedIDs.remove(entry.id) }
                            }
                        )) {
                            HStack(spacing: 9) {
                                Text("\(entry.id + 1).")
                                    .frame(width: 26, alignment: .trailing)
                                    .foregroundStyle(theme.muted)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.video.title)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(theme.text)
                                        .lineLimit(1)
                                    Text("\(entry.video.artist) · \(timeLabel(entry.video.duration ?? 0))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(theme.muted)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .toggleStyle(.checkbox)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        if entry.id != playlist.entries.last?.id { Divider().padding(.leading, 10) }
                    }
                }
            }
            .frame(height: min(CGFloat(playlist.entries.count) * 55, 225))
            .background(theme.canvas, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.line))
        }
        .padding(12)
        .background(theme.sidebar, in: RoundedRectangle(cornerRadius: 9))
    }
}
