import Foundation

enum CaptureCardKind: String, CaseIterable, Hashable, Sendable {
    case photo
    case audio
    case place
    case weather
    case music
    case link
    case todo
    case status

    var label: String {
        switch self {
        case .photo: return "Photo"
        case .audio: return "Voice"
        case .place: return "Place"
        case .weather: return "Weather"
        case .music: return "Music"
        case .link: return "Link"
        case .todo: return "Task"
        case .status: return "Status"
        }
    }

    var iconName: String {
        switch self {
        case .photo: return "photo.fill"
        case .audio: return "waveform"
        case .place: return "mappin.and.ellipse"
        case .weather: return "cloud.sun.fill"
        case .music: return "music.note"
        case .link: return "link"
        case .todo: return "checklist"
        case .status: return "hourglass"
        }
    }
}

enum CaptureCardVisualState: String, CaseIterable, Hashable, Sendable {
    case normal
    case loading
    case error
    case disabled
}

enum CaptureCardProvenanceDisplayMode: String, CaseIterable, Hashable, Sendable, Identifiable {
    case production
    case debug
    case hidden

    var id: String { rawValue }

    var label: String {
        switch self {
        case .production:
            return "Production"
        case .debug:
            return "Debug"
        case .hidden:
            return "Hidden"
        }
    }

    func visual(for origin: CaptureArtifactOrigin?) -> CaptureCardProvenanceVisual? {
        guard let origin else { return nil }

        switch self {
        case .production:
            return nil
        case .debug:
            return CaptureCardProvenanceVisual(label: origin.captureBadgeLabel, symbolName: nil, isCompact: false)
        case .hidden:
            return nil
        }
    }
}

struct CaptureCardProvenanceVisual: Hashable, Sendable {
    let label: String?
    let symbolName: String?
    let isCompact: Bool
}

