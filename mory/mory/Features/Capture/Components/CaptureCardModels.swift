import CoreGraphics
import Foundation

nonisolated func captureWeatherTemperatureTitle(_ temperatureCelsius: Double) -> String {
    String(format: String(localized: "capture.card.weather.temperature.format"), temperatureCelsius)
}

nonisolated func captureWeatherMetadata(humidity: Double, windSpeedKmh: Double, uvIndex: Int) -> String {
    String(
        format: String(localized: "capture.card.weather.metadata.format"),
        humidity * 100,
        windSpeedKmh,
        uvIndex
    )
}

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
        case .photo: return String(localized: "capture.card.kind.photo")
        case .audio: return String(localized: "capture.card.kind.audio")
        case .place: return String(localized: "capture.card.kind.place")
        case .weather: return String(localized: "capture.card.kind.weather")
        case .music: return String(localized: "capture.card.kind.music")
        case .link: return String(localized: "capture.card.kind.link")
        case .todo: return String(localized: "capture.card.kind.todo")
        case .status: return String(localized: "capture.card.kind.status")
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
            return String(localized: "capture.card.provenanceDisplay.production")
        case .debug:
            return String(localized: "capture.card.provenanceDisplay.debug")
        case .hidden:
            return String(localized: "capture.card.provenanceDisplay.hidden")
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
        case .sunny: return String(localized: "capture.card.weather.sunny")
        case .clearNight: return String(localized: "capture.card.weather.clearNight")
        case .cloudy: return String(localized: "capture.card.weather.cloudy")
        case .rain: return String(localized: "capture.card.weather.rain")
        case .heavyRain: return String(localized: "capture.card.weather.heavyRain")
        case .snow: return String(localized: "capture.card.weather.snow")
        case .thunderstorm: return String(localized: "capture.card.weather.thunderstorm")
        case .fog: return String(localized: "capture.card.weather.fog")
        case .wind: return String(localized: "capture.card.weather.wind")
        case .hot: return String(localized: "capture.card.weather.hot")
        case .cold: return String(localized: "capture.card.weather.cold")
        case .unknown: return String(localized: "capture.card.weather.unknown")
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

    nonisolated static func resolve(
        conditionCode: String?,
        condition: String? = nil,
        temperatureCelsius: Double? = nil,
        windSpeedKmh: Double? = nil,
        isDaylight: Bool? = nil
    ) -> CaptureWeatherVisualStyle {
        if let style = resolveOfficialConditionCode(conditionCode, isDaylight: isDaylight) {
            return style
        }
        return resolve(
            condition: condition,
            temperatureCelsius: temperatureCelsius,
            windSpeedKmh: windSpeedKmh,
            isNight: isDaylight == false
        )
    }

    nonisolated static func resolve(
        condition: String?,
        temperatureCelsius: Double? = nil,
        windSpeedKmh: Double? = nil,
        isNight: Bool = false
    ) -> CaptureWeatherVisualStyle {
        let value = condition?.lowercased() ?? ""

        if value.contains("thunder") || value.contains("storm") || value.contains("雷") || value.contains("台风") || value.contains("飓风") || value.contains("冰雹") {
            return .thunderstorm
        }
        if value.contains("heavy rain") || value.contains("downpour") || value.contains("暴雨") || value.contains("大雨") {
            return .heavyRain
        }
        if value.contains("snow") || value.contains("sleet") || value.contains("雪") || value.contains("雨夹雪") || value.contains("冻雨") {
            return .snow
        }
        if value.contains("rain") || value.contains("shower") || value.contains("drizzle") || value.contains("雨") || value.contains("阵雨") {
            return .rain
        }
        if value.contains("fog") || value.contains("mist") || value.contains("haze") || value.contains("雾") || value.contains("霾") || value.contains("烟") {
            return .fog
        }
        if value.contains("wind") || value.contains("breezy") || value.contains("风") || (windSpeedKmh ?? 0) >= 40 {
            return .wind
        }
        if value.contains("hot") || value.contains("炎热") {
            return .hot
        }
        if let temperatureCelsius, temperatureCelsius >= 32 {
            return .hot
        }
        if value.contains("frigid") || value.contains("cold") || value.contains("寒冷") {
            return .cold
        }
        if let temperatureCelsius, temperatureCelsius <= 2 {
            return .cold
        }
        if value.contains("cloud") || value.contains("overcast") || value.contains("多云") || value.contains("阴") {
            return .cloudy
        }
        if value.contains("clear") || value.contains("sun") || value.contains("fair") || value.contains("晴") || value.contains("无云") {
            return isNight ? .clearNight : .sunny
        }
        return isNight ? .clearNight : .unknown
    }

    private nonisolated static func resolveOfficialConditionCode(
        _ conditionCode: String?,
        isDaylight: Bool?
    ) -> CaptureWeatherVisualStyle? {
        guard let normalized = conditionCode?.normalizedWeatherConditionCode else { return nil }
        switch normalized {
        case "clear", "mostlyclear":
            return isDaylight == false ? .clearNight : .sunny
        case "partlycloudy", "mostlycloudy", "cloudy":
            return .cloudy
        case "foggy", "haze", "smoky", "blowingdust":
            return .fog
        case "breezy", "windy":
            return .wind
        case "drizzle", "rain", "sunshowers":
            return .rain
        case "heavyrain":
            return .heavyRain
        case "isolatedthunderstorms", "scatteredthunderstorms", "strongstorms", "thunderstorms", "tropicalstorm", "hurricane", "hail":
            return .thunderstorm
        case "flurries", "sleet", "snow", "sunflurries", "wintrymix", "blizzard", "blowingsnow", "freezingdrizzle", "freezingrain", "heavysnow":
            return .snow
        case "hot":
            return .hot
        case "frigid":
            return .cold
        default:
            return nil
        }
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
            return String(localized: "capture.card.motion.static")
        case .subtle:
            return String(localized: "capture.card.motion.subtle")
        case .enhanced:
            return String(localized: "capture.card.motion.enhanced")
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
        case .playing: return String(localized: "capture.card.music.playing")
        case .paused: return String(localized: "capture.card.music.paused")
        case .stopped: return String(localized: "capture.card.music.stopped")
        case .unavailable: return String(localized: "capture.card.music.unavailable")
        case .searchResult: return String(localized: "capture.card.music.searchResult")
        }
    }
}

