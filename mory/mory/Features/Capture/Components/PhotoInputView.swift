import SwiftUI
import PhotosUI

struct PhotoInputView: View {
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var selectedPhotoData: Data?
    @Binding var selectedPhotoThumbnail: Data?
    @Binding var photoFilename: String
    @Binding var isProcessingPhoto: Bool
    @Binding var photoProcessorResult: PhotoArtifactProcessor.Result?
    @Binding var noteText: String

    var body: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            if let selectedPhotoData {
                if let uiImage = UIImage(data: selectedPhotoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(8)
                }
                Text("capture.photo.selected").foregroundStyle(.secondary)
            } else {
                Label("capture.photo.select", systemImage: "photo")
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task { await process(newItem) }
        }

        if isProcessingPhoto {
            HStack(spacing: 8) {
                ProgressView()
                Text("capture.photo.analyzing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let result = photoProcessorResult {
            VStack(alignment: .leading, spacing: 4) {
                if !result.summary.isEmpty {
                    Text(result.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                if !result.ocrText.isEmpty {
                    Text("capture.photo.ocrPreview \(String(result.ocrText.prefix(100)))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
        }

        TextField("capture.photo.notePlaceholder", text: $noteText, axis: .vertical)
            .lineLimit(2...5)
    }

    @MainActor
    private func process(_ item: PhotosPickerItem?) async {
        guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
        selectedPhotoData = data
        let filename = "photo_\(Date().timeIntervalSince1970).jpg"
        photoFilename = filename
        isProcessingPhoto = true
        photoProcessorResult = nil
        let processor = PhotoArtifactProcessor()
        let result = await processor.process(imageData: data, filename: filename)
        selectedPhotoThumbnail = result.thumbnailData
        photoProcessorResult = result
        isProcessingPhoto = false
    }
}
