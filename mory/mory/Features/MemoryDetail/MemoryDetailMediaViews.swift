import PhotosUI
import SwiftUI
import UIKit

struct MemoryPhotoGallery: View {
    let artifacts: [Artifact]

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        if artifacts.count == 1, let artifact = artifacts.first {
            MemoryMediaStillView(artifact: artifact)
                .aspectRatio(4 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 20)
        } else if !artifacts.isEmpty {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(artifacts) { artifact in
                    MemoryMediaStillView(artifact: artifact)
                        .aspectRatio(artifact.id.uuidString.hashValue.isMultiple(of: 2) ? 0.82 : 1.18, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
        } else {
            MemoryDetailEmptyBlock(
                titleKey: "memory.detail.empty.gallery.title",
                messageKey: "memory.detail.empty.gallery.message",
                systemImage: "photo.on.rectangle"
            )
            .padding(.horizontal, 20)
        }
    }
}

struct MemoryMediaStillView: View {
    let artifact: Artifact

    var body: some View {
        Group {
            if artifact.kind == .livePhoto {
                MemoryLivePhotoView(artifact: artifact)
            } else if let data = artifact.binaryPayload, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let data = artifact.previewPayload, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.12))
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipped()
        .accessibilityLabel(Text(artifact.memoryDetailSummary))
    }
}

struct MemoryLivePhotoView: View {
    let artifact: Artifact

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let stillData = artifact.previewPayload,
               let pairedVideoData = artifact.binaryPayload,
               let placeholder = UIImage(data: stillData) {
                LivePhotoResourceView(
                    stillData: stillData,
                    pairedVideoData: pairedVideoData,
                    placeholder: placeholder
                )
            } else if let data = artifact.previewPayload, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.12))
                    Image(systemName: "livephoto")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }

            Label("Live Photo", systemImage: "livephoto")
                .font(.caption2.weight(.semibold))
                .labelStyle(.iconOnly)
                .padding(7)
                .background(.ultraThinMaterial, in: Circle())
                .padding(8)
        }
    }
}

struct LivePhotoResourceView: UIViewRepresentable {
    let stillData: Data
    let pairedVideoData: Data
    let placeholder: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFill
        view.isMuted = true
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        context.coordinator.load(
            stillData: stillData,
            pairedVideoData: pairedVideoData,
            placeholder: placeholder
        ) { livePhoto in
            uiView.livePhoto = livePhoto
        }
    }

    final class Coordinator {
        private var temporaryURLs: [URL] = []
        private var loadKey: Int?

        deinit {
            temporaryURLs.forEach { try? FileManager.default.removeItem(at: $0) }
        }

        func load(
            stillData: Data,
            pairedVideoData: Data,
            placeholder: UIImage,
            completion: @escaping (PHLivePhoto?) -> Void
        ) {
            let key = stillData.count ^ pairedVideoData.count
            guard loadKey != key else { return }
            loadKey = key
            temporaryURLs.forEach { try? FileManager.default.removeItem(at: $0) }
            temporaryURLs = []

            let baseURL = FileManager.default.temporaryDirectory.appendingPathComponent("mory_live_photo_\(UUID().uuidString)")
            let stillURL = baseURL.appendingPathExtension("jpg")
            let videoURL = baseURL.appendingPathExtension("mov")
            do {
                try stillData.write(to: stillURL, options: .atomic)
                try pairedVideoData.write(to: videoURL, options: .atomic)
                temporaryURLs = [stillURL, videoURL]
                PHLivePhoto.request(
                    withResourceFileURLs: temporaryURLs,
                    placeholderImage: placeholder,
                    targetSize: .zero,
                    contentMode: .aspectFill
                ) { livePhoto, _ in
                    completion(livePhoto)
                }
            } catch {
                completion(nil)
            }
        }
    }
}
