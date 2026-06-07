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
        availableSize: CGSize? = nil
    ) -> MemoryCardObjectMetrics {
        let density = MemoryCardPresentationPolicy.normalizedDensity(explicitDensity, for: contentKind)
        let availableWidth = availableSize?.width
        var metrics = baseMetrics(contentKind: contentKind, density: density, availableWidth: availableWidth)
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
        columnWidth: CGFloat
    ) -> CGFloat {
        resolve(
            contentKind: contentKind,
            density: density,
            availableSize: CGSize(width: columnWidth, height: .greatestFiniteMagnitude)
        ).preferredSize.height
    }

    private static func baseMetrics(
        contentKind: MemoryCardContentKind,
        density: MemoryCardContentDensity,
        availableWidth: CGFloat?
    ) -> MemoryCardObjectMetrics {
        let width = max(120, min(availableWidth ?? 188, 260))
        var metrics = MemoryCardObjectMetrics(
            contentKind: contentKind,
            density: density,
            preferredSize: CGSize(width: width, height: defaultHeight(for: contentKind, density: density, width: width)),
            padding: padding(for: density),
            titleLineLimit: density == .simple ? 1 : 2,
            detailLineLimit: detailLineLimit(for: contentKind, density: density),
            metadataLineLimit: 1,
            thumbnailScale: thumbnailScale(for: contentKind)
        )

        switch contentKind {
        case .weather, .affect, .status:
            metrics.padding = density == .simple
                ? MemoryCardObjectPadding(top: 10, leading: 12, bottom: 10, trailing: 12)
                : MemoryCardObjectPadding(14)
        case .recordBody, .prompt:
            metrics.detailLineLimit = density == .detailed ? 12 : 8
        case .photo, .livePhoto:
            metrics.titleLineLimit = 2
            metrics.detailLineLimit = 2
        case .video, .audio, .music, .place, .link, .todo, .person, .journalingSuggestion, .bundle:
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

    private static func detailLineLimit(
        for contentKind: MemoryCardContentKind,
        density: MemoryCardContentDensity
    ) -> Int {
        switch (contentKind, density) {
        case (.recordBody, .detailed), (.prompt, .detailed):
            return 12
        case (.recordBody, _), (.prompt, _):
            return 8
        case (.todo, .detailed), (.link, .detailed):
            return 5
        case (.weather, .simple), (.affect, .simple), (.status, .simple):
            return 1
        case (_, .simple):
            return 2
        case (_, .standard):
            return 3
        case (_, .detailed):
            return 4
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
        width: CGFloat
    ) -> CGFloat {
        let base: CGFloat
        switch contentKind {
        case .recordBody, .prompt:
            base = density == .detailed ? 226 : 190
        case .photo, .livePhoto:
            base = width * 1.18 + 42
        case .video:
            base = width * 0.72
        case .audio:
            base = density == .simple ? 88 : 126
        case .music:
            base = density == .simple ? 112 : 156
        case .place:
            base = density == .simple ? 118 : 148
        case .weather:
            base = density == .simple ? 92 : 148
        case .link, .todo:
            base = density == .simple ? 116 : 156
        case .person:
            base = density == .simple ? 144 : 190
        case .affect, .status:
            base = density == .simple ? 112 : 148
        case .journalingSuggestion, .bundle:
            base = 158
        }
        return max(72, min(base, 320))
    }
}
