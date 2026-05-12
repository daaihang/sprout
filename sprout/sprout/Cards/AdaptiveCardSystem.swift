import SwiftUI
import UIKit

enum AdaptiveCardDensity: String, CaseIterable, Identifiable {
    case compact
    case standard
    case relaxed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compact: "Compact"
        case .standard: "Standard"
        case .relaxed: "Relaxed"
        }
    }
}

enum AdaptiveCardLayoutMode: String {
    case compactStrip
    case compactTile
    case splitLeadingVisual
    case stackedInfo
    case heroOverlay
}

enum AdaptiveCardPreferredLayout {
    case automatic
    case leadingVisual
    case metricFocus
    case listSummary
    case heroOverlay
    case stackedInfo
}

enum AdaptiveCardTransitionStyle: String, CaseIterable, Identifiable {
    case soft
    case standard
    case energetic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .soft: "Soft"
        case .standard: "Standard"
        case .energetic: "Energetic"
        }
    }

    var animation: Animation {
        switch self {
        case .soft:
            .easeInOut(duration: 0.26)
        case .standard:
            .spring(duration: 0.36, bounce: 0.16)
        case .energetic:
            .spring(duration: 0.42, bounce: 0.24)
        }
    }
}

enum AdaptiveCardFontFamily: String, CaseIterable, Identifiable {
    case sfPro
    case sfProRounded
    case sfCompact
    case sfMono
    case newYork

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sfPro: "SF Pro"
        case .sfProRounded: "SF Rounded"
        case .sfCompact: "SF Compact"
        case .sfMono: "SF Mono"
        case .newYork: "New York"
        }
    }
}

enum AdaptiveCardTypographyRole {
    case heroTitle
    case title
    case subtitle
    case body
    case metric
    case badge
    case meta
    case caption
}

struct AdaptiveCardTypographySpec {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let width: Font.Width?
    let monospacedDigits: Bool
    let tracking: CGFloat
}

struct AdaptiveCardTypography {
    var titleFamily: AdaptiveCardFontFamily
    var subtitleFamily: AdaptiveCardFontFamily
    var bodyFamily: AdaptiveCardFontFamily
    var metricFamily: AdaptiveCardFontFamily
    var badgeFamily: AdaptiveCardFontFamily

    static let `default` = AdaptiveCardTypography(
        titleFamily: .sfPro,
        subtitleFamily: .sfCompact,
        bodyFamily: .sfPro,
        metricFamily: .sfProRounded,
        badgeFamily: .sfCompact
    )

    func spec(for role: AdaptiveCardTypographyRole, context: AdaptiveCardLayoutContext) -> AdaptiveCardTypographySpec {
        let density = context.density
        switch role {
        case .heroTitle:
            return makeSpec(
                family: titleFamily,
                size: density == .relaxed ? 22 : 18,
                weight: .semibold
            )
        case .title:
            return makeSpec(
                family: titleFamily,
                size: density == .compact ? 13 : (density == .relaxed ? 18 : 15),
                weight: .semibold
            )
        case .subtitle:
            return makeSpec(
                family: subtitleFamily,
                size: density == .compact ? 10.5 : 12,
                weight: .medium
            )
        case .body:
            return makeSpec(
                family: bodyFamily,
                size: density == .relaxed ? 13.5 : 12,
                weight: .regular
            )
        case .metric:
            return makeSpec(
                family: metricFamily,
                size: density == .compact ? 30 : (density == .relaxed ? 58 : 42),
                weight: .semibold
            )
        case .badge:
            return makeSpec(
                family: badgeFamily,
                size: density == .compact ? 10.5 : 11.5,
                weight: .semibold
            )
        case .meta:
            return makeSpec(
                family: subtitleFamily,
                size: density == .compact ? 10 : 11,
                weight: .medium
            )
        case .caption:
            return makeSpec(
                family: subtitleFamily,
                size: density == .compact ? 9.5 : 10,
                weight: .regular
            )
        }
    }

    private func makeSpec(family: AdaptiveCardFontFamily, size: CGFloat, weight: Font.Weight) -> AdaptiveCardTypographySpec {
        let design: Font.Design
        let width: Font.Width?
        let mono = family == .sfMono

        switch family {
        case .sfPro:
            design = .default
            width = nil
        case .sfProRounded:
            design = .rounded
            width = nil
        case .sfCompact:
            design = .default
            width = .compressed
        case .sfMono:
            design = .monospaced
            width = nil
        case .newYork:
            design = .serif
            width = nil
        }

        return AdaptiveCardTypographySpec(
            size: size,
            weight: weight,
            design: design,
            width: width,
            monospacedDigits: mono,
            tracking: family == .sfCompact ? -0.1 : 0
        )
    }
}

struct AdaptiveCardTheme {
    var primaryTint: Color = .accentColor
    var secondaryTint: Color = .secondary
    var metricTint: Color = .primary
    var symbolTint: Color = .accentColor
    var badgeTint: Color = .accentColor
    var softFill: Color = Color.accentColor.opacity(0.12)
    var overlayGradient: [Color] = [.clear, .black.opacity(0.58)]
    var typography: AdaptiveCardTypography = .default
    var densityOverride: AdaptiveCardDensity? = nil
    var transitionStyle: AdaptiveCardTransitionStyle = .standard

    static let `default` = AdaptiveCardTheme()

    func tinted(_ color: Color) -> AdaptiveCardTheme {
        var copy = self
        copy.primaryTint = color
        copy.symbolTint = color
        copy.badgeTint = color
        copy.softFill = color.opacity(0.12)
        return copy
    }

    func withMetricFamily(_ family: AdaptiveCardFontFamily) -> AdaptiveCardTheme {
        var copy = self
        copy.typography.metricFamily = family
        return copy
    }

    func withDensity(_ density: AdaptiveCardDensity?) -> AdaptiveCardTheme {
        var copy = self
        copy.densityOverride = density
        return copy
    }

    func withTransitionStyle(_ style: AdaptiveCardTransitionStyle) -> AdaptiveCardTheme {
        var copy = self
        copy.transitionStyle = style
        return copy
    }
}