enum CaptureWeatherVisualStyle: String, CaseIterable, Hashable, Sendable, Identifiable {
    case sunny
    case clearNight
    case cloudy
    case rain
    case heavyRain
    case snow
    case thunderstorm
    case fog
    case wind
    case hot
    case cold
    case unknown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sunny: return "Sunny"
        case .clearNight: return "Clear night"
        case .cloudy: return "Cloudy"
        case .rain: return "Rain"
        case .heavyRain: return "Heavy rain"
        case .snow: return "Snow"
        case .thunderstorm: return "Thunderstorm"
        case .fog: return "Fog"
        case .wind: return "Wind"
        case .hot: return "Hot"
        case .cold: return "Cold"
        case .unknown: return "Unknown"
        }
    }

    var symbolName: String {
        switch self {
        case .sunny:
            return "sun.max.fill"
        case .clearNight:
            return "moon.stars.fill"
        case .cloudy:
            return "cloud.fill"
        case .rain:
            return "cloud.rain.fill"
        case .heavyRain:
            return "cloud.heavyrain.fill"
        case .snow:
            return "cloud.snow.fill"
        case .thunderstorm:
            return "cloud.bolt.rain.fill"
        case .fog:
            return "cloud.fog.fill"
        case .wind:
            return "wind"
        case .hot:
            return "thermometer.sun.fill"
        case .cold:
            return "thermometer.low"
        case .unknown:
            return "questionmark.circle"
        }
    }

    var symbolMotion: CaptureWeatherSymbolMotion {
        switch self {
        case .sunny, .hot, .fog, .thunderstorm:
            return .pulse
        case .clearNight:
            return .scale
        case .rain, .heavyRain, .snow:
            return .variableColor
        case .wind:
            return .wiggle
        case .cloudy, .cold:
            return .bounce
        case .unknown:
            return .none
        }
    }

    var motionPattern: CaptureWeatherMotionPattern {
        switch self {
        case .sunny, .hot:
            return .sunGlow
        case .clearNight:
            return .nightTwinkle
        case .rain:
            return .rainFall
        case .heavyRain:
            return .heavyRainFall
        case .snow, .cold:
            return .snowDrift
        case .thunderstorm:
            return .thunderstorm
        case .fog, .cloudy:
            return .fogDrift
        case .wind:
            return .windFlow
        case .unknown:
            return .staticPattern
        }
    }

    func resolvedMotionPattern(reduceMotion: Bool) -> CaptureWeatherMotionPattern {
        reduceMotion ? .staticPattern : motionPattern
    }

    var atmosphereSpec: CaptureWeatherAtmosphereSpec {
        CaptureWeatherAtmosphereSpec(
            style: self,
            palette: atmospherePalette,
            motionPattern: motionPattern,
            intensity: atmosphereIntensity
        )
    }

    func resolvedAtmosphereSpec(reduceMotion: Bool) -> CaptureWeatherAtmosphereSpec {
        var spec = atmosphereSpec
        if reduceMotion {
            spec.motionPattern = .staticPattern
            spec.intensity = min(spec.intensity, 0.42)
        }
        return spec
    }

    private var atmospherePalette: CaptureWeatherAtmospherePalette {
        switch self {
        case .sunny:
            return .warmLight
        case .clearNight:
            return .night
        case .cloudy:
            return .softCloud
        case .rain:
            return .coolRain
        case .heavyRain, .thunderstorm:
            return .storm
        case .snow, .cold:
            return .frost
        case .fog:
            return .fog
        case .wind:
            return .wind
        case .hot:
            return .heat
        case .unknown:
            return .neutral
        }
    }

    private var atmosphereIntensity: Double {
        switch self {
        case .sunny, .clearNight, .cloudy, .fog, .wind:
            return 0.62
        case .rain, .snow:
            return 0.72
        case .heavyRain, .thunderstorm, .hot, .cold:
            return 0.86
        case .unknown:
            return 0.36
        }
    }

    static func resolve(
        condition: String?,
        temperatureCelsius: Double? = nil,
        windSpeedKmh: Double? = nil,
        isNight: Bool = false
    ) -> CaptureWeatherVisualStyle {
        let value = condition?.lowercased() ?? ""

        if value.contains("thunder") || value.contains("storm") {
            return .thunderstorm
        }
        if value.contains("heavy rain") || value.contains("downpour") {
            return .heavyRain
        }
        if value.contains("rain") || value.contains("shower") || value.contains("drizzle") {
            return .rain
        }
        if value.contains("snow") || value.contains("sleet") || value.contains("hail") {
            return .snow
        }
        if value.contains("fog") || value.contains("mist") || value.contains("haze") {
            return .fog
        }
        if value.contains("wind") || (windSpeedKmh ?? 0) >= 40 {
            return .wind
        }
        if let temperatureCelsius, temperatureCelsius >= 32 {
            return .hot
        }
        if let temperatureCelsius, temperatureCelsius <= 2 {
            return .cold
        }
        if value.contains("cloud") || value.contains("overcast") {
            return .cloudy
        }
        if value.contains("clear") || value.contains("sun") || value.contains("fair") {
            return isNight ? .clearNight : .sunny
        }
        return isNight ? .clearNight : .unknown
    }
}

enum CaptureWeatherSymbolMotion: String, Hashable, Sendable {
    case none
    case pulse
    case variableColor
    case wiggle
    case bounce
    case scale
}

enum CaptureWeatherSymbolMotionLevel: String, CaseIterable, Hashable, Sendable, Identifiable {
    case staticOnly
    case subtle
    case enhanced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .staticOnly:
            return "Static"
        case .subtle:
            return "Subtle"
        case .enhanced:
            return "Enhanced"
        }
    }
}

enum CaptureWeatherMotionPattern: String, Hashable, Sendable {
    case staticPattern
    case sunGlow
    case nightTwinkle
    case rainFall
    case heavyRainFall
    case snowDrift
    case thunderstorm
    case fogDrift
    case windFlow
}

enum CaptureWeatherAtmospherePalette: String, Hashable, Sendable {
    case warmLight
    case night
    case softCloud
    case coolRain
    case storm
    case frost
    case fog
    case wind
    case heat
    case neutral
}

struct CaptureWeatherAtmosphereSpec: Hashable, Sendable {
    let style: CaptureWeatherVisualStyle
    let palette: CaptureWeatherAtmospherePalette
    var motionPattern: CaptureWeatherMotionPattern
    var intensity: Double
}

