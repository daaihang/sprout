import SwiftUI

struct MemoryDetailAdaptiveView: View {
    let presentation: MemoryDetailPresentationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            MemoryDetailHeader(presentation: presentation)

            switch presentation.mode {
            case .story:
                MemoryStoryModeView(presentation: presentation)
            case .text:
                MemoryTextModeView(presentation: presentation)
            case .gallery:
                MemoryGalleryModeView(presentation: presentation)
            case .audio:
                MemoryAudioModeView(presentation: presentation)
            case .checkIn:
                MemoryCheckInModeView(presentation: presentation)
            case .link:
                MemoryLinkModeView(presentation: presentation)
            case .article:
                MemoryArticleModeView(presentation: presentation)
            }
        }
    }
}
