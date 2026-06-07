import SwiftUI

struct CaptureCardRenderContext: Hashable, Sendable {
    let contentKind: MemoryCardContentKind
    let density: MemoryCardContentDensity
    let metrics: MemoryCardObjectMetrics
    let availableSize: CGSize?
    let mediaAspectRatio: CGFloat?

    init(presentation: CaptureCardPresentation, availableSize: CGSize?) {
        let contentKind = presentation.contentKind
        let mediaAspectRatio = presentation.item.payload.mediaAspectRatio
        let density = MemoryCardPresentationPolicy.normalizedDensity(
            presentation.contentDensity,
            for: contentKind
        )
        self.contentKind = contentKind
        self.density = density
        self.availableSize = availableSize
        self.mediaAspectRatio = mediaAspectRatio
        self.metrics = MemoryCardObjectMetrics.resolve(
            contentKind: contentKind,
            density: density,
            availableSize: availableSize,
            mediaAspectRatio: mediaAspectRatio
        )
    }

    var isSimple: Bool { density == .simple }
    var isStandard: Bool { density == .standard }
    var isDetailed: Bool { density == .detailed }
    var chromeCornerRadius: CGFloat { isSimple ? 999 : 20 }
}

extension CaptureCardPayload {
    var mediaAspectRatio: CGFloat? {
        switch self {
        case let .photo(payload):
            return payload.mediaDimensions?.aspectRatio
        case let .video(payload):
            return payload.mediaDimensions?.aspectRatio
        case let .livePhoto(payload):
            return payload.mediaDimensions?.aspectRatio
        case .audio, .place, .weather, .music, .link, .todo, .prompt, .person, .affect, .journalingSuggestion, .status:
            return nil
        }
    }
}

extension ArtifactMediaDimensions {
    var aspectRatio: CGFloat? {
        guard let width,
              let height,
              width > 0,
              height > 0
        else { return nil }
        return CGFloat(width) / CGFloat(height)
    }
}