enum CaptureMusicPlaybackState: String, CaseIterable, Hashable, Sendable, Identifiable {
    case playing
    case paused
    case stopped
    case unavailable
    case searchResult

    var id: String { rawValue }

    var label: String {
        switch self {
        case .playing: return "Playing"
        case .paused: return "Paused"
        case .stopped: return "Stopped"
        case .unavailable: return "Unavailable"
        case .searchResult: return "Search result"
        }
    }
}

struct CaptureCardItem: Identifiable, Hashable, Sendable {
    let id: String
    var kind: CaptureCardKind
    var origin: CaptureArtifactOrigin?
    var state: CaptureCardVisualState
    var title: String?
    var detail: String
    var metadata: String?
    var thumbnailData: Data?
    var artworkURL: String?
    var artworkPalette: MusicArtworkPalette?
    var latitude: Double?
    var longitude: Double?
    var durationSeconds: Int?
    var weatherStyle: CaptureWeatherVisualStyle?
    var musicPlaybackState: CaptureMusicPlaybackState?
    var mapSnapshotData: Data?
    var isLocationPrivacyEnabled: Bool
    var isSelected: Bool
    var isRemovable: Bool

    var displaysSelection: Bool {
        state == .normal && isSelected
    }

    var allowsPrimaryAction: Bool {
        state == .normal
    }

    var displaysRemoveControl: Bool {
        isRemovable && (state == .normal || state == .error)
    }

    init(
        id: String = UUID().uuidString,
        kind: CaptureCardKind,
        origin: CaptureArtifactOrigin? = .manual,
        state: CaptureCardVisualState = .normal,
        title: String? = nil,
        detail: String,
        metadata: String? = nil,
        thumbnailData: Data? = nil,
        artworkURL: String? = nil,
        artworkPalette: MusicArtworkPalette? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        durationSeconds: Int? = nil,
        weatherStyle: CaptureWeatherVisualStyle? = nil,
        musicPlaybackState: CaptureMusicPlaybackState? = nil,
        mapSnapshotData: Data? = nil,
        isLocationPrivacyEnabled: Bool = false,
        isSelected: Bool = false,
        isRemovable: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.origin = origin
        self.state = state
        self.title = title
        self.detail = detail
        self.metadata = metadata
        self.thumbnailData = thumbnailData
        self.artworkURL = artworkURL
        self.artworkPalette = artworkPalette
        self.latitude = latitude
        self.longitude = longitude
        self.durationSeconds = durationSeconds
        self.weatherStyle = weatherStyle
        self.musicPlaybackState = musicPlaybackState
        self.mapSnapshotData = mapSnapshotData
        self.isLocationPrivacyEnabled = isLocationPrivacyEnabled
        self.isSelected = isSelected
        self.isRemovable = isRemovable
    }
}

extension CaptureCardItem {
    init(attachment item: CaptureComposerAttachmentItem) {
        self.init(
            id: item.id,
            kind: CaptureCardKind(composerKind: item.kind),
            origin: item.origin,
            state: item.isProcessing ? .loading : .normal,
            title: item.kind.label,
            detail: item.detail,
            metadata: item.secondaryText,
            thumbnailData: item.thumbnailData,
            artworkURL: item.artworkURL,
            artworkPalette: item.artworkPalette,
            weatherStyle: item.weatherStyle,
            isSelected: item.isSelected,
            isRemovable: item.isRemovable
        )
    }

