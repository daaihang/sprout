import SwiftUI
import UIKit

struct CaptureCardLabView: View {
    @State private var selectedIDs: Set<String> = []
    @State private var removedIDs: Set<String> = []
    @State private var isShowingMotionState = false
    @State private var selectedWeatherConditionCode = "mostlyClear"
    @State private var isWeatherDaylight = true
    @State private var selectedWeatherOrigin: CaptureArtifactOrigin = .context
    @State private var selectedWeatherSymbolMotionLevel: CaptureWeatherSymbolMotionLevel = .subtle
    @State private var selectedWeatherIntensity: CaptureCardLabWeatherIntensity = .balanced
    @State private var isWeatherReduceMotionEnabled = false
    @State private var weatherTemperature = 23.0
    @State private var selectedMusicFixtureID = CaptureCardLabFixtures.musicFixtures.first?.id ?? ""
    @State private var selectedMusicState: CaptureMusicPlaybackState = .playing
    @State private var selectedMusicCardStyle: CaptureMusicCardStyle = .compactRow
    @State private var liveMusicPreview: CaptureCardItem?
    @State private var musicSearchQuery = ""
    @State private var musicSearchResults: [MusicCatalogSongCandidate] = []
    @State private var selectedSearchMusicPreview: CaptureCardItem?
    @State private var isLoadingNowPlaying = false
    @State private var isSearchingMusic = false
    @State private var musicMessage: String?
    @State private var selectedPlaceScenarioID = CaptureCardLabFixtures.placeScenarios.first?.id ?? ""
    @State private var selectedPlaceCardStyle: CapturePlaceCardStyle = .standard
    @State private var placeSnapshotData: Data?
    @State private var isGeneratingPlaceSnapshot = false
    @State private var isPlacePrivacyEnabled = false
    @State private var placeSnapshotMessage: String?
    @State private var selectedPlaceSnapshotAppearance: CaptureCardLabAppearanceMode = .light
    @State private var selectedAppearanceMode: CaptureCardLabAppearanceMode = .light
    @State private var selectedAppearanceContrast: CaptureCardLabContrastMode = .standard
    @State private var isAppearanceReduceMotionEnabled = false
    @State private var selectedProvenanceDisplayMode: CaptureCardProvenanceDisplayMode = .production
    @State private var showsLayoutGuides = false
    @State private var showsFieldAudit = false

    private let musicService = MusicContextService()
    private static let weatherConditionCodes = [
        "blowingDust",
        "clear",
        "cloudy",
        "foggy",
        "haze",
        "mostlyClear",
        "mostlyCloudy",
        "partlyCloudy",
        "smoky",
        "breezy",
        "windy",
        "drizzle",
        "heavyRain",
        "isolatedThunderstorms",
        "rain",
        "sunShowers",
        "scatteredThunderstorms",
        "strongStorms",
        "thunderstorms",
        "frigid",
        "hail",
        "hot",
        "flurries",
        "sleet",
        "snow",
        "sunFlurries",
        "wintryMix",
        "blizzard",
        "blowingSnow",
        "freezingDrizzle",
        "freezingRain",
        "heavySnow",
        "hurricane",
        "tropicalStorm",
    ]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Preview motion states", isOn: $isShowingMotionState.animation(.spring(response: 0.3, dampingFraction: 0.82)))
                    Toggle("Show layout guides", isOn: $showsLayoutGuides)
                    Toggle("Show field audit", isOn: $showsFieldAudit)
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
            photoGroupLabSection
            typeLabSections

            labSection(
                title: String(localized: "debug.captureCardLab.allTypes.title"),
                subtitle: String(localized: "debug.captureCardLab.allTypes.subtitle"),
                items: CaptureCardLabFixtures.allTypes
            )

            originsComparisonSection

            labSection(
                title: String(localized: "debug.captureCardLab.states.title"),
                subtitle: String(localized: "debug.captureCardLab.states.subtitle"),
                items: CaptureCardLabFixtures.states
            )

            labSection(
                title: String(localized: "debug.captureCardLab.edgeCases.title"),
                subtitle: String(localized: "debug.captureCardLab.edgeCases.subtitle"),
                items: CaptureCardLabFixtures.edgeCases
            )

            labSection(
                title: String(localized: "debug.captureCardLab.status.title"),
                subtitle: String(localized: "debug.captureCardLab.status.subtitle"),
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
        .onChange(of: selectedPlaceSnapshotAppearance) { _, _ in
            resetPlaceSnapshot()
        }
    }

