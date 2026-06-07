import SwiftUI

struct MemoryCardActionMenuConfiguration {
    var contentKind: MemoryCardContentKind
    var contentDensity: MemoryCardContentDensity
    var canPreview = true
    var canEdit = false
    var canSetDensity = true
    var canMergeMedia = false
    var canSpreadMedia = false
    var canDelete = false
    var onPreview: () -> Void = {}
    var onEdit: () -> Void = {}
    var onSetDensity: (MemoryCardContentDensity) -> Void = { _ in }
    var onMergeMedia: () -> Void = {}
    var onSpreadMedia: () -> Void = {}
    var onDelete: () -> Void = {}
}

struct MemoryCardActionMenu: View {
    let configuration: MemoryCardActionMenuConfiguration

    var body: some View {
        if configuration.canPreview {
            Button {
                configuration.onPreview()
            } label: {
                Label("memory.card.preview", systemImage: "eye")
            }
        }

        if configuration.canEdit {
            Button {
                configuration.onEdit()
            } label: {
                Label("memory.card.edit", systemImage: "pencil")
            }
        }

        if configuration.canSetDensity {
            Menu {
                ForEach(MemoryCardPresentationPolicy.supportedDensities(for: configuration.contentKind)) { density in
                    Button {
                        configuration.onSetDensity(density)
                    } label: {
                        Label(
                            density.menuLabel,
                            systemImage: density == configuration.contentDensity ? "checkmark" : density.systemImage
                        )
                    }
                }
            } label: {
                Label("memory.card.displayDensity", systemImage: "rectangle.3.group")
            }
        }

        if configuration.canMergeMedia {
            Button {
                configuration.onMergeMedia()
            } label: {
                Label("memory.card.mergeMedia", systemImage: "rectangle.stack.badge.plus")
            }
        }

        if configuration.canSpreadMedia {
            Button {
                configuration.onSpreadMedia()
            } label: {
                Label("memory.card.spreadMedia", systemImage: "square.split.2x1")
            }
        }

        if configuration.canDelete {
            Divider()

            Button(role: .destructive) {
                configuration.onDelete()
            } label: {
                Label("common.delete", systemImage: "trash")
            }
        }
    }
}
