import PhotosUI
import SwiftUI

struct CaptureComposerToolbar: ToolbarContent {
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    let isTextInputFocused: Bool
    let isProcessingPhoto: Bool
    let isCollectingContext: Bool
    let onCamera: () -> Void
    let onAudio: () -> Void
    let onLink: () -> Void
    let onMusic: () -> Void
    let onLocation: () -> Void
    let onTodo: () -> Void
    let onRefreshContext: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: toolbarPlacement) {
            actionStrip
        }
    }

    private var toolbarPlacement: ToolbarItemPlacement {
        isTextInputFocused ? .keyboard : .bottomBar
    }

    private var actionStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                actionButton(icon: "camera", title: "Camera", action: onCamera)
                    .disabled(isProcessingPhoto)

                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 0, matching: .images) {
                    actionButtonLabel(icon: "photo.on.rectangle", title: "Photo")
                }
                .disabled(isProcessingPhoto)

                actionButton(icon: "mic", title: "Voice", action: onAudio)
                actionButton(icon: "link", title: "Link", action: onLink)
                actionButton(icon: "music.note", title: "Music", action: onMusic)
                actionButton(icon: "mappin.and.ellipse", title: "Place", action: onLocation)
                actionButton(icon: "checklist", title: "Task", action: onTodo)
                actionButton(icon: "arrow.clockwise", title: "Context", action: onRefreshContext)
                    .disabled(isCollectingContext)
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
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