enum CaptureMusicCardStyle: String, CaseIterable, Hashable, Sendable, Identifiable {
    case compactRow
    case compactTile
    case cover
    case auto

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compactRow: return String(localized: "capture.card.music.style.compactRow")
        case .compactTile: return String(localized: "capture.card.music.style.compactTile")
        case .cover: return String(localized: "capture.card.music.style.cover")
        case .auto: return String(localized: "capture.card.music.style.auto")
        }
    }

    func resolved(for item: CaptureCardItem) -> CaptureMusicCardStyle {
        switch self {
        case .compactRow:
            return .compactRow
        case .compactTile:
            return .compactTile
        case .cover:
            return .cover
        case .auto:
            return .compactRow
        }
    }
}

enum CapturePlaceCardStyle: String, CaseIterable, Hashable, Sendable, Identifiable {
    case standard
    case immersive
    case auto

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: return String(localized: "capture.card.place.style.standard")
        case .immersive: return String(localized: "capture.card.place.style.immersive")
        case .auto: return String(localized: "capture.card.place.style.auto")
        }
    }

    func resolved(for item: CaptureCardItem) -> CapturePlaceCardStyle {
        switch self {
        case .standard:
            return .standard
        case .immersive:
            return .immersive
        case .auto:
            return item.mapSnapshotData == nil ? .standard : .standard
        }
    }
}

enum CapturePhotoGroupStyle: String, CaseIterable, Hashable, Sendable, Identifiable {
    case mosaic
    case stack
    case carousel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mosaic: return String(localized: "capture.card.photoGroup.mosaic")
        case .stack: return String(localized: "capture.card.photoGroup.stack")
        case .carousel: return String(localized: "capture.card.photoGroup.carousel")
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
    var photoCount: Int
    var photoGroupStyle: CapturePhotoGroupStyle?
    var artworkURL: String?
    var artworkPalette: MusicArtworkPalette?
    var latitude: Double?
    var longitude: Double?
    var durationSeconds: Int?
    var weatherStyle: CaptureWeatherVisualStyle?
    var weatherConditionCode: String?
    var weatherSymbolName: String?
    var weatherIsDaylight: Bool?
    var musicPlaybackState: CaptureMusicPlaybackState?
    var mapSnapshotData: Data?
    var isLocationPrivacyEnabled: Bool
    var isSelected: Bool
    var isRemovable: Bool

    var displaysSelection: Bool {
        state == .normal && isSelected && !displaysRemoveControl
    }

    var allowsPrimaryAction: Bool {
        state == .normal
    }

    var displaysRemoveControl: Bool {
        isRemovable && (state == .normal || state == .error)
    }

