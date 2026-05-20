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
        ZStack(alignment: .topTrailing) {
            content
                .frame(width: 190, height: 132)
                .background(containerBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(containerStroke)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    cardFooter
                }
                .overlay {
                    if item.state == .loading {
                        loadingOverlay
                    }
                }

            trailingControl
                .padding(9)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .photo:
            PhotoCaptureCardContent(item: item, accent: accent)
        case .audio:
            AudioCaptureCardContent(item: item, accent: accent)
        case .place:
            PlaceCaptureCardContent(item: item, accent: accent, highContrastOverride: highContrastOverride)
        case .weather:
            WeatherCaptureCardContent(
                item: item,
                accent: accent,
                reduceMotionOverride: reduceMotionOverride,
                symbolMotionLevel: weatherSymbolMotionLevel,
                atmosphereIntensityScale: weatherAtmosphereIntensityScale
            )
        case .music:
            MusicCaptureCardContent(item: item, accent: accent, palette: palette)
        case .link:
            LinkCaptureCardContent(item: item, accent: accent)
        case .todo:
            TodoCaptureCardContent(item: item, accent: accent)
        case .status:
            StatusCaptureCardContent(item: item, accent: accent)
        }
    }

    private var cardFooter: some View {
        HStack(spacing: 6) {
            if let origin = item.origin,
               let visual = provenanceDisplayMode.visual(for: origin) {
                originBadge(visual, origin: origin)
            }

            if let metadata = item.metadata?.trimmedOrNil {
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
        .accessibilityLabel(item.state == .error ? "Remove failed item" : "Remove")
    }

    private var loadingOverlay: some View {
        LinearGradient(
            colors: [.clear, palette.primaryText.opacity(0.2), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .allowsHitTesting(false)
    }

    private var containerBackground: some ShapeStyle {
        .regularMaterial
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
}

private struct PhotoCaptureCardContent: View {
    let item: CaptureCardItem
    let accent: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
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

            titleBlock(foreground: .white, shadow: true)
                .padding(.horizontal, 12)
                .padding(.bottom, 36)
        }
    }

    private func titleBlock(foreground: Color, shadow: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title?.trimmedOrNil ?? "Photo")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(accent, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title?.trimmedOrNil ?? "Voice")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if let duration = item.durationSeconds {
                        Text(formatDuration(duration))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<12, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(accent.opacity(index.isMultiple(of: 3) ? 0.95 : 0.38))
                        .frame(width: 4, height: CGFloat([12, 22, 15, 30, 18, 26, 13, 34, 21, 16, 28, 14][index]))
                }
            }

            Text(item.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(accent.opacity(0.08))
    }
}

private struct PlaceCaptureCardContent: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let item: CaptureCardItem
    let accent: Color
    let highContrastOverride: Bool?

    var body: some View {
        ZStack {
            placeBackground

            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(placePrimaryText, accent)

                Spacer()

                Text(item.title?.trimmedOrNil ?? "Place")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(placePrimaryText)
                    .lineLimit(1)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(placeSecondaryText)
                    .lineLimit(2)
            }
            .shadow(color: placeTextShadow, radius: 3, y: 1)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
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
                        VisualEffectBlur()
                            .opacity(0.42)
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
            }
            .stroke(accent.opacity(0.34), lineWidth: 2)

            VStack(spacing: 22) {
                ForEach(0..<4, id: \.self) { _ in
                    Rectangle().fill(Color.primary.opacity(0.045)).frame(height: 1)
                }
            }
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

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            weatherIcon

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title?.trimmedOrNil ?? "Weather")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
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
        item.weatherStyle ?? .resolve(condition: [item.title, item.detail].compactMap { $0 }.joined(separator: " "))
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
        Image(systemName: weatherStyle.symbolName)
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

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                LinearGradient(colors: palette.background, startPoint: .topLeading, endPoint: .bottomTrailing)
                if let artworkURL = item.artworkURL, let url = URL(string: artworkURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            musicPlaceholder
                        }
                    }
                } else {
                    musicPlaceholder
                }
            }
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title?.trimmedOrNil ?? "Music")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(1)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if musicState == .playing || musicState == .paused {
                        MusicEqualizerView(isPlaying: musicState == .playing, accent: accent)
                    }
                    Text(musicState.label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }
            }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "safari.fill")
                    .font(.title3)
                    .foregroundStyle(accent)
                Text(item.metadata?.trimmedOrNil ?? "Link")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(item.title?.trimmedOrNil ?? "Link")
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            Text(item.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(accent.opacity(0.08))
    }
}

private struct TodoCaptureCardContent: View {
    let item: CaptureCardItem
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.displaysSelection ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(accent)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title?.trimmedOrNil ?? "Task")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(item.detail)
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
    let item: CaptureCardItem
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundStyle(statusColor)

            Text(item.title?.trimmedOrNil ?? "Status")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

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

private struct VisualEffectBlur: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