enum AdaptiveCardThemePreset: String, CaseIterable, Identifiable {
    case automatic
    case sunrise
    case ocean
    case forest
    case rose
    case graphite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automatic: "Auto"
        case .sunrise: "Sunrise"
        case .ocean: "Ocean"
        case .forest: "Forest"
        case .rose: "Rose"
        case .graphite: "Graphite"
        }
    }

    func makeTheme() -> AdaptiveCardTheme {
        switch self {
        case .automatic:
            return .default
        case .sunrise:
            return AdaptiveCardTheme(
                primaryTint: Color(red: 0.93, green: 0.47, blue: 0.23),
                secondaryTint: .secondary,
                metricTint: .primary,
                symbolTint: Color(red: 0.98, green: 0.58, blue: 0.24),
                badgeTint: Color(red: 0.93, green: 0.47, blue: 0.23),
                softFill: Color(red: 0.98, green: 0.55, blue: 0.22).opacity(0.14),
                overlayGradient: [.clear, Color.black.opacity(0.62)],
                typography: .default,
                densityOverride: nil,
                transitionStyle: .standard
            )
        case .ocean:
            return AdaptiveCardTheme(
                primaryTint: Color(red: 0.14, green: 0.47, blue: 0.84),
                secondaryTint: .secondary,
                metricTint: .primary,
                symbolTint: Color(red: 0.17, green: 0.58, blue: 0.92),
                badgeTint: Color(red: 0.14, green: 0.47, blue: 0.84),
                softFill: Color(red: 0.17, green: 0.58, blue: 0.92).opacity(0.14),
                overlayGradient: [.clear, Color.black.opacity(0.62)],
                typography: .default,
                densityOverride: nil,
                transitionStyle: .standard
            )
        case .forest:
            return AdaptiveCardTheme(
                primaryTint: Color(red: 0.18, green: 0.51, blue: 0.36),
                secondaryTint: .secondary,
                metricTint: .primary,
                symbolTint: Color(red: 0.19, green: 0.63, blue: 0.41),
                badgeTint: Color(red: 0.18, green: 0.51, blue: 0.36),
                softFill: Color(red: 0.19, green: 0.63, blue: 0.41).opacity(0.14),
                overlayGradient: [.clear, Color.black.opacity(0.62)],
                typography: .default,
                densityOverride: nil,
                transitionStyle: .standard
            )
        case .rose:
            return AdaptiveCardTheme(
                primaryTint: Color(red: 0.76, green: 0.28, blue: 0.43),
                secondaryTint: .secondary,
                metricTint: .primary,
                symbolTint: Color(red: 0.88, green: 0.34, blue: 0.52),
                badgeTint: Color(red: 0.76, green: 0.28, blue: 0.43),
                softFill: Color(red: 0.88, green: 0.34, blue: 0.52).opacity(0.14),
                overlayGradient: [.clear, Color.black.opacity(0.62)],
                typography: .default,
                densityOverride: nil,
                transitionStyle: .energetic
            )
        case .graphite:
            return AdaptiveCardTheme(
                primaryTint: Color(white: 0.18),
                secondaryTint: .secondary,
                metricTint: .primary,
                symbolTint: Color(white: 0.32),
                badgeTint: Color(white: 0.25),
                softFill: Color.black.opacity(0.08),
                overlayGradient: [.clear, Color.black.opacity(0.68)],
                typography: .default,
                densityOverride: nil,
                transitionStyle: .soft
            )
        }
    }
}

struct AdaptiveCardBadge {
    var text: String
    var systemImage: String?
}

struct AdaptiveCardMetaItem: Identifiable {
    let id = UUID()
    var systemImage: String?
    var text: String
    var tint: Color? = nil
}

struct AdaptiveCardMetric {
    var value: String
    var unit: String? = nil
    var caption: String? = nil
    var accessibilityLabel: String? = nil
}

struct AdaptiveCardProgress {
    var value: Double
    var label: String? = nil
    var trailingText: String? = nil
}

struct AdaptiveCardListItem: Identifiable {
    let id = UUID()
    var systemImage: String?
    var symbolColor: Color? = nil
    var title: String
    var subtitle: String? = nil
    var emphasis: Bool = false
}

struct AdaptiveCardVisual {
    enum Treatment {
        case symbol
        case emoji
        case thumbnail
        case cover
        case hero
    }

    let treatment: Treatment
    let tint: Color?
    let accessibilityLabel: String?
    let sourceAspectRatio: CGFloat?
    let view: AnyView

    var isMedia: Bool {
        switch treatment {
        case .thumbnail, .cover, .hero:
            true
        case .symbol, .emoji:
            false
        }
    }

    var prefersHero: Bool { treatment == .hero }

    static func symbol(
        _ name: String,
        tint: Color? = nil,
        renderingMode: SymbolRenderingMode = .hierarchical
    ) -> AdaptiveCardVisual {
        AdaptiveCardVisual(
            treatment: .symbol,
            tint: tint,
            accessibilityLabel: nil,
            sourceAspectRatio: nil,
            view: AnyView(
                Image(systemName: name)
                    .symbolRenderingMode(renderingMode)
                    .contentTransition(.symbolEffect(.replace))
            )
        )
    }

    static func emoji(_ value: String, tint: Color? = nil) -> AdaptiveCardVisual {
        AdaptiveCardVisual(
            treatment: .emoji,
            tint: tint,
            accessibilityLabel: value,
            sourceAspectRatio: nil,
            view: AnyView(Text(value))
        )
    }

    static func remoteImage(
        _ url: URL?,
        placeholderSystemName: String,
        treatment: Treatment = .cover
    ) -> AdaptiveCardVisual {
        AdaptiveCardVisual(
            treatment: treatment,
            tint: nil,
            accessibilityLabel: nil,
            sourceAspectRatio: nil,
            view: AnyView(
                CachedRemoteImage(url: url, contentMode: .fill) {
                    ZStack {
                        Color.secondary.opacity(0.12)
                        Image(systemName: placeholderSystemName)
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                }
            )
        )
    }

    static func uiImage(_ image: UIImage, treatment: Treatment = .hero) -> AdaptiveCardVisual {
        AdaptiveCardVisual(
            treatment: treatment,
            tint: nil,
            accessibilityLabel: nil,
            sourceAspectRatio: image.size.height > 0 ? image.size.width / image.size.height : nil,
            view: AnyView(
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            )
        )
    }

    static func custom(
        treatment: Treatment,
        tint: Color? = nil,
        accessibilityLabel: String? = nil,
        sourceAspectRatio: CGFloat? = nil,
        @ViewBuilder _ view: () -> some View
    ) -> AdaptiveCardVisual {
        AdaptiveCardVisual(
            treatment: treatment,
            tint: tint,
            accessibilityLabel: accessibilityLabel,
            sourceAspectRatio: sourceAspectRatio,
            view: AnyView(view())
        )
    }
}

struct AdaptiveCardContent {
    var preferredLayout: AdaptiveCardPreferredLayout = .automatic
    var accent: Color? = nil
    var visual: AdaptiveCardVisual? = nil
    var title: String? = nil
    var subtitle: String? = nil
    var body: String? = nil
    var badge: AdaptiveCardBadge? = nil
    var metric: AdaptiveCardMetric? = nil
    var progress: AdaptiveCardProgress? = nil
    var metaItems: [AdaptiveCardMetaItem] = []
    var listItems: [AdaptiveCardListItem] = []
    var supplementary: AnyView? = nil
    var footer: String? = nil
}

struct AdaptiveCardLayoutContext {
    let containerSize: CGSize
    let inset: CGFloat
    let contentSize: CGSize
    let density: AdaptiveCardDensity
    let aspectRatio: CGFloat