    var hasTrailingControl: Bool {
        state == .loading || state == .error || displaysRemoveControl || displaysSelection
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
        photoCount: Int = 1,
        photoGroupStyle: CapturePhotoGroupStyle? = nil,
        artworkURL: String? = nil,
        artworkPalette: MusicArtworkPalette? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        durationSeconds: Int? = nil,
        weatherStyle: CaptureWeatherVisualStyle? = nil,
        weatherConditionCode: String? = nil,
        weatherSymbolName: String? = nil,
        weatherIsDaylight: Bool? = nil,
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
        self.photoCount = photoCount
        self.photoGroupStyle = photoGroupStyle
        self.artworkURL = artworkURL
        self.artworkPalette = artworkPalette
        self.latitude = latitude
        self.longitude = longitude
        self.durationSeconds = durationSeconds
        self.weatherStyle = weatherStyle
        self.weatherConditionCode = weatherConditionCode
        self.weatherSymbolName = weatherSymbolName
        self.weatherIsDaylight = weatherIsDaylight
        self.musicPlaybackState = musicPlaybackState
        self.mapSnapshotData = mapSnapshotData
        self.isLocationPrivacyEnabled = isLocationPrivacyEnabled
        self.isSelected = isSelected
        self.isRemovable = isRemovable
    }
}

extension CaptureCardItem {
    var hasArtwork: Bool {
        kind == .music && (artworkURL?.trimmedOrNil != nil || thumbnailData != nil)
    }
}

extension CaptureCardItem {
    init(attachment item: CaptureComposerAttachmentItem) {
        self.init(
            id: item.id,
            kind: CaptureCardKind(composerKind: item.kind),
            origin: item.origin,
            state: item.isProcessing ? .loading : .normal,
            title: item.title ?? item.kind.label,
            detail: item.detail,
            metadata: item.metadata ?? item.secondaryText,
            thumbnailData: item.thumbnailData,
            artworkURL: item.artworkURL,
            artworkPalette: item.artworkPalette,
            latitude: item.latitude,
            longitude: item.longitude,
            weatherStyle: item.weatherStyle,
            weatherConditionCode: item.weatherConditionCode,
            weatherSymbolName: item.weatherSymbolName,
            weatherIsDaylight: item.weatherIsDaylight,
            isSelected: item.isSelected,
            isRemovable: item.isRemovable
        )
    }

