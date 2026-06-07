import QuickLook
import SwiftUI

struct MemoryCardPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let urls: [URL]
    var canDelete = false
    var onDelete: () -> Void = {}

    @State private var selectedURL: URL?
    @State private var isConfirmingDelete = false

    var body: some View {
        NavigationStack {
            Group {
                if let selectedURL {
                    QuickLookPreview(url: selectedURL)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ContentUnavailableView("memory.card.preview", systemImage: "eye")
                }
            }
            .navigationTitle("memory.card.preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done") {
                        dismiss()
                    }
                }
                if canDelete {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            isConfirmingDelete = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("common.delete")
                    }
                }
                if urls.count > 1 {
                    ToolbarItem(placement: .bottomBar) {
                        Picker("memory.card.preview", selection: Binding(
                            get: { selectedURL ?? urls[0] },
                            set: { selectedURL = $0 }
                        )) {
                            ForEach(urls, id: \.self) { url in
                                Text(url.lastPathComponent).tag(url)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            .confirmationDialog("memory.card.delete.title", isPresented: $isConfirmingDelete) {
                Button("common.delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("memory.card.delete.message")
            }
            .onAppear {
                if selectedURL == nil {
                    selectedURL = urls.first
                }
            }
        }
    }
}

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url
        controller.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