    init(
        draft: CaptureArtifactDraft,
        id: String? = nil,
        state: CaptureCardVisualState = .normal,
        musicPlaybackState: CaptureMusicPlaybackState? = nil
    ) {
        switch draft {
        case let .text(title, body, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                kind: .status,
                origin: origin,
                state: state,
                title: title ?? "Text",
                detail: captureCardModelSnippet(body) ?? "Text"
            )
        case let .photo(title, summary, filename, _, thumbnailData, ocrText, _, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                kind: .photo,
                origin: origin,
                state: state,
                title: title,
                detail: [captureCardModelSnippet(summary), captureCardModelSnippet(ocrText), filename.trimmedOrNil].compactMap { $0 }.first ?? "Photo attached",
                metadata: filename.trimmedOrNil,
                thumbnailData: thumbnailData,
                isRemovable: origin == .manual || origin == .context
            )
        case let .audio(title, summary, filename, _, transcriptionText, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                kind: .audio,
                origin: origin,
                state: state,
                title: title ?? "Voice",
                detail: captureCardModelSnippet(transcriptionText) ?? captureCardModelSnippet(summary) ?? "Voice attached",
                metadata: filename.trimmedOrNil,
                isRemovable: origin == .manual || origin == .context
            )
        case let .location(title, summary, latitude, longitude, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                kind: .place,
                origin: origin,
                state: state,
                title: title ?? "Place",
                detail: captureCardModelSnippet(summary) ?? "Location attached",
                metadata: coordinateMetadata(latitude: latitude, longitude: longitude),
                latitude: latitude,
                longitude: longitude,
                isSelected: false,
                isRemovable: origin == .manual || origin == .context
            )
        case let .link(title, url, note, summary, _, thumbnailData, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                kind: .link,
                origin: origin,
                state: state,
                title: title ?? "Link",
                detail: summary.flatMap(captureCardModelSnippet) ?? note.flatMap(captureCardModelSnippet) ?? captureCardModelSnippet(url) ?? "Link attached",
                metadata: URL(string: url)?.host() ?? url,
                thumbnailData: thumbnailData,
                isRemovable: origin == .manual || origin == .context
            )
        case let .todo(title, note, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                kind: .todo,
                origin: origin,
                state: state,
                title: title,
                detail: note.flatMap(captureCardModelSnippet) ?? "Task",
                metadata: "Task",
                isRemovable: origin == .manual || origin == .context
            )
        case let .weather(condition, temp, humidity, windSpeed, uvIndex, latitude, longitude, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                kind: .weather,
                origin: origin,
                state: state,
                title: condition,
                detail: "\(String(format: "%.0f", temp))°C · \(String(format: "%.0f", humidity * 100))% humidity · wind \(String(format: "%.0f", windSpeed)) km/h",
                metadata: "UV \(uvIndex)",
                latitude: latitude,
                longitude: longitude,
                weatherStyle: .resolve(condition: condition, temperatureCelsius: temp, windSpeedKmh: windSpeed),
                isSelected: false,
                isRemovable: origin == .manual || origin == .context
            )
        case let .music(trackName, artistName, albumName, durationSeconds, artworkURL, artworkPalette, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                kind: .music,
                origin: origin,
                state: state,
                title: trackName,
                detail: [artistName.trimmedOrNil, albumName.trimmedOrNil].compactMap { $0 }.joined(separator: " · "),
                metadata: musicPlaybackState?.label ?? (origin == .context ? "Now playing" : "Music"),
                artworkURL: artworkURL,
                artworkPalette: artworkPalette,
                durationSeconds: durationSeconds,
                musicPlaybackState: musicPlaybackState,
                isSelected: false,
                isRemovable: origin == .manual || origin == .context
            )
        }
    }
}

extension CaptureCardKind {
    init(composerKind: CaptureComposerAttachmentItem.Kind) {
        switch composerKind {
        case .photo:
            self = .photo
        case .audio:
            self = .audio
        case .location:
            self = .place
        case .link:
            self = .link
        case .todo:
            self = .todo
        case .weather:
            self = .weather
        case .music:
            self = .music
        case .status:
            self = .status
        }
    }
}

enum CaptureCardLabFixtures {
    static let allTypes: [CaptureCardItem] = [
        CaptureCardItem(
            id: "fixture-photo",
            kind: .photo,
            title: "Weekend light",
            detail: "Three photos from the kitchen table.",
            metadata: "3 images",
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-audio",
            kind: .audio,
            title: "Voice note",
            detail: "I should remember the way this idea clicked after lunch.",
            metadata: "Transcript ready",
            durationSeconds: 74,
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-place",
            kind: .place,
            origin: .context,
            title: "Anfu Road",
            detail: "Shanghai, near the corner cafe.",
            metadata: "31.218, 121.446",
            latitude: 31.218,
            longitude: 121.446,
            isSelected: true
        ),
        CaptureCardItem(
            id: "fixture-weather",
            kind: .weather,
            origin: .context,
            title: "Cloudy",
            detail: "23°C · light wind · humidity 61%",
            metadata: "Captured nearby",
            weatherStyle: .cloudy,
            isSelected: true
        ),
        CaptureCardItem(
            id: "fixture-music",
            kind: .music,
            origin: .context,
            title: "Midnight City",
            detail: "M83 · Hurry Up, We're Dreaming",
            metadata: "Now playing",
            durationSeconds: 244,
            musicPlaybackState: .playing,
            isSelected: true
        ),
        CaptureCardItem(
            id: "fixture-link",
            kind: .link,
            title: "SwiftUI ToolbarItemPlacement",
            detail: "developer.apple.com/documentation/swiftui/toolbaritemplacement",
            metadata: "Apple Developer",
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-todo",
            kind: .todo,
            title: "Follow up",
            detail: "Send the draft invitation before Friday.",
            metadata: "Task",
            isRemovable: true
        ),
    ]