    init(artifact: Artifact, state: CaptureCardVisualState = .normal) {
        switch artifact.kind {
        case .text:
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                kind: .status,
                origin: artifact.captureCardOrigin,
                state: state,
                title: artifact.title.trimmedOrNil ?? String(localized: "capture.card.kind.text"),
                detail: captureCardModelSnippet(artifact.textContent)
                    ?? captureCardModelSnippet(artifact.summary)
                    ?? String(localized: "capture.card.kind.text")
            )
        case .photo:
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                kind: .photo,
                origin: artifact.captureCardOrigin,
                state: state,
                title: artifact.title.trimmedOrNil,
                detail: captureCardModelSnippet(artifact.summary)
                    ?? captureCardModelSnippet(artifact.textContent)
                    ?? String(localized: "capture.card.photo.attached"),
                metadata: artifact.mediaRef?.filename.trimmedOrNil,
                thumbnailData: artifact.previewPayload ?? artifact.binaryPayload,
                isRemovable: false
            )
        case .audio:
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                kind: .audio,
                origin: artifact.captureCardOrigin,
                state: state,
                title: artifact.title.trimmedOrNil ?? String(localized: "capture.card.kind.audio"),
                detail: artifact.metadata["transcriptionText"].flatMap(captureCardModelSnippet)
                    ?? captureCardModelSnippet(artifact.textContent)
                    ?? captureCardModelSnippet(artifact.summary)
                    ?? String(localized: "capture.card.audio.attached"),
                metadata: artifact.mediaRef?.filename.trimmedOrNil,
                isRemovable: false
            )
        case .music:
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                kind: .music,
                origin: artifact.captureCardOrigin,
                state: state,
                title: artifact.metadata["trackName"]?.trimmedOrNil
                    ?? artifact.title.trimmedOrNil
                    ?? String(localized: "capture.card.kind.music"),
                detail: [
                    artifact.metadata["artistName"]?.trimmedOrNil,
                    artifact.metadata["albumName"]?.trimmedOrNil
                ]
                .compactMap { $0 }
                .joined(separator: " · ")
                .trimmedOrNil
                    ?? captureCardModelSnippet(artifact.summary)
                    ?? String(localized: "capture.card.kind.music"),
                metadata: nil,
                thumbnailData: artifact.previewPayload ?? artifact.binaryPayload,
                artworkURL: artifact.metadata["artworkURL"]?.trimmedOrNil,
                artworkPalette: artifact.captureCardArtworkPalette,
                durationSeconds: artifact.metadata["durationSeconds"].flatMap(Int.init),
                musicPlaybackState: .stopped,
                isRemovable: false
            )
        case .link:
            let url = artifact.metadata["url"]?.trimmedOrNil
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                kind: .link,
                origin: artifact.captureCardOrigin,
                state: state,
                title: artifact.title.trimmedOrNil ?? String(localized: "capture.card.kind.link"),
                detail: captureCardModelSnippet(artifact.summary)
                    ?? captureCardModelSnippet(artifact.textContent)
                    ?? url
                    ?? String(localized: "capture.card.link.attached"),
                metadata: url.flatMap { URL(string: $0)?.host() },
                thumbnailData: artifact.previewPayload,
                isRemovable: false
            )
        case .location:
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                kind: .place,
                origin: artifact.captureCardOrigin,
                state: state,
                title: artifact.title.trimmedOrNil ?? String(localized: "capture.card.kind.place"),
                detail: captureCardModelSnippet(artifact.summary)
                    ?? captureCardModelSnippet(artifact.textContent)
                    ?? String(localized: "capture.card.place.attached"),
                metadata: nil,
                latitude: artifact.metadata["latitude"].flatMap(Double.init),
                longitude: artifact.metadata["longitude"].flatMap(Double.init),
                isRemovable: false
            )
        case .weather:
            let condition = artifact.metadata["condition"]?.trimmedOrNil
                ?? artifact.summary.trimmedOrNil
                ?? artifact.title.trimmedOrNil
                ?? String(localized: "capture.card.kind.weather")
            let temperature = artifact.metadata["temperatureCelsius"].flatMap(Double.init)
            let windSpeed = artifact.metadata["windSpeedKmh"].flatMap(Double.init)
            let humidity = artifact.metadata["humidity"].flatMap(Double.init)
            let uvIndex = artifact.metadata["uvIndex"].flatMap(Int.init)
            let isDaylight = artifact.metadata["isDaylight"].flatMap(Bool.init)
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                kind: .weather,
                origin: artifact.captureCardOrigin,
                state: state,
                title: temperature.map(captureWeatherTemperatureTitle) ?? artifact.title.trimmedOrNil,
                detail: condition,
                metadata: Self.weatherMetadata(humidity: humidity, windSpeedKmh: windSpeed, uvIndex: uvIndex),
                latitude: artifact.metadata["latitude"].flatMap(Double.init),
                longitude: artifact.metadata["longitude"].flatMap(Double.init),
                weatherStyle: .resolve(
                    conditionCode: artifact.metadata["conditionCode"],
                    condition: condition,
                    temperatureCelsius: temperature,
                    windSpeedKmh: windSpeed,
                    isDaylight: isDaylight
                ),
                weatherConditionCode: artifact.metadata["conditionCode"]?.trimmedOrNil,
                weatherSymbolName: artifact.metadata["symbolName"]?.trimmedOrNil,
                weatherIsDaylight: isDaylight,
                isRemovable: false
            )
        case .todo:
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                kind: .todo,
                origin: artifact.captureCardOrigin,
                state: state,
                title: artifact.title.trimmedOrNil ?? String(localized: "capture.card.kind.todo"),
                detail: captureCardModelSnippet(artifact.summary)
                    ?? captureCardModelSnippet(artifact.textContent)
                    ?? String(localized: "capture.card.kind.todo"),
                metadata: nil,
                isRemovable: false
            )
        case .document:
            self.init(
                id: "artifact-\(artifact.id.uuidString)",
                kind: .status,
                origin: artifact.captureCardOrigin,
                state: state,
                title: artifact.title.trimmedOrNil ?? String(localized: "capture.card.kind.status"),
                detail: captureCardModelSnippet(artifact.summary)
                    ?? captureCardModelSnippet(artifact.textContent)
                    ?? artifact.mediaRef?.filename
                    ?? String(localized: "capture.card.kind.status"),
                metadata: artifact.mediaRef?.filename.trimmedOrNil,
                isRemovable: false
            )
        }
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
                title: title ?? String(localized: "capture.card.kind.text"),
                detail: captureCardModelSnippet(body) ?? String(localized: "capture.card.kind.text")
            )
        case let .photo(title, summary, filename, _, thumbnailData, ocrText, _, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                kind: .photo,
                origin: origin,
                state: state,
                title: title,
                detail: [captureCardModelSnippet(summary), captureCardModelSnippet(ocrText), filename.trimmedOrNil].compactMap { $0 }.first ?? String(localized: "capture.card.photo.attached"),
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
                title: title ?? String(localized: "capture.card.kind.audio"),
                detail: captureCardModelSnippet(transcriptionText) ?? captureCardModelSnippet(summary) ?? String(localized: "capture.card.audio.attached"),
                metadata: filename.trimmedOrNil,
                isRemovable: origin == .manual || origin == .context
            )
        case let .location(title, summary, latitude, longitude, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                kind: .place,
                origin: origin,
                state: state,
                title: title ?? String(localized: "capture.card.kind.place"),
                detail: captureCardModelSnippet(summary) ?? String(localized: "capture.card.place.attached"),
                metadata: nil,
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
                title: title ?? String(localized: "capture.card.kind.link"),
                detail: summary.flatMap(captureCardModelSnippet) ?? note.flatMap(captureCardModelSnippet) ?? captureCardModelSnippet(url) ?? String(localized: "capture.card.link.attached"),
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
                detail: note.flatMap(captureCardModelSnippet) ?? String(localized: "capture.card.kind.todo"),
                metadata: String(localized: "capture.card.kind.todo"),
                isRemovable: origin == .manual || origin == .context
            )
        case let .weather(condition, temp, humidity, windSpeed, uvIndex, latitude, longitude, conditionCode, symbolName, isDaylight, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                kind: .weather,
                origin: origin,
                state: state,
                title: captureWeatherTemperatureTitle(temp),
                detail: condition,
                metadata: captureWeatherMetadata(humidity: humidity, windSpeedKmh: windSpeed, uvIndex: uvIndex),
                latitude: latitude,
                longitude: longitude,
                weatherStyle: .resolve(
                    conditionCode: conditionCode,
                    condition: condition,
                    temperatureCelsius: temp,
                    windSpeedKmh: windSpeed,
                    isDaylight: isDaylight
                ),
                weatherConditionCode: conditionCode,
                weatherSymbolName: symbolName,
                weatherIsDaylight: isDaylight,
                isSelected: false,
                isRemovable: origin == .manual || origin == .context
            )
        case let .music(trackName, artistName, albumName, durationSeconds, artworkURL, artworkData, artworkPalette, origin):
            self.init(
                id: id ?? "draft-\(draft.id)",
                kind: .music,
                origin: origin,
                state: state,
                title: trackName,
                detail: [artistName.trimmedOrNil, albumName.trimmedOrNil].compactMap { $0 }.joined(separator: " · "),
                metadata: nil,
                thumbnailData: artworkData,
                artworkURL: artworkURL,
                artworkPalette: artworkPalette,
                durationSeconds: durationSeconds,
                musicPlaybackState: musicPlaybackState,
                isSelected: false,
                isRemovable: origin == .manual || origin == .context
            )
        }
    }

    private static func weatherMetadata(humidity: Double?, windSpeedKmh: Double?, uvIndex: Int?) -> String? {
        guard let humidity, let windSpeedKmh, let uvIndex else { return nil }
        return captureWeatherMetadata(humidity: humidity, windSpeedKmh: windSpeedKmh, uvIndex: uvIndex)
    }
}

