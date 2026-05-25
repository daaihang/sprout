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

    func visual(for origin: CaptureArtifactOrigin?, provenance: CaptureProvenance?) -> CaptureCardProvenanceVisual? {
        switch self {
        case .production:
            guard let provenance, provenance.originCategory != .userInput else { return nil }
            return CaptureCardProvenanceVisual(label: provenance.displayLabel, symbolName: provenance.sourceKind.symbolName, isCompact: true)
        case .debug:
            if let provenance {
                return CaptureCardProvenanceVisual(label: provenance.compactDebugLabel, symbolName: provenance.sourceKind.symbolName, isCompact: false)
            }
            guard let origin else { return nil }
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
                canRemove: false,
                canRetry: false,
                canSelect: false,
                canReorder: true
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
    var surfaceMode: CaptureCardSurfaceMode

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
        showsFieldAudit: Bool = false,
        surfaceMode: CaptureCardSurfaceMode = .standard
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
        self.surfaceMode = surfaceMode
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

    static func detailEditing(_ artifact: Artifact) -> CaptureCardPresentation {
        detailEditing(CaptureCardItem(artifact: artifact))
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
        showsFieldAudit: Bool = false,
        surfaceMode: CaptureCardSurfaceMode = .standard
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
            showsFieldAudit: showsFieldAudit,
            surfaceMode: surfaceMode
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

extension CaptureProvenanceSourceKind {
    var symbolName: String? {
        switch self {
        case .composer:
            return "square.and.pencil"
        case .voice, .audioRecorder:
            return "waveform"
        case .camera, .photoLibrary:
            return "photo"
        case .autoContext:
            return "sparkles"
        case .shareSheet:
            return "square.and.arrow.up"
        case .appIntent, .shortcut:
            return "wand.and.stars"
        case .widget:
            return "platter.2.filled.iphone"
        case .journalingSuggestion:
            return "book.pages"
        case .health:
            return "heart"
        case .fitness:
            return "figure.run"
        case .aiAnalysis:
            return "sparkle.magnifyingglass"
        case .debugFixture:
            return "wrench.and.screwdriver"
        case .linkComposer:
            return "link"
        case .musicPicker:
            return "music.note"
        case .locationPicker:
            return "mappin.and.ellipse"
        case .todoComposer:
            return "checklist"
        case .moodPicker:
            return "face.smiling"
        case .unknown:
            return nil
        }
    }
}
