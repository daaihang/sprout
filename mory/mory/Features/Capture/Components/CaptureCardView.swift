import SwiftUI

struct CaptureCardView: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let presentation: CaptureCardPresentation
    var onTap: (() -> Void)?
    var onRemove: (() -> Void)?

    init(
        presentation: CaptureCardPresentation,
        onTap: (() -> Void)? = nil,
        onRemove: (() -> Void)? = nil
    ) {
        self.presentation = presentation
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
        musicCardStyle: CaptureMusicCardStyle = .auto,
        placeCardStyle: CapturePlaceCardStyle = .auto,
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
                musicCardStyle: musicCardStyle,
                placeCardStyle: placeCardStyle,
                showsLayoutGuides: showsLayoutGuides,
                showsFieldAudit: showsFieldAudit
            ),
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

    private func objectMetrics(for recipe: MemoryCardVisualRecipe) -> MemoryCardObjectMetrics {
        MemoryCardObjectMetrics.resolve(
            recipe: recipe,
            sizeToken: presentation.sizeToken,
            density: presentation.contentDensity
        )
    }

    @ViewBuilder
    private var cardBody: some View {
        if presentation.surfaceMode == .skeuomorphic {
            skeuomorphicCardBody
        } else {
            standardCardBody
        }
    }

    private var standardCardBody: some View {
        CaptureCardChrome(
            item: item,
            containerBackground: containerBackground,
            containerStroke: containerStroke,
            footer: cardFooter,
            trailingControl: trailingControl,
            showsLayoutGuides: showsLayoutGuides,
            fieldAuditText: showsFieldAudit ? fieldAuditText : nil
        ) {
            content
        }
    }

    @ViewBuilder
    private var skeuomorphicCardBody: some View {
        if let visualRecipe = presentation.visualRecipe {
            skeuomorphicCardBody(for: visualRecipe)
        } else {
            skeuomorphicCardBodyForPayload
        }
    }

    @ViewBuilder
    private func skeuomorphicCardBody(for visualRecipe: MemoryCardVisualRecipe) -> some View {
        switch visualRecipe {
        case .polaroid:
            if case let .photo(payload) = item.payload {
                PolaroidCaptureCardContent(common: common, payload: payload, metrics: objectMetrics(for: .polaroid))
            } else {
                notebookSkeuomorphicCard
            }
        case .filmFrame:
            if case let .video(payload) = item.payload {
                FilmFrameCaptureCardContent(common: common, payload: payload, accent: accent, metrics: objectMetrics(for: .filmFrame))
            } else {
                notebookSkeuomorphicCard
            }
        case .livePhotoPrint:
            if case let .livePhoto(payload) = item.payload {
                LivePhotoPrintCaptureCardContent(common: common, payload: payload, accent: accent, metrics: objectMetrics(for: .livePhotoPrint))
            } else {
                notebookSkeuomorphicCard
            }
        case .cassette:
            if case let .audio(payload) = item.payload {
                CassetteCaptureCardContent(common: common, payload: payload, sizeToken: presentation.sizeToken, density: presentation.contentDensity, metrics: objectMetrics(for: .cassette))
            } else {
                notebookSkeuomorphicCard
            }
        case .vinyl:
            if case let .music(payload) = item.payload {
                VinylRecordCaptureCardContent(common: common, payload: payload, accent: accent, metrics: objectMetrics(for: .vinyl))
            } else {
                notebookSkeuomorphicCard
            }
        case .notebook:
            notebookSkeuomorphicCard
        case .mapTicket:
            if case let .place(payload) = item.payload {
                MapTicketCaptureCardContent(common: common, payload: payload, accent: accent, metrics: objectMetrics(for: .mapTicket))
            } else {
                notebookSkeuomorphicCard
            }
        case .weatherStamp:
            if case let .weather(payload) = item.payload {
                WeatherStampCaptureCardContent(common: common, payload: payload, accent: accent, sizeToken: presentation.sizeToken, density: presentation.contentDensity, variant: presentation.visualVariant, metrics: objectMetrics(for: .weatherStamp))
            } else {
                notebookSkeuomorphicCard
            }
        case .linkNote:
            if case let .link(payload) = item.payload {
                LinkNoteCaptureCardContent(common: common, payload: payload, accent: accent, sizeToken: presentation.sizeToken, density: presentation.contentDensity, metrics: objectMetrics(for: .linkNote))
            } else {
                notebookSkeuomorphicCard
            }
        case .taskNote:
            if case let .todo(payload) = item.payload {
                TaskNoteCaptureCardContent(common: common, payload: payload, accent: accent, metrics: objectMetrics(for: .taskNote))
            } else {
                notebookSkeuomorphicCard
            }
        case .personCard:
            if case let .person(payload) = item.payload {
                PersonContextCaptureCardContent(common: common, payload: payload, accent: accent, metrics: objectMetrics(for: .personCard))
            } else {
                notebookSkeuomorphicCard
            }
        case .affectCard:
            if case let .affect(payload) = item.payload {
                MoodSwatchCaptureCardContent(common: common, payload: payload, accent: accent, sizeToken: presentation.sizeToken, density: presentation.contentDensity, metrics: objectMetrics(for: .affectCard))
            } else {
                MoodSwatchCaptureCardContent(common: common, payload: nil, accent: accent, sizeToken: presentation.sizeToken, density: presentation.contentDensity, metrics: objectMetrics(for: .affectCard))
            }
        case .bundlePacket:
            bundlePacketSkeuomorphicCard(metrics: objectMetrics(for: .bundlePacket))
        case .statusNote:
            PlainSystemNoteCaptureCardContent(common: common, accent: accent, metrics: objectMetrics(for: .statusNote))
        }
    }

    @ViewBuilder
    private var skeuomorphicCardBodyForPayload: some View {
        switch item.payload {
        case let .photo(payload):
            PolaroidCaptureCardContent(common: common, payload: payload, metrics: objectMetrics(for: .polaroid))
        case let .video(payload):
            FilmFrameCaptureCardContent(common: common, payload: payload, accent: accent, metrics: objectMetrics(for: .filmFrame))
        case let .livePhoto(payload):
            LivePhotoPrintCaptureCardContent(common: common, payload: payload, accent: accent, metrics: objectMetrics(for: .livePhotoPrint))
        case let .audio(payload):
            CassetteCaptureCardContent(common: common, payload: payload, sizeToken: presentation.sizeToken, density: presentation.contentDensity, metrics: objectMetrics(for: .cassette))
        case let .music(payload):
            VinylRecordCaptureCardContent(common: common, payload: payload, accent: accent, metrics: objectMetrics(for: .vinyl))
        case let .todo(payload):
            TaskNoteCaptureCardContent(common: common, payload: payload, accent: accent, metrics: objectMetrics(for: .taskNote))
        case let .link(payload):
            LinkNoteCaptureCardContent(common: common, payload: payload, accent: accent, sizeToken: presentation.sizeToken, density: presentation.contentDensity, metrics: objectMetrics(for: .linkNote))
        case .prompt:
            notebookSkeuomorphicCard
        case let .person(payload):
            PersonContextCaptureCardContent(common: common, payload: payload, accent: accent, metrics: objectMetrics(for: .personCard))
        case let .affect(payload):
            MoodSwatchCaptureCardContent(common: common, payload: payload, accent: accent, sizeToken: presentation.sizeToken, density: presentation.contentDensity, metrics: objectMetrics(for: .affectCard))
        case let .weather(payload):
            WeatherStampCaptureCardContent(common: common, payload: payload, accent: accent, sizeToken: presentation.sizeToken, density: presentation.contentDensity, variant: presentation.visualVariant, metrics: objectMetrics(for: .weatherStamp))
        case let .place(payload):
            MapTicketCaptureCardContent(common: common, payload: payload, accent: accent, metrics: objectMetrics(for: .mapTicket))
        case .journalingSuggestion:
            bundlePacketSkeuomorphicCard(metrics: objectMetrics(for: .bundlePacket))
        case .status:
            PlainSystemNoteCaptureCardContent(common: common, accent: accent, metrics: objectMetrics(for: .statusNote))
        }
    }

    private var notebookSkeuomorphicCard: some View {
        NotebookCaptureCardContent(common: common, item: item, accent: accent, metrics: objectMetrics(for: .notebook))
    }

    @ViewBuilder
    private func bundlePacketSkeuomorphicCard(metrics: MemoryCardObjectMetrics) -> some View {
        switch item.payload {
        case let .journalingSuggestion(payload):
            BundlePacketCaptureCardContent(
                common: common,
                thumbnailData: payload.thumbnailData,
                itemCount: payload.artifactCount,
                accent: accent,
                metrics: metrics
            )
        case let .photo(payload):
            BundlePacketCaptureCardContent(
                common: common,
                thumbnailData: payload.thumbnailData,
                itemCount: payload.photoCount,
                accent: accent,
                metrics: metrics
            )
        default:
            BundlePacketCaptureCardContent(
                common: common,
                thumbnailData: nil,
                itemCount: nil,
                accent: accent,
                metrics: metrics
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.payload {
        case let .photo(payload):
            PhotoCaptureCardContent(common: common, payload: payload, accent: accent, highContrast: highContrast)
        case let .video(payload):
            VideoCaptureCardContent(common: common, payload: payload, accent: accent, highContrast: highContrast)
        case let .livePhoto(payload):
            LivePhotoCaptureCardContent(common: common, payload: payload, accent: accent, highContrast: highContrast)
        case let .audio(payload):
            AudioCaptureCardContent(common: common, payload: payload, accent: accent)
        case let .place(payload):
            PlaceCaptureCardContent(
                common: common,
                payload: payload,
                accent: accent,
                highContrastOverride: highContrastOverride,
                style: presentation.placeCardStyle.resolved(for: item)
            )
        case let .weather(payload):
            WeatherCaptureCardContent(
                common: common,
                payload: payload,
                accent: accent,
                reduceMotionOverride: reduceMotionOverride,
                symbolMotionLevel: presentation.weatherSymbolMotionLevel,
                atmosphereIntensityScale: presentation.weatherAtmosphereIntensityScale,
                highContrast: highContrast
            )
        case let .music(payload):
            MusicCaptureCardContent(
                common: common,
                payload: payload,
                accent: accent,
                palette: palette,
                style: presentation.musicCardStyle.resolved(for: item),
                highContrast: highContrast
            )
        case let .link(payload):
            LinkCaptureCardContent(common: common, payload: payload, accent: accent)
        case let .todo(payload):
            TodoCaptureCardContent(common: common, payload: payload, accent: accent, isSelected: presentation.displaysSelection)
        case let .prompt(payload):
            StatusCaptureCardContent(
                common: common.replacingDetail(payload.answer?.trimmedOrNil ?? payload.prompt),
                payload: CaptureStatusCardPayload(),
                accent: accent
            )
        case .person:
            StatusCaptureCardContent(common: common, payload: CaptureStatusCardPayload(), accent: accent)
        case .affect:
            StatusCaptureCardContent(common: common, payload: CaptureStatusCardPayload(), accent: accent)
        case let .journalingSuggestion(payload):
            JournalingSuggestionCaptureCardContent(common: common, payload: payload, accent: accent, highContrast: highContrast)
        case let .status(payload):
            StatusCaptureCardContent(common: common, payload: payload, accent: accent)
        }
    }

    private var cardFooter: some View {
        HStack(spacing: 6) {
            if let origin = item.origin,
               let visual = presentation.provenanceDisplayMode.visual(for: origin, provenance: item.provenance) {
                originBadge(visual, origin: origin)
            }

            if let metadata = visibleFooterMetadata {
                Text(metadata)
                    .font(.caption2)
                    .foregroundStyle(footerMetadataForeground)
                    .lineLimit(1)
            }
        }
        .padding(10)
    }

    private func originBadge(_ visual: CaptureCardProvenanceVisual, origin: CaptureArtifactOrigin) -> some View {
        HStack(spacing: visual.isCompact ? 3 : 4) {
            if let symbolName = visual.symbolName {
                Image(systemName: symbolName)
                    .font(.caption2.weight(.semibold))
            }
            if let label = visual.label {
                Text(label)
                    .lineLimit(1)
            }
        }
            .font(.caption2.weight(visual.isCompact ? .medium : .semibold))
            .foregroundStyle(originForeground(for: origin))
            .padding(.horizontal, visual.isCompact ? 5 : 7)
            .padding(.vertical, visual.isCompact ? 2 : 3)
            .background {
                Capsule()
                    .fill(originBackground(for: origin))
            }
            .opacity(visual.isCompact ? 0.74 : 1)
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
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(
                presentation.displaysSelection ? palette.selectionStroke : Color.primary.opacity(highContrast ? 0.18 : 0.08),
                lineWidth: presentation.displaysSelection ? (highContrast ? 1.8 : 1.35) : (highContrast ? 1.2 : 1)
            )
    }

    private func originForeground(for origin: CaptureArtifactOrigin?) -> Color {
        if usesMapLegibility {
            return mapFooterForeground
        }
        switch origin {
        case .manual:
            return .primary
        case .context:
            return palette.controlTint
        case .imported:
            return palette.controlTint.opacity(0.82)
        case .inferred:
            return palette.controlTint.opacity(0.72)
        case nil:
            return .secondary
        }
    }

    private func originBackground(for origin: CaptureArtifactOrigin?) -> Color {
        if usesMapLegibility {
            return mapFooterBackground
        }
        return originForeground(for: origin).opacity(highContrast ? 0.2 : 0.13)
    }

    private var footerMetadataForeground: Color {
        usesMapLegibility ? mapFooterForeground.opacity(0.78) : .secondary
    }

    private var visibleFooterMetadata: String? {
        guard let metadata = item.metadata?.trimmedOrNil else { return nil }
        guard presentation.provenanceDisplayMode != .debug else { return metadata }
        guard item.kind == .weather else { return nil }
        guard let origin = item.origin else { return metadata }
        let normalizedMetadata = metadata.lowercased()
        let hiddenOriginValues = [
            origin.rawValue.lowercased(),
            origin.captureBadgeLabel.lowercased(),
        ]
        return hiddenOriginValues.contains(normalizedMetadata) ? nil : metadata
    }

    private var usesMapLegibility: Bool {
        guard case let .place(payload) = item.payload else { return false }
        return payload.mapSnapshotData != nil && !payload.isPrivacyEnabled
    }

    private var mapLegibilityStyle: CaptureMapLegibilityStyle {
        guard case let .place(payload) = item.payload, usesMapLegibility else { return .fallback }
        return CaptureMapLegibilityStyle.resolve(snapshotData: payload.mapSnapshotData)
    }

    private var mapFooterForeground: Color {
        switch mapLegibilityStyle {
        case .lightText:
            return .white
        case .darkText:
            return .black.opacity(0.86)
        case .fallback:
            return .primary
        }
    }

    private var mapFooterBackground: Color {
        switch mapLegibilityStyle {
        case .lightText:
            return .black.opacity(highContrast ? 0.48 : 0.28)
        case .darkText:
            return .white.opacity(highContrast ? 0.78 : 0.56)
        case .fallback:
            return Color.primary.opacity(highContrast ? 0.18 : 0.1)
        }
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