    init(containerSize: CGSize, theme: AdaptiveCardTheme) {
        self.containerSize = containerSize
        let minAxis = min(containerSize.width, containerSize.height)
        let inset = max(10, min(18, minAxis * 0.12))
        self.inset = inset
        self.contentSize = CGSize(
            width: max(containerSize.width - inset * 2, 0),
            height: max(containerSize.height - inset * 2, 0)
        )
        self.aspectRatio = containerSize.height > 0 ? containerSize.width / containerSize.height : 1

        if let override = theme.densityOverride {
            self.density = override
        } else if containerSize.height < 88 || containerSize.width < 132 {
            self.density = .compact
        } else if containerSize.height > 170 && containerSize.width > 180 {
            self.density = .relaxed
        } else {
            self.density = .standard
        }
    }

    var spacing: CGFloat {
        switch density {
        case .compact: 6
        case .standard: 10
        case .relaxed: 12
        }
    }

    var isLandscape: Bool { aspectRatio >= 1.15 }
    var isPortrait: Bool { aspectRatio <= 0.95 }

    var supportsHero: Bool { contentSize.width >= 116 && contentSize.height >= 116 }
    var supportsSplit: Bool { contentSize.width >= 160 }
    var supportsBody: Bool { contentSize.height >= 94 }
    var supportsMeta: Bool { contentSize.height >= 72 }
    var supportsList: Bool { contentSize.height >= 120 }

    func titleLineLimit(for mode: AdaptiveCardLayoutMode, hasBody: Bool) -> Int {
        switch mode {
        case .compactStrip:
            return 1
        case .compactTile:
            return density == .compact ? 1 : 2
        case .splitLeadingVisual:
            return density == .relaxed ? 2 : 1
        case .stackedInfo:
            return hasBody && density == .compact ? 1 : (density == .relaxed ? 2 : 1)
        case .heroOverlay:
            return density == .relaxed ? 3 : 2
        }
    }

    func bodyLineLimit(for mode: AdaptiveCardLayoutMode) -> Int {
        switch mode {
        case .compactStrip:
            return 1
        case .compactTile:
            return density == .compact ? 1 : 2
        case .splitLeadingVisual:
            return density == .compact ? 1 : 2
        case .stackedInfo:
            return density == .relaxed ? 4 : 2
        case .heroOverlay:
            return density == .relaxed ? 4 : 2
        }
    }

    func textLineBudget(for mode: AdaptiveCardLayoutMode) -> Int {
        let height = contentSize.height

        switch mode {
        case .compactStrip:
            return height < 40 ? 1 : 2
        case .compactTile, .splitLeadingVisual:
            if height < 78 { return 1 }
            if height < 118 { return 2 }
            if height < 168 { return 3 }
            if height < 232 { return 4 }
            return density == .relaxed ? 5 : 4
        case .stackedInfo:
            if height < 78 { return 1 }
            if height < 118 { return 2 }
            if height < 168 { return 3 }
            if height < 232 { return 4 }
            return density == .relaxed ? 6 : 5
        case .heroOverlay:
            if height < 92 { return 2 }
            if height < 132 { return 3 }
            if height < 196 { return 4 }
            return density == .relaxed ? 6 : 5
        }
    }

    fileprivate func textPolicy(for mode: AdaptiveCardLayoutMode, hasSubtitle: Bool, hasBody: Bool) -> AdaptiveCardTextPolicy {
        let budget = textLineBudget(for: mode)

        switch mode {
        case .compactStrip:
            return AdaptiveCardTextPolicy(
                titleLines: budget > 0 ? 1 : 0,
                bodyLines: 0,
                showsSubtitle: hasSubtitle && budget > 1
            )
        default:
            break
        }

        let baseTitle = titleLineLimit(for: mode, hasBody: hasBody)
        let baseBody = bodyLineLimit(for: mode)

        if !hasBody {
            let titleLines = max(0, min(baseTitle, hasSubtitle ? max(1, budget - 1) : budget))
            let showsSubtitle = hasSubtitle && budget > titleLines
            return AdaptiveCardTextPolicy(titleLines: titleLines, bodyLines: 0, showsSubtitle: showsSubtitle)
        }

        let titleCap = mode == .heroOverlay || mode == .stackedInfo ? 2 : 1
        let titleLines = max(0, min(baseTitle, max(1, min(budget - 1, titleCap))))
        let showsSubtitle = hasSubtitle && budget >= 5
        let remaining = max(budget - titleLines - (showsSubtitle ? 1 : 0), 0)
        let bodyLines = min(baseBody, remaining)
        return AdaptiveCardTextPolicy(titleLines: titleLines, bodyLines: bodyLines, showsSubtitle: showsSubtitle)
    }

    func resolvedLayout(for content: AdaptiveCardContent) -> AdaptiveCardLayoutMode {
        if content.preferredLayout == .heroOverlay, supportsHero, content.visual?.isMedia == true {
            return .heroOverlay
        }

        if density == .compact && isLandscape {
            return .compactStrip
        }

        if content.preferredLayout == .leadingVisual, supportsSplit, content.visual != nil {
            return .splitLeadingVisual
        }

        if content.preferredLayout == .metricFocus {
            if density == .compact && isLandscape {
                return .compactStrip
            }
            return .stackedInfo
        }

        if content.preferredLayout == .stackedInfo {
            return .stackedInfo
        }

        if content.preferredLayout == .listSummary && supportsSplit && content.visual != nil {
            return .splitLeadingVisual
        }

        if content.visual?.prefersHero == true && supportsHero && !isLandscape {
            return .heroOverlay
        }

        if !supportsSplit && content.visual != nil {
            return .compactTile
        }

        if supportsSplit && content.visual != nil {
            return .splitLeadingVisual
        }

        if density == .compact {
            return .compactStrip
        }

        return .stackedInfo
    }
}

struct AdaptiveCardDiagnostics: Equatable {
    var layoutMode: String = "-"
    var density: String = "-"
    var metricFont: String = "-"
    var theme: String = "-"
    var titleOverflow: Bool = false
    var bodyOverflow: Bool = false
    var subtitleOverflow: Bool = false
    var visibleListItems: String = "-"
    var heroCrop: String = "-"
    var fallbackReason: String = "-"

    static let empty = AdaptiveCardDiagnostics()
}

private struct AdaptiveCardTextPolicy {
    var titleLines: Int
    var bodyLines: Int
    var showsSubtitle: Bool
}

private struct AdaptiveCardTextMeasureResult {
    var requiredHeight: CGFloat
    var allowedHeight: CGFloat
    var isTruncated: Bool
}

private struct AdaptiveCardOverflowReport {
    var resolvedMode: AdaptiveCardLayoutMode
    var titleOverflow: Bool = false
    var subtitleOverflow: Bool = false
    var bodyOverflow: Bool = false
    var visibleListItems: Int = 0
    var totalListItems: Int = 0
    var heroCropFraction: CGFloat = 0
    var fallbackReason: String = "ok"
}

struct AdaptiveCardDiagnosticsPreferenceKey: PreferenceKey {
    static var defaultValue: AdaptiveCardDiagnostics = .empty

