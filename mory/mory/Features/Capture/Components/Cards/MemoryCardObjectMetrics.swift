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
    var contentKind: MemoryCardContentKind
    var density: MemoryCardContentDensity
    var preferredSize: CGSize
    var padding: MemoryCardObjectPadding
    var titleLineLimit: Int
    var detailLineLimit: Int
    var metadataLineLimit: Int
    var thumbnailScale: MemoryCardObjectThumbnailScale

    static func resolve(
        contentKind: MemoryCardContentKind,
        density explicitDensity: MemoryCardContentDensity? = nil,
        availableSize: CGSize? = nil,
        mediaAspectRatio: CGFloat? = nil
    ) -> MemoryCardObjectMetrics {
        let density = MemoryCardPresentationPolicy.normalizedDensity(explicitDensity, for: contentKind)
        let availableWidth = availableSize?.width
        var metrics = baseMetrics(
            contentKind: contentKind,
            density: density,
            availableWidth: availableWidth,
            mediaAspectRatio: mediaAspectRatio
        )
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
        for contentKind: MemoryCardContentKind,
        density: MemoryCardContentDensity? = nil,
        columnWidth: CGFloat,
        mediaAspectRatio: CGFloat? = nil
    ) -> CGFloat {
        resolve(
            contentKind: contentKind,
            density: density,
            availableSize: CGSize(width: columnWidth, height: .greatestFiniteMagnitude),
            mediaAspectRatio: mediaAspectRatio
        ).preferredSize.height
    }

    private static func baseMetrics(
        contentKind: MemoryCardContentKind,
        density: MemoryCardContentDensity,
        availableWidth: CGFloat?,
        mediaAspectRatio: CGFloat?
    ) -> MemoryCardObjectMetrics {
        let width = max(120, min(availableWidth ?? 188, 260))
        var metrics = MemoryCardObjectMetrics(
            contentKind: contentKind,
            density: density,
            preferredSize: CGSize(
                width: width,
                height: defaultHeight(
                    for: contentKind,
                    density: density,
                    width: width,
                    mediaAspectRatio: mediaAspectRatio
                )
            ),
            padding: padding(for: density),
            titleLineLimit: titleLineLimit(for: contentKind, density: density),
            detailLineLimit: detailLineLimit(for: contentKind, density: density),
            metadataLineLimit: 1,
            thumbnailScale: thumbnailScale(for: contentKind)
        )

        switch contentKind {
        case .photo, .video, .livePhoto:
            metrics.padding = MemoryCardObjectPadding(0)
            metrics.titleLineLimit = 0
            metrics.detailLineLimit = 0
            metrics.metadataLineLimit = 0
        case .weather, .affect, .status:
            metrics.padding = density == .simple
                ? MemoryCardObjectPadding(top: 10, leading: 12, bottom: 10, trailing: 12)
                : MemoryCardObjectPadding(14)
        case .recordBody, .prompt:
            metrics.detailLineLimit = density == .detailed ? 6 : 4
        case .audio, .music, .place, .link, .todo, .person, .journalingSuggestion, .bundle:
            break
        }

        return metrics
    }

    private static func padding(for density: MemoryCardContentDensity) -> MemoryCardObjectPadding {
        switch density {
        case .simple:
            return MemoryCardObjectPadding(top: 10, leading: 12, bottom: 10, trailing: 12)
        case .standard:
            return MemoryCardObjectPadding(14)
        case .detailed:
            return MemoryCardObjectPadding(16)
        }
    }

    private static func titleLineLimit(
        for contentKind: MemoryCardContentKind,
        density: MemoryCardContentDensity
    ) -> Int {
        switch contentKind {
        case .photo, .video, .livePhoto:
            return 0
        case .place where density != .simple:
            return 1
        case .affect:
            return 1
        case _ where density == .simple:
            return 1
        default:
            return 2
        }
    }

    private static func detailLineLimit(
        for contentKind: MemoryCardContentKind,
        density: MemoryCardContentDensity
    ) -> Int {
        if contentKind == .photo || contentKind == .video || contentKind == .livePhoto {
            return 0
        }
        switch (contentKind, density) {
        case (.recordBody, .detailed), (.prompt, .detailed), (.audio, .detailed), (.music, .detailed),
            (.todo, .detailed), (.journalingSuggestion, .detailed), (.bundle, .detailed):
            return 6
        case (.place, .detailed):
            return 1
        case (.place, .standard):
            return 0
        case (.weather, .simple), (.affect, .simple), (.status, .simple):
            return 1
        case (_, .simple):
            return 1
        case (_, .standard):
            return 4
        case (_, .detailed):
            return 6
        }
    }

    private static func thumbnailScale(for contentKind: MemoryCardContentKind) -> MemoryCardObjectThumbnailScale {
        switch contentKind {
        case .weather, .affect, .status:
            return .none
        case .photo, .video, .livePhoto, .bundle, .journalingSuggestion:
            return .fill
        case .recordBody, .audio, .music, .place, .link, .todo, .prompt, .person:
            return .fit
        }
    }

    private static func defaultHeight(
        for contentKind: MemoryCardContentKind,
        density: MemoryCardContentDensity,
        width: CGFloat,
        mediaAspectRatio: CGFloat?
    ) -> CGFloat {
        let base: CGFloat
        switch contentKind {
        case .recordBody:
            switch density {
            case .simple:
                base = 76
            case .standard:
                base = 168
            case .detailed:
                base = 232
            }
        case .prompt:
            base = density == .detailed ? 222 : 168
        case .photo, .livePhoto:
            base = mediaHeight(width: width, mediaAspectRatio: mediaAspectRatio)
        case .video:
            base = mediaHeight(width: width, mediaAspectRatio: mediaAspectRatio)
        case .audio:
            base = densityHeight(density, simple: 76, standard: 148, detailed: 220)
        case .music:
            base = densityHeight(density, simple: 76, standard: 156, detailed: 228)
        case .place:
            switch density {
            case .simple:
                base = 76
            case .standard:
                base = width * 3 / 4
            case .detailed:
                base = width * 4 / 3
            }
        case .weather:
            base = density == .simple ? 82 : 148
        case .link, .todo:
            base = densityHeight(density, simple: 76, standard: 148, detailed: 220)
        case .person:
            base = density == .simple ? 76 : 156
        case .affect, .status:
            base = density == .simple ? 76 : 148
        case .journalingSuggestion, .bundle:
            base = densityHeight(density, simple: 76, standard: 156, detailed: 220)
        }
        return max(64, min(base, 420))
    }

    static func clampedMediaAspectRatio(_ ratio: CGFloat?) -> CGFloat {
        guard let ratio, ratio.isFinite, ratio > 0 else { return 1 }
        return min(max(ratio, 9 / 16), 16 / 9)
    }

    private static func mediaHeight(width: CGFloat, mediaAspectRatio: CGFloat?) -> CGFloat {
        width / clampedMediaAspectRatio(mediaAspectRatio)
    }

    private static func densityHeight(
        _ density: MemoryCardContentDensity,
        simple: CGFloat,
        standard: CGFloat,
        detailed: CGFloat
    ) -> CGFloat {
        switch density {
        case .simple:
            return simple
        case .standard:
            return standard
        case .detailed:
            return detailed
        }
    }
}
