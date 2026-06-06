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
        density explicitDensity: MemoryCardContentDensity? = nil,
        availableSize: CGSize? = nil
    ) -> MemoryCardObjectMetrics {
        let normalizedSize = MemoryCardRecipeLayoutPolicy.normalizedSize(sizeToken, for: recipe)
        let density = explicitDensity ?? MemoryCardRecipeLayoutPolicy.contentDensity(for: normalizedSize)
        let base = baseMetrics(for: normalizedSize, density: density)
        let resolved = recipeOverrides(recipe: recipe, sizeToken: normalizedSize, density: density, base: base)
        return resolved.fitting(in: availableSize)
    }

    func fitting(in availableSize: CGSize?) -> MemoryCardObjectMetrics {
        guard let availableSize,
              availableSize.width.isFinite,
              availableSize.height.isFinite,
              availableSize.width > 1,
              availableSize.height > 1
        else {
            return self
        }

        var metrics = self
        let bounds = Self.ratioBounds(for: sizeToken)
        let fittedWidth = preferredSize.width.clamped(
            to: (availableSize.width * bounds.minimumWidth)...(availableSize.width * bounds.maximumWidth)
        )
        let fittedHeight = preferredSize.height.clamped(
            to: (availableSize.height * bounds.minimumHeight)...(availableSize.height * bounds.maximumHeight)
        )

        if fittedWidth != preferredSize.width || fittedHeight != preferredSize.height {
            let shrinkScale = min(fittedWidth / preferredSize.width, fittedHeight / preferredSize.height)
            if shrinkScale < 1 {
                metrics.padding = padding.scaled(by: max(0.58, shrinkScale))
            }
            metrics.preferredSize = CGSize(width: fittedWidth, height: fittedHeight)
        }

        return metrics
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
                preferredSize: CGSize(width: 194, height: 168),
                padding: MemoryCardObjectPadding(13),
                titleLineLimit: 2,
                detailLineLimit: 3,
                metadataLineLimit: 1,
                thumbnailScale: .fit
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
            metrics.preferredSize = CGSize(width: 194, height: 188)
            metrics.detailLineLimit = 10
        case (.polaroid, .card), (.livePhotoPrint, .card):
            metrics.preferredSize = CGSize(width: 178, height: 218)
            metrics.titleLineLimit = 2
            metrics.detailLineLimit = 2
        case (.filmFrame, .card):
            metrics.preferredSize = CGSize(width: 194, height: 132)
            metrics.detailLineLimit = 2
        case (.cassette, .strip):
            metrics.preferredSize = CGSize(width: 168, height: 64)
        case (.cassette, .card):
            metrics.preferredSize = CGSize(width: 194, height: 126)
            metrics.detailLineLimit = 4
        case (.vinyl, .strip):
            metrics.preferredSize = CGSize(width: 168, height: 82)
            metrics.detailLineLimit = 1
        case (.vinyl, .card):
            metrics.preferredSize = CGSize(width: 194, height: 154)
            metrics.detailLineLimit = 2
        case (.mapTicket, .strip):
            metrics.preferredSize = CGSize(width: 176, height: 96)
            metrics.detailLineLimit = 1
        case (.mapTicket, .card):
            metrics.preferredSize = CGSize(width: 194, height: 128)
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
            metrics.preferredSize = CGSize(width: 194, height: 148)
            metrics.detailLineLimit = 2
        case (.affectCard, .stamp), (.statusNote, .stamp):
            metrics.preferredSize = CGSize(width: 116, height: 110)
            metrics.detailLineLimit = 1
        case (.affectCard, .strip), (.statusNote, .strip):
            metrics.preferredSize = CGSize(width: 176, height: 112)
            metrics.detailLineLimit = 2
        case (.linkNote, .strip):
            metrics.preferredSize = CGSize(width: 176, height: 96)
            metrics.detailLineLimit = 1
        case (.linkNote, .card):
            metrics.preferredSize = CGSize(width: 194, height: 148)
            metrics.detailLineLimit = 3
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
            metrics.preferredSize = CGSize(width: 194, height: 150)
            metrics.detailLineLimit = 2
        default:
            break
        }

        return metrics
    }

    private static func ratioBounds(for size: MemoryCardSizeToken) -> MemoryCardObjectRatioBounds {
        switch size {
        case .stamp:
            return MemoryCardObjectRatioBounds(
                minimumWidth: 0.72,
                minimumHeight: 0.72,
                maximumWidth: 1.32,
                maximumHeight: 1.32
            )
        case .strip:
            return MemoryCardObjectRatioBounds(
                minimumWidth: 0.78,
                minimumHeight: 0.76,
                maximumWidth: 1.22,
                maximumHeight: 1.22
            )
        case .card:
            return MemoryCardObjectRatioBounds(
                minimumWidth: 0.78,
                minimumHeight: 0.76,
                maximumWidth: 1.18,
                maximumHeight: 1.18
            )
        }
    }
}

private struct MemoryCardObjectRatioBounds: Hashable, Sendable {
    var minimumWidth: CGFloat
    var minimumHeight: CGFloat
    var maximumWidth: CGFloat
    var maximumHeight: CGFloat
}

private extension MemoryCardObjectPadding {
    func scaled(by scale: CGFloat) -> MemoryCardObjectPadding {
        MemoryCardObjectPadding(
            top: top * scale,
            leading: leading * scale,
            bottom: bottom * scale,
            trailing: trailing * scale
        )
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