private extension Artifact {
    var captureCardOrigin: CaptureArtifactOrigin? {
        metadata["captureOrigin"].flatMap(CaptureArtifactOrigin.init(rawValue:))
    }

    var captureCardArtworkPalette: MusicArtworkPalette? {
        let palette = MusicArtworkPalette(
            backgroundColorHex: metadata["artworkBackgroundColor"]?.trimmedOrNil,
            primaryTextColorHex: metadata["artworkPrimaryTextColor"]?.trimmedOrNil,
            secondaryTextColorHex: metadata["artworkSecondaryTextColor"]?.trimmedOrNil
        )
        return palette.isEmpty ? nil : palette
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
            title: String(localized: "debug.captureCardLab.fixture.photo.title"),
            detail: String(localized: "debug.captureCardLab.fixture.photo.detail"),
            metadata: String(format: String(localized: "capture.card.photo.count.format"), 3),
            photoCount: 3,
            photoGroupStyle: .mosaic,
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-audio",
            kind: .audio,
            title: String(localized: "debug.captureCardLab.fixture.audio.title"),
            detail: String(localized: "debug.captureCardLab.fixture.audio.detail"),
            metadata: String(localized: "debug.captureCardLab.fixture.audio.metadata"),
            durationSeconds: 74,
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-place",
            kind: .place,
            origin: .context,
            title: String(localized: "debug.captureCardLab.fixture.place.title"),
            detail: String(localized: "debug.captureCardLab.fixture.place.detail"),
            metadata: "31.218, 121.446",
            latitude: 31.218,
            longitude: 121.446,
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-weather",
            kind: .weather,
            origin: .context,
            title: String(localized: "capture.card.weather.cloudy"),
            detail: "23°C · light wind · humidity 61%",
            metadata: String(localized: "debug.captureCardLab.fixture.weather.metadata"),
            weatherStyle: .cloudy,
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-music",
            kind: .music,
            origin: .context,
            title: "Midnight City",
            detail: "M83 · Hurry Up, We're Dreaming",
            metadata: String(localized: "capture.card.music.nowPlaying"),
            durationSeconds: 244,
            musicPlaybackState: .playing,
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-link",
            kind: .link,
            title: "SwiftUI ToolbarItemPlacement",
            detail: "developer.apple.com/documentation/swiftui/toolbaritemplacement",
            metadata: String(localized: "debug.captureCardLab.fixture.link.metadata"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "fixture-todo",
            kind: .todo,
            title: String(localized: "debug.captureCardLab.fixture.todo.title"),
            detail: String(localized: "debug.captureCardLab.fixture.todo.detail"),
            metadata: String(localized: "capture.card.kind.todo"),
            isRemovable: true
        ),
    ]

