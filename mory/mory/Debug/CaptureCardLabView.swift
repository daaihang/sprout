import SwiftUI
import UIKit

struct CaptureCardLabView: View {
    @State private var selectedIDs: Set<String> = []
    @State private var removedIDs: Set<String> = []
    @State private var isShowingMotionState = false
    @State private var selectedWeatherStyle: CaptureWeatherVisualStyle = .sunny
    @State private var selectedWeatherOrigin: CaptureArtifactOrigin = .context
    @State private var selectedWeatherSymbolMotionLevel: CaptureWeatherSymbolMotionLevel = .subtle
    @State private var selectedWeatherIntensity: CaptureCardLabWeatherIntensity = .balanced
    @State private var isWeatherReduceMotionEnabled = false
    @State private var weatherTemperature = 23.0
    @State private var selectedMusicFixtureID = CaptureCardLabFixtures.musicFixtures.first?.id ?? ""
    @State private var selectedMusicState: CaptureMusicPlaybackState = .playing
    @State private var liveMusicPreview: CaptureCardItem?
    @State private var musicSearchQuery = ""
    @State private var musicSearchResults: [MusicCatalogSongCandidate] = []
    @State private var selectedSearchMusicPreview: CaptureCardItem?
    @State private var isLoadingNowPlaying = false
    @State private var isSearchingMusic = false
    @State private var musicMessage: String?
    @State private var selectedPlaceScenarioID = CaptureCardLabFixtures.placeScenarios.first?.id ?? ""
    @State private var placeSnapshotData: Data?
    @State private var isGeneratingPlaceSnapshot = false
    @State private var isPlacePrivacyEnabled = false
    @State private var placeSnapshotMessage: String?
    @State private var selectedAppearanceMode: CaptureCardLabAppearanceMode = .light
    @State private var selectedAppearanceContrast: CaptureCardLabContrastMode = .standard
    @State private var isAppearanceReduceMotionEnabled = false
    @State private var selectedProvenanceDisplayMode: CaptureCardProvenanceDisplayMode = .production

