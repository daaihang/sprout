import SwiftUI
import MusicKit

struct MusicCardSheet: View {
    @Binding var data: MusicCardData
    var musicService: MusicService
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var songResults: [Song] = []
    @State private var albumResults: [Album] = []
    @State private var isSearching = false
    @State private var isLoadingURL = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                switch musicService.authorizationStatus {
                case .denied, .restricted:
                    deniedView
                default:
                    contentList
                }
            }
            .navigationTitle("添加音乐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .task {
            if musicService.authorizationStatus == .notDetermined {
                await musicService.requestAuthorization()
            }
        }
    }

    @ViewBuilder
    private var contentList: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("粘贴链接或搜索歌曲、专辑、歌手", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .onSubmit { performSearch(searchText) }
                        .onChange(of: searchText) { _, newValue in
                            scheduleSearch(newValue)
                        }
                    if isSearching || isLoadingURL {
                        ProgressView().scaleEffect(0.8)
                    } else if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            songResults = []
                            albumResults = []
                            errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let nowPlaying = musicService.nowPlayingData, searchText.isEmpty {
                Section("正在播放") {
                    nowPlayingRow(nowPlaying)
                }
            }

            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.subheadline)
                }
            }

            if !songResults.isEmpty {
                Section("歌曲") {
                    ForEach(songResults, id: \.id) { song in
                        Button { selectSong(song) } label: {
                            songRow(song)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !albumResults.isEmpty {
                Section("专辑") {
                    ForEach(albumResults, id: \.id) { album in
                        Button { selectAlbum(album) } label: {
                            albumRow(album)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if searchText.isEmpty && musicService.nowPlayingData == nil && songResults.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("粘贴 Apple Music 链接\n或输入歌曲、专辑名称")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
                .listRowBackground(Color.clear)
            }
        }
    }

    @ViewBuilder
    private var deniedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "music.note.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("需要音乐权限")
                .font(.headline)
            Text("请在设置中允许访问 Apple Music")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("打开设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private func nowPlayingRow(_ nowPlaying: MusicCardData) -> some View {
        HStack(spacing: 12) {
            artworkImageView(image: nowPlaying.albumArtwork, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(nowPlaying.trackName)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                Text(nowPlaying.artistName)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                data = nowPlaying
                dismiss()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func songRow(_ song: Song) -> some View {
        HStack(spacing: 12) {
            artworkView(artwork: song.artwork, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(song.artistName)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if let album = song.albumTitle {
                    Text(album)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func albumRow(_ album: Album) -> some View {
        HStack(spacing: 12) {
            artworkView(artwork: album.artwork, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(album.artistName)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func artworkView(artwork: Artwork?, size: CGFloat) -> some View {
        Group {
            if let artwork = artwork,
               let url = artwork.url(width: Int(size * 2), height: Int(size * 2)) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    artworkPlaceholder
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                artworkPlaceholder
                    .frame(width: size, height: size)
            }
        }
    }

    @ViewBuilder
    private func artworkImageView(image: UIImage?, size: CGFloat) -> some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                artworkPlaceholder
                    .frame(width: size, height: size)
            }
        }
    }

    @ViewBuilder
    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.gray.opacity(0.2))
            .overlay(Image(systemName: "music.note").foregroundColor(.secondary))
    }

    private func scheduleSearch(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            songResults = []
            albumResults = []
            errorMessage = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            performSearch(trimmed)
        }
    }

    private func performSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if AppleMusicLinkParser.shared.isAppleMusicURL(trimmed), let url = URL(string: trimmed) {
            loadFromURL(url)
        } else {
            searchMusicCatalog(query: trimmed)
        }
    }

    private func loadFromURL(_ url: URL) {
        isLoadingURL = true
        errorMessage = nil
        songResults = []
        albumResults = []
        Task {
            do {
                let musicData = try await AppleMusicLinkParser.shared.fetchSongDetails(from: url)
                data = musicData
                isLoadingURL = false
                dismiss()
            } catch {
                errorMessage = "无法加载音乐: \(error.localizedDescription)"
                isLoadingURL = false
            }
        }
    }

    private func searchMusicCatalog(query: String) {
        guard musicService.authorizationStatus == .authorized else {
            errorMessage = "需要音乐库访问权限，请先授权"
            return
        }
        isSearching = true
        errorMessage = nil
        Task {
            do {
                var request = MusicCatalogSearchRequest(term: query, types: [Song.self, Album.self])
                request.limit = 10
                let response = try await request.response()
                songResults = response.songs.map { $0 }
                albumResults = response.albums.map { $0 }
                isSearching = false
            } catch {
                errorMessage = "搜索失败: \(error.localizedDescription)"
                isSearching = false
            }
        }
    }

    private func selectSong(_ song: Song) {
        Task {
            var artwork: UIImage? = nil
            if let artworkAsset = song.artwork,
               let url = artworkAsset.url(width: 300, height: 300),
               let (imageData, _) = try? await URLSession.shared.data(from: url) {
                artwork = UIImage(data: imageData)
            }
            data = MusicCardData(
                trackName: song.title,
                artistName: song.artistName,
                albumName: song.albumTitle ?? "",
                albumArtwork: artwork,
                appleMusicURL: song.url,
                isPlaying: false
            )
            dismiss()
        }
    }

    private func selectAlbum(_ album: Album) {
        Task {
            var artwork: UIImage? = nil
            if let artworkAsset = album.artwork,
               let url = artworkAsset.url(width: 300, height: 300),
               let (imageData, _) = try? await URLSession.shared.data(from: url) {
                artwork = UIImage(data: imageData)
            }
            data = MusicCardData(
                trackName: album.title,
                artistName: album.artistName,
                albumName: album.title,
                albumArtwork: artwork,
                appleMusicURL: album.url,
                isPlaying: false
            )
            dismiss()
        }
    }
}