    static let origins: [CaptureCardItem] = CaptureArtifactOrigin.allCases.map { origin in
        CaptureCardItem(
            id: "origin-\(origin.rawValue)",
            kind: .place,
            origin: origin,
            title: "Same place",
            detail: "One place card rendered with \(origin.captureBadgeLabel) origin.",
            metadata: origin.rawValue,
            latitude: 31.218,
            longitude: 121.446,
            isSelected: origin == .context,
            isRemovable: origin == .manual
        )
    }

    static let states: [CaptureCardItem] = [
        CaptureCardItem(
            id: "state-normal",
            kind: .music,
            title: "Normal",
            detail: "A regular card with no transient state.",
            metadata: "Ready"
        ),
        CaptureCardItem(
            id: "state-selected",
            kind: .weather,
            origin: .context,
            title: "Selected",
            detail: "Context cards can be selected without changing their content type.",
            metadata: "Context",
            isSelected: true
        ),
        CaptureCardItem(
            id: "state-loading",
            kind: .status,
            origin: nil,
            state: .loading,
            title: "Collecting context",
            detail: "Looking for nearby place, weather, and music.",
            metadata: "Working"
        ),
        CaptureCardItem(
            id: "state-error",
            kind: .status,
            origin: nil,
            state: .error,
            title: "Context failed",
            detail: "Location permission is unavailable.",
            metadata: "Retry available"
        ),
        CaptureCardItem(
            id: "state-disabled",
            kind: .link,
            state: .disabled,
            title: "Disabled",
            detail: "This card is visible but not currently interactive.",
            metadata: "Unavailable"
        ),
        CaptureCardItem(
            id: "state-removable",
            kind: .photo,
            title: "Removable",
            detail: "Manual attachments can expose a remove affordance.",
            metadata: "Manual",
            isRemovable: true
        ),
    ]

    static let edgeCases: [CaptureCardItem] = [
        CaptureCardItem(
            id: "edge-long",
            kind: .audio,
            title: nil,
            detail: "A very long transcript preview that should wrap cleanly without making the card feel like a form field or requiring the user to create an artificial title before saving a memory.",
            metadata: "12:04",
            durationSeconds: 724,
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-no-image",
            kind: .photo,
            title: nil,
            detail: "Photo has no generated thumbnail yet.",
            metadata: "Processing",
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-manual-music",
            kind: .music,
            origin: .manual,
            title: "Searched song",
            detail: "A manually searched song should not look like automatic context.",
            metadata: "Manual"
        ),
        CaptureCardItem(
            id: "edge-context-weather",
            kind: .weather,
            origin: .context,
            title: "Rain",
            detail: "16°C · umbrella weather",
            metadata: "Context",
            isSelected: false
        ),
    ]

    static let status: [CaptureCardItem] = [
        CaptureCardItem(
            id: "status-context",
            kind: .status,
            origin: nil,
            state: .loading,
            title: "Collecting context",
            detail: "Checking place, weather, and currently playing music."
        ),
        CaptureCardItem(
            id: "status-empty-context",
            kind: .status,
            origin: nil,
            title: "No context found",
            detail: "Nothing automatic will be added unless the user chooses it."
        ),
        CaptureCardItem(
            id: "status-photo-processing",
            kind: .status,
            origin: nil,
            state: .loading,
            title: "Processing photo",
            detail: "Preparing the image attachment."
        ),
        CaptureCardItem(
            id: "status-voice-refining",
            kind: .status,
            origin: nil,
            state: .loading,
            title: "Refining transcript",
            detail: "Cleaning repeated words and generating a concise internal title."
        ),
    ]

