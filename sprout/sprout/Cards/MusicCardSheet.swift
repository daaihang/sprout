import SwiftUI
import MusicKit

struct MusicCardSheet: View {
    @Binding var data: MusicCardData
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var searchResults: [Song] = []
    @State private var isSearching = false
    @State private var isLoadingURL = false
    @State private var errorMessage: String?
    @State private var authorizationStatus: MusicAuthorization.Status = .notDetermined

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBarSection
                    .padding()

                if let error = errorMessage {
                    errorView(error)
                } else if isLoadingURL {
                    loadingView
                } else if searchResults.isEmpty && searchText.isEmpty {
                    emptyStateView
                } else if searchResults.isEmpty {
                    noResultsView
                } else {
                    resultsList
                }

                Spacer()
            }
            .navigationTitle("添加音乐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !searchResults.isEmpty {
                        Button("完成") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .onAppear {
            checkAuthorization()
        }
    }

    @ViewBuilder
    private var searchBarSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("粘贴链接或搜索歌曲、专辑、歌手", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                        errorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("粘贴 Apple Music 链接或输入搜索关键词")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("搜索音乐")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("粘贴 Apple Music 链接或输入歌曲、专辑、歌手名称")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }

    @ViewBuilder
    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))
            Text("未找到结果")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 60)
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在加载...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 60)
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }

    @ViewBuilder
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(searchResults, id: \.id) { song in
                    Button {
                        selectSong(song)
                    } label: {
                        songRow(song)
                    }
                    Divider()
                }
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func songRow(_ song: Song) -> some View {
        HStack(spacing: 12) {
            artworkView(for: song)

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
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func artworkView(for song: Song) -> some View {
        let size: CGFloat = 50
        Group {
            if let artwork = song.artwork {
                AsyncImage(url: artwork.url(width: Int(size * 2), height: Int(size * 2))) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    artworkPlaceholder
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                artworkPlaceholder
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    @ViewBuilder
    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.gray.opacity(0.2))
            .overlay(
                Image(systemName: "music.note")
                    .foregroundColor(.secondary)
            )
    }

    private func checkAuthorization() {
        authorizationStatus = MusicAuthorization.currentStatus
        if authorizationStatus == .notDetermined {
            Task {
                let status = await MusicAuthorization.request()
                await MainActor.run {
                    authorizationStatus = status
                }
            }
        }
    }

    private func performSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let url = URL(string: trimmed), AppleMusicLinkParser.shared.isAppleMusicURL(trimmed) {
            loadFromURL(url)
        } else {
            searchMusicCatalog(query: trimmed)
        }
    }

    private func loadFromURL(_ url: URL) {
        isLoadingURL = true
        errorMessage = nil
        searchResults = []

        Task {
            do {
                let musicData = try await AppleMusicLinkParser.shared.fetchSongDetails(from: url)
                await MainActor.run {
                    data = musicData
                    isLoadingURL = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "无法加载音乐: \(error.localizedDescription)"
                    isLoadingURL = false
                }
            }
        }
    }

    private func searchMusicCatalog(query: String) {
        guard authorizationStatus == .authorized else {
            errorMessage = "需要音乐库访问权限"
            return
        }

        isSearching = true
        errorMessage = nil

        Task {
            do {
                var request = MusicCatalogSearchRequest(term: query, types: [Song.self, Album.self])
                request.limit = 15

                let response = try await request.response()
                await MainActor.run {
                    searchResults = response.songs.map { $0 }
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "搜索失败: \(error.localizedDescription)"
                    isSearching = false
                }
            }
        }
    }

    private func selectSong(_ song: Song) {
        var artwork: UIImage?
        if let artworkAsset = song.artwork {
            let size = CGSize(width: 300, height: 300)
            if let url = artworkAsset.url(width: Int(size.width), height: Int(size.height)) {
                Task {
                    if let (imageData, _) = try? await URLSession.shared.data(from: url),
                       let image = UIImage(data: imageData) {
                        await MainActor.run {
                            data.albumArtwork = image
                        }
                    }
                }
            }
        }

        data = MusicCardData(
            trackName: song.title,
            artistName: song.artistName,
            albumName: song.albumTitle ?? "",
            albumArtwork: nil,
            appleMusicURL: song.url,
            isPlaying: false
        )
        dismiss()
    }
}