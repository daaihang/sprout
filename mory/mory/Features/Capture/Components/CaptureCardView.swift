import SwiftUI
import UIKit

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

    private var cardBody: some View {
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
    private var content: some View {
        switch item.payload {
        case let .photo(payload):
            PhotoCaptureCardContent(common: common, payload: payload, accent: accent, highContrast: highContrast)
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
        case let .status(payload):
            StatusCaptureCardContent(common: common, payload: payload, accent: accent)
        }
    }

    private var cardFooter: some View {
        HStack(spacing: 6) {
            if let origin = item.origin,
               let visual = presentation.provenanceDisplayMode.visual(for: origin) {
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

private struct CaptureCardChrome<Content: View, Footer: View, TrailingControl: View, ContainerStroke: View>: View {
    let item: CaptureCardItem
    let containerBackground: AnyShapeStyle
    let containerStroke: ContainerStroke
    let footer: Footer
    let trailingControl: TrailingControl
    let showsLayoutGuides: Bool
    let fieldAuditText: String?
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
                .frame(width: 190, height: 132)
                .background(containerBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .redacted(reason: item.state == .loading ? .placeholder : [])
                .overlay(alignment: .bottomLeading) { footer }
                .overlay {
                    if showsLayoutGuides {
                        layoutGuides
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let fieldAuditText {
                        Text(fieldAuditText)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.primary)
                            .padding(5)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .padding(6)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(containerStroke)

            trailingControl
                .padding(9)
        }
    }

    private var layoutGuides: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(.yellow.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        .allowsHitTesting(false)
    }
}

private struct PhotoCaptureCardContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let common: CaptureCardCommonDisplay
    let payload: CapturePhotoCardPayload
    let accent: Color
    let highContrast: Bool

    var body: some View {
        if payload.photoCount > 1 {
            photoGroupContent
        } else {
            singlePhotoContent
        }
    }

    private var singlePhotoContent: some View {
        ZStack(alignment: .bottomLeading) {
            photoBackground
            photoScrim
            titleBlock(legibility: legibility)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
    }

    private var photoGroupContent: some View {
        ZStack(alignment: .bottomLeading) {
            switch payload.groupStyle ?? .mosaic {
            case .mosaic:
                mosaicBackground
            case .stack:
                stackBackground
            case .carousel:
                carouselBackground
            }

            photoScrim
            VStack(alignment: .leading, spacing: 5) {
                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.photos"))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(String(format: String(localized: "capture.card.photo.count.format"), payload.photoCount))
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(legibility.primaryText)
            .shadow(color: legibility.shadow, radius: 3, y: 1)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private var photoBackground: some View {
        if let image = payload.thumbnailImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            LinearGradient(colors: [accent.opacity(0.8), .orange.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var mosaicBackground: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                sampleTile(index: 0)
                    .frame(width: width * 0.58, height: height)
                    .position(x: width * 0.29, y: height * 0.5)
                VStack(spacing: 2) {
                    sampleTile(index: 1)
                    sampleTile(index: 2)
                }
                .frame(width: width * 0.42, height: height)
                .position(x: width * 0.79, y: height * 0.5)
            }
        }
    }

    private var stackBackground: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(sampleGradient(index: index))
                    .overlay(alignment: .center) {
                        Image(systemName: "photo")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white.opacity(index == 0 ? 0.84 : 0.36))
                    }
                    .frame(width: 132, height: 92)
                    .rotationEffect(.degrees(Double(index - 1) * 5))
                    .offset(x: CGFloat(index - 1) * 13, y: CGFloat(index - 1) * 5)
                    .shadow(color: .black.opacity(index == 0 ? 0.18 : 0.08), radius: 8, y: 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(sampleGradient(index: 3).opacity(0.5))
    }

    private var carouselBackground: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 60 : 1 / 30)) { timeline in
            let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 8) / 8
            GeometryReader { proxy in
                let tileWidth = proxy.size.width * 0.44
                let spacing: CGFloat = 8
                let travel = (tileWidth + spacing) * 3
                HStack(spacing: spacing) {
                    ForEach(0..<6, id: \.self) { index in
                        sampleTile(index: index)
                            .frame(width: tileWidth, height: proxy.size.height)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .offset(x: -CGFloat(phase) * travel)
            }
        }
    }

    private func sampleTile(index: Int) -> some View {
        ZStack {
            sampleGradient(index: index)
            if let image = payload.thumbnailImage, index == 0 {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.42))
            }
        }
        .clipped()
    }

    private func sampleGradient(index: Int) -> LinearGradient {
        let palettes: [[Color]] = [
            [accent.opacity(0.92), .orange.opacity(0.76)],
            [.pink.opacity(0.82), .purple.opacity(0.62)],
            [.teal.opacity(0.75), .blue.opacity(0.58)],
            [.indigo.opacity(0.72), accent.opacity(0.42)],
        ]
        let colors = palettes[index % palettes.count]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var photoScrim: some View {
        LinearGradient(
            colors: legibility.scrimColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var legibility: CaptureCardLegibility {
        CaptureCardLegibility.imageData(payload.thumbnailData, highContrast: highContrast)
    }

    private func titleBlock(legibility: CaptureCardLegibility) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.photo"))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(common.detail)
                .font(.caption)
                .lineLimit(2)
        }
        .foregroundStyle(legibility.primaryText)
        .shadow(color: legibility.shadow, radius: 3, y: 1)
    }
}

private struct AudioCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureAudioCardPayload
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(accent, in: Circle())

                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.audio"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let duration = payload.durationSeconds {
                    Text(formatDuration(duration))
                        .font(.caption2.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
                }
            }

            Text(transcriptPreview)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                Image(systemName: transcriptIsAvailable ? "text.quote" : "waveform")
                    .font(.caption2.weight(.semibold))
                Text(transcriptIsAvailable ? String(localized: "capture.card.audio.transcript") : String(localized: "capture.card.audio.original"))
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(accent.opacity(0.08))
    }

    private var transcriptPreview: String {
        guard let detail = common.detail.trimmedOrNil, detail != String(localized: "capture.card.audio.attached") else {
            return String(localized: "capture.card.audio.originalAttached")
        }
        return detail
    }

    private var transcriptIsAvailable: Bool {
        common.detail.trimmedOrNil != nil && common.detail != String(localized: "capture.card.audio.attached")
    }
}

private struct PlaceCaptureCardContent: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let common: CaptureCardCommonDisplay
    let payload: CapturePlaceCardPayload
    let accent: Color
    let highContrastOverride: Bool?
    let style: CapturePlaceCardStyle

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            placeBackground

            switch style {
            case .immersive:
                immersiveFooter
            case .standard, .auto:
                standardContent
            }
        }
    }

    private var standardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(placePrimaryText, accent)

            Spacer()

            VStack(alignment: .leading, spacing: 3) {
                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.place"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(placePrimaryText)
                    .lineLimit(1)
                Text(common.detail)
                    .font(.caption)
                    .foregroundStyle(placeSecondaryText)
                    .lineLimit(2)
            }
        }
        .shadow(color: placeTextShadow, radius: 3, y: 1)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var immersiveFooter: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.place"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(placePrimaryText)
                .lineLimit(1)
            Text(common.detail)
                .font(.caption)
                .foregroundStyle(placeSecondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .shadow(color: placeTextShadow, radius: 3, y: 1)
    }

    @ViewBuilder
    private var placeBackground: some View {
        if let image = payload.mapSnapshotImage, !payload.isPrivacyEnabled {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .overlay(placeSnapshotScrim)
        } else {
            mapBackground
                .overlay {
                    if payload.isPrivacyEnabled {
                        privacyLocationMask
                    }
                }
        }
    }

    private var privacyLocationMask: some View {
        LinearGradient(
            colors: [
                Color(.secondarySystemBackground).opacity(0.34),
                accent.opacity(0.12),
                Color(.systemBackground).opacity(0.52),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var mapBackground: some View {
        ZStack {
            accent.opacity(0.1)
            Path { path in
                path.move(to: CGPoint(x: 0, y: 32))
                path.addCurve(to: CGPoint(x: 190, y: 52), control1: CGPoint(x: 58, y: 4), control2: CGPoint(x: 104, y: 82))
                path.move(to: CGPoint(x: 20, y: 132))
                path.addCurve(to: CGPoint(x: 184, y: 16), control1: CGPoint(x: 50, y: 62), control2: CGPoint(x: 132, y: 90))
                path.move(to: CGPoint(x: 18, y: 18))
                path.addLine(to: CGPoint(x: 76, y: 98))
                path.move(to: CGPoint(x: 116, y: 0))
                path.addLine(to: CGPoint(x: 154, y: 132))
            }
            .stroke(accent.opacity(0.34), lineWidth: 2)
            Circle()
                .fill(accent.opacity(0.14))
                .frame(width: 42, height: 42)
                .offset(x: 54, y: -18)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1.2)
                .frame(width: 92, height: 54)
                .rotationEffect(.degrees(-9))
                .offset(x: -32, y: 28)
        }
    }

    private var legibilityStyle: CaptureMapLegibilityStyle {
        guard payload.mapSnapshotData != nil, !payload.isPrivacyEnabled else {
            return .fallback
        }
        return CaptureMapLegibilityStyle.resolve(snapshotData: payload.mapSnapshotData)
    }

    private var legibility: CaptureCardLegibility {
        CaptureCardLegibility.map(
            snapshotData: payload.mapSnapshotData,
            isPrivacyEnabled: payload.isPrivacyEnabled,
            highContrast: highContrast
        )
    }

    private var placePrimaryText: Color {
        legibility.primaryText
    }

    private var placeSecondaryText: Color {
        legibility.secondaryText
    }

    private var placeTextShadow: Color {
        legibility.shadow
    }

    private var placeSnapshotScrim: some View {
        LinearGradient(
            colors: placeScrimColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var placeScrimColors: [Color] {
        legibility.scrimColors
    }

    private var highContrast: Bool {
        highContrastOverride ?? (colorSchemeContrast == .increased)
    }
}

private struct WeatherCaptureCardContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let common: CaptureCardCommonDisplay
    let payload: CaptureWeatherCardPayload
    let accent: Color
    let reduceMotionOverride: Bool?
    let symbolMotionLevel: CaptureWeatherSymbolMotionLevel
    let atmosphereIntensityScale: Double
    let highContrast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.weather"))
                    .font(.system(size: 35, weight: .bold, design: .rounded))
                    .foregroundStyle(legibility.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 8)
                weatherIcon
            }

            Text(common.detail)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(legibility.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .shadow(color: legibility.shadow, radius: 3, y: 1)
        .background {
            WeatherAtmosphereView(
                spec: weatherAtmosphereSpec,
                isReduceMotionEnabled: resolvedReduceMotion
            )
        }
    }

    private var weatherStyle: CaptureWeatherVisualStyle {
        payload.style ?? .resolve(
            conditionCode: payload.conditionCode,
            condition: [common.title, common.detail].compactMap { $0 }.joined(separator: " "),
            isDaylight: payload.isDaylight
        )
    }

    private var legibility: CaptureCardLegibility {
        CaptureCardLegibility.weather(style: weatherStyle, highContrast: highContrast)
    }

    @ViewBuilder
    private var weatherIcon: some View {
        switch resolvedSymbolMotion {
        case .none:
            weatherIconBase
        case .pulse:
            weatherIconBase.symbolEffect(.pulse, options: .repeating, isActive: !resolvedReduceMotion)
        case .variableColor:
            weatherIconBase.symbolEffect(.variableColor, options: .repeating, isActive: !resolvedReduceMotion)
        case .wiggle:
            weatherIconBase.symbolEffect(.wiggle, options: .repeating, isActive: !resolvedReduceMotion)
        case .bounce:
            weatherIconBase.symbolEffect(.bounce, options: .repeating, isActive: !resolvedReduceMotion)
        case .scale:
            weatherIconBase.symbolEffect(.scale, options: .repeating, isActive: !resolvedReduceMotion)
        }
    }

    private var weatherIconBase: some View {
        Image(systemName: payload.symbolName?.trimmedOrNil ?? weatherStyle.symbolName)
            .font(.system(size: 27, weight: .semibold))
            .symbolRenderingMode(.multicolor)
            .frame(width: 32, height: 32)
    }

    private var resolvedReduceMotion: Bool {
        reduceMotionOverride ?? reduceMotion
    }

    private var weatherAtmosphereSpec: CaptureWeatherAtmosphereSpec {
        var spec = weatherStyle.resolvedAtmosphereSpec(reduceMotion: resolvedReduceMotion)
        spec.intensity = min(1, max(0.2, spec.intensity * atmosphereIntensityScale))
        return spec
    }

    private var resolvedSymbolMotion: CaptureWeatherSymbolMotion {
        guard !resolvedReduceMotion else { return .none }
        switch symbolMotionLevel {
        case .staticOnly:
            return .none
        case .subtle:
            switch weatherStyle {
            case .sunny, .hot, .clearNight:
                return .scale
            case .fog, .cloudy, .cold:
                return .pulse
            case .rain, .heavyRain, .snow, .thunderstorm, .wind, .unknown:
                return .none
            }
        case .enhanced:
            return weatherStyle.symbolMotion
        }
    }
}

private struct MusicCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureMusicCardPayload
    let accent: Color
    let palette: CaptureCardPalette
    let style: CaptureMusicCardStyle
    let highContrast: Bool

    var body: some View {
        switch style {
        case .compactRow, .auto:
            compactRowBody
        case .compactTile:
            compactTileBody
        case .cover:
            coverBody
        }
    }

    private var compactRowBody: some View {
        ZStack {
            musicBackground

            HStack(alignment: .center, spacing: 10) {
                compactArtwork(size: 48)

                VStack(alignment: .leading, spacing: 5) {
                    Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.music"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(coverLegibility.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                    Text(common.detail)
                        .font(.caption)
                        .foregroundStyle(coverLegibility.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .shadow(color: coverLegibility.shadow, radius: 3, y: 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private var compactTileBody: some View {
        ZStack {
            musicBackground

            VStack(alignment: .leading, spacing: 7) {
                compactArtwork(size: 46)

                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.music"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(coverLegibility.primaryText)
                    .lineLimit(2)
                Text(common.detail)
                    .font(.caption2)
                    .foregroundStyle(coverLegibility.secondaryText)
                    .lineLimit(1)
            }
            .padding(12)
            .shadow(color: coverLegibility.shadow, radius: 3, y: 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var coverBody: some View {
        ZStack {
            musicBackground

            VStack(spacing: 5) {
                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.music"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(coverLegibility.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(common.detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(coverLegibility.secondaryText)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .shadow(color: coverLegibility.shadow, radius: 3, y: 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func compactArtwork(size: CGFloat) -> some View {
        ZStack {
            LinearGradient(colors: palette.background, startPoint: .topLeading, endPoint: .bottomTrailing)
            artworkImageView(contentMode: .fill)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size >= 50 ? 12 : 10, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            if musicState == .playing && payload.hasArtwork {
                MusicEqualizerView(isPlaying: true, accent: .white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.34), in: Capsule())
                    .padding(5)
            }
        }
    }

    private var musicCoverScrimColors: [Color] {
        coverLegibility.scrimColors
    }

    private var coverLegibility: CaptureCardLegibility {
        if payload.artworkData != nil {
            return CaptureCardLegibility.imageData(payload.artworkData, highContrast: highContrast)
        }
        return CaptureCardLegibility.palette(palette, highContrast: highContrast)
    }

    private var musicBackground: some View {
        ZStack {
            LinearGradient(colors: palette.background, startPoint: .topLeading, endPoint: .bottomTrailing)
            artworkBackgroundImage
                .scaleEffect(1.24)
                .blur(radius: 16)
                .saturation(1.08)
                .opacity(0.62)
            LinearGradient(
                colors: musicCoverScrimColors,
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private var artworkBackgroundImage: some View {
        if let image = payload.artworkImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else if let artworkURL = payload.artworkURL, let url = URL(string: artworkURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                default:
                    Color.clear
                }
            }
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func artworkImageView(contentMode: ContentMode) -> some View {
        if let image = payload.artworkImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else if let artworkURL = payload.artworkURL, let url = URL(string: artworkURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                default:
                    musicPlaceholder
                }
            }
        } else {
            musicPlaceholder
        }
    }

    private var musicState: CaptureMusicPlaybackState {
        payload.playbackState ?? (common.origin == .context ? .playing : .searchResult)
    }

    private var musicPlaceholder: some View {
        Image(systemName: "music.note")
            .font(.title2.weight(.bold))
            .foregroundStyle(palette.primaryText.opacity(0.92))
    }
}

private struct LinkCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureLinkCardPayload
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "safari.fill")
                    .font(.title3)
                    .foregroundStyle(accent)
                Text(linkHeader)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(linkTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            if let linkDetail {
                Text(linkDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(accent.opacity(0.08))
    }

    private var linkHeader: String {
        common.metadata?.trimmedOrNil ?? URL(string: common.detail)?.host() ?? String(localized: "capture.card.kind.link")
    }

    private var linkTitle: String {
        let title = common.title?.trimmedOrNil
        if let title, !sameField(title, linkHeader) {
            return title
        }
        return linkHeader
    }

    private var linkDetail: String? {
        let detail = common.detail.trimmedOrNil
        guard let detail, !sameField(detail, linkTitle), !sameField(detail, linkHeader) else {
            return nil
        }
        return detail
    }

    private func sameField(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare(rhs.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }
}

private struct TodoCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureTodoCardPayload
    let accent: Color
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(accent)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.todo"))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(common.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(accent.opacity(0.08))
    }
}

private struct StatusCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureStatusCardPayload
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundStyle(statusColor)

            Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.status"))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Text(common.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(statusColor.opacity(0.08))
    }

    private var statusIcon: String {
        switch common.state {
        case .loading:
            return "hourglass"
        case .error:
            return "exclamationmark.triangle.fill"
        case .disabled:
            return "minus.circle"
        case .normal:
            return "info.circle"
        }
    }

    private var statusColor: Color {
        switch common.state {
        case .loading:
            return .blue
        case .error:
            return .red
        case .disabled:
            return .secondary
        case .normal:
            return .secondary
        }
    }
}

private extension CapturePhotoCardPayload {
    var thumbnailImage: UIImage? {
        guard let thumbnailData else { return nil }
        return UIImage(data: thumbnailData)
    }
}

private extension CaptureMusicCardPayload {
    var artworkImage: UIImage? {
        guard let artworkData else { return nil }
        return UIImage(data: artworkData)
    }

    var hasArtwork: Bool {
        artworkURL?.trimmedOrNil != nil || artworkData != nil
    }
}

private extension CapturePlaceCardPayload {
    var mapSnapshotImage: UIImage? {
        guard let mapSnapshotData else { return nil }
        return UIImage(data: mapSnapshotData)
    }
}

private func formatDuration(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let remainder = seconds % 60
    return "\(minutes):\(String(format: "%02d", remainder))"
}

private struct MusicEqualizerView: View {
    let isPlaying: Bool
    let accent: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    let animatedHeight = 7 + abs(sin(time * 2.6 + Double(index))) * 11
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(accent.opacity(isPlaying ? 0.76 : 0.34))
                        .frame(width: 3, height: isPlaying ? animatedHeight : CGFloat([8, 13, 10, 15, 9][index]))
                }
            }
        }
        .frame(width: 28, height: 18, alignment: .bottom)
    }
}