    private let musicService = MusicContextService()

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Preview motion states", isOn: $isShowingMotionState.animation(.spring(response: 0.3, dampingFraction: 0.82)))
                    Text("This lab uses fixture-only data. It does not request permissions, save memories, or alter the production composer.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Controls")
            }

            weatherLabSection
            musicLabSection
            placeLabSection
            appearanceLabSection
            palettePreviewSection

            labSection(
                title: "All Types",
                subtitle: "Real content kinds only. Automatic context appears as place, weather, or music with Context origin.",
                items: CaptureCardLabFixtures.allTypes
            )

            originsComparisonSection

            labSection(
                title: "States",
                subtitle: "Selection, loading, error, disabled, and removable affordances.",
                items: CaptureCardLabFixtures.states
            )

            labSection(
                title: "Edge Cases",
                subtitle: "Long text, missing media, manual music, and context weather.",
                items: CaptureCardLabFixtures.edgeCases
            )

            labSection(
                title: "Status",
                subtitle: "Temporary cards for context collection, photo processing, transcript refinement, and empty states.",
                items: CaptureCardLabFixtures.status
            )
        }
        .navigationTitle("Capture Card Lab")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPlaceScenarioID) { _, _ in
            resetPlaceSnapshot()
        }
        .onChange(of: isPlacePrivacyEnabled) { _, _ in
            resetPlaceSnapshot()
        }
    }

    private var weatherLabSection: some View {
        Section {
            Picker("Condition", selection: $selectedWeatherStyle) {
                ForEach(CaptureWeatherVisualStyle.allCases) { style in
                    Text(style.label).tag(style)
                }
            }

            Picker("Origin", selection: $selectedWeatherOrigin) {
                ForEach(CaptureArtifactOrigin.allCases, id: \.self) { origin in
                    Text(origin.captureBadgeLabel).tag(origin)
                }
            }

            Picker("Symbol motion", selection: $selectedWeatherSymbolMotionLevel) {
                ForEach(CaptureWeatherSymbolMotionLevel.allCases) { level in
                    Text(level.label).tag(level)
                }
            }

            Picker("Atmosphere", selection: $selectedWeatherIntensity) {
                ForEach(CaptureCardLabWeatherIntensity.allCases) { intensity in
                    Text(intensity.label).tag(intensity)
                }
            }

            Picker("Source labels", selection: $selectedProvenanceDisplayMode) {
                ForEach(CaptureCardProvenanceDisplayMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            Toggle("Reduce Motion", isOn: $isWeatherReduceMotionEnabled)

            Stepper("Temperature \(Int(weatherTemperature))°C", value: $weatherTemperature, in: -15...42, step: 1)

            CaptureCardView(
                item: weatherPreviewCard,
                reduceMotionOverride: isWeatherReduceMotionEnabled,
                provenanceDisplayMode: selectedProvenanceDisplayMode,
                weatherSymbolMotionLevel: selectedWeatherSymbolMotionLevel,
                weatherAtmosphereIntensityScale: selectedWeatherIntensity.scale
            )
                .padding(.vertical, 4)
        } header: {
            Text("Weather Lab")
        } footer: {
            Text("Weather cards keep kind=weather. The selected origin only changes the badge and context affordance.")
        }
    }

    private var musicLabSection: some View {
        Section {
            Picker("Fixture", selection: $selectedMusicFixtureID) {
                ForEach(CaptureCardLabFixtures.musicFixtures) { item in
                    Text(item.title ?? item.detail).tag(item.id)
                }
            }

            Picker("Playback", selection: $selectedMusicState) {
                ForEach(CaptureMusicPlaybackState.allCases) { state in
                    Text(state.label).tag(state)
                }
            }

            CaptureCardView(
                item: musicFixturePreviewCard,
                provenanceDisplayMode: selectedProvenanceDisplayMode
            )
                .padding(.vertical, 4)

            Button {
                Task { await loadNowPlayingPreview() }
            } label: {
                Label(isLoadingNowPlaying ? "Loading now playing" : "Load current playing song", systemImage: "music.note")
            }
            .disabled(isLoadingNowPlaying)

            if let liveMusicPreview {
                CaptureCardView(
                    item: liveMusicPreview,
                    provenanceDisplayMode: selectedProvenanceDisplayMode
                )
                    .padding(.vertical, 4)
            }

            TextField("Search Apple Music", text: $musicSearchQuery)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit {
                    Task { await searchMusicPreview() }
                }

            Button {
                Task { await searchMusicPreview() }
            } label: {
                Label(isSearchingMusic ? "Searching music" : "Search music preview", systemImage: "magnifyingglass")
            }
            .disabled(isSearchingMusic || musicSearchQuery.trimmedOrNil == nil)

            if !musicSearchResults.isEmpty {
                ForEach(musicSearchResults.prefix(5)) { song in
                    Button {
                        selectedSearchMusicPreview = CaptureCardItem(
                            draft: song.toDraft(origin: .manual),
                            id: "music-search-\(song.title)-\(song.artistName)",
                            musicPlaybackState: .searchResult
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(song.title)
                                .font(.subheadline.weight(.semibold))
                            Text([song.artistName, song.albumTitle].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let selectedSearchMusicPreview {
                CaptureCardView(
                    item: selectedSearchMusicPreview,
                    provenanceDisplayMode: selectedProvenanceDisplayMode
                )
                    .padding(.vertical, 4)
            }

            if let musicMessage {
                Text(musicMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Music Lab")
        } footer: {
            Text("Live and search previews only update this debug page. They do not save memories.")
        }
    }

    private var placeLabSection: some View {
        Section {
            Picker("Scenario", selection: $selectedPlaceScenarioID) {
                ForEach(CaptureCardLabFixtures.placeScenarios) { scenario in
                    Text(scenario.label).tag(scenario.id)
                }
            }

            Toggle("Privacy blur", isOn: $isPlacePrivacyEnabled)

            Button {
                Task { await generatePlaceSnapshot() }
            } label: {
                Label(isGeneratingPlaceSnapshot ? "Generating map" : "Generate map snapshot", systemImage: "map")
            }
            .disabled(isGeneratingPlaceSnapshot || !selectedPlaceScenario.item.hasCoordinate || isPlacePrivacyEnabled)

            CaptureCardView(
                item: placePreviewCard,
                provenanceDisplayMode: selectedProvenanceDisplayMode
            )
                .padding(.vertical, 4)

            if let placeSnapshotMessage {
                Text(placeSnapshotMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Place Lab")
        } footer: {
            Text("Map snapshots are static images. Cards fall back to a lightweight map texture when no snapshot is available.")
        }
    }

    private var appearanceLabSection: some View {
        Section {
            Picker("Appearance", selection: $selectedAppearanceMode) {
                ForEach(CaptureCardLabAppearanceMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            Picker("Contrast", selection: $selectedAppearanceContrast) {
                ForEach(CaptureCardLabContrastMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            Toggle("Reduce Motion", isOn: $isAppearanceReduceMotionEnabled)

            Picker("Source labels", selection: $selectedProvenanceDisplayMode) {
                ForEach(CaptureCardProvenanceDisplayMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(appearancePreviewCards) { item in
                        CaptureCardView(
                            item: item,
                            reduceMotionOverride: isAppearanceReduceMotionEnabled,
                            highContrastOverride: selectedAppearanceContrast.isHighContrast,
                            provenanceDisplayMode: selectedProvenanceDisplayMode,
                            weatherSymbolMotionLevel: selectedWeatherSymbolMotionLevel,
                            weatherAtmosphereIntensityScale: selectedWeatherIntensity.scale
                        )
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .environment(\.colorScheme, selectedAppearanceMode.colorScheme)
        } header: {
            Text("Appearance Lab")
        } footer: {
            Text("Preview the same card system across light, dark, high contrast, and reduced motion environments.")
        }
    }

    private var originsComparisonSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                Text("Compare the same origin fixtures in production, debug, and hidden source label modes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(CaptureCardProvenanceDisplayMode.allCases) { mode in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(mode.label)
                            .font(.subheadline.weight(.semibold))

                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 12) {
                                ForEach(CaptureCardLabFixtures.origins) { item in
                                    CaptureCardView(
                                        item: item,
                                        provenanceDisplayMode: mode
                                    )
                                }
                            }
                            .scrollTargetLayout()
                            .padding(.vertical, 2)
                        }
                        .scrollIndicators(.hidden)
                        .scrollTargetBehavior(.viewAligned)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 12, trailing: 0))
        } header: {
            Text("Origins")
        }
    }

    private func labSection(title: String, subtitle: String, items: [CaptureCardItem]) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(renderedItems(items)) { item in
                            CaptureCardView(
                                item: item,
                                provenanceDisplayMode: selectedProvenanceDisplayMode,
                                onTap: { toggleSelection(for: item.id) },
                                onRemove: { remove(item.id) }
                            )
                            .scrollTransition(.animated, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.965)
                                    .opacity(phase.isIdentity ? 1 : 0.82)
                            }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 12, trailing: 0))
        } header: {
            Text(title)
        }
    }

    private func renderedItems(_ items: [CaptureCardItem]) -> [CaptureCardItem] {
        items
            .filter { !removedIDs.contains($0.id) }
            .map { item in
                var rendered = item
                if selectedIDs.contains(item.id) {
                    rendered.isSelected.toggle()
                }
                if isShowingMotionState, rendered.kind == .audio || rendered.kind == .music {
                    rendered.isSelected = true
                }
                return rendered
            }
    }

    private func toggleSelection(for id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func remove(_ id: String) {
        _ = withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
            removedIDs.insert(id)
        }
    }

    private var weatherPreviewCard: CaptureCardItem {
        CaptureCardItem(
            id: "weather-lab-\(selectedWeatherStyle.rawValue)",
            kind: .weather,
            origin: selectedWeatherOrigin,
            title: selectedWeatherStyle.label,
            detail: "\(Int(weatherTemperature))°C · \(weatherPreviewHumidity)% humidity · \(weatherPreviewWind) km/h wind",
            metadata: selectedWeatherStyle.symbolName,
            weatherStyle: selectedWeatherStyle,
            isSelected: false,
            isRemovable: selectedWeatherOrigin == .manual || selectedWeatherOrigin == .context
        )
    }

    private var weatherPreviewHumidity: Int {
        switch selectedWeatherStyle {
        case .rain, .heavyRain, .thunderstorm, .fog, .snow:
            return 82
        case .hot:
            return 36
        default:
            return 58
        }
    }

    private var weatherPreviewWind: Int {
        selectedWeatherStyle == .wind ? 48 : 12
    }

    private var selectedMusicFixture: CaptureCardItem {
        CaptureCardLabFixtures.musicFixtures.first(where: { $0.id == selectedMusicFixtureID })
            ?? CaptureCardLabFixtures.musicFixtures[0]
    }

    private var musicFixturePreviewCard: CaptureCardItem {
        var item = selectedMusicFixture
        item.musicPlaybackState = selectedMusicState
        item.metadata = selectedMusicState.label
        item.origin = selectedMusicState == .searchResult ? .manual : item.origin
        if selectedMusicState == .stopped || selectedMusicState == .unavailable {
            item.title = selectedMusicState.label
            item.detail = selectedMusicState == .stopped ? "Playback is stopped, so no context card should be generated." : "Music permission or queue data is unavailable."
            item.origin = nil
            item.isSelected = false
            item.isRemovable = false
        }
        return item
    }

    @MainActor
    private func loadNowPlayingPreview() async {
        isLoadingNowPlaying = true
        musicMessage = nil
        defer { isLoadingNowPlaying = false }

        if let draft = await musicService.captureNowPlaying(origin: .context) {
            liveMusicPreview = CaptureCardItem(
                draft: draft,
                id: "music-live-now-playing",
                musicPlaybackState: .playing
            )
            musicMessage = "Loaded current playing song as a Context preview."
        } else {
            liveMusicPreview = CaptureCardItem(
                id: "music-live-unavailable",
                kind: .status,
                origin: nil,
                state: .normal,
                title: "No current song",
                detail: "No playing song is available, or Music authorization is unavailable.",
                metadata: "No card generated"
            )
            musicMessage = "No music content card was generated."
        }
    }

    @MainActor
    private func searchMusicPreview() async {
        guard let query = musicSearchQuery.trimmedOrNil else { return }
        isSearchingMusic = true
        musicMessage = nil
        defer { isSearchingMusic = false }

        let results = await musicService.searchSongs(query: query, limit: 8)
        musicSearchResults = results
        musicMessage = results.isEmpty ? "No songs found or Music authorization unavailable." : "Choose a result to preview a Manual music card."
    }

    private var selectedPlaceScenario: CapturePlaceLabScenario {
        CaptureCardLabFixtures.placeScenarios.first(where: { $0.id == selectedPlaceScenarioID })
            ?? CaptureCardLabFixtures.placeScenarios[0]
    }

    private var placePreviewCard: CaptureCardItem {
        var item = selectedPlaceScenario.item
        item.mapSnapshotData = placeSnapshotData
        item.isLocationPrivacyEnabled = isPlacePrivacyEnabled
        if isPlacePrivacyEnabled {
            item.metadata = "Privacy"
        }
        return item
    }

    private var appearancePreviewCards: [CaptureCardItem] {
        [
            weatherPreviewCard,
            placePreviewCard,
            musicFixturePreviewCard,
            CaptureCardLabFixtures.allTypes.first(where: { $0.kind == .photo }) ?? CaptureCardLabFixtures.allTypes[0],
            CaptureCardLabFixtures.states.first(where: { $0.state == .error }) ?? CaptureCardLabFixtures.states[0],
        ]
    }

    private var palettePreviewSection: some View {
        labSection(
            title: "Palette Preview",
            subtitle: "Default, weather, map, sampled photo, and music artwork palettes driving borders, text, and content surfaces.",
            items: palettePreviewCards
        )
    }

    private var palettePreviewCards: [CaptureCardItem] {
        [
            CaptureCardItem(kind: .audio, title: "Default", detail: "Fallback type color palette.", durationSeconds: 42),
            CaptureCardItem(kind: .weather, title: "Rain", detail: "18°C · rain palette", weatherStyle: .rain),
            placePreviewCard,
            CaptureCardItem(kind: .photo, title: "Sampled photo", detail: "Thumbnail-derived accent.", thumbnailData: samplePaletteImageData),
            CaptureCardItem(
                kind: .music,
                title: "Artwork color",
                detail: "Album-derived palette",
                artworkPalette: MusicArtworkPalette(
                    backgroundColorHex: "#3B2148",
                    primaryTextColorHex: "#FFFFFF",
                    secondaryTextColorHex: "#D8C6E6"
                ),
                musicPlaybackState: .playing
            ),
        ]
    }

    private var samplePaletteImageData: Data? {
        UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80)).image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
            UIColor.systemOrange.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 18, y: 10, width: 56, height: 56))
        }
        .pngData()
    }

    @MainActor
    private func generatePlaceSnapshot() async {
        isGeneratingPlaceSnapshot = true
        placeSnapshotMessage = nil
        defer { isGeneratingPlaceSnapshot = false }

        let item = selectedPlaceScenario.item
        let data = await CapturePlaceMapSnapshotter.snapshotData(
            latitude: item.latitude,
            longitude: item.longitude,
            privacyEnabled: isPlacePrivacyEnabled
        )
        placeSnapshotData = data
        placeSnapshotMessage = data == nil ? "No snapshot generated. Fallback map texture is still displayed." : "Generated static MapKit snapshot."
    }

    private func resetPlaceSnapshot() {
        placeSnapshotData = nil
        placeSnapshotMessage = nil
    }
}

private enum CaptureCardLabAppearanceMode: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

private enum CaptureCardLabContrastMode: String, CaseIterable, Identifiable {
    case standard
    case increased

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard:
            return "Standard"
        case .increased:
            return "High contrast"
        }
    }

    var isHighContrast: Bool {
        switch self {
        case .standard:
            return false
        case .increased:
            return true
        }
    }
}

private enum CaptureCardLabWeatherIntensity: String, CaseIterable, Identifiable {
    case calm
    case balanced
    case vivid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .calm:
            return "Calm"
        case .balanced:
            return "Balanced"
        case .vivid:
            return "Vivid"
        }
    }

    var scale: Double {
        switch self {
        case .calm:
            return 0.65
        case .balanced:
            return 1
        case .vivid:
            return 1.24
        }
    }
}

private extension CaptureCardItem {
    var hasCoordinate: Bool {
        latitude != nil && longitude != nil
    }
}