    static let origins: [CaptureCardItem] = CaptureArtifactOrigin.allCases.map { origin in
        CaptureCardItem(
            id: "origin-\(origin.rawValue)",
            kind: .place,
            origin: origin,
            title: String(localized: "debug.captureCardLab.origins.title"),
            detail: String(localized: "debug.captureCardLab.origins.detail"),
            metadata: nil,
            latitude: 31.218,
            longitude: 121.446,
            isSelected: false,
            isRemovable: false
        )
    }

    static let states: [CaptureCardItem] = [
        CaptureCardItem(
            id: "state-normal",
            kind: .music,
            title: String(localized: "debug.captureCardLab.state.normal.title"),
            detail: String(localized: "debug.captureCardLab.state.normal.detail"),
            metadata: String(localized: "debug.captureCardLab.state.normal.metadata")
        ),
        CaptureCardItem(
            id: "state-selected",
            kind: .weather,
            title: String(localized: "debug.captureCardLab.state.selected.title"),
            detail: String(localized: "debug.captureCardLab.state.selected.detail"),
            metadata: String(localized: "capture.card.selected"),
            isSelected: true
        ),
        CaptureCardItem(
            id: "state-loading",
            kind: .status,
            origin: nil,
            state: .loading,
            title: String(localized: "debug.captureCardLab.state.loading.title"),
            detail: String(localized: "debug.captureCardLab.state.loading.detail"),
            metadata: String(localized: "capture.card.kind.working")
        ),
        CaptureCardItem(
            id: "state-error",
            kind: .status,
            origin: nil,
            state: .error,
            title: String(localized: "debug.captureCardLab.state.error.title"),
            detail: String(localized: "debug.captureCardLab.state.error.detail"),
            metadata: String(localized: "debug.captureCardLab.state.error.metadata")
        ),
        CaptureCardItem(
            id: "state-disabled",
            kind: .link,
            state: .disabled,
            title: String(localized: "debug.captureCardLab.state.disabled.title"),
            detail: String(localized: "debug.captureCardLab.state.disabled.detail"),
            metadata: String(localized: "capture.card.music.unavailable")
        ),
        CaptureCardItem(
            id: "state-removable",
            kind: .photo,
            title: String(localized: "debug.captureCardLab.state.removable.title"),
            detail: String(localized: "debug.captureCardLab.state.removable.detail"),
            metadata: String(localized: "debug.captureCardLab.state.removable.metadata"),
            isRemovable: true
        ),
    ]

