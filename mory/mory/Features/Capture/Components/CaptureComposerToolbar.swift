import PhotosUI
import SwiftUI

struct CaptureComposerActionStrip: View {
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    let isProcessingPhoto: Bool
    let isCollectingContext: Bool
    let onMood: () -> Void
    let onJournaling: () -> Void
    let onCamera: () -> Void
    let onAudio: () -> Void
    let onLink: () -> Void
    let onMusic: () -> Void
    let onLocation: () -> Void
    let onTodo: () -> Void
    let onRefreshContext: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                actionButton(icon: "face.smiling", title: "Mood", action: onMood)
                actionButton(icon: "book.pages", title: "Journaling", action: onJournaling)
                actionButton(icon: "camera", title: String(localized: "capture.toolbar.camera"), action: onCamera)
                    .disabled(isProcessingPhoto)

                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 0, matching: .images) {
                    actionButtonLabel(icon: "photo.on.rectangle", title: String(localized: "capture.toolbar.photo"))
                }
                .disabled(isProcessingPhoto)

                actionButton(icon: "mic", title: String(localized: "capture.toolbar.voice"), action: onAudio)
                actionButton(icon: "link", title: String(localized: "capture.toolbar.link"), action: onLink)
                actionButton(icon: "music.note", title: String(localized: "capture.toolbar.music"), action: onMusic)
                actionButton(icon: "mappin.and.ellipse", title: String(localized: "capture.toolbar.place"), action: onLocation)
                actionButton(icon: "checklist", title: String(localized: "capture.toolbar.task"), action: onTodo)
                actionButton(icon: "arrow.clockwise", title: String(localized: "capture.toolbar.context"), action: onRefreshContext)
                    .disabled(isCollectingContext)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func actionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            actionButtonLabel(icon: icon, title: title)
        }
        .buttonStyle(.plain)
    }

    private func actionButtonLabel(icon: String, title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.footnote)
            .labelStyle(.iconOnly)
            .frame(width: 30, height: 30)
    }
}
