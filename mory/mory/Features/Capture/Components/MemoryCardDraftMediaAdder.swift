import PhotosUI
import SwiftUI
import UIKit

struct MemoryCardDraftMediaAddResult {
    var drafts: [CaptureArtifactDraft] = []
    var errors: [Error] = []

    var firstErrorMessage: String? {
        errors.first?.localizedDescription
    }
}

enum MemoryCardDraftMediaAdder {
    static func manualProvenance(_ sourceKind: CaptureProvenanceSourceKind) -> CaptureProvenance {
        CaptureProvenance(originCategory: .userInput, sourceKind: sourceKind)
    }

    @MainActor
    static func drafts(fromPhotoItems items: [PhotosPickerItem]) async -> MemoryCardDraftMediaAddResult {
        var result = MemoryCardDraftMediaAddResult()
        let processor = MediaArtifactProcessor()
        for item in items {
            do {
                let draft = try await processor.process(
                    item: item,
                    origin: .manual,
                    provenance: manualProvenance(.photoLibrary)
                )
                result.drafts.append(draft)
            } catch {
                result.errors.append(error)
            }
        }
        return result
    }

    @MainActor
    static func draft(fromCameraImage image: UIImage) async -> CaptureArtifactDraft? {
        guard let data = image.jpegData(compressionQuality: 0.86) else { return nil }
        return await draft(
            fromPhotoData: data,
            filename: "camera_\(Int(Date().timeIntervalSince1970)).jpg",
            provenance: manualProvenance(.camera)
        )
    }

    @MainActor
    static func draft(
        fromPhotoData data: Data,
        filename: String,
        provenance: CaptureProvenance
    ) async -> CaptureArtifactDraft {
        let result = await PhotoArtifactProcessor().process(imageData: data, filename: filename)
        let summary = result.summary.trimmedOrNil ?? String(localized: "quickCapture.photo.defaultSummary")
        return .photo(
            title: nil,
            summary: summary,
            filename: filename,
            imageData: data,
            thumbnailData: result.thumbnailData,
            ocrText: result.ocrText,
            photoMetadata: result.metadata,
            origin: .manual,
            provenance: provenance
        )
    }
}
