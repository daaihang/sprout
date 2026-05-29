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
    var sizeToken: MemoryCardSizeToken
    var density: MemoryCardContentDensity
    var preferredSize: CGSize
    var padding: MemoryCardObjectPadding
    var titleLineLimit: Int
    var detailLineLimit: Int
    var metadataLineLimit: Int
    var thumbnailScale: MemoryCardObjectThumbnailScale

    static func resolve(
        recipe: MemoryCardVisualRecipe,
        sizeToken: MemoryCardSizeToken,
        density explicitDensity: MemoryCardContentDensity? = nil
    ) -> MemoryCardObjectMetrics {
        let normalizedSize = MemoryCardRecipeLayoutPolicy.normalizedSize(sizeToken, for: recipe)
        let density = explicitDensity ?? MemoryCardRecipeLayoutPolicy.contentDensity(for: normalizedSize)
        let base = baseMetrics(for: normalizedSize, density: density)
        return recipeOverrides(recipe: recipe, sizeToken: normalizedSize, density: density, base: base)
    }

    private static func baseMetrics(
        for size: MemoryCardSizeToken,
        density: MemoryCardContentDensity
    ) -> MemoryCardObjectMetrics {
        switch size {
        case .stamp:
            return MemoryCardObjectMetrics(
                recipe: .statusNote,
                sizeToken: size,
                density: density,
                preferredSize: CGSize(width: 106, height: 104),
                padding: MemoryCardObjectPadding(10),
                titleLineLimit: 1,
                detailLineLimit: 1,
                metadataLineLimit: 1,
                thumbnailScale: .none
            )
        case .strip:
            return MemoryCardObjectMetrics(
                recipe: .statusNote,
                sizeToken: size,
                density: density,
                preferredSize: CGSize(width: 168, height: 76),
                padding: MemoryCardObjectPadding(top: 10, leading: 12, bottom: 10, trailing: 12),
                titleLineLimit: 1,
                detailLineLimit: 1,
                metadataLineLimit: 1,
                thumbnailScale: .fit
            )
        case .card:
            return MemoryCardObjectMetrics(
                recipe: .statusNote,
                sizeToken: size,
                density: density,
                preferredSize: CGSize(width: 214, height: 148),
                padding: MemoryCardObjectPadding(13),
                titleLineLimit: 2,
                detailLineLimit: 3,
                metadataLineLimit: 1,
                thumbnailScale: .fit
            )
        case .square:
            return MemoryCardObjectMetrics(
                recipe: .statusNote,
                sizeToken: size,
                density: density,
                preferredSize: CGSize(width: 184, height: 224),
                padding: MemoryCardObjectPadding(10),
                titleLineLimit: 1,
                detailLineLimit: 2,
                metadataLineLimit: 1,
                thumbnailScale: .fill
            )
        case .tape:
            return MemoryCardObjectMetrics(
                recipe: .statusNote,
                sizeToken: size,
                density: density,
                preferredSize: CGSize(width: 232, height: 136),
                padding: MemoryCardObjectPadding(top: 12, leading: 14, bottom: 12, trailing: 14),
                titleLineLimit: 1,
                detailLineLimit: 2,
                metadataLineLimit: 1,
                thumbnailScale: .fill
            )
        case .banner:
            return MemoryCardObjectMetrics(
                recipe: .statusNote,
                sizeToken: size,
                density: density,
                preferredSize: CGSize(width: 340, height: 196),
                padding: MemoryCardObjectPadding(16),
                titleLineLimit: 2,
                detailLineLimit: 5,
                metadataLineLimit: 2,
                thumbnailScale: .fill
            )
        }
    }

    private static func recipeOverrides(
        recipe: MemoryCardVisualRecipe,
        sizeToken: MemoryCardSizeToken,
        density: MemoryCardContentDensity,
        base: MemoryCardObjectMetrics
    ) -> MemoryCardObjectMetrics {
        var metrics = base
        metrics.recipe = recipe
        metrics.sizeToken = sizeToken
        metrics.density = density

        switch (recipe, sizeToken) {
        case (.notebook, .card):
            metrics.preferredSize = CGSize(width: 190, height: 204)
            metrics.detailLineLimit = 6
        case (.notebook, .banner):
            metrics.preferredSize = CGSize(width: 326, height: 218)
            metrics.detailLineLimit = 10
        case (.polaroid, .square), (.livePhotoPrint, .square):
            metrics.preferredSize = CGSize(width: 178, height: 218)
            metrics.detailLineLimit = 1
        case (.polaroid, .banner), (.livePhotoPrint, .banner):
            metrics.preferredSize = CGSize(width: 278, height: 334)
            metrics.titleLineLimit = 2
            metrics.detailLineLimit = 2
        case (.filmFrame, .tape):
            metrics.preferredSize = CGSize(width: 232, height: 154)
            metrics.detailLineLimit = 1
        case (.filmFrame, .banner):
            metrics.preferredSize = CGSize(width: 336, height: 214)
            metrics.detailLineLimit = 2
        case (.cassette, .strip):
            metrics.preferredSize = CGSize(width: 168, height: 64)
        case (.cassette, .tape):
            metrics.preferredSize = CGSize(width: 232, height: 136)
        case (.cassette, .banner):
            metrics.preferredSize = CGSize(width: 418, height: 126)
            metrics.detailLineLimit = 4
        case (.vinyl, .strip):
            metrics.preferredSize = CGSize(width: 168, height: 82)
            metrics.detailLineLimit = 1
        case (.vinyl, .tape):
            metrics.preferredSize = CGSize(width: 230, height: 150)
            metrics.detailLineLimit = 1
        case (.mapTicket, .card):
            metrics.preferredSize = CGSize(width: 234, height: 128)
            metrics.detailLineLimit = 2
        case (.weatherStamp, .stamp):
            metrics.preferredSize = CGSize(width: 58, height: 58)
            metrics.padding = MemoryCardObjectPadding(6)
            metrics.titleLineLimit = 1
            metrics.detailLineLimit = 1
        case (.weatherStamp, .strip):
            metrics.preferredSize = CGSize(width: 168, height: 64)
            metrics.padding = MemoryCardObjectPadding(top: 8, leading: 12, bottom: 8, trailing: 12)
            metrics.titleLineLimit = 1
            metrics.detailLineLimit = 1
        case (.weatherStamp, .card):
            metrics.preferredSize = CGSize(width: 214, height: 148)
            metrics.detailLineLimit = 2
        case (.affectCard, .stamp), (.statusNote, .stamp):
            metrics.preferredSize = CGSize(width: 116, height: 110)
            metrics.detailLineLimit = 1
        case (.affectCard, .strip), (.statusNote, .strip):
            metrics.preferredSize = CGSize(width: 176, height: 112)
            metrics.detailLineLimit = 2
        case (.linkNote, .card):
            metrics.preferredSize = CGSize(width: 214, height: 148)
            metrics.detailLineLimit = 3
        case (.linkNote, .banner):
            metrics.preferredSize = CGSize(width: 326, height: 192)
            metrics.detailLineLimit = 5
        case (.taskNote, .strip), (.personCard, .strip):
            metrics.preferredSize = CGSize(width: 176, height: 96)
            metrics.titleLineLimit = 1
            metrics.detailLineLimit = 1
        case (.taskNote, .card):
            metrics.preferredSize = CGSize(width: 194, height: 148)
            metrics.detailLineLimit = 4
        case (.personCard, .card):
            metrics.preferredSize = CGSize(width: 148, height: 190)
            metrics.detailLineLimit = 2
        case (.bundlePacket, .card):
            metrics.preferredSize = CGSize(width: 220, height: 150)
            metrics.detailLineLimit = 2
        case (.bundlePacket, .square):
            metrics.preferredSize = CGSize(width: 236, height: 206)
            metrics.detailLineLimit = 3
        default:
            break
        }

        return metrics
    }
}