    static func reduce(value: inout AdaptiveCardDiagnostics, nextValue: () -> AdaptiveCardDiagnostics) {
        value = nextValue()
    }
}

private struct AdaptiveCardThemeKey: EnvironmentKey {
    static var defaultValue: AdaptiveCardTheme = .default
}

extension EnvironmentValues {
    var adaptiveCardTheme: AdaptiveCardTheme {
        get { self[AdaptiveCardThemeKey.self] }
        set { self[AdaptiveCardThemeKey.self] = newValue }
    }
}

extension View {
    func adaptiveCardTheme(_ theme: AdaptiveCardTheme) -> some View {
        environment(\.adaptiveCardTheme, theme)
    }

    func adaptiveCardTextStyle(
        _ role: AdaptiveCardTypographyRole,
        context: AdaptiveCardLayoutContext,
        theme: AdaptiveCardTheme
    ) -> some View {
        let spec = theme.typography.spec(for: role, context: context)
        return self
            .font(.system(size: spec.size, weight: spec.weight, design: spec.design))
            .applyIfLet(spec.width) { view, width in
                view.fontWidth(width)
            }
            .tracking(spec.tracking)
            .applyIf(spec.monospacedDigits) { view in
                view.monospacedDigit()
            }
    }

    func adaptiveCardDiagnostics(_ value: AdaptiveCardDiagnostics) -> some View {
        preference(key: AdaptiveCardDiagnosticsPreferenceKey.self, value: value)
    }

    @ViewBuilder
    fileprivate func applyIf(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    @ViewBuilder
    fileprivate func applyIfLet<T>(_ value: T?, transform: (Self, T) -> some View) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}

struct AdaptiveCardRoot<Placeholder: View>: View {
    let content: AdaptiveCardContent?
    let themeLabel: String
    @ViewBuilder let placeholder: () -> Placeholder

    @Environment(\.adaptiveCardTheme) private var baseTheme

    init(
        content: AdaptiveCardContent?,
        themeLabel: String = "Custom",
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.content = content
        self.themeLabel = themeLabel
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let content {
                GeometryReader { geo in
                    let theme = resolvedTheme(for: content)
                    let context = AdaptiveCardLayoutContext(containerSize: geo.size, theme: theme)
                    let overflow = AdaptiveCardOverflowAnalyzer(content: content, context: context, theme: theme).resolve()
                    let diagnostics = AdaptiveCardDiagnostics(
                        layoutMode: overflow.resolvedMode.rawValue,
                        density: context.density.label,
                        metricFont: theme.typography.metricFamily.label,
                        theme: themeLabel,
                        titleOverflow: overflow.titleOverflow,
                        bodyOverflow: overflow.bodyOverflow,
                        subtitleOverflow: overflow.subtitleOverflow,
                        visibleListItems: "\(overflow.visibleListItems)/\(overflow.totalListItems)",
                        heroCrop: overflow.heroCropFraction > 0 ? "\(Int((overflow.heroCropFraction * 100).rounded()))%" : "0%",
                        fallbackReason: overflow.fallbackReason
                    )

                    AdaptiveCardRenderer(content: content, context: context, theme: theme, overflow: overflow)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .adaptiveCardDiagnostics(diagnostics)
                }
            } else {
                placeholder()
            }
        }
    }

    private func resolvedTheme(for content: AdaptiveCardContent) -> AdaptiveCardTheme {
        if let accent = content.accent {
            return baseTheme.tinted(accent)
        }
        return baseTheme
    }
}

private struct AdaptiveCardRenderer: View {
    let content: AdaptiveCardContent
    let context: AdaptiveCardLayoutContext
    let theme: AdaptiveCardTheme
    let overflow: AdaptiveCardOverflowReport

    private var mode: AdaptiveCardLayoutMode {
        overflow.resolvedMode
    }

    private var layoutAnimation: Animation {
        theme.transitionStyle.animation
    }

    private var textPolicy: AdaptiveCardTextPolicy {
        context.textPolicy(
            for: mode,
            hasSubtitle: mode == .compactStrip ? compactSubtitle != nil : content.subtitle != nil,
            hasBody: content.body != nil
        )
    }

    var body: some View {
        Group {
            switch mode {
            case .compactStrip:
                compactStrip
            case .compactTile:
                compactTile
            case .splitLeadingVisual:
                splitLeadingVisual
            case .stackedInfo:
                stackedInfo
            case .heroOverlay:
                heroOverlay
            }
        }
        .animation(layoutAnimation, value: mode.rawValue)
        .animation(layoutAnimation, value: content.title)
        .animation(layoutAnimation, value: content.subtitle)
        .animation(layoutAnimation, value: content.body)
        .animation(layoutAnimation, value: content.metric?.value)
        .animation(layoutAnimation, value: content.badge?.text)
    }

