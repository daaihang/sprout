import Foundation

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

enum CaptureCardRole: String, CaseIterable, Hashable, Sendable {
    case composerEditing
    case detailViewing
    case detailEditing
    case debugLab
}

struct CaptureCardCapabilities: Hashable, Sendable {
    var canOpen: Bool
    var canRemove: Bool
    var canRetry: Bool
    var canSelect: Bool
    var canReorder: Bool

    static func resolve(role: CaptureCardRole, item: CaptureCardItem) -> CaptureCardCapabilities {
        switch role {
        case .composerEditing:
            return CaptureCardCapabilities(
                canOpen: true,
                canRemove: item.isRemovable,
                canRetry: false,
                canSelect: false,
                canReorder: false
            )
        case .detailViewing:
            return CaptureCardCapabilities(
                canOpen: true,
                canRemove: false,
                canRetry: false,
                canSelect: false,
                canReorder: false
            )
        case .detailEditing:
            return CaptureCardCapabilities(
                canOpen: true,
                canRemove: item.isRemovable,
                canRetry: false,
                canSelect: false,
                canReorder: false
            )
        case .debugLab:
            return CaptureCardCapabilities(
                canOpen: true,
                canRemove: item.isRemovable,
                canRetry: false,
                canSelect: item.isSelected,
                canReorder: false
            )
        }
    }
}

struct CaptureCardPresentation: Hashable, Sendable {
    var item: CaptureCardItem
    var role: CaptureCardRole
    var capabilities: CaptureCardCapabilities
    var provenanceDisplayMode: CaptureCardProvenanceDisplayMode
    var reduceMotionOverride: Bool?
    var highContrastOverride: Bool?
    var weatherSymbolMotionLevel: CaptureWeatherSymbolMotionLevel
    var weatherAtmosphereIntensityScale: Double
    var musicCardStyle: CaptureMusicCardStyle
    var placeCardStyle: CapturePlaceCardStyle
    var showsLayoutGuides: Bool
    var showsFieldAudit: Bool

    init(
        item: CaptureCardItem,
        role: CaptureCardRole,
        capabilities: CaptureCardCapabilities? = nil,
        provenanceDisplayMode: CaptureCardProvenanceDisplayMode,
        reduceMotionOverride: Bool? = nil,
        highContrastOverride: Bool? = nil,
        weatherSymbolMotionLevel: CaptureWeatherSymbolMotionLevel = .subtle,
        weatherAtmosphereIntensityScale: Double = 1,
        musicCardStyle: CaptureMusicCardStyle = .auto,
        placeCardStyle: CapturePlaceCardStyle = .auto,
        showsLayoutGuides: Bool = false,
        showsFieldAudit: Bool = false
    ) {
        self.item = item
        self.role = role
        self.capabilities = capabilities ?? CaptureCardCapabilities.resolve(role: role, item: item)
        self.provenanceDisplayMode = provenanceDisplayMode
        self.reduceMotionOverride = reduceMotionOverride
        self.highContrastOverride = highContrastOverride
        self.weatherSymbolMotionLevel = weatherSymbolMotionLevel
        self.weatherAtmosphereIntensityScale = weatherAtmosphereIntensityScale
        self.musicCardStyle = musicCardStyle
        self.placeCardStyle = placeCardStyle
        self.showsLayoutGuides = showsLayoutGuides
        self.showsFieldAudit = showsFieldAudit
    }

    static func composerAttachment(_ attachment: CaptureComposerAttachmentItem) -> CaptureCardPresentation {
        CaptureCardPresentation(
            item: attachment.card,
            role: .composerEditing,
            provenanceDisplayMode: .production,
            musicCardStyle: .compactRow,
            placeCardStyle: .standard
        )
    }

    static func detailArtifact(_ artifact: Artifact) -> CaptureCardPresentation {
        CaptureCardPresentation(
            item: CaptureCardItem(artifact: artifact),
            role: .detailViewing,
            provenanceDisplayMode: .production,
            musicCardStyle: .compactRow,
            placeCardStyle: .standard
        )
    }

    static func detailEditing(_ item: CaptureCardItem) -> CaptureCardPresentation {
        CaptureCardPresentation(
            item: item,
            role: .detailEditing,
            provenanceDisplayMode: .production,
            musicCardStyle: .compactRow,
            placeCardStyle: .standard
        )
    }

    static func debug(
        _ item: CaptureCardItem,
        reduceMotionOverride: Bool? = nil,
        highContrastOverride: Bool? = nil,
        provenanceDisplayMode: CaptureCardProvenanceDisplayMode = .debug,
        weatherSymbolMotionLevel: CaptureWeatherSymbolMotionLevel = .subtle,
        weatherAtmosphereIntensityScale: Double = 1,
        musicCardStyle: CaptureMusicCardStyle = .auto,
        placeCardStyle: CapturePlaceCardStyle = .auto,
        showsLayoutGuides: Bool = false,
        showsFieldAudit: Bool = false
    ) -> CaptureCardPresentation {
        CaptureCardPresentation(
            item: item,
            role: .debugLab,
            provenanceDisplayMode: provenanceDisplayMode,
            reduceMotionOverride: reduceMotionOverride,
            highContrastOverride: highContrastOverride,
            weatherSymbolMotionLevel: weatherSymbolMotionLevel,
            weatherAtmosphereIntensityScale: weatherAtmosphereIntensityScale,
            musicCardStyle: musicCardStyle,
            placeCardStyle: placeCardStyle,
            showsLayoutGuides: showsLayoutGuides,
            showsFieldAudit: showsFieldAudit
        )
    }

    var allowsPrimaryAction: Bool {
        item.state == .normal && capabilities.canOpen
    }

    var displaysRemoveControl: Bool {
        capabilities.canRemove && (item.state == .normal || item.state == .error)
    }

    var displaysSelection: Bool {
        capabilities.canSelect && item.state == .normal && item.isSelected && !displaysRemoveControl
    }

    var hasTrailingControl: Bool {
        item.state == .loading || item.state == .error || displaysRemoveControl || displaysSelection
    }
}

extension CaptureArtifactOrigin {
    var captureBadgeLabel: String {
        switch self {
        case .manual:
            return String(localized: "capture.origin.manual")
        case .context:
            return String(localized: "capture.origin.context")
        case .imported:
            return String(localized: "capture.origin.imported")
        case .inferred:
            return String(localized: "capture.origin.inferred")
        }
    }
}
