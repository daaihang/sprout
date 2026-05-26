import AVFoundation
import Foundation
import Photos
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

nonisolated final class MediaArtifactProcessor: Sendable {
    enum MediaProcessingError: Error {
        case unsupportedMedia
        case missingPhotosAsset
        case missingLivePhotoResource
    }

    @MainActor
    func process(
        item: PhotosPickerItem,
        origin: CaptureArtifactOrigin = .manual,
        provenance: CaptureProvenance? = nil
    ) async throws -> CaptureArtifactDraft {
        if item.isLivePhotoSelection {
            return try await processLivePhotoItem(item, origin: origin, provenance: provenance)
        }

        if item.isVideoSelection {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw MediaProcessingError.unsupportedMedia
            }
            let filename = item.preferredFilename(defaultBase: "video", extension: item.preferredVideoExtension)
            return try await processVideoData(
                data,
                filename: filename,
                origin: origin,
                provenance: provenance,
                metadata: item.itemIdentifier.map { ["localIdentifier": $0] } ?? [:]
            )
        }

        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw MediaProcessingError.unsupportedMedia
        }
        return await processPhotoData(
            data,
            filename: item.preferredFilename(defaultBase: "photo", extension: "jpg"),
            origin: origin,
            provenance: provenance,
            metadata: item.itemIdentifier.map { ["localIdentifier": $0] } ?? [:]
        )
    }

    @MainActor
    func processPhotoData(
        _ data: Data,
        filename: String,
        origin: CaptureArtifactOrigin = .manual,
        provenance: CaptureProvenance? = nil,
        metadata: [String: String] = [:]
    ) async -> CaptureArtifactDraft {
        let result = await PhotoArtifactProcessor().process(imageData: data, filename: filename)
        return .photo(
            title: nil,
            summary: result.summary.trimmedOrNil ?? "Photo capture",
            filename: filename,
            imageData: data,
            thumbnailData: result.thumbnailData,
            ocrText: result.ocrText,
            photoMetadata: result.metadata.merging(metadata) { _, new in new },
            origin: origin,
            provenance: provenance
        )
    }

    @MainActor
    func processVideoData(
        _ data: Data,
        filename: String,
        origin: CaptureArtifactOrigin = .manual,
        provenance: CaptureProvenance? = nil,
        metadata: [String: String] = [:]
    ) async throws -> CaptureArtifactDraft {
        let result = try await Task.detached(priority: .userInitiated) {
            try Self.videoPreview(data: data, filename: filename)
        }.value
        var videoMetadata = metadata
        if let durationSeconds = result.durationSeconds {
            videoMetadata["durationSeconds"] = "\(durationSeconds)"
        }
        videoMetadata["mimeType"] = Self.mimeType(forVideoFilename: filename)
        videoMetadata["byteCount"] = "\(data.count)"
        return .video(
            title: nil,
            summary: "Video capture",
            filename: filename,
            videoData: data,
            thumbnailData: result.thumbnailData,
            videoMetadata: videoMetadata,
            origin: origin,
            provenance: provenance
        )
    }

    @MainActor
    func processLivePhotoData(
        stillData: Data,
        pairedVideoData: Data,
        stillFilename: String,
        videoFilename: String,
        origin: CaptureArtifactOrigin = .manual,
        provenance: CaptureProvenance? = nil,
        metadata: [String: String] = [:]
    ) async -> CaptureArtifactDraft {
        let stillResult = await PhotoArtifactProcessor().process(imageData: stillData, filename: stillFilename)
        var liveMetadata = metadata
        liveMetadata["stillByteCount"] = "\(stillData.count)"
        liveMetadata["pairedVideoByteCount"] = "\(pairedVideoData.count)"
        liveMetadata["pairedVideoMimeType"] = Self.mimeType(forVideoFilename: videoFilename)
        return .livePhoto(
            title: nil,
            summary: stillResult.summary.trimmedOrNil ?? "Live Photo capture",
            stillFilename: stillFilename,
            videoFilename: videoFilename,
            stillImageData: stillData,
            pairedVideoData: pairedVideoData,
            thumbnailData: stillResult.thumbnailData,
            metadata: stillResult.metadata.merging(liveMetadata) { _, new in new },
            origin: origin,
            provenance: provenance
        )
    }

    @MainActor
    private func processLivePhotoItem(
        _ item: PhotosPickerItem,
        origin: CaptureArtifactOrigin,
        provenance: CaptureProvenance?
    ) async throws -> CaptureArtifactDraft {
        guard let localIdentifier = item.itemIdentifier else {
            throw MediaProcessingError.missingPhotosAsset
        }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = assets.firstObject else {
            throw MediaProcessingError.missingPhotosAsset
        }
        let resources = PHAssetResource.assetResources(for: asset)
        guard let stillResource = resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto }),
              let pairedVideoResource = resources.first(where: { $0.type == .pairedVideo || $0.type == .fullSizePairedVideo })
        else {
            throw MediaProcessingError.missingLivePhotoResource
        }
        let stillData = try await Self.resourceData(for: stillResource)
        let videoData = try await Self.resourceData(for: pairedVideoResource)
        return await processLivePhotoData(
            stillData: stillData,
            pairedVideoData: videoData,
            stillFilename: stillResource.originalFilename,
            videoFilename: pairedVideoResource.originalFilename,
            origin: origin,
            provenance: provenance,
            metadata: [
                "localIdentifier": localIdentifier,
                "stillResourceType": "\(stillResource.type.rawValue)",
                "pairedVideoResourceType": "\(pairedVideoResource.type.rawValue)"
            ]
        )
    }

    private static func resourceData(for resource: PHAssetResource) async throws -> Data {
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(resource.originalFilename.pathExtensionOrDefault)
        defer { try? FileManager.default.removeItem(at: url) }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: options) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        return try Data(contentsOf: url)
    }

    nonisolated private static func videoPreview(data: Data, filename: String) throws -> (thumbnailData: Data?, durationSeconds: Int?) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(filename.pathExtensionOrDefault)
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url, options: .atomic)
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        let duration = seconds.isFinite && seconds > 0 ? Int(seconds.rounded()) : nil
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 900, height: 900)
        guard let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) else {
            return (nil, duration)
        }
        let image = UIImage(cgImage: cgImage)
        let thumbnail = image.jpegData(compressionQuality: 0.72)
        return (thumbnail, duration)
    }

    nonisolated private static func mimeType(forVideoFilename filename: String) -> String {
        filename.lowercased().hasSuffix(".mov") ? "video/quicktime" : "video/mp4"
    }
}

private extension PhotosPickerItem {
    var isLivePhotoSelection: Bool {
        supportedContentTypes.contains { $0.identifier == "com.apple.live-photo" }
    }

    var isVideoSelection: Bool {
        supportedContentTypes.contains { $0.conforms(to: .movie) || $0.conforms(to: .video) }
    }

    var preferredVideoExtension: String {
        if supportedContentTypes.contains(where: { $0.conforms(to: .quickTimeMovie) }) {
            return "mov"
        }
        return "mp4"
    }

    func preferredFilename(defaultBase: String, extension fileExtension: String) -> String {
        let id = itemIdentifier?.components(separatedBy: "/").last?.trimmedOrNil ?? "\(Int(Date().timeIntervalSince1970))"
        return "\(defaultBase)_\(id).\(fileExtension)"
    }
}

private extension String {
    nonisolated var pathExtensionOrDefault: String {
        let ext = (self as NSString).pathExtension
        return ext.isEmpty ? "dat" : ext
    }
}
