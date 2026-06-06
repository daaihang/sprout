import SwiftUI

enum MemoryCardObjectThumbnailScale: String, Codable, Hashable, Sendable {
    case none
    case fit
    case fill
}

struct MemoryCardObjectPadding: Hashable, Sendable {
    var top: CGFloat
    var leading: CGFloat
    var bottom: CGFloat
    var trailing: CGFloat

    init(_ value: CGFloat) {
        self.top = value
        self.leading = value
        self.bottom = value
        self.trailing = value
    }

    init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    var edgeInsets: EdgeInsets {
        EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
    }
}

struct MemoryCardObjectMetrics: Hashable, Sendable {
    var recipe: MemoryCardVisualRecipe
    var density: MemoryCardContentDensity
    var preferredSize: CGSize
    var padding: MemoryCardObjectPadding
    var titleLineLimit: Int
    var detailLineLimit: Int
    var metadataLineLimit: Int
    var thumbnailScale: MemoryCardObjectThumbnailScale

    static func resolve(
        recipe: MemoryCardVisualRecipe,
        density explicitDensity: MemoryCardContentDensity? = nil,
        availableSize: CGSize? = nil
    ) -> MemoryCardObjectMetrics {
        let density = MemoryCardRecipeLayoutPolicy.normalizedDensity(explicitDensity, for: recipe)
        let availableWidth = availableSize?.width
        var metrics = baseMetrics(recipe: recipe, density: density, availableWidth: availableWidth)
        if let availableSize,
           availableSize.width.isFinite,
           availableSize.width > 1 {
            metrics.preferredSize.width = availableSize.width
            if availableSize.height.isFinite, availableSize.height > 1 {
                metrics.preferredSize.height = min(max(metrics.preferredSize.height, 1), availableSize.height)
            }
        }
        return metrics
    }

    static func estimatedHeight(
        for recipe: MemoryCardVisualRecipe,
        density: MemoryCardContentDensity? = nil,
        columnWidth: CGFloat
    ) -> CGFloat {
        resolve(
            recipe: recipe,
            density: density,
            availableSize: CGSize(width: columnWidth, height: .greatestFiniteMagnitude)
        ).preferredSize.height
    }

    private static func baseMetrics(
        recipe: MemoryCardVisualRecipe,
        density: MemoryCardContentDensity,
        availableWidth: CGFloat?
    ) -> MemoryCardObjectMetrics {
        let width = max(120, min(availableWidth ?? 188, 260))
        var metrics = MemoryCardObjectMetrics(
            recipe: recipe,
            density: density,
            preferredSize: CGSize(width: width, height: defaultHeight(for: recipe, density: density, width: width)),
            padding: padding(for: density),
            titleLineLimit: density == .compact ? 1 : 2,
            detailLineLimit: detailLineLimit(for: recipe, density: density),
            metadataLineLimit: 1,
            thumbnailScale: thumbnailScale(for: recipe)
        )

        switch recipe {
        case .weatherStamp, .affectCard, .statusNote:
            metrics.padding = density == .compact
                ? MemoryCardObjectPadding(top: 10, leading: 12, bottom: 10, trailing: 12)
                : MemoryCardObjectPadding(14)
        case .notebook:
            metrics.detailLineLimit = density == .expanded ? 12 : 8
        case .polaroid, .livePhotoPrint:
            metrics.titleLineLimit = 2
            metrics.detailLineLimit = 2
        case .filmFrame, .cassette, .vinyl, .mapTicket, .linkNote, .taskNote, .personCard, .bundlePacket:
            break
        }

        return metrics
    }

    private static func padding(for density: MemoryCardContentDensity) -> MemoryCardObjectPadding {
        switch density {
        case .compact:
            return MemoryCardObjectPadding(top: 10, leading: 12, bottom: 10, trailing: 12)
        case .regular:
            return MemoryCardObjectPadding(14)
        case .expanded:
            return MemoryCardObjectPadding(16)
        }
    }

    private static func detailLineLimit(
        for recipe: MemoryCardVisualRecipe,
        density: MemoryCardContentDensity
    ) -> Int {
        switch (recipe, density) {
        case (.notebook, .expanded):
            return 12
        case (.notebook, _):
            return 8
        case (.taskNote, .expanded), (.linkNote, .expanded):
            return 5
        case (.weatherStamp, .compact), (.affectCard, .compact), (.statusNote, .compact):
            return 1
        case (_, .compact):
            return 2
        case (_, .regular):
            return 3
        case (_, .expanded):
            return 4
        }
    }

    private static func thumbnailScale(for recipe: MemoryCardVisualRecipe) -> MemoryCardObjectThumbnailScale {
        switch recipe {
        case .weatherStamp, .affectCard, .statusNote:
            return .none
        case .polaroid, .filmFrame, .livePhotoPrint, .bundlePacket:
            return .fill
        case .notebook, .cassette, .vinyl, .mapTicket, .linkNote, .taskNote, .personCard:
            return .fit
        }
    }

    private static func defaultHeight(
        for recipe: MemoryCardVisualRecipe,
        density: MemoryCardContentDensity,
        width: CGFloat
    ) -> CGFloat {
        let base: CGFloat
        switch recipe {
        case .notebook:
            base = density == .expanded ? 226 : 190
        case .polaroid, .livePhotoPrint:
            base = width * 1.18 + 42
        case .filmFrame:
            base = width * 0.72
        case .cassette:
            base = density == .compact ? 88 : 126
        case .vinyl:
            base = density == .compact ? 112 : 156
        case .mapTicket:
            base = density == .compact ? 118 : 148
        case .weatherStamp:
            base = density == .compact ? 92 : 148
        case .linkNote, .taskNote:
            base = density == .compact ? 116 : 156
        case .personCard:
            base = density == .compact ? 144 : 190
        case .affectCard, .statusNote:
            base = density == .compact ? 112 : 148
        case .bundlePacket:
            base = 158
        }
        return max(72, min(base, 320))
    }
}