    private var weatherLabSection: some View {
        Section {
            Picker("WeatherKit condition", selection: $selectedWeatherConditionCode) {
                ForEach(Self.weatherConditionCodes, id: \.self) { code in
                    Text(code).tag(code)
                }
            }

            Toggle("Daylight", isOn: $isWeatherDaylight)

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

            Stepper(String(format: String(localized: "debug.captureCardLab.weather.temperature.format"), Int(weatherTemperature)), value: $weatherTemperature, in: -15...42, step: 1)

            CaptureCardView(
                presentation: debugPresentation(
                    weatherPreviewCard,
                    reduceMotionOverride: isWeatherReduceMotionEnabled,
                    weatherSymbolMotionLevel: selectedWeatherSymbolMotionLevel,
                    weatherAtmosphereIntensityScale: selectedWeatherIntensity.scale
                )
            )
                .padding(.vertical, 4)
        } header: {
            Text("Weather Lab")
        } footer: {
            Text("Weather cards keep kind=weather. Origin remains debug data; production cards hide source labels.")
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

            Picker("Style", selection: $selectedMusicCardStyle) {
                ForEach(CaptureMusicCardStyle.allCases) { style in
                    Text(style.label).tag(style)
                }
            }

            CaptureCardView(
                presentation: debugPresentation(musicFixturePreviewCard)
            )
                .padding(.vertical, 4)

            Button {
                Task { await loadNowPlayingPreview() }
            } label: {
                Label(isLoadingNowPlaying ? String(localized: "debug.captureCardLab.music.loadingNowPlaying") : String(localized: "debug.captureCardLab.music.loadNowPlaying"), systemImage: "music.note")
            }
            .disabled(isLoadingNowPlaying)

            if let liveMusicPreview {
                CaptureCardView(
                    presentation: debugPresentation(liveMusicPreview)
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
                Label(isSearchingMusic ? String(localized: "debug.captureCardLab.music.searching") : String(localized: "debug.captureCardLab.music.searchPreview"), systemImage: "magnifyingglass")
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
                    presentation: debugPresentation(selectedSearchMusicPreview)
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

            Picker("Style", selection: $selectedPlaceCardStyle) {
                ForEach(CapturePlaceCardStyle.allCases) { style in
                    Text(style.label).tag(style)
                }
            }

            Picker("Snapshot appearance", selection: $selectedPlaceSnapshotAppearance) {
                ForEach(CaptureCardLabAppearanceMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            Button {
                Task { await generatePlaceSnapshot() }
            } label: {
                Label(isGeneratingPlaceSnapshot ? String(localized: "debug.captureCardLab.place.generatingMap") : String(localized: "debug.captureCardLab.place.generateSnapshot"), systemImage: "map")
            }
            .disabled(isGeneratingPlaceSnapshot || !selectedPlaceScenario.item.hasCoordinate || isPlacePrivacyEnabled)

            CaptureCardView(
                presentation: debugPresentation(placePreviewCard)
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
                            presentation: debugPresentation(
                                item,
                                reduceMotionOverride: isAppearanceReduceMotionEnabled,
                                highContrastOverride: selectedAppearanceContrast.isHighContrast,
                                weatherSymbolMotionLevel: selectedWeatherSymbolMotionLevel,
                                weatherAtmosphereIntensityScale: selectedWeatherIntensity.scale
                            )
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
                                        presentation: debugPresentation(
                                            item,
                                            provenanceDisplayMode: mode
                                        )
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
                                presentation: debugPresentation(item),
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

    private func debugPresentation(
        _ item: CaptureCardItem,
        reduceMotionOverride: Bool? = nil,
        highContrastOverride: Bool? = nil,
        provenanceDisplayMode: CaptureCardProvenanceDisplayMode? = nil,
        weatherSymbolMotionLevel: CaptureWeatherSymbolMotionLevel? = nil,
        weatherAtmosphereIntensityScale: Double? = nil
    ) -> CaptureCardPresentation {
        .debug(
            item,
            reduceMotionOverride: reduceMotionOverride,
            highContrastOverride: highContrastOverride,
            provenanceDisplayMode: provenanceDisplayMode ?? selectedProvenanceDisplayMode,
            weatherSymbolMotionLevel: weatherSymbolMotionLevel ?? selectedWeatherSymbolMotionLevel,
            weatherAtmosphereIntensityScale: weatherAtmosphereIntensityScale ?? selectedWeatherIntensity.scale,
            musicCardStyle: selectedMusicCardStyle,
            placeCardStyle: selectedPlaceCardStyle,
            showsLayoutGuides: showsLayoutGuides,
            showsFieldAudit: showsFieldAudit
        )
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
            id: "weather-lab-\(selectedWeatherConditionCode)-\(isWeatherDaylight)",
            kind: .weather,
            origin: selectedWeatherOrigin,
            title: captureWeatherTemperatureTitle(weatherTemperature),
            detail: selectedWeatherConditionCode,
            metadata: captureWeatherMetadata(
                humidity: Double(weatherPreviewHumidity) / 100,
                windSpeedKmh: Double(weatherPreviewWind),
                uvIndex: 3
            ),
            weatherStyle: resolvedWeatherStyle,
            weatherConditionCode: selectedWeatherConditionCode,
            weatherSymbolName: resolvedWeatherStyle.symbolName,
            weatherIsDaylight: isWeatherDaylight,
            isSelected: false,
            isRemovable: selectedWeatherOrigin == .manual || selectedWeatherOrigin == .context
        )
    }

    private var resolvedWeatherStyle: CaptureWeatherVisualStyle {
        .resolve(
            conditionCode: selectedWeatherConditionCode,
            condition: selectedWeatherConditionCode,
            temperatureCelsius: weatherTemperature,
            windSpeedKmh: Double(weatherPreviewWindForConditionCode),
            isDaylight: isWeatherDaylight
        )
    }

    private var weatherPreviewHumidity: Int {
        switch resolvedWeatherStyle {
        case .rain, .heavyRain, .thunderstorm, .fog, .snow:
            return 82
        case .hot:
            return 36
        default:
            return 58
        }
    }

    private var weatherPreviewWind: Int {
        weatherPreviewWindForConditionCode
    }

    private var weatherPreviewWindForConditionCode: Int {
        let normalized = selectedWeatherConditionCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
        return normalized == "windy" || normalized == "breezy" ? 48 : 12
    }

    private var selectedMusicFixture: CaptureCardItem {
        CaptureCardLabFixtures.musicFixtures.first(where: { $0.id == selectedMusicFixtureID })
            ?? CaptureCardLabFixtures.musicFixtures[0]
    }

    private var musicFixturePreviewCard: CaptureCardItem {
        var item = selectedMusicFixture
        if case .music(var payload) = item.payload {
            payload.playbackState = selectedMusicState
            if selectedMusicCardStyle == .cover,
               payload.artworkURL?.trimmedOrNil == nil,
               payload.artworkData == nil {
                payload.artworkData = sampleMusicArtworkData
                payload.artworkPalette = MusicArtworkPalette(
                    backgroundColorHex: "#291539",
                    primaryTextColorHex: "#FFFFFF",
                    secondaryTextColorHex: "#E6D5F2"
                )
            }
            item.payload = .music(payload)
        }
        item.metadata = selectedMusicState.label
        item.origin = selectedMusicState == .searchResult ? .manual : item.origin
        if selectedMusicState == .stopped || selectedMusicState == .unavailable {
            item.title = selectedMusicState.label
            item.detail = selectedMusicState == .stopped
                ? String(localized: "debug.captureCardLab.music.stopped.detail")
                : String(localized: "debug.captureCardLab.music.unavailable.detail")
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
            musicMessage = String(localized: "debug.captureCardLab.music.loadedNowPlaying")
        } else {
            liveMusicPreview = CaptureCardItem(
                id: "music-live-unavailable",
                kind: .status,
                origin: nil,
                state: .normal,
                title: String(localized: "debug.captureCardLab.music.noCurrentSong.title"),
                detail: String(localized: "debug.captureCardLab.music.noCurrentSong.detail"),
                metadata: String(localized: "debug.captureCardLab.music.noCardGenerated")
            )
            musicMessage = String(localized: "debug.captureCardLab.music.noContentCard")
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
        musicMessage = results.isEmpty
            ? String(localized: "debug.captureCardLab.music.noSongsOrAuthorization")
            : String(localized: "debug.captureCardLab.music.chooseResult")
    }

    private var selectedPlaceScenario: CapturePlaceLabScenario {
        CaptureCardLabFixtures.placeScenarios.first(where: { $0.id == selectedPlaceScenarioID })
            ?? CaptureCardLabFixtures.placeScenarios[0]
    }

    private var placePreviewCard: CaptureCardItem {
        var item = selectedPlaceScenario.item
        if case .place(var payload) = item.payload {
            payload.mapSnapshotData = placeSnapshotData
            payload.isPrivacyEnabled = isPlacePrivacyEnabled
            item.payload = .place(payload)
        }
        if isPlacePrivacyEnabled {
            item.metadata = String(localized: "debug.captureCardLab.place.privacy")
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
            title: String(localized: "debug.captureCardLab.palette.title"),
            subtitle: String(localized: "debug.captureCardLab.palette.subtitle"),
            items: palettePreviewCards
        )
    }

    private var photoGroupLabSection: some View {
        labSection(
            title: String(localized: "debug.captureCardLab.photoGroups.title"),
            subtitle: String(localized: "debug.captureCardLab.photoGroups.subtitle"),
            items: photoGroupPreviewCards
        )
    }

    private var typeLabSections: some View {
        ForEach(CaptureCardKind.allCases, id: \.self) { kind in
            labSection(
                title: "\(kind.label) Debug",
                subtitle: String(localized: "debug.captureCardLab.type.subtitle"),
                items: typeLabItems(for: kind)
            )
        }
    }

    private func typeLabItems(for kind: CaptureCardKind) -> [CaptureCardItem] {
        var items = (CaptureCardLabFixtures.allTypes
            + CaptureCardLabFixtures.states
            + CaptureCardLabFixtures.edgeCases
            + CaptureCardLabFixtures.status
            + photoGroupPreviewCards
            + CaptureCardLabFixtures.musicFixtures
            + CaptureCardLabFixtures.placeScenarios.map(\.item))
            .filter { $0.kind == kind }
        if kind == .weather {
            items.insert(weatherPreviewCard, at: 0)
        }
        if kind == .place {
            items.insert(placePreviewCard, at: 0)
        }
        if kind == .music {
            items.insert(musicFixturePreviewCard, at: 0)
        }
        return Array(Dictionary(grouping: items, by: \.id).compactMap { $0.value.first }.prefix(10))
    }

    private var palettePreviewCards: [CaptureCardItem] {
        [
            CaptureCardItem(kind: .audio, title: String(localized: "debug.captureCardLab.palette.default.title"), detail: String(localized: "debug.captureCardLab.palette.default.detail"), durationSeconds: 42),
            CaptureCardItem(kind: .weather, title: String(localized: "capture.card.weather.rain"), detail: String(localized: "debug.captureCardLab.palette.weather.detail"), weatherStyle: .rain),
            placePreviewCard,
            CaptureCardItem(kind: .photo, title: String(localized: "debug.captureCardLab.palette.photo.title"), detail: String(localized: "debug.captureCardLab.palette.photo.detail"), thumbnailData: samplePaletteImageData),
            CaptureCardItem(
                kind: .music,
                title: String(localized: "debug.captureCardLab.palette.music.title"),
                detail: String(localized: "debug.captureCardLab.palette.music.detail"),
                thumbnailData: sampleMusicArtworkData,
                artworkPalette: MusicArtworkPalette(
                    backgroundColorHex: "#3B2148",
                    primaryTextColorHex: "#FFFFFF",
                    secondaryTextColorHex: "#D8C6E6"
                ),
                musicPlaybackState: .playing
            ),
        ]
    }

    private var photoGroupPreviewCards: [CaptureCardItem] {
        CaptureCardLabFixtures.photoGroups.map { item in
            var preview = item
            if case .photo(var payload) = preview.payload {
                payload.thumbnailData = samplePaletteImageData
                preview.payload = .photo(payload)
            }
            return preview
        }
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

    private var sampleMusicArtworkData: Data? {
        UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120)).image { context in
            UIColor(red: 0.16, green: 0.08, blue: 0.24, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 120))
            UIColor(red: 0.92, green: 0.24, blue: 0.58, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 18, y: 18, width: 84, height: 84))
            UIColor(red: 0.96, green: 0.76, blue: 0.38, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 42, y: 34, width: 58, height: 58))
        }
        .pngData()
    }

    @MainActor
    private func generatePlaceSnapshot() async {
        isGeneratingPlaceSnapshot = true
        placeSnapshotMessage = nil
        defer { isGeneratingPlaceSnapshot = false }

        let item = selectedPlaceScenario.item
        guard case let .place(payload) = item.payload else { return }
        let data = await CapturePlaceMapSnapshotter.snapshotData(
            latitude: payload.latitude,
            longitude: payload.longitude,
            privacyEnabled: isPlacePrivacyEnabled,
            interfaceStyle: selectedPlaceSnapshotAppearance.userInterfaceStyle
        )
        placeSnapshotData = data
        placeSnapshotMessage = data == nil
            ? String(localized: "debug.captureCardLab.place.snapshotFailed")
            : String(localized: "debug.captureCardLab.place.snapshotGenerated")
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
            return String(localized: "debug.captureCardLab.appearance.light")
        case .dark:
            return String(localized: "debug.captureCardLab.appearance.dark")
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

    var userInterfaceStyle: UIUserInterfaceStyle {
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
            return String(localized: "debug.captureCardLab.contrast.standard")
        case .increased:
            return String(localized: "debug.captureCardLab.contrast.high")
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
            return String(localized: "debug.captureCardLab.intensity.calm")
        case .balanced:
            return String(localized: "debug.captureCardLab.intensity.balanced")
        case .vivid:
            return String(localized: "debug.captureCardLab.intensity.vivid")
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
        guard case let .place(payload) = payload else { return false }
        return payload.latitude != nil && payload.longitude != nil
    }
}
