import SwiftUI
import UIKit

struct CaptureCardView: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let item: CaptureCardItem
    var reduceMotionOverride: Bool?
    var highContrastOverride: Bool?
    var provenanceDisplayMode: CaptureCardProvenanceDisplayMode = .production
    var weatherSymbolMotionLevel: CaptureWeatherSymbolMotionLevel = .subtle
    var weatherAtmosphereIntensityScale: Double = 1
    var musicCardStyle: CaptureMusicCardStyle = .auto
    var placeCardStyle: CapturePlaceCardStyle = .auto
    var showsLayoutGuides = false
    var showsFieldAudit = false
    var onTap: (() -> Void)?
    var onRemove: (() -> Void)?

    var body: some View {
        Button {
            guard item.allowsPrimaryAction else { return }
            onTap?()
        } label: {
            cardBody
        }
        .buttonStyle(.plain)
        .disabled(item.state == .disabled)
        .opacity(item.state == .disabled ? 0.48 : 1)
        .scaleEffect(item.displaysSelection ? 1.018 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: item.displaysSelection)
        .transition(.scale(scale: 0.96).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var cardBody: some View {
        CaptureCardChrome(
            item: item,
            containerBackground: containerBackground,
            containerStroke: containerStroke,
            loadingOverlay: loadingOverlay,
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
        switch item.kind {
        case .photo:
            PhotoCaptureCardContent(item: item, accent: accent, topTrailingAvoidance: topTrailingAvoidance)
        case .audio:
            AudioCaptureCardContent(item: item, accent: accent, topTrailingAvoidance: topTrailingAvoidance)
        case .place:
            PlaceCaptureCardContent(
                item: item,
                accent: accent,
                highContrastOverride: highContrastOverride,
                topTrailingAvoidance: topTrailingAvoidance,
                style: placeCardStyle.resolved(for: item)
            )
        case .weather:
            WeatherCaptureCardContent(
                item: item,
                accent: accent,
                reduceMotionOverride: reduceMotionOverride,
                symbolMotionLevel: weatherSymbolMotionLevel,
                atmosphereIntensityScale: weatherAtmosphereIntensityScale,
                topTrailingAvoidance: topTrailingAvoidance
            )
        case .music:
            MusicCaptureCardContent(
                item: item,
                accent: accent,
                palette: palette,
                style: musicCardStyle.resolved(for: item),
                topTrailingAvoidance: topTrailingAvoidance
            )
        case .link:
            LinkCaptureCardContent(item: item, accent: accent, topTrailingAvoidance: topTrailingAvoidance)
        case .todo:
            TodoCaptureCardContent(item: item, accent: accent, topTrailingAvoidance: topTrailingAvoidance)
        case .status:
            StatusCaptureCardContent(item: item, accent: accent, topTrailingAvoidance: topTrailingAvoidance)
        }
    }

    private var cardFooter: some View {
        HStack(spacing: 6) {
            if let origin = item.origin,
               let visual = provenanceDisplayMode.visual(for: origin) {
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
                .background(.regularMaterial, in: Circle())
        } else if item.displaysRemoveControl {
            removeButton
        } else if item.state == .error {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .padding(7)
                .background(.regularMaterial, in: Circle())
        } else if item.displaysSelection {
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

    private var loadingOverlay: some View {
        LinearGradient(
            colors: [.clear, palette.primaryText.opacity(0.2), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .allowsHitTesting(false)
    }

    private var containerBackground: AnyShapeStyle {
        AnyShapeStyle(.regularMaterial)
    }

    private var containerStroke: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(
                item.displaysSelection ? palette.selectionStroke : Color.primary.opacity(highContrast ? 0.18 : 0.08),
                lineWidth: item.displaysSelection ? (highContrast ? 1.8 : 1.35) : (highContrast ? 1.2 : 1)
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
        guard provenanceDisplayMode != .debug else { return metadata }
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
        item.kind == .place && item.mapSnapshotData != nil && !item.isLocationPrivacyEnabled
    }

    private var mapLegibilityStyle: CaptureMapLegibilityStyle {
        usesMapLegibility ? CaptureMapLegibilityStyle.resolve(snapshotData: item.mapSnapshotData) : .materialFallback
    }

    private var mapFooterForeground: Color {
        switch mapLegibilityStyle {
        case .lightText:
            return .white
        case .darkText:
            return .black.opacity(0.86)
        case .materialFallback:
            return .primary
        }
    }

    private var mapFooterBackground: Color {
        switch mapLegibilityStyle {
        case .lightText:
            return .black.opacity(highContrast ? 0.48 : 0.28)
        case .darkText:
            return .white.opacity(highContrast ? 0.78 : 0.56)
        case .materialFallback:
            return Color.primary.opacity(highContrast ? 0.18 : 0.1)
        }
    }

    private var highContrast: Bool {
        highContrastOverride ?? (colorSchemeContrast == .increased)
    }

    private var topTrailingAvoidance: CGFloat {
        item.topTrailingAvoidance
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
            "kind=\(item.kind.rawValue)",
            "state=\(item.state.rawValue)",
            "origin=\(item.origin?.rawValue ?? "nil")",
            "title=\(item.title ?? "nil")",
            "detail=\(item.detail)",
            "metadata=\(item.metadata ?? "nil")",
            "conditionCode=\(item.weatherConditionCode ?? "nil")",
            "symbolName=\(item.weatherSymbolName ?? "nil")",
            "isDaylight=\(item.weatherIsDaylight.map(String.init) ?? "nil")",
            "weatherStyle=\(resolvedWeatherStyleForAudit.rawValue)",
        ].joined(separator: "\n")
    }

    private var resolvedWeatherStyleForAudit: CaptureWeatherVisualStyle {
        item.weatherStyle ?? .resolve(
            conditionCode: item.weatherConditionCode,
            condition: [item.title, item.detail].compactMap { $0 }.joined(separator: " "),
            isDaylight: item.weatherIsDaylight
        )
    }
}

private struct CaptureCardChrome<Content: View, Footer: View, TrailingControl: View, LoadingOverlay: View, ContainerStroke: View>: View {
    let item: CaptureCardItem
    let containerBackground: AnyShapeStyle
    let containerStroke: ContainerStroke
    let loadingOverlay: LoadingOverlay
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
                .overlay(containerStroke)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .bottomLeading) { footer }
                .overlay {
                    if item.state == .loading {
                        loadingOverlay
                    }
                }
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

            trailingControl
                .padding(9)
        }
    }

    private var layoutGuides: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.yellow.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            if item.hasTrailingControl {
                Rectangle()
                    .fill(.red.opacity(0.14))
                    .frame(width: item.topTrailingAvoidance, height: item.topTrailingAvoidance)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct PhotoCaptureCardContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let item: CaptureCardItem
    let accent: Color
    let topTrailingAvoidance: CGFloat

    var body: some View {
        if item.photoCount > 1 {
            photoGroupContent
        } else {
            singlePhotoContent
        }
    }

    private var singlePhotoContent: some View {
        ZStack(alignment: .bottomLeading) {
            photoBackground
            photoScrim
            titleBlock(foreground: .primary, shadow: false)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, 36)
                .padding(.trailing, titleTrailingPadding)
        }
    }

    private var photoGroupContent: some View {
        ZStack(alignment: .bottomLeading) {
            switch item.photoGroupStyle ?? .mosaic {
            case .mosaic:
                mosaicBackground
            case .stack:
                stackBackground
            case .carousel:
                carouselBackground
            }

            photoScrim
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title?.trimmedOrNil ?? String(localized: "capture.card.kind.photos"))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(String(format: String(localized: "capture.card.photo.count.format"), item.photoCount))
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 36)
            .padding(.trailing, titleTrailingPadding)
        }
    }

    @ViewBuilder
    private var photoBackground: some View {
        if let image = item.thumbnailImage {
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
            if let image = item.thumbnailImage, index == 0 {
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
            colors: photoUsesLightText
                ? [.clear, .black.opacity(0.12), .black.opacity(0.52)]
                : [.clear, .white.opacity(0.16), .white.opacity(0.64)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var photoUsesLightText: Bool {
        CaptureImageLegibilityStyle.resolve(imageData: item.thumbnailData) != .darkText
    }

    private var titleTrailingPadding: CGFloat {
        topTrailingAvoidance > 0 ? max(0, topTrailingAvoidance - 14) : 0
    }

    private func titleBlock(foreground: Color, shadow: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title?.trimmedOrNil ?? String(localized: "capture.card.kind.photo"))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(item.detail)
                .font(.caption)
                .lineLimit(2)
        }
        .foregroundStyle(foreground)
        .shadow(color: shadow ? .black.opacity(0.22) : .clear, radius: 3, y: 1)
    }
}

private struct AudioCaptureCardContent: View {
    let item: CaptureCardItem
    let accent: Color
    let topTrailingAvoidance: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(accent, in: Circle())

                Text(item.title?.trimmedOrNil ?? String(localized: "capture.card.kind.audio"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let duration = item.durationSeconds {
                    Text(formatDuration(duration))
                        .font(.caption2.monospacedDigit().weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.trailing, topTrailingAvoidance)

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
        guard let detail = item.detail.trimmedOrNil, detail != String(localized: "capture.card.audio.attached") else {
            return String(localized: "capture.card.audio.originalAttached")
        }
        return detail
    }

    private var transcriptIsAvailable: Bool {
        item.detail.trimmedOrNil != nil && item.detail != String(localized: "capture.card.audio.attached")
    }
}

private struct PlaceCaptureCardContent: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let item: CaptureCardItem
    let accent: Color
    let highContrastOverride: Bool?
    let topTrailingAvoidance: CGFloat
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
                .padding(.trailing, topTrailingAvoidance)

            Spacer()

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title?.trimmedOrNil ?? String(localized: "capture.card.kind.place"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .shadow(color: placeTextShadow, radius: 3, y: 1)
        .padding(12)
        .padding(.trailing, topTrailingAvoidance > 0 ? 10 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var immersiveFooter: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title?.trimmedOrNil ?? String(localized: "capture.card.kind.place"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(item.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .padding(.trailing, topTrailingAvoidance > 0 ? 10 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(immersiveFooterBackground)
    }

    private var immersiveFooterBackground: some View {
        Rectangle()
            .fill(.regularMaterial)
    }

    @ViewBuilder
    private var placeBackground: some View {
        if let image = item.mapSnapshotImage, !item.isLocationPrivacyEnabled {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .overlay(placeSnapshotScrim)
        } else {
            mapBackground
                .overlay {
                    if item.isLocationPrivacyEnabled {
                        Rectangle()
                            .fill(.regularMaterial)
                    }
                }
        }
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
        guard item.mapSnapshotData != nil, !item.isLocationPrivacyEnabled else {
            return .materialFallback
        }
        return CaptureMapLegibilityStyle.resolve(snapshotData: item.mapSnapshotData)
    }

    private var placePrimaryText: Color {
        switch legibilityStyle {
        case .lightText:
            return .white
        case .darkText:
            return .black.opacity(0.88)
        case .materialFallback:
            return .primary
        }
    }

    private var placeSecondaryText: Color {
        switch legibilityStyle {
        case .lightText:
            return .white.opacity(highContrast ? 0.92 : 0.78)
        case .darkText:
            return .black.opacity(highContrast ? 0.78 : 0.62)
        case .materialFallback:
            return .secondary
        }
    }

    private var placeTextShadow: Color {
        legibilityStyle == .lightText ? .black.opacity(0.26) : .clear
    }

    private var placeSnapshotScrim: some View {
        LinearGradient(
            colors: placeScrimColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var placeScrimColors: [Color] {
        switch legibilityStyle {
        case .lightText:
            return [.black.opacity(0.05), .black.opacity(highContrast ? 0.62 : 0.42)]
        case .darkText:
            return [.white.opacity(0.16), .white.opacity(highContrast ? 0.74 : 0.54)]
        case .materialFallback:
            return [.clear, .black.opacity(0.18)]
        }
    }

    private var highContrast: Bool {
        highContrastOverride ?? (colorSchemeContrast == .increased)
    }
}

private struct WeatherCaptureCardContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let item: CaptureCardItem
    let accent: Color
    let reduceMotionOverride: Bool?
    let symbolMotionLevel: CaptureWeatherSymbolMotionLevel
    let atmosphereIntensityScale: Double
    let topTrailingAvoidance: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            weatherIcon

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title?.trimmedOrNil ?? String(localized: "capture.card.kind.weather"))
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(.trailing, topTrailingAvoidance)
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            WeatherAtmosphereView(
                spec: weatherAtmosphereSpec,
                isReduceMotionEnabled: resolvedReduceMotion
            )
        }
    }

    private var weatherStyle: CaptureWeatherVisualStyle {
        item.weatherStyle ?? .resolve(
            conditionCode: item.weatherConditionCode,
            condition: [item.title, item.detail].compactMap { $0 }.joined(separator: " "),
            isDaylight: item.weatherIsDaylight
        )
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
        Image(systemName: item.weatherSymbolName?.trimmedOrNil ?? weatherStyle.symbolName)
            .font(.system(size: 34, weight: .semibold))
            .symbolRenderingMode(.multicolor)
            .frame(width: 44)
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
    let item: CaptureCardItem
    let accent: Color
    let palette: CaptureCardPalette
    let style: CaptureMusicCardStyle
    let topTrailingAvoidance: CGFloat

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
        HStack(alignment: .top, spacing: 11) {
            compactArtwork(size: 54)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title?.trimmedOrNil ?? String(localized: "capture.card.kind.music"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(1)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(2)
                Spacer(minLength: 0)
                musicFooter()
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.trailing, topTrailingAvoidance)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            LinearGradient(
                colors: musicState == .unavailable || musicState == .stopped
                    ? [Color.secondary.opacity(0.08), Color.secondary.opacity(0.04)]
                    : palette.background.map { $0.opacity(0.16) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var compactTileBody: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 9) {
                compactArtwork(size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title?.trimmedOrNil ?? String(localized: "capture.card.kind.music"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(2)
                    Text(item.detail)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }
                .padding(.trailing, topTrailingAvoidance)
            }

            Spacer(minLength: 0)
            musicFooter()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            LinearGradient(
                colors: musicState == .unavailable || musicState == .stopped
                    ? [Color.secondary.opacity(0.08), Color.secondary.opacity(0.04)]
                    : palette.background.map { $0.opacity(0.16) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var coverBody: some View {
        ZStack {
            coverBackground

            VStack(spacing: 5) {
                Text(item.title?.trimmedOrNil ?? String(localized: "capture.card.kind.music"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(item.detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .padding(.top, topTrailingAvoidance > 0 ? 12 : 0)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
    }

    private func musicFooter(alignment: Alignment = .leading) -> some View {
        HStack(spacing: 6) {
            if musicState == .playing {
                MusicEqualizerView(isPlaying: true, accent: accent)
            }

            if let visibleMusicStateText {
                Text(visibleMusicStateText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var musicCoverUsesLightText: Bool {
        CaptureImageLegibilityStyle.resolve(imageData: item.thumbnailData) != .darkText
    }

    private var musicCoverScrimColors: [Color] {
        if musicCoverUsesLightText {
            return [.black.opacity(0.16), .black.opacity(0.5)]
        }
        return [.white.opacity(0.24), .white.opacity(0.68)]
    }

    private var visibleMusicStateText: String? {
        switch musicState {
        case .playing:
            return nil
        case .paused, .stopped, .unavailable, .searchResult:
            return musicState.label
        }
    }

    private var coverBackground: some View {
        ZStack {
            LinearGradient(colors: palette.background, startPoint: .topLeading, endPoint: .bottomTrailing)
            artworkImageView(contentMode: .fill)
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
    private func artworkImageView(contentMode: ContentMode) -> some View {
        if let image = item.thumbnailImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else if let artworkURL = item.artworkURL, let url = URL(string: artworkURL) {
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
        item.musicPlaybackState ?? (item.origin == .context ? .playing : .searchResult)
    }

    private var musicPlaceholder: some View {
        Image(systemName: "music.note")
            .font(.title2.weight(.bold))
            .foregroundStyle(palette.primaryText.opacity(0.92))
    }
}

private struct LinkCaptureCardContent: View {
    let item: CaptureCardItem
    let accent: Color
    let topTrailingAvoidance: CGFloat

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
            .padding(.trailing, topTrailingAvoidance)

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
        item.metadata?.trimmedOrNil ?? URL(string: item.detail)?.host() ?? String(localized: "capture.card.kind.link")
    }

    private var linkTitle: String {
        let title = item.title?.trimmedOrNil
        if let title, !sameField(title, linkHeader) {
            return title
        }
        return linkHeader
    }

    private var linkDetail: String? {
        let detail = item.detail.trimmedOrNil
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
    let item: CaptureCardItem
    let accent: Color
    let topTrailingAvoidance: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.displaysSelection ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(accent)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title?.trimmedOrNil ?? String(localized: "capture.card.kind.todo"))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(.trailing, topTrailingAvoidance)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(accent.opacity(0.08))
    }
}

private struct StatusCaptureCardContent: View {
    let item: CaptureCardItem
    let accent: Color
    let topTrailingAvoidance: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundStyle(statusColor)

            Text(item.title?.trimmedOrNil ?? String(localized: "capture.card.kind.status"))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.trailing, topTrailingAvoidance)

            Text(item.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(statusColor.opacity(0.08))
    }

    private var statusIcon: String {
        switch item.state {
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
        switch item.state {
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

private enum CaptureImageLegibilityStyle {
    case lightText
    case darkText

    static func resolve(imageData: Data?) -> CaptureImageLegibilityStyle {
        guard let imageData,
              let image = UIImage(data: imageData) else {
            return .lightText
        }
        return resolve(image: image)
    }

    static func resolve(image: UIImage) -> CaptureImageLegibilityStyle {
        guard let cgImage = image.cgImage else { return .lightText }
        let width = 1
        let height = 1
        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixel,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return .lightText
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let red = Double(pixel[0]) / 255
        let green = Double(pixel[1]) / 255
        let blue = Double(pixel[2]) / 255
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.58 ? .darkText : .lightText
    }
}

private extension CaptureCardItem {
    var thumbnailImage: UIImage? {
        guard let thumbnailData else { return nil }
        return UIImage(data: thumbnailData)
    }

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
