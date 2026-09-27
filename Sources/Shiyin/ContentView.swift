import SwiftUI

struct ContentView: View {
    @Environment(\.themePalette) private var theme
    @Bindable var store: MusicStore
    @State private var section: LibrarySection = .home
    @State private var search = ""
    @State private var isPlaylistSheetPresented = false
    @State private var playlistName = ""
    @State private var inspectorVisible = true
    @State private var isSelecting = false
    @State private var selectedTrackIDs: Set<UUID> = []
    @State private var isRenamePlaylistPresented = false
    @State private var renamedPlaylistName = ""
    @State private var playlistToDelete: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar.frame(width: 213)
                Rectangle().fill(theme.line).frame(width: 1)
                mainPane.frame(maxWidth: .infinity, maxHeight: .infinity)
                if inspectorVisible {
                    Rectangle().fill(theme.line).frame(width: 1)
                    inspector.frame(width: 285)
                }
            }
            Rectangle().fill(theme.line).frame(height: 1)
            PlayerBar(store: store, inspectorVisible: $inspectorVisible)
                .frame(height: 100)
        }
        .background(theme.canvas)
        .sheet(isPresented: $store.isImportPresented) { ImportSheet(store: store) }
        .sheet(isPresented: $store.isSettingsPresented) { SettingsSheet(store: store) }
        .sheet(isPresented: $isPlaylistSheetPresented) {
            VStack(alignment: .leading, spacing: 18) {
                Text("新建歌单").font(.system(size: 21, weight: .semibold, design: .serif)).foregroundStyle(theme.text)
                TextField("歌单名称", text: $playlistName).textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("取消") { isPlaylistSheetPresented = false }
                    Button("创建") {
                        store.createPlaylist(name: playlistName)
                        isPlaylistSheetPresented = false
                        playlistName = ""
                    }
                    .buttonStyle(SoftButtonStyle(filled: true))
                    .disabled(playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(26).frame(width: 360)
        }
        .sheet(isPresented: $isRenamePlaylistPresented) {
            VStack(alignment: .leading, spacing: 18) {
                Text("重命名歌单").font(.system(size: 21, weight: .semibold, design: .serif))
                TextField("歌单名称", text: $renamedPlaylistName).textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("取消") { isRenamePlaylistPresented = false }
                    Button("保存") {
                        if case .playlist(let id) = section { store.renamePlaylist(id, to: renamedPlaylistName) }
                        isRenamePlaylistPresented = false
                    }
                    .disabled(renamedPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.padding(26).frame(width: 360)
        }
        .confirmationDialog("删除这个歌单？", isPresented: Binding(
            get: { playlistToDelete != nil }, set: { if !$0 { playlistToDelete = nil } })) {
            Button("删除歌单", role: .destructive) {
                if let id = playlistToDelete { store.deletePlaylist(id) }
                playlistToDelete = nil
                section = .all
                selectedTrackIDs.removeAll()
            }
            Button("取消", role: .cancel) { playlistToDelete = nil }
        } message: { Text("曲目仍保留在资料库，本地音频文件不会被删除。") }
        .alert("提示", isPresented: Binding(get: { store.statusMessage != nil }, set: { if !$0 { store.statusMessage = nil } })) {
            Button("好") { store.statusMessage = nil }
        } message: { Text(store.statusMessage ?? "") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "circle.lefthalf.filled").font(.system(size: 19)).foregroundStyle(theme.accent)
                Text("拾音").font(.system(size: 19, weight: .semibold, design: .serif)).foregroundStyle(theme.text)
            }
            .padding(.horizontal, 21).padding(.top, 25).padding(.bottom, 30)
            Text("音乐").font(.system(size: 10, weight: .bold)).tracking(1.7).foregroundStyle(theme.muted)
                .padding(.horizontal, 20).padding(.bottom, 9)
            sidebarItem(.home, "聆听空间", "house")
            sidebarItem(.all, "全部曲目", "square.stack", count: store.tracks.count)
            sidebarItem(.downloads, "下载任务", "arrow.down.to.line", count: store.downloads.filter { $0.state == .downloading || $0.state == .waiting }.count)
            HStack {
                Text("我的歌单").font(.system(size: 10, weight: .bold)).tracking(1.7).foregroundStyle(theme.muted)
                Spacer()
                Button { isPlaylistSheetPresented = true } label: { Image(systemName: "plus").font(.system(size: 13)) }
                    .buttonStyle(.plain).foregroundStyle(theme.muted)
                    .help("新建歌单")
            }
            .padding(.horizontal, 20).padding(.top, 31).padding(.bottom, 9)
            sidebarItem(.favorites, "喜欢的音乐", "heart")
            ForEach(store.playlists) { playlist in
                sidebarItem(.playlist(playlist.id), playlist.name, "circle.fill")
            }
            Spacer(minLength: 18)
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text("音乐空间").foregroundStyle(theme.text)
                    Spacer()
                    Text("\(store.tracks.count) 首曲目").foregroundStyle(theme.muted)
                }
                .font(.system(size: 11, weight: .medium))
                Capsule().fill(theme.line).frame(height: 4)
                    .overlay(alignment: .leading) { Capsule().fill(theme.accent).frame(width: min(CGFloat(store.tracks.count) * 12 + 10, 164), height: 4) }
                Text("音频保存在这台 Mac 上").font(.system(size: 10)).foregroundStyle(theme.muted)
                Button { store.isSettingsPresented = true } label: {
                    Label("外观与设置", systemImage: "paintpalette").font(.system(size: 11))
                }
                .buttonStyle(.plain).foregroundStyle(theme.muted).padding(.top, 11)
            }
            .padding(19)
        }
        .background(theme.sidebar)
    }

    private func sidebarItem(_ destination: LibrarySection, _ title: String, _ symbol: String, count: Int? = nil) -> some View {
        Button { section = destination; search = ""; selectedTrackIDs.removeAll(); isSelecting = false } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 14)).frame(width: 17)
                Text(title).lineLimit(1)
                Spacer(minLength: 0)
                if let count, count > 0 { Text("\(count)").font(.system(size: 10)).foregroundStyle(theme.muted) }
            }
            .font(.system(size: 12, weight: section == destination ? .semibold : .medium))
            .foregroundStyle(section == destination ? theme.accentDark : theme.muted)
            .padding(.horizontal, 12).frame(height: 35)
            .background(section == destination ? theme.selected : .clear, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10).padding(.bottom, 3)
    }

    private var mainPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                HStack(spacing: 7) {
                    Text("资料库").foregroundStyle(theme.muted)
                    Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(theme.muted)
                    Text(sectionTitle).foregroundStyle(theme.text)
                }
                .font(.system(size: 11, weight: .medium))
                Spacer(minLength: 12)
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass").foregroundStyle(theme.muted)
                    TextField("搜索曲目、艺人", text: $search).textFieldStyle(.plain)
                        .font(.system(size: 11)).foregroundStyle(theme.text)
                }
                .padding(.horizontal, 10).frame(width: 190, height: 32)
                .background(theme.sidebar, in: RoundedRectangle(cornerRadius: 7))
                Button { store.isSettingsPresented = true } label: {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.accentDark)
                        .frame(width: 32, height: 32)
                        .background(theme.sidebar, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain).help("切换配色")
                Button { store.isImportPresented = true } label: { Label("导入链接", systemImage: "plus") }
                    .buttonStyle(SoftButtonStyle(filled: true))
            }
            .padding(.horizontal, 27).frame(height: 63)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if section == .home { hero.padding(.bottom, 28) }
                    if section == .downloads { downloadsContent }
                    else { libraryContent }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 27).padding(.top, 20).padding(.bottom, 30)
            }
        }
        .background(theme.canvas)
    }

    private var hero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 15)
                .fill(LinearGradient(colors: theme.hero, startPoint: .leading, endPoint: .trailing))
            HStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("YOUR LISTENING ROOM").font(.system(size: 9, weight: .bold)).tracking(2.1).foregroundStyle(theme.accentDark)
                    Text("让喜欢的声音，\n留在身边。")
                        .font(.system(size: 29, weight: .semibold, design: .serif)).lineSpacing(3).foregroundStyle(theme.text)
                    Text("收藏灵感，沉浸播放。你的音乐，只属于此刻。")
                        .font(.system(size: 11)).foregroundStyle(theme.muted).frame(maxWidth: 220, alignment: .leading)
                    Button { store.togglePlay() } label: { Label("继续播放", systemImage: "play.fill") }
                        .buttonStyle(SoftButtonStyle(filled: true)).padding(.top, 3)
                }
                .padding(.leading, 29)
                Spacer()
                RecordView(size: 228).offset(x: 35, y: 20)
            }
            .clipped()
        }
        .frame(height: 249)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(theme.line, lineWidth: 1))
        .clipped()
    }

    private var sectionTitle: String {
        switch section {
        case .home: "聆听空间"
        case .all: "全部曲目"
        case .downloads: "下载任务"
        case .favorites: "喜欢的音乐"
        case .playlist(let id): store.playlists.first(where: { $0.id == id })?.name ?? "歌单"
        }
    }

    private var visibleTracks: [Track] {
        let candidates: [Track]
        switch section {
        case .home, .all: candidates = store.tracks
        case .favorites: candidates = store.tracks.filter(\.isFavorite)
        case .playlist(let id):
            let ids = store.playlists.first(where: { $0.id == id })?.trackIDs ?? []
            candidates = ids.compactMap { id in store.tracks.first(where: { $0.id == id }) }
        case .downloads: candidates = []
        }
        guard !search.isEmpty else { return candidates }
        return candidates.filter { $0.title.localizedCaseInsensitiveContains(search) || $0.artist.localizedCaseInsensitiveContains(search) }
    }

    private var libraryContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section == .home ? "RECENTLY ADDED" : "YOUR COLLECTION")
                .font(.system(size: 9, weight: .bold)).tracking(1.8).foregroundStyle(theme.accent)
            HStack {
                Text(section == .home ? "最近加入" : sectionTitle)
                    .font(.system(size: 22, weight: .semibold, design: .serif)).foregroundStyle(theme.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 12)
                if case .playlist = section {
                    Menu {
                        Button("重命名歌单") {
                            renamedPlaylistName = sectionTitle
                            isRenamePlaylistPresented = true
                        }
                        Button("删除歌单", role: .destructive) {
                            if case .playlist(let id) = section { playlistToDelete = id }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .foregroundStyle(theme.accentDark)
                    .background(theme.sidebar, in: RoundedRectangle(cornerRadius: 8))
                    .help("管理歌单")
                }
                Button(isSelecting ? "完成" : "多选") {
                    isSelecting.toggle()
                    selectedTrackIDs.removeAll()
                }.buttonStyle(SoftButtonStyle())
            }.padding(.top, 5)
            if isSelecting && !selectedTrackIDs.isEmpty {
                HStack(spacing: 13) {
                    Text("已选 \(selectedTrackIDs.count) 首")
                    if !store.playlists.isEmpty {
                        Menu("加入歌单") {
                            ForEach(store.playlists) { playlist in
                                Button(playlist.name) {
                                    store.addToPlaylist(selectedTrackIDs, playlistID: playlist.id)
                                    selectedTrackIDs.removeAll()
                                }
                            }
                        }
                    }
                    if case .playlist(let id) = section {
                        Button("从歌单移除") {
                            store.removeFromPlaylist(selectedTrackIDs, playlistID: id)
                            selectedTrackIDs.removeAll()
                        }
                    }
                }.font(.system(size: 11)).padding(.top, 12)
            }
            if case .playlist = section, !isSelecting {
                Text("拖动曲目可调整歌单顺序")
                    .font(.system(size: 10)).foregroundStyle(theme.muted).padding(.top, 8)
            }
            if visibleTracks.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "music.note.list").font(.system(size: 30)).foregroundStyle(theme.accent)
                    Text(search.isEmpty ? "这里还没有音乐" : "没有找到曲目")
                        .font(.system(size: 17, weight: .semibold, design: .serif)).foregroundStyle(theme.text)
                    Text(search.isEmpty ? "导入 YouTube 或 B 站链接，建立你的资料库。" : "试试其他关键词。")
                        .font(.system(size: 11)).foregroundStyle(theme.muted)
                    if search.isEmpty {
                        Button("导入链接") { store.isImportPresented = true }
                            .buttonStyle(SoftButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 65)
            } else {
                HStack {
                    Text("标题").frame(maxWidth: .infinity, alignment: .leading)
                    Text("来源").frame(width: 80, alignment: .leading)
                    Text("时长").frame(width: 48, alignment: .trailing)
                    Color.clear.frame(width: 34)
                }
                .font(.system(size: 10, weight: .medium)).foregroundStyle(theme.muted)
                .padding(.horizontal, 9).padding(.top, 23).padding(.bottom, 9)
                ForEach(visibleTracks) { track in
                    TrackRow(store: store, track: track, playContext: visibleTracks,
                             playlistID: { if case .playlist(let id) = section { return id }; return nil }(),
                             isSelecting: isSelecting, isSelected: selectedTrackIDs.contains(track.id)) {
                        if !selectedTrackIDs.insert(track.id).inserted { selectedTrackIDs.remove(track.id) }
                    }
                    .draggable(track.id.uuidString)
                    .dropDestination(for: String.self) { items, _ in
                        guard case .playlist(let id) = section,
                              let first = items.first, let source = UUID(uuidString: first) else { return false }
                        store.moveInPlaylist(source, before: track.id, playlistID: id)
                        return true
                    }
                }
            }
        }
    }

    private var downloadsContent: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("DOWNLOADS").font(.system(size: 9, weight: .bold)).tracking(1.8).foregroundStyle(theme.accent)
            Text("下载任务").font(.system(size: 22, weight: .semibold, design: .serif)).foregroundStyle(theme.text)
            if store.downloads.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.to.line").font(.system(size: 30)).foregroundStyle(theme.accent)
                    Text("目前没有下载任务").font(.system(size: 16, weight: .semibold, design: .serif))
                    Button("导入链接") { store.isImportPresented = true }.buttonStyle(SoftButtonStyle())
                }.foregroundStyle(theme.text).frame(maxWidth: .infinity).padding(.vertical, 75)
            } else {
                LazyVStack(spacing: 15) {
                    ForEach(store.downloads) { item in
                        HStack(spacing: 13) {
                            ArtworkView(title: item.title, size: 44)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.text).lineLimit(1)
                                if case .failed(let message) = item.state {
                                    CopyableErrorView(title: "下载失败", message: message)
                                    if message.localizedCaseInsensitiveContains("Sign in to confirm") {
                                        Text("YouTube 要求登录验证。选择已登录的浏览器后重试。")
                                            .font(.system(size: 10)).foregroundStyle(theme.muted)
                                    }
                                } else {
                                    Text(downloadLabel(item)).font(.system(size: 10)).foregroundStyle(theme.muted).lineLimit(2)
                                }
                                if item.state == .downloading { ProgressView(value: item.progress).tint(theme.accent) }
                            }
                            Spacer()
                            if item.state == .waiting || item.state == .downloading {
                                Button { store.cancelDownload(item.id) } label: { Image(systemName: "xmark") }
                                    .buttonStyle(.plain).foregroundStyle(theme.muted).help("取消下载")
                            }
                            if case .failed(let message) = item.state {
                                if message.localizedCaseInsensitiveContains("Sign in to confirm") {
                                    Button("登录设置") { store.isSettingsPresented = true }
                                        .buttonStyle(SoftButtonStyle())
                                }
                                Button("重试") { store.retryDownload(item.id) }
                                    .buttonStyle(SoftButtonStyle())
                            }
                        }
                        .padding(12).background(theme.sidebar, in: RoundedRectangle(cornerRadius: 9))
                    }
                }
            }
        }
    }

    private func downloadLabel(_ item: DownloadItem) -> String {
        switch item.state {
        case .waiting: "准备中"
        case .downloading: "正在下载 · \(Int(item.progress * 100))%"
        case .finished: "已完成 · 已加入资料库"
        case .failed: "下载失败"
        case .cancelled: "已取消"
        }
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("正在播放").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.text)
                Spacer()
                Button { inspectorVisible = false } label: { Image(systemName: "sidebar.right") }
                    .buttonStyle(.plain).foregroundStyle(theme.muted).help("隐藏播放信息")
            }
            .padding(.bottom, 25)
            ArtworkView(title: store.currentTrack?.title ?? "拾音", size: 240)
                .frame(maxWidth: .infinity)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.currentTrack?.title ?? "等待播放")
                        .font(.system(size: 18, weight: .semibold, design: .serif)).foregroundStyle(theme.text).lineLimit(2)
                    Text(store.currentTrack?.artist ?? "从资料库选一首音乐")
                        .font(.system(size: 11)).foregroundStyle(theme.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                if let track = store.currentTrack {
                    Button { store.toggleFavorite(track.id) } label: {
                        Image(systemName: track.isFavorite ? "heart.fill" : "heart")
                    }.buttonStyle(.plain).foregroundStyle(theme.accent)
                }
            }
            .padding(.top, 19).padding(.bottom, 28)
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text("声音细节").fontWeight(.semibold)
                    Spacer()
                    Text("本地音频").foregroundStyle(theme.accent)
                }
                HStack(spacing: 6) {
                    Circle().fill(theme.accent).frame(width: 5, height: 5)
                    Text("保存在这台 Mac 上")
                    Spacer()
                    Text(store.currentTrack?.format ?? "—")
                }
            }
            .font(.system(size: 10)).foregroundStyle(theme.muted)
            .padding(.bottom, 27)
            HStack {
                Text("接下来播放").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.text)
                Text("\(store.queue.count) 首").font(.system(size: 10)).foregroundStyle(theme.muted)
                Spacer()
                Button("清空") { store.clearQueue() }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(theme.muted)
            }
            .padding(.bottom, 11)
            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(store.upcomingTracks) { track in
                        HStack(spacing: 5) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 9)).foregroundStyle(theme.muted)
                            queueTrackButton(track)
                                .draggable(track.id.uuidString)
                                .dropDestination(for: String.self) { items, _ in
                                    guard let first = items.first, let source = UUID(uuidString: first) else { return false }
                                    store.moveQueue(source, before: track.id)
                                    return true
                                }
                            Button { store.removeFromQueue(track.id) } label: { Image(systemName: "xmark") }
                                .buttonStyle(.plain).foregroundStyle(theme.muted).help("从队列移除")
                        }
                    }
                    if !store.automaticUpcomingTracks.isEmpty {
                        Text("随后播放").font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(theme.muted).padding(.top, 10)
                        ForEach(Array(store.automaticUpcomingTracks.prefix(20))) { track in
                            queueTrackButton(track)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 21).padding(.top, 24).padding(.bottom, 15)
        .background(theme.inspector)
    }

    private func queueTrackButton(_ track: Track) -> some View {
        Button { store.playUpcoming(track) } label: {
            HStack(spacing: 8) {
                ArtworkView(title: track.title, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title).font(.system(size: 10, weight: .semibold)).foregroundStyle(theme.text).lineLimit(1)
                    Text(track.artist).font(.system(size: 9)).foregroundStyle(theme.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(5).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

private struct TrackRow: View {
    @Environment(\.themePalette) private var theme
    @State private var isDeleteConfirmationPresented = false
    let store: MusicStore
    let track: Track
    let playContext: [Track]
    let playlistID: UUID?
    let isSelecting: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button { if isSelecting { onSelect() } else { store.play(track, in: playContext) } } label: {
                HStack(spacing: 11) {
                    if isSelecting {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(theme.accentDark)
                    }
                    ArtworkView(title: track.title, size: 39)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.text).lineLimit(1)
                        Text(track.artist).font(.system(size: 10)).foregroundStyle(theme.muted).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }.buttonStyle(.plain).frame(maxWidth: .infinity)
            Text(URL(string: track.sourceURL).map(YouTubeClient.isBilibiliURL) == true ? "B 站" : "YouTube")
                .font(.system(size: 10)).foregroundStyle(theme.muted).frame(width: 80, alignment: .leading)
            Text(timeLabel(track.duration)).font(.system(size: 10)).foregroundStyle(theme.muted).frame(width: 48, alignment: .trailing)
            Menu {
                Button("立即播放") { store.play(track, in: playContext) }
                Button("下一首播放") { store.playNext(track) }
                Button("添加到播放队列") { store.addToQueue(track) }
                if let playlistID {
                    Button("从当前歌单移除") { store.removeFromPlaylist([track.id], playlistID: playlistID) }
                }
                Button(track.isFavorite ? "取消喜欢" : "添加到喜欢的音乐") { store.toggleFavorite(track.id) }
                if !store.playlists.isEmpty {
                    Menu("加入歌单") {
                        ForEach(store.playlists) { playlist in
                            Button(playlist.name) { store.add(track, to: playlist.id) }
                        }
                    }
                }
                Divider()
                Button("在访达中显示") { NSWorkspace.shared.activateFileViewerSelecting([store.fileURL(for: track)]) }
                Button("从资料库移除（保留文件）") { store.remove(track) }
                Button("从资料库移除并删除文件", role: .destructive) {
                    isDeleteConfirmationPresented = true
                }
            } label: { Image(systemName: "ellipsis").frame(width: 30, height: 30).contentShape(Rectangle()) }
                .menuStyle(.borderlessButton).foregroundStyle(theme.muted).frame(width: 34)
        }
        .padding(.horizontal, 9).frame(height: 57)
        .background(store.currentTrackID == track.id ? theme.selected : .clear, in: RoundedRectangle(cornerRadius: 7))
        .confirmationDialog("删除本地音频文件？", isPresented: $isDeleteConfirmationPresented) {
            Button("移到废纸篓并从资料库移除", role: .destructive) { store.removeIncludingFile(track) }
            Button("取消", role: .cancel) { }
        } message: {
            Text("“\(track.title)”的音频文件将移到废纸篓。")
        }
    }
}