    static let musicFixtures: [CaptureCardItem] = [
        CaptureCardItem(
            id: "music-fixture-m83",
            kind: .music,
            origin: .context,
            title: "Midnight City",
            detail: "M83 · Hurry Up, We're Dreaming",
            metadata: "Now playing",
            durationSeconds: 244,
            musicPlaybackState: .playing,
            isSelected: true
        ),
        CaptureCardItem(
            id: "music-fixture-japanese-house",
            kind: .music,
            origin: .manual,
            title: "Sunshine Baby",
            detail: "The Japanese House · In the End It Always Does",
            metadata: "Search result",
            durationSeconds: 220,
            musicPlaybackState: .searchResult,
            isRemovable: true
        ),
        CaptureCardItem(
            id: "music-fixture-paused",
            kind: .music,
            origin: .context,
            title: "Paused song",
            detail: "A context candidate should calm down when playback pauses.",
            metadata: "Paused",
            durationSeconds: 184,
            musicPlaybackState: .paused
        ),
    ]

    static let placeScenarios: [CapturePlaceLabScenario] = [
        CapturePlaceLabScenario(
            id: "current-place",
            label: "Current context",
            item: CaptureCardItem(
                id: "place-current",
                kind: .place,
                origin: .context,
                title: "Anfu Road",
                detail: "Shanghai · near the corner cafe",
                metadata: "31.218, 121.446",
                latitude: 31.218,
                longitude: 121.446,
                isSelected: true
            )
        ),
        CapturePlaceLabScenario(
            id: "manual-pin",
            label: "Manual map pin",
            item: CaptureCardItem(
                id: "place-manual",
                kind: .place,
                origin: .manual,
                title: "Selected point",
                detail: "A hand-picked point on the map.",
                metadata: "31.230, 121.474",
                latitude: 31.230,
                longitude: 121.474,
                isRemovable: true
            )
        ),
        CapturePlaceLabScenario(
            id: "search-result",
            label: "Search result",
            item: CaptureCardItem(
                id: "place-search",
                kind: .place,
                origin: .manual,
                title: "Shanghai Library",
                detail: "1555 Huaihai Middle Road",
                metadata: "Search",
                latitude: 31.207,
                longitude: 121.444,
                isRemovable: true
            )
        ),
        CapturePlaceLabScenario(
            id: "same-name-far",
            label: "Same name far away",
            item: CaptureCardItem(
                id: "place-same-name-far",
                kind: .place,
                origin: .inferred,
                title: "Blue Bottle Coffee",
                detail: "Name match but coordinates should keep it separate.",
                metadata: "Far coordinate",
                latitude: 37.776,
                longitude: -122.423
            )
        ),
        CapturePlaceLabScenario(
            id: "near-different-name",
            label: "Near different name",
            item: CaptureCardItem(
                id: "place-near-different-name",
                kind: .place,
                origin: .context,
                title: "Different reverse geocode",
                detail: "Coordinates are close, but the resolved name changed.",
                metadata: "Nearby",
                latitude: 31.2184,
                longitude: 121.4463,
                isSelected: true
            )
        ),
        CapturePlaceLabScenario(
            id: "no-coordinate",
            label: "No coordinate",
            item: CaptureCardItem(
                id: "place-no-coordinate",
                kind: .place,
                origin: .imported,
                title: "Imported place name",
                detail: "No coordinates available yet.",
                metadata: "No map"
            )
        ),
    ]
}

struct CapturePlaceLabScenario: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let item: CaptureCardItem
}

private func coordinateMetadata(latitude: Double?, longitude: Double?) -> String? {
    guard let latitude, let longitude else { return nil }
    return String(format: "%.3f, %.3f", latitude, longitude)
}

private func captureCardModelSnippet(_ string: String) -> String? {
    let value = string.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return nil }
    let collapsed = value
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    guard collapsed.count > 96 else { return collapsed }
    return String(collapsed.prefix(93)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
}
