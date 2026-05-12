import SwiftUI
import UIKit
import Combine

private enum RemoteImageCache {
    static let memory = NSCache<NSURL, UIImage>()
}

@MainActor
private final class RemoteImageLoader: ObservableObject {
    @Published var phase: AsyncImagePhase = .empty
    private var currentURL: URL?

    func load(url: URL?) async {
        guard currentURL != url else { return }
        currentURL = url

        guard let url else {
            phase = .empty
            return
        }

        if let cached = cachedImage(for: url) {
            phase = .success(Image(uiImage: cached))
            return
        }

        phase = .empty

        let request = URLRequest(
            url: url,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 30
        )

        do {
            let cachedResponse = URLCache.shared.cachedResponse(for: request)
            let data: Data
            let response: URLResponse

            if let cachedResponse {
                data = cachedResponse.data
                response = cachedResponse.response
            } else {
                let result = try await URLSession.shared.data(for: request)
                data = result.0
                response = result.1
                if let httpResponse = response as? HTTPURLResponse {
                    URLCache.shared.storeCachedResponse(
                        CachedURLResponse(response: httpResponse, data: data),
                        for: request
                    )
                }
            }

            guard let image = UIImage(data: data) else {
                phase = .failure(URLError(.cannotDecodeContentData))
                return
            }

            store(image, for: url)
            phase = .success(Image(uiImage: image))
        } catch {
            if Task.isCancelled {
                return
            }
            phase = .failure(error)
        }
    }

    private func cachedImage(for url: URL) -> UIImage? {
        if let image = RemoteImageCache.memory.object(forKey: url as NSURL) {
            return image
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        if let cachedResponse = URLCache.shared.cachedResponse(for: request),
           let image = UIImage(data: cachedResponse.data) {
            store(image, for: url)
            return image
        }

        return nil
    }

    private func store(_ image: UIImage, for url: URL) {
        RemoteImageCache.memory.setObject(image, forKey: url as NSURL)
    }
}

struct CachedRemoteImage<Placeholder: View>: View {
    let url: URL?
    private let contentMode: ContentMode
    private let placeholder: () -> Placeholder
    @StateObject private var loader = RemoteImageLoader()

    enum ContentMode {
        case fit
        case fill
    }

    init(
        url: URL?,
        contentMode: ContentMode = .fit,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            switch loader.phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode == .fill ? .fill : .fit)
            case .failure, .empty:
                placeholder()
            @unknown default:
                placeholder()
            }
        }
        .task(id: url?.absoluteString) {
            await loader.load(url: url)
        }
    }
}

struct PreparedPhotoMedia {
    let imageData: Data
    let thumbnailData: Data?
}

func preparePhotoMediaPayloads(from images: [UIImage]) async -> [PreparedPhotoMedia] {
    await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            let payloads: [PreparedPhotoMedia] = images.compactMap { image in
                let imageData = image.jpegData(compressionQuality: 0.85)
                let thumbnailData = image
                    .preparingThumbnail(of: CGSize(width: 300, height: 300))?
                    .jpegData(compressionQuality: 0.7)

                guard let imageData else { return nil }
                return PreparedPhotoMedia(imageData: imageData, thumbnailData: thumbnailData)
            }
            continuation.resume(returning: payloads)
        }
    }
}
