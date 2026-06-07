import PhotosUI
import SwiftUI

struct MemoryAddCardMenu: View {
    enum LabelStyle {
        case toolbar
        case footer
    }

    @Binding var selectedPhotoItems: [PhotosPickerItem]
    let labelStyle: LabelStyle
    var isProcessingPhoto = false
    var isCollectingContext = false
    var includesText = true
    var includesMood = false
    var includesJournaling = false
    var includesContextRefresh = false
    var onText: () -> Void = {}
    var onMood: () -> Void = {}
    var onJournaling: () -> Void = {}
    var onCamera: () -> Void = {}
    var onAudio: () -> Void = {}
    var onLink: () -> Void = {}
    var onMusic: () -> Void = {}
    var onLocation: () -> Void = {}
    var onTodo: () -> Void = {}
    var onRefreshContext: () -> Void = {}

    var body: some View {
        Menu {
            if includesText {
                Button {
                    onText()
                } label: {
                    Label("capture.card.kind.text", systemImage: "note.text")
                }
            }

            Button {
                onCamera()
            } label: {
                Label("capture.toolbar.camera", systemImage: "camera")
            }
            .disabled(isProcessingPhoto)

            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 0,
                matching: .any(of: [.images, .videos, .livePhotos])
            ) {
                Label("capture.toolbar.photo", systemImage: "photo.on.rectangle")
            }
            .disabled(isProcessingPhoto)

            Button {
                onAudio()
            } label: {
                Label("capture.toolbar.voice", systemImage: "mic")
            }

            Button {
                onLink()
            } label: {
                Label("capture.toolbar.link", systemImage: "link")
            }

            Button {
                onMusic()
            } label: {
                Label("capture.toolbar.music", systemImage: "music.note")
            }

            Button {
                onLocation()
            } label: {
                Label("capture.toolbar.place", systemImage: "mappin.and.ellipse")
            }

            Button {
                onTodo()
            } label: {
                Label("capture.toolbar.task", systemImage: "checklist")
            }

            if includesMood {
                Button {
                    onMood()
                } label: {
                    Label("capture.card.kind.affect", systemImage: "face.smiling")
                }
            }

            if includesJournaling {
                Button {
                    onJournaling()
                } label: {
                    Label("capture.card.kind.journalingSuggestion", systemImage: "book.pages")
                }
            }

            if includesContextRefresh {
                Divider()

                Button {
                    onRefreshContext()
                } label: {
                    Label("capture.toolbar.context", systemImage: "arrow.clockwise")
                }
                .disabled(isCollectingContext)
            }
        } label: {
            label
        }
    }

    @ViewBuilder
    private var label: some View {
        switch labelStyle {
        case .toolbar:
            Label("capture.action.addCard", systemImage: "plus")
                .font(.footnote.weight(.semibold))
        case .footer:
            Label("capture.action.addCard", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule())
        }
    }
}
