import SwiftUI

struct CaptureCardView: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let presentation: CaptureCardPresentation
    var objectAvailableSize: CGSize?
    var onTap: (() -> Void)?
    var onRemove: (() -> Void)?

    init(
        presentation: CaptureCardPresentation,
        objectAvailableSize: CGSize? = nil,
        onTap: (() -> Void)? = nil,
        onRemove: (() -> Void)? = nil
    ) {
        self.presentation = presentation
        self.objectAvailableSize = objectAvailableSize
        self.onTap = onTap
        self.onRemove = onRemove
    }

    init(
        item: CaptureCardItem,
        reduceMotionOverride: Bool? = nil,
        highContrastOverride: Bool? = nil,
        provenanceDisplayMode: CaptureCardProvenanceDisplayMode = .production,
        weatherSymbolMotionLevel: CaptureWeatherSymbolMotionLevel = .subtle,
        weatherAtmosphereIntensityScale: Double = 1,
        objectAvailableSize: CGSize? = nil,
        showsLayoutGuides: Bool = false,
        showsFieldAudit: Bool = false,
        onTap: (() -> Void)? = nil,
        onRemove: (() -> Void)? = nil
    ) {
        self.init(
            presentation: .debug(
                item,
                reduceMotionOverride: reduceMotionOverride,
                highContrastOverride: highContrastOverride,
                provenanceDisplayMode: provenanceDisplayMode,
                weatherSymbolMotionLevel: weatherSymbolMotionLevel,
                weatherAtmosphereIntensityScale: weatherAtmosphereIntensityScale,
                showsLayoutGuides: showsLayoutGuides,
                showsFieldAudit: showsFieldAudit
            ),
            objectAvailableSize: objectAvailableSize,
            onTap: onTap,
            onRemove: onRemove
        )
    }

    var body: some View {
        Button {
            guard presentation.allowsPrimaryAction else { return }
            onTap?()
        } label: {
            cardBody
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: renderContext.chromeCornerRadius, style: .continuous))
        .disabled(item.state == .disabled)
        .opacity(item.state == .disabled ? 0.48 : 1)
        .scaleEffect(presentation.displaysSelection ? 1.018 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: presentation.displaysSelection)
        .transition(.scale(scale: 0.96).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var item: CaptureCardItem {
        presentation.item
    }

    private var common: CaptureCardCommonDisplay {
        item.commonDisplay
    }

    private var renderContext: CaptureCardRenderContext {
        CaptureCardRenderContext(presentation: presentation, availableSize: objectAvailableSize)
    }

    private var cardBody: some View {
        standardCardBody
    }

    private var standardCardBody: some View {
        CaptureCardChrome(
            item: item,
            containerBackground: containerBackground,
            containerStroke: containerStroke,
            trailingControl: trailingControl,
            showsLayoutGuides: showsLayoutGuides,
            fieldAuditText: showsFieldAudit ? fieldAuditText : nil,
            cornerRadius: renderContext.chromeCornerRadius
        ) {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.payload {
        case let .photo(payload):
            PhotoCaptureCardContent(common: common, payload: payload, context: renderContext, accent: accent, highContrast: highContrast)
        case let .video(payload):
            VideoCaptureCardContent(common: common, payload: payload, context: renderContext, accent: accent, highContrast: highContrast)
        case let .livePhoto(payload):
            LivePhotoCaptureCardContent(common: common, payload: payload, context: renderContext, accent: accent, highContrast: highContrast)
        case let .audio(payload):
            AudioCaptureCardContent(common: common, payload: payload, context: renderContext, accent: accent)
        case let .place(payload):
            PlaceCaptureCardContent(
                common: common,
                payload: payload,
                context: renderContext,
                accent: accent,
                highContrastOverride: highContrastOverride
            )
        case let .weather(payload):
            WeatherCaptureCardContent(
                common: common,
                payload: payload,
                accent: accent,
                context: renderContext,
                reduceMotionOverride: reduceMotionOverride,
                symbolMotionLevel: presentation.weatherSymbolMotionLevel,
                atmosphereIntensityScale: presentation.weatherAtmosphereIntensityScale,
                highContrast: highContrast
            )
        case let .music(payload):
            MusicCaptureCardContent(
                common: common,
                payload: payload,
                context: renderContext,
                accent: accent,
                palette: palette,
                highContrast: highContrast
            )
        case let .link(payload):
            LinkCaptureCardContent(common: common, payload: payload, context: renderContext, accent: accent)
        case let .todo(payload):
            TodoCaptureCardContent(common: common, payload: payload, context: renderContext, accent: accent, isSelected: presentation.displaysSelection)
        case let .prompt(payload):
            if renderContext.contentKind == .recordBody {
                RecordBodyCaptureCardContent(common: common, payload: payload, context: renderContext, accent: accent)
            } else {
                PromptCaptureCardContent(common: common, payload: payload, context: renderContext, accent: accent)
            }
        case let .person(payload):
            PersonCaptureCardContent(common: common, payload: payload, context: renderContext, accent: accent)
        case let .affect(payload):
            AffectCaptureCardContent(common: common, payload: payload, context: renderContext, accent: accent)
        case let .journalingSuggestion(payload):
            if renderContext.contentKind == .bundle {
                BundleCaptureCardContent(common: common, payload: payload, context: renderContext, accent: accent, highContrast: highContrast)
            } else {
                JournalingSuggestionCaptureCardContent(common: common, payload: payload, context: renderContext, accent: accent, highContrast: highContrast)
            }
        case let .status(payload):
            StatusCaptureCardContent(common: common, payload: payload, context: renderContext, accent: accent)
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        if item.state == .loading {
            ProgressView()
                .controlSize(.small)
                .padding(6)
                .background(Color(.secondarySystemBackground).opacity(0.92), in: Circle())
        } else if presentation.displaysRemoveControl {
            removeButton
        } else if item.state == .error {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .padding(7)
                .background(Color(.secondarySystemBackground).opacity(0.92), in: Circle())
        } else if presentation.displaysSelection {
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, accent)
                .font(.title3)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var removeButton: some View {
        Button {
            onRemove?()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.title3)
        }
        .buttonStyle(.plain)
        .foregroundStyle(item.state == .error ? .red.opacity(0.86) : .secondary)
        .accessibilityLabel(item.state == .error ? String(localized: "capture.card.removeFailed") : String(localized: "common.delete"))
    }

    private var containerBackground: AnyShapeStyle {
        AnyShapeStyle(Color(.secondarySystemBackground))
    }

    private var containerStroke: some View {
        RoundedRectangle(cornerRadius: renderContext.chromeCornerRadius, style: .continuous)
            .stroke(
                presentation.displaysSelection ? palette.selectionStroke : Color.primary.opacity(highContrast ? 0.18 : 0.08),
                lineWidth: presentation.displaysSelection ? (highContrast ? 1.8 : 1.35) : (highContrast ? 1.2 : 1)
            )
    }

    private var mapLegibilityStyle: CaptureMapLegibilityStyle {
        guard case let .place(payload) = item.payload,
              let snapshotData = payload.mapSnapshotData,
              !payload.isPrivacyEnabled
        else { return .fallback }
        return CaptureMapLegibilityStyle.resolve(snapshotData: snapshotData)
    }

    private var highContrast: Bool {
        highContrastOverride ?? (colorSchemeContrast == .increased)
    }

    private var reduceMotionOverride: Bool? {
        presentation.reduceMotionOverride
    }

    private var highContrastOverride: Bool? {
        presentation.highContrastOverride
    }

    private var showsLayoutGuides: Bool {
        presentation.showsLayoutGuides
    }

    private var showsFieldAudit: Bool {
        presentation.showsFieldAudit
    }

    private var accent: Color {
        palette.accent
    }

    private var palette: CaptureCardPalette {
        CaptureCardPalette.resolve(
            for: item,
            highContrast: highContrast,
            mapLegibility: mapLegibilityStyle
        )
    }

    private var accessibilityLabel: String {
        [
            item.kind.label,
            item.origin?.captureBadgeLabel,
            item.state == .normal ? nil : item.state.rawValue,
            item.title?.trimmedOrNil,
            item.detail.trimmedOrNil,
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }

    private var fieldAuditText: String {
        [
            "role=\(presentation.role.rawValue)",
            "contentKind=\(presentation.contentKind.rawValue)",
            "density=\(renderContext.density.rawValue)",
            "aspect=\(renderContext.mediaAspectRatio.map { String(format: "%.3f", $0) } ?? "nil")",
            "kind=\(item.kind.rawValue)",
            "payload=\(item.payload.kind.rawValue)",
            "state=\(item.state.rawValue)",
            "origin=\(item.origin?.rawValue ?? "nil")",
            "canOpen=\(presentation.capabilities.canOpen)",
            "canRemove=\(presentation.capabilities.canRemove)",
            "canSelect=\(presentation.capabilities.canSelect)",
            "title=\(item.title ?? "nil")",
            "detail=\(item.detail)",
            "metadata=\(item.metadata ?? "nil")",
            "conditionCode=\(weatherPayloadForAudit?.conditionCode ?? "nil")",
            "symbolName=\(weatherPayloadForAudit?.symbolName ?? "nil")",
            "isDaylight=\(weatherPayloadForAudit?.isDaylight.map(String.init) ?? "nil")",
            "weatherStyle=\(resolvedWeatherStyleForAudit.rawValue)",
        ].joined(separator: "\n")
    }

    private var weatherPayloadForAudit: CaptureWeatherCardPayload? {
        guard case let .weather(payload) = item.payload else { return nil }
        return payload
    }

    private var resolvedWeatherStyleForAudit: CaptureWeatherVisualStyle {
        weatherPayloadForAudit?.style ?? .resolve(
            conditionCode: weatherPayloadForAudit?.conditionCode,
            condition: [item.title, item.detail].compactMap { $0 }.joined(separator: " "),
            isDaylight: weatherPayloadForAudit?.isDaylight
        )
    }
}