    private var compactStrip: some View {
        HStack(alignment: .center, spacing: context.spacing) {
            if let visual = content.visual {
                AdaptiveCardVisualView(
                    visual: visual,
                    mode: mode,
                    context: context,
                    theme: theme,
                    idealSize: CGSize(width: max(36, context.contentSize.height * 0.72), height: max(36, context.contentSize.height * 0.72))
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                if let title = content.title {
                    Text(title)
                        .adaptiveCardTextStyle(.title, context: context, theme: theme)
                        .foregroundStyle(.primary)
                        .lineLimit(textPolicy.titleLines)
                        .contentTransition(.interpolate)
                }
                if textPolicy.showsSubtitle, let subtitle = compactSubtitle {
                    Text(subtitle)
                        .adaptiveCardTextStyle(.subtitle, context: context, theme: theme)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .contentTransition(.interpolate)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailingCompactAccessory
        }
        .padding(context.inset)
    }

    private var compactTile: some View {
        VStack(alignment: .leading, spacing: context.spacing) {
            if let visual = content.visual {
                AdaptiveCardVisualView(
                    visual: visual,
                    mode: mode,
                    context: context,
                    theme: theme,
                    idealSize: CGSize(width: context.contentSize.width, height: max(context.contentSize.height * 0.52, 56))
                )
                .frame(maxWidth: .infinity)
            }

            if let metric = content.metric {
                AdaptiveCardMetricView(metric: metric, context: context, theme: theme, mode: mode)
            }

            primaryTextStack
            footerStack
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(context.inset)
    }

    private var splitLeadingVisual: some View {
        HStack(alignment: .center, spacing: max(context.spacing, 12)) {
            if let visual = content.visual {
                AdaptiveCardVisualView(
                    visual: visual,
                    mode: mode,
                    context: context,
                    theme: theme,
                    idealSize: CGSize(width: max(52, min(context.contentSize.width * 0.34, 108)), height: max(56, context.contentSize.height - 6))
                )
            }

            VStack(alignment: .leading, spacing: context.spacing * 0.6) {
                headerRow

                if let metric = content.metric, content.preferredLayout == .metricFocus {
                    AdaptiveCardMetricView(metric: metric, context: context, theme: theme, mode: mode)
                }

                primaryTextStack

                if let supplementary = content.supplementary {
                    supplementary
                }

                if let progress = content.progress {
                    AdaptiveCardProgressView(progress: progress, theme: theme)
                }

                metaRows(limit: context.density == .relaxed ? 3 : 2)
                listRows(limit: context.density == .relaxed ? 3 : 2)
                footerStack
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(context.inset)
    }

    private var stackedInfo: some View {
        VStack(alignment: .leading, spacing: context.spacing) {
            headerRow

            if let metric = content.metric {
                AdaptiveCardMetricView(metric: metric, context: context, theme: theme, mode: mode)
            }

            primaryTextStack

            if let supplementary = content.supplementary {
                supplementary
            }

            if let progress = content.progress {
                AdaptiveCardProgressView(progress: progress, theme: theme)
            }

            metaRows(limit: context.density == .relaxed ? 4 : 2)
            listRows(limit: context.supportsList ? (context.density == .relaxed ? 5 : 3) : 1)
            footerStack
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(context.inset)
    }

    private var heroOverlay: some View {
        ZStack(alignment: .bottomLeading) {
            if let visual = content.visual {
                AdaptiveCardVisualView(
                    visual: visual,
                    mode: mode,
                    context: context,
                    theme: theme,
                    idealSize: context.containerSize
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Rectangle()
                    .fill(theme.softFill)
            }

            LinearGradient(colors: theme.overlayGradient, startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 6) {
                if let badge = content.badge {
                    AdaptiveCardBadgeView(badge: badge, context: context, theme: theme, forceLightForeground: true)
                }
                if let title = content.title {
                    Text(title)
                        .adaptiveCardTextStyle(.heroTitle, context: context, theme: theme)
                        .foregroundStyle(.white)
                        .lineLimit(textPolicy.titleLines)
                        .contentTransition(.interpolate)
                }
                if textPolicy.showsSubtitle, let subtitle = content.subtitle {
                    Text(subtitle)
                        .adaptiveCardTextStyle(.subtitle, context: context, theme: theme)
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .contentTransition(.interpolate)
                }
                if textPolicy.bodyLines > 0, let body = content.body {
                    Text(body)
                        .adaptiveCardTextStyle(.body, context: context, theme: theme)
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(textPolicy.bodyLines)
                        .contentTransition(.interpolate)
                }
            }
            .padding(context.inset)
        }
        .clipShape(RoundedRectangle(cornerRadius: GridConfig.cardCornerRadius, style: .continuous))
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 8) {
            if let visual = content.visual, !visual.isMedia {
                AdaptiveCardVisualView(
                    visual: visual,
                    mode: mode,
                    context: context,
                    theme: theme,
                    idealSize: CGSize(width: context.density == .compact ? 28 : 42, height: context.density == .compact ? 28 : 42)
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                if let title = content.title {
                    Text(title)
                        .adaptiveCardTextStyle(.title, context: context, theme: theme)
                        .foregroundStyle(.primary)
                        .lineLimit(textPolicy.titleLines)
                        .contentTransition(.interpolate)
                }
                if textPolicy.showsSubtitle, let subtitle = content.subtitle {
                    Text(subtitle)
                        .adaptiveCardTextStyle(.subtitle, context: context, theme: theme)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .contentTransition(.interpolate)
                }
            }

            Spacer(minLength: 0)

            if let badge = content.badge {
                AdaptiveCardBadgeView(badge: badge, context: context, theme: theme)
            }
        }
    }

    @ViewBuilder
    private var primaryTextStack: some View {
        if textPolicy.bodyLines > 0, let body = content.body {
            Text(body)
                .adaptiveCardTextStyle(.body, context: context, theme: theme)
                .foregroundStyle(.primary)
                .lineLimit(textPolicy.bodyLines)
                .contentTransition(.interpolate)
        }
    }

    @ViewBuilder
    private var trailingCompactAccessory: some View {
        if let metric = content.metric {
            AdaptiveCardMetricInlineView(metric: metric, context: context, theme: theme)
        } else if let badge = content.badge {
            AdaptiveCardBadgeView(badge: badge, context: context, theme: theme)
        } else if let meta = content.metaItems.first {
            AdaptiveCardMetaItemView(item: meta, context: context, theme: theme)
        }
    }

    private var compactSubtitle: String? {
        content.subtitle ?? content.body ?? content.metaItems.first?.text
    }

    @ViewBuilder
    private func metaRows(limit: Int) -> some View {
        if !content.metaItems.isEmpty && context.supportsMeta {
            let visible = Array(content.metaItems.prefix(limit))
            VStack(alignment: .leading, spacing: 6) {
                ForEach(visible) { item in
                    AdaptiveCardMetaItemView(item: item, context: context, theme: theme)
                }
            }
        }
    }

    @ViewBuilder
    private func listRows(limit: Int) -> some View {
        if !content.listItems.isEmpty && context.supportsList {
            let effectiveLimit = min(limit, max(overflow.visibleListItems, 0))
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(content.listItems.prefix(effectiveLimit))) { item in
                    HStack(alignment: .top, spacing: 8) {
                        if let systemImage = item.systemImage {
                            Image(systemName: systemImage)
                                .font(.system(size: context.density == .compact ? 11 : 12, weight: .medium))
                                .foregroundStyle(item.symbolColor ?? theme.secondaryTint)
                                .contentTransition(.symbolEffect(.replace))
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .adaptiveCardTextStyle(item.emphasis ? .meta : .body, context: context, theme: theme)
                                .foregroundStyle(item.emphasis ? .primary : .secondary)
                                .lineLimit(1)
                                .contentTransition(.interpolate)

                            if let subtitle = item.subtitle, context.density != .compact {
                                Text(subtitle)
                                    .adaptiveCardTextStyle(.caption, context: context, theme: theme)
                                    .foregroundStyle(.secondary.opacity(0.8))
                                    .lineLimit(1)
                                    .contentTransition(.interpolate)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var footerStack: some View {
        if let footer = content.footer {
            Text(footer)
                .adaptiveCardTextStyle(.caption, context: context, theme: theme)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .contentTransition(.interpolate)
        }
    }
}

private struct AdaptiveCardVisualView: View {
    let visual: AdaptiveCardVisual
    let mode: AdaptiveCardLayoutMode
    let context: AdaptiveCardLayoutContext
    let theme: AdaptiveCardTheme
    let idealSize: CGSize

    var body: some View {
        Group {
            switch visual.treatment {
            case .symbol:
                visual.view
                    .font(.system(size: symbolPointSize, weight: .semibold))
                    .foregroundStyle(visual.tint ?? theme.symbolTint)
                    .frame(width: idealSize.width, height: idealSize.height)
                    .background(theme.softFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            case .emoji:
                visual.view
                    .font(.system(size: symbolPointSize))
                    .frame(width: idealSize.width, height: idealSize.height)
                    .background((visual.tint ?? theme.softFill).opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            case .thumbnail, .cover:
                visual.view
                    .frame(width: idealSize.width, height: idealSize.height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            case .hero:
                visual.view
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
        }
        .accessibilityLabel(visual.accessibilityLabel ?? "")
    }

    private var symbolPointSize: CGFloat {
        switch mode {
        case .compactStrip:
            return max(18, idealSize.height * 0.46)
        case .compactTile:
            return max(22, min(idealSize.height * 0.48, 44))
        case .splitLeadingVisual:
            return max(20, min(idealSize.height * 0.4, 42))
        case .stackedInfo:
            return context.density == .relaxed ? 34 : 26
        case .heroOverlay:
            return max(28, min(idealSize.height * 0.28, 52))
        }
    }
}

private struct AdaptiveCardMetricView: View {
    let metric: AdaptiveCardMetric
    let context: AdaptiveCardLayoutContext
    let theme: AdaptiveCardTheme
    let mode: AdaptiveCardLayoutMode

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(metric.value)
                    .adaptiveCardTextStyle(.metric, context: context, theme: theme)
                    .foregroundStyle(theme.metricTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .contentTransition(.numericText())

                if let unit = metric.unit {
                    Text(unit)
                        .adaptiveCardTextStyle(.subtitle, context: context, theme: theme)
                        .foregroundStyle(.secondary)
                        .baselineOffset(mode == .compactStrip ? 0 : 3)
                        .lineLimit(1)
                        .contentTransition(.interpolate)
                }
            }

            if let caption = metric.caption {
                Text(caption)
                    .adaptiveCardTextStyle(.meta, context: context, theme: theme)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .contentTransition(.interpolate)
            }
        }
    }
}

private struct AdaptiveCardMetricInlineView: View {
    let metric: AdaptiveCardMetric
    let context: AdaptiveCardLayoutContext
    let theme: AdaptiveCardTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(metric.value)
                .font(.system(size: context.density == .compact ? 24 : 28, weight: .semibold, design: theme.typography.metricFamily == .sfMono ? .monospaced : .rounded))
                .foregroundStyle(theme.metricTint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .contentTransition(.numericText())

            if let unit = metric.unit {
                Text(unit)
                    .adaptiveCardTextStyle(.caption, context: context, theme: theme)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AdaptiveCardBadgeView: View {
    let badge: AdaptiveCardBadge
    let context: AdaptiveCardLayoutContext
    let theme: AdaptiveCardTheme
    var forceLightForeground: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage = badge.systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: context.density == .compact ? 10 : 11, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
            }

            Text(badge.text)
                .adaptiveCardTextStyle(.badge, context: context, theme: theme)
                .lineLimit(1)
                .contentTransition(.interpolate)
        }
        .foregroundStyle(forceLightForeground ? .white : theme.badgeTint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((forceLightForeground ? Color.white.opacity(0.16) : theme.softFill), in: Capsule())
    }
}

private struct AdaptiveCardMetaItemView: View {
    let item: AdaptiveCardMetaItem
    let context: AdaptiveCardLayoutContext
    let theme: AdaptiveCardTheme

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage = item.systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: context.density == .compact ? 10.5 : 11, weight: .medium))
                    .foregroundStyle(item.tint ?? theme.secondaryTint)
                    .contentTransition(.symbolEffect(.replace))
            }

            Text(item.text)
                .adaptiveCardTextStyle(.meta, context: context, theme: theme)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .contentTransition(.interpolate)
        }
    }
}

private struct AdaptiveCardProgressView: View {
    let progress: AdaptiveCardProgress
    let theme: AdaptiveCardTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if progress.label != nil || progress.trailingText != nil {
                HStack(spacing: 8) {
                    if let label = progress.label {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    if let trailingText = progress.trailingText {
                        Text(trailingText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(theme.primaryTint)
                    }
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.softFill)
                    Capsule()
                        .fill(theme.primaryTint)
                        .frame(width: geo.size.width * max(0, min(progress.value, 1)))
                }
            }
            .frame(height: 6)
        }
    }
}

private struct AdaptiveCardOverflowAnalyzer {
    let content: AdaptiveCardContent
    let context: AdaptiveCardLayoutContext
    let theme: AdaptiveCardTheme

    func resolve() -> AdaptiveCardOverflowReport {
        let preferred = context.resolvedLayout(for: content)
        let candidates = candidateModes(startingWith: preferred)

        for (index, mode) in candidates.enumerated() {
            let report = measure(mode: mode)
            if !report.titleOverflow && !report.subtitleOverflow && !report.bodyOverflow {
                if index == 0 {
                    return report
                }
                var adjusted = report
                adjusted.fallbackReason = "fallback from \(preferred.rawValue)"
                return adjusted
            }
        }

        var fallback = measure(mode: candidates.last ?? preferred)
        fallback.fallbackReason = "overflow unresolved"
        return fallback
    }

    private func candidateModes(startingWith preferred: AdaptiveCardLayoutMode) -> [AdaptiveCardLayoutMode] {
        let fallbackOrder: [AdaptiveCardLayoutMode] = {
            switch preferred {
            case .heroOverlay:
                [.heroOverlay, .splitLeadingVisual, .stackedInfo, .compactTile, .compactStrip]
            case .splitLeadingVisual:
                [.splitLeadingVisual, .stackedInfo, .compactTile, .compactStrip]
            case .stackedInfo:
                [.stackedInfo, .splitLeadingVisual, .compactTile, .compactStrip]
            case .compactTile:
                [.compactTile, .splitLeadingVisual, .compactStrip]
            case .compactStrip:
                [.compactStrip]
            }
        }()

        return Array(NSOrderedSet(array: fallbackOrder)) as? [AdaptiveCardLayoutMode] ?? fallbackOrder
    }

    private func measure(mode: AdaptiveCardLayoutMode) -> AdaptiveCardOverflowReport {
        switch mode {
        case .compactStrip:
            measureCompactStrip()
        case .compactTile:
            measureCompactTile()
        case .splitLeadingVisual:
            measureSplitLeadingVisual()
        case .stackedInfo:
            measureStackedInfo()
        case .heroOverlay:
            measureHeroOverlay()
        }
    }

    private func measureCompactStrip() -> AdaptiveCardOverflowReport {
        let textPolicy = context.textPolicy(
            for: .compactStrip,
            hasSubtitle: compactSubtitle != nil,
            hasBody: false
        )
        let visualWidth = content.visual == nil ? 0 : max(36, context.contentSize.height * 0.72)
        let trailingWidth: CGFloat
        if let metric = content.metric {
            trailingWidth = measureMetricInlineWidth(metric)
        } else if let badge = content.badge {
            trailingWidth = measureBadgeWidth(badge)
        } else if let meta = content.metaItems.first {
            trailingWidth = measureMetaWidth(meta)
        } else {
            trailingWidth = 0
        }

        let availableWidth = max(context.contentSize.width - visualWidth - trailingWidth - context.spacing * 2, 32)
        let titleHeight = measureText(
            content.title,
            role: .title,
            width: availableWidth,
            lineLimit: textPolicy.titleLines,
            allowedHeight: singleOrDoubleLineAllowance(role: .title, count: textPolicy.titleLines)
        )
        let subtitleHeight = measureText(
            textPolicy.showsSubtitle ? compactSubtitle : nil,
            role: .subtitle,
            width: availableWidth,
            lineLimit: 1,
            allowedHeight: singleLineHeight(for: .subtitle)
        )

        return AdaptiveCardOverflowReport(
            resolvedMode: .compactStrip,
            titleOverflow: titleHeight.isTruncated,
            subtitleOverflow: subtitleHeight.isTruncated,
            bodyOverflow: false,
            visibleListItems: 0,
            totalListItems: content.listItems.count,
            heroCropFraction: 0,
            fallbackReason: "ok"
        )
    }

    private func measureCompactTile() -> AdaptiveCardOverflowReport {
        let textPolicy = context.textPolicy(for: .compactTile, hasSubtitle: false, hasBody: content.body != nil)
        let availableWidth = max(context.contentSize.width, 44)
        let visualHeight = content.visual == nil ? 0 : max(context.contentSize.height * 0.52, 56)
        let metricHeight = content.metric == nil ? 0 : measureMetricHeight(for: .compactTile, width: availableWidth)
        let titleAllowed = content.title == nil ? 0 : singleOrDoubleLineAllowance(role: .title, count: textPolicy.titleLines)
        let title = measureText(content.title, role: .title, width: availableWidth, lineLimit: textPolicy.titleLines, allowedHeight: titleAllowed)
        let bodyAllowed = content.body == nil ? 0 : singleOrDoubleLineAllowance(role: .body, count: textPolicy.bodyLines)
        let body = measureText(content.body, role: .body, width: availableWidth, lineLimit: textPolicy.bodyLines, allowedHeight: bodyAllowed)
        let footer = measureText(content.footer, role: .caption, width: availableWidth, lineLimit: 1, allowedHeight: singleLineHeight(for: .caption))
        let used = visualHeight + metricHeight + title.allowedHeight + body.allowedHeight + footer.allowedHeight + context.spacing * 3
        let bodyOverflow = body.isTruncated || used > context.contentSize.height + 2

        return AdaptiveCardOverflowReport(
            resolvedMode: .compactTile,
            titleOverflow: title.isTruncated,
            subtitleOverflow: false,
            bodyOverflow: bodyOverflow,
            visibleListItems: 0,
            totalListItems: content.listItems.count,
            heroCropFraction: 0,
            fallbackReason: "ok"
        )
    }

    private func measureSplitLeadingVisual() -> AdaptiveCardOverflowReport {
        let textPolicy = context.textPolicy(
            for: .splitLeadingVisual,
            hasSubtitle: content.subtitle != nil,
            hasBody: content.body != nil
        )
        let visualWidth = content.visual == nil ? 0 : max(52, min(context.contentSize.width * 0.34, 108))
        let availableWidth = max(context.contentSize.width - visualWidth - max(context.spacing, 12), 44)
        let title = measureText(content.title, role: .title, width: availableWidth, lineLimit: textPolicy.titleLines, allowedHeight: singleOrDoubleLineAllowance(role: .title, count: textPolicy.titleLines))
        let subtitle = measureText(textPolicy.showsSubtitle ? content.subtitle : nil, role: .subtitle, width: availableWidth, lineLimit: 1, allowedHeight: singleLineHeight(for: .subtitle))
        let body = measureText(content.body, role: .body, width: availableWidth, lineLimit: textPolicy.bodyLines, allowedHeight: singleOrDoubleLineAllowance(role: .body, count: textPolicy.bodyLines))
        let metricHeight: CGFloat = content.metric != nil && content.preferredLayout == .metricFocus
            ? measureMetricHeight(for: .splitLeadingVisual, width: availableWidth)
            : 0
        let progressHeight: CGFloat = content.progress == nil ? 0 : 22
        let metaVisible = min(content.metaItems.count, context.density == .relaxed ? 3 : 2)
        let metaHeight = CGFloat(metaVisible) * (singleLineHeight(for: .meta) + 4)
        let listVisible = fittedListCount(maxCount: context.density == .relaxed ? 3 : 2, availableWidth: availableWidth, availableHeight: max(context.contentSize.height - 80, 0))
        let listHeight = CGFloat(listVisible) * (singleLineHeight(for: .body) + 8)
        let footer = measureText(content.footer, role: .caption, width: availableWidth, lineLimit: 1, allowedHeight: singleLineHeight(for: .caption))
        let textAndMetricHeight = title.allowedHeight + subtitle.allowedHeight + body.allowedHeight + metricHeight
        let supportingHeight = progressHeight + metaHeight + listHeight + footer.allowedHeight
        let layoutSpacing = context.spacing * CGFloat(4)
        let used = textAndMetricHeight + supportingHeight + layoutSpacing

        return AdaptiveCardOverflowReport(
            resolvedMode: .splitLeadingVisual,
            titleOverflow: title.isTruncated,
            subtitleOverflow: subtitle.isTruncated,
            bodyOverflow: body.isTruncated || used > context.contentSize.height + 2,
            visibleListItems: listVisible,
            totalListItems: content.listItems.count,
            heroCropFraction: 0,
            fallbackReason: "ok"
        )
    }

    private func measureStackedInfo() -> AdaptiveCardOverflowReport {
        let textPolicy = context.textPolicy(
            for: .stackedInfo,
            hasSubtitle: content.subtitle != nil,
            hasBody: content.body != nil
        )
        let availableWidth = max(context.contentSize.width, 44)
        let title = measureText(content.title, role: .title, width: availableWidth, lineLimit: textPolicy.titleLines, allowedHeight: singleOrDoubleLineAllowance(role: .title, count: textPolicy.titleLines))
        let subtitle = measureText(textPolicy.showsSubtitle ? content.subtitle : nil, role: .subtitle, width: availableWidth, lineLimit: 1, allowedHeight: singleLineHeight(for: .subtitle))
        let body = measureText(content.body, role: .body, width: availableWidth, lineLimit: textPolicy.bodyLines, allowedHeight: singleOrDoubleLineAllowance(role: .body, count: textPolicy.bodyLines))
        let metricHeight: CGFloat = content.metric == nil ? 0 : measureMetricHeight(for: .stackedInfo, width: availableWidth)
        let progressHeight: CGFloat = content.progress == nil ? 0 : 22
        let metaVisible = min(content.metaItems.count, context.density == .relaxed ? 4 : 2)
        let metaHeight = CGFloat(metaVisible) * (singleLineHeight(for: .meta) + 4)
        let maxList = context.supportsList ? (context.density == .relaxed ? 5 : 3) : 1
        let listVisible = fittedListCount(maxCount: maxList, availableWidth: availableWidth, availableHeight: max(context.contentSize.height - 96, 0))
        let listHeight = CGFloat(listVisible) * (singleLineHeight(for: .body) + 8)
        let footer = measureText(content.footer, role: .caption, width: availableWidth, lineLimit: 1, allowedHeight: singleLineHeight(for: .caption))
        let textAndMetricHeight = title.allowedHeight + subtitle.allowedHeight + body.allowedHeight + metricHeight
        let supportingHeight = progressHeight + metaHeight + listHeight + footer.allowedHeight
        let layoutSpacing = context.spacing * CGFloat(5)
        let used = textAndMetricHeight + supportingHeight + layoutSpacing

        return AdaptiveCardOverflowReport(
            resolvedMode: .stackedInfo,
            titleOverflow: title.isTruncated,
            subtitleOverflow: subtitle.isTruncated,
            bodyOverflow: body.isTruncated || used > context.contentSize.height + 2,
            visibleListItems: listVisible,
            totalListItems: content.listItems.count,
            heroCropFraction: 0,
            fallbackReason: "ok"
        )
    }

    private func measureHeroOverlay() -> AdaptiveCardOverflowReport {
        let textPolicy = context.textPolicy(
            for: .heroOverlay,
            hasSubtitle: content.subtitle != nil,
            hasBody: content.body != nil
        )
        let availableWidth = max(context.contentSize.width, 44)
        let title = measureText(content.title, role: .heroTitle, width: availableWidth, lineLimit: textPolicy.titleLines, allowedHeight: singleOrDoubleLineAllowance(role: .heroTitle, count: textPolicy.titleLines))
        let subtitle = measureText(textPolicy.showsSubtitle ? content.subtitle : nil, role: .subtitle, width: availableWidth, lineLimit: 1, allowedHeight: singleLineHeight(for: .subtitle))
        let body = measureText(content.body, role: .body, width: availableWidth, lineLimit: textPolicy.bodyLines, allowedHeight: singleOrDoubleLineAllowance(role: .body, count: textPolicy.bodyLines))
        let badgeHeight: CGFloat = content.badge == nil ? 0 : 28
        let textHeight = title.allowedHeight + subtitle.allowedHeight + body.allowedHeight
        let layoutSpacing = context.spacing * CGFloat(3)
        let used = textHeight + badgeHeight + layoutSpacing
        let heroCrop = estimatedHeroCrop()

        return AdaptiveCardOverflowReport(
            resolvedMode: .heroOverlay,
            titleOverflow: title.isTruncated,
            subtitleOverflow: subtitle.isTruncated,
            bodyOverflow: body.isTruncated || used > context.contentSize.height * 0.62,
            visibleListItems: 0,
            totalListItems: content.listItems.count,
            heroCropFraction: heroCrop,
            fallbackReason: heroCrop > 0.28 ? "hero crop \(Int((heroCrop * 100).rounded()))%" : "ok"
        )
    }

    private func measureText(
        _ text: String?,
        role: AdaptiveCardTypographyRole,
        width: CGFloat,
        lineLimit: Int,
        allowedHeight: CGFloat
    ) -> AdaptiveCardTextMeasureResult {
        guard let text, !text.isEmpty, lineLimit > 0, allowedHeight > 0 else {
            return AdaptiveCardTextMeasureResult(requiredHeight: 0, allowedHeight: 0, isTruncated: false)
        }

        let spec = theme.typography.spec(for: role, context: context)
        let font = UIFont.systemFont(ofSize: spec.size, weight: uiWeight(from: spec.weight))
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph
        ]
        let rect = NSAttributedString(string: text, attributes: attributes).boundingRect(
            with: CGSize(width: max(width, 1), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let measuredHeight = ceil(rect.height)
        return AdaptiveCardTextMeasureResult(
            requiredHeight: measuredHeight,
            allowedHeight: allowedHeight,
            isTruncated: measuredHeight > allowedHeight + 1
        )
    }

    private func fittedListCount(maxCount: Int, availableWidth: CGFloat, availableHeight: CGFloat) -> Int {
        guard maxCount > 0, availableHeight > 0 else { return 0 }
        var used: CGFloat = 0
        var count = 0
        for item in content.listItems.prefix(maxCount) {
            let title = measureText(item.title, role: item.emphasis ? .meta : .body, width: availableWidth - 20, lineLimit: 1, allowedHeight: singleLineHeight(for: item.emphasis ? .meta : .body))
            let subtitleAllowance = item.subtitle == nil || context.density == .compact ? 0 : singleLineHeight(for: .caption)
            let rowHeight = max(title.allowedHeight + subtitleAllowance + 4, 20)
            if used + rowHeight > availableHeight + 1 {
                break
            }
            used += rowHeight + 6
            count += 1
        }
        return count
    }

    private func measureMetricHeight(for mode: AdaptiveCardLayoutMode, width: CGFloat) -> CGFloat {
        guard let metric = content.metric else { return 0 }
        let value = measureText(metric.value, role: .metric, width: width * 0.72, lineLimit: 1, allowedHeight: context.density == .compact ? 36 : (context.density == .relaxed ? 72 : 56))
        let caption = measureText(metric.caption, role: .meta, width: width, lineLimit: 2, allowedHeight: singleOrDoubleLineAllowance(role: .meta, count: 2))
        let unitHeight = metric.unit == nil ? 0 : singleLineHeight(for: .subtitle)
        return value.allowedHeight + max(unitHeight, 0) + caption.allowedHeight + (mode == .compactTile ? 2 : 6)
    }

    private func measureMetricInlineWidth(_ metric: AdaptiveCardMetric) -> CGFloat {
        let value = measureText(metric.value, role: .metric, width: 140, lineLimit: 1, allowedHeight: 40)
        let unit = measureText(metric.unit, role: .caption, width: 40, lineLimit: 1, allowedHeight: singleLineHeight(for: .caption))
        return min(150, max(42, value.requiredHeight * 1.25 + unit.requiredHeight * 0.8))
    }

    private func measureBadgeWidth(_ badge: AdaptiveCardBadge) -> CGFloat {
        let text = measureText(badge.text, role: .badge, width: 120, lineLimit: 1, allowedHeight: singleLineHeight(for: .badge))
        return max(48, text.requiredHeight * 2.2 + (badge.systemImage == nil ? 14 : 28))
    }

    private func measureMetaWidth(_ meta: AdaptiveCardMetaItem) -> CGFloat {
        let text = measureText(meta.text, role: .meta, width: 100, lineLimit: 1, allowedHeight: singleLineHeight(for: .meta))
        return max(42, text.requiredHeight * 2 + (meta.systemImage == nil ? 0 : 18))
    }

    private func estimatedHeroCrop() -> CGFloat {
        guard let imageRatio = content.visual?.sourceAspectRatio, imageRatio > 0 else { return 0 }
        let containerRatio = max(context.containerSize.width / max(context.containerSize.height, 1), 0.01)
        if abs(imageRatio - containerRatio) < 0.01 {
            return 0
        }

        if imageRatio > containerRatio {
            return max(0, 1 - (containerRatio / imageRatio))
        } else {
            return max(0, 1 - (imageRatio / containerRatio))
        }
    }

    private func singleLineHeight(for role: AdaptiveCardTypographyRole) -> CGFloat {
        let spec = theme.typography.spec(for: role, context: context)
        return ceil(spec.size * 1.24)
    }

    private func singleOrDoubleLineAllowance(role: AdaptiveCardTypographyRole, count: Int) -> CGFloat {
        CGFloat(max(count, 0)) * singleLineHeight(for: role)
    }

    private var compactSubtitle: String? {
        content.subtitle ?? content.body ?? content.metaItems.first?.text
    }

    private func uiWeight(from weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }
}