    static let edgeCases: [CaptureCardItem] = [
        CaptureCardItem(
            id: "edge-long",
            kind: .audio,
            title: nil,
            detail: String(localized: "debug.captureCardLab.edge.longTranscript.detail"),
            metadata: "12:04",
            durationSeconds: 724,
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-no-image",
            kind: .photo,
            title: nil,
            detail: String(localized: "debug.captureCardLab.edge.noImage.detail"),
            metadata: String(localized: "debug.captureCardLab.status.processing"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-manual-music",
            kind: .music,
            origin: .manual,
            title: String(localized: "debug.captureCardLab.edge.manualMusic.title"),
            detail: String(localized: "debug.captureCardLab.edge.manualMusic.detail"),
            metadata: String(localized: "capture.card.music.searchResult")
        ),
        CaptureCardItem(
            id: "edge-context-weather",
            kind: .weather,
            origin: .context,
            title: String(localized: "capture.card.weather.rain"),
            detail: "16°C · umbrella weather",
            metadata: "UV 2",
            isSelected: false
        ),
        CaptureCardItem(
            id: "edge-weather-zh-mostly-clear",
            kind: .weather,
            origin: .context,
            title: "大部晴朗无云",
            detail: "21°C · 湿度 48%",
            metadata: "UV 4",
            weatherStyle: .resolve(condition: "大部晴朗无云"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-weather-zh-mostly-cloudy",
            kind: .weather,
            origin: .context,
            title: "大部多云",
            detail: "19°C · 湿度 64%",
            metadata: "UV 2",
            weatherStyle: .resolve(condition: "大部多云"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-weather-zh-thunder-shower",
            kind: .weather,
            origin: .context,
            title: "雷阵雨",
            detail: "17°C · 湿度 86%",
            metadata: "UV 1",
            weatherStyle: .resolve(condition: "雷阵雨"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-weather-zh-wintry-mix",
            kind: .weather,
            origin: .context,
            title: "雨夹雪",
            detail: "1°C · 湿度 82%",
            metadata: "UV 0",
            weatherStyle: .resolve(condition: "雨夹雪"),
            isRemovable: true
        ),
        CaptureCardItem(
            id: "edge-weather-zh-haze",
            kind: .weather,
            origin: .context,
            title: "霾",
            detail: "12°C · 湿度 58%",
            metadata: "UV 1",
            weatherStyle: .resolve(condition: "霾"),
            isRemovable: true
        ),
    ]

    static let status: [CaptureCardItem] = [
        CaptureCardItem(
            id: "status-context",
            kind: .status,
            origin: nil,
            state: .loading,
            title: String(localized: "debug.captureCardLab.status.context.title"),
            detail: String(localized: "debug.captureCardLab.status.context.detail")
        ),
        CaptureCardItem(
            id: "status-empty-context",
            kind: .status,
            origin: nil,
            title: String(localized: "debug.captureCardLab.status.emptyContext.title"),
            detail: String(localized: "debug.captureCardLab.status.emptyContext.detail")
        ),
        CaptureCardItem(
            id: "status-photo-processing",
            kind: .status,
            origin: nil,
            state: .loading,
            title: String(localized: "debug.captureCardLab.status.photoProcessing.title"),
            detail: String(localized: "debug.captureCardLab.status.photoProcessing.detail")
        ),
        CaptureCardItem(
            id: "status-voice-refining",
            kind: .status,
            origin: nil,
            state: .loading,
            title: String(localized: "debug.captureCardLab.status.voiceRefining.title"),
            detail: String(localized: "debug.captureCardLab.status.voiceRefining.detail")
        ),
    ]

    static let photoGroups: [CaptureCardItem] = [
        CaptureCardItem(
            id: "photo-single",
            kind: .photo,
            title: String(localized: "debug.captureCardLab.photo.single.title"),
            detail: String(localized: "debug.captureCardLab.photo.single.detail"),
            metadata: String(format: String(localized: "capture.card.photo.count.format"), 1),
            photoCount: 1
        ),
        CaptureCardItem(
            id: "photo-group-mosaic",
            kind: .photo,
            title: String(localized: "debug.captureCardLab.photo.mosaic.title"),
            detail: String(localized: "debug.captureCardLab.photo.mosaic.detail"),
            metadata: String(format: String(localized: "capture.card.photo.count.format"), 4),
            photoCount: 4,
            photoGroupStyle: .mosaic
        ),
        CaptureCardItem(
            id: "photo-group-stack",
            kind: .photo,
            title: String(localized: "debug.captureCardLab.photo.stack.title"),
            detail: String(localized: "debug.captureCardLab.photo.stack.detail"),
            metadata: String(format: String(localized: "capture.card.photo.count.format"), 5),
            photoCount: 5,
            photoGroupStyle: .stack
        ),
        CaptureCardItem(
            id: "photo-group-carousel",
            kind: .photo,
            title: String(localized: "debug.captureCardLab.photo.carousel.title"),
            detail: String(localized: "debug.captureCardLab.photo.carousel.detail"),
            metadata: String(format: String(localized: "capture.card.photo.count.format"), 8),
            photoCount: 8,
            photoGroupStyle: .carousel
        ),
    ]

    static let musicFixtures: [CaptureCardItem] = [
        CaptureCardItem(
            id: "music-fixture-m83",
            kind: .music,
            origin: .context,
            title: "Midnight City",
            detail: "M83 · Hurry Up, We're Dreaming",
            metadata: String(localized: "capture.card.music.nowPlaying"),
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
            metadata: String(localized: "capture.card.music.searchResult"),
            durationSeconds: 220,
            musicPlaybackState: .searchResult,
            isRemovable: true
        ),
        CaptureCardItem(
            id: "music-fixture-paused",
            kind: .music,
            origin: .context,
            title: String(localized: "debug.captureCardLab.music.paused.title"),
            detail: String(localized: "debug.captureCardLab.music.paused.detail"),
            metadata: String(localized: "capture.card.music.paused"),
            durationSeconds: 184,
            musicPlaybackState: .paused
        ),
    ]

    static let placeScenarios: [CapturePlaceLabScenario] = [
        CapturePlaceLabScenario(
            id: "current-place",
            label: String(localized: "debug.captureCardLab.place.current.label"),
            item: CaptureCardItem(
                id: "place-current",
                kind: .place,
                origin: .context,
                title: String(localized: "debug.captureCardLab.fixture.place.title"),
                detail: String(localized: "debug.captureCardLab.place.current.detail"),
                metadata: "31.218, 121.446",
                latitude: 31.218,
                longitude: 121.446,
                isRemovable: true
            )
        ),
        CapturePlaceLabScenario(
            id: "manual-pin",
            label: String(localized: "debug.captureCardLab.place.manual.label"),
            item: CaptureCardItem(
                id: "place-manual",
                kind: .place,
                origin: .manual,
                title: String(localized: "debug.captureCardLab.place.manual.title"),
                detail: String(localized: "debug.captureCardLab.place.manual.detail"),
                metadata: "31.230, 121.474",
                latitude: 31.230,
                longitude: 121.474,
                isRemovable: true
            )
        ),
        CapturePlaceLabScenario(
            id: "search-result",
            label: String(localized: "capture.card.music.searchResult"),
            item: CaptureCardItem(
                id: "place-search",
                kind: .place,
                origin: .manual,
                title: "Shanghai Library",
                detail: "1555 Huaihai Middle Road",
                metadata: String(localized: "capture.action.search"),
                latitude: 31.207,
                longitude: 121.444,
                isRemovable: true
            )
        ),
        CapturePlaceLabScenario(
            id: "same-name-far",
            label: String(localized: "debug.captureCardLab.place.sameNameFar.label"),
            item: CaptureCardItem(
                id: "place-same-name-far",
                kind: .place,
                origin: .inferred,
                title: "Blue Bottle Coffee",
                detail: String(localized: "debug.captureCardLab.place.sameNameFar.detail"),
                metadata: String(localized: "debug.captureCardLab.place.sameNameFar.metadata"),
                latitude: 37.776,
                longitude: -122.423
            )
        ),
        CapturePlaceLabScenario(
            id: "near-different-name",
            label: String(localized: "debug.captureCardLab.place.nearDifferentName.label"),
            item: CaptureCardItem(
                id: "place-near-different-name",
                kind: .place,
                origin: .context,
                title: String(localized: "debug.captureCardLab.place.nearDifferentName.title"),
                detail: String(localized: "debug.captureCardLab.place.nearDifferentName.detail"),
                metadata: String(localized: "debug.captureCardLab.place.nearDifferentName.metadata"),
                latitude: 31.2184,
                longitude: 121.4463,
                isRemovable: true
            )
        ),
        CapturePlaceLabScenario(
            id: "no-coordinate",
            label: String(localized: "debug.captureCardLab.place.noCoordinate.label"),
            item: CaptureCardItem(
                id: "place-no-coordinate",
                kind: .place,
                origin: .imported,
                title: String(localized: "debug.captureCardLab.place.noCoordinate.title"),
                detail: String(localized: "debug.captureCardLab.place.noCoordinate.detail"),
                metadata: String(localized: "debug.captureCardLab.place.noCoordinate.metadata")
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

private extension String {
    nonisolated var normalizedWeatherConditionCode: String? {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
        return normalized.isEmpty ? nil : String(normalized)
    }
}
