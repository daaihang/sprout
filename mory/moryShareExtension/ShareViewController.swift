import Foundation
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private var didStart = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStart else { return }
        didStart = true
        Task { await captureSharedItems() }
    }

    private func captureSharedItems() async {
        do {
            let payload = try await SharedPayloadExtractor().extract(from: extensionContext)
            let request = ExternalCaptureRequest(
                sourceKind: .shareSheet,
                title: payload.title,
                text: payload.text,
                url: payload.url,
                context: "shareExtension:moryShareExtension",
                attachments: payload.attachments
            )
            _ = try ExternalCaptureInboxWriter().enqueue(request)
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            extensionContext?.cancelRequest(withError: error)
        }
    }
}

private struct SharedPayload {
    var title: String?
    var text: String
    var url: String?
    var attachments: [ExternalCaptureAttachmentDraft]
}

private struct SharedPayloadExtractor {
    func extract(from context: NSExtensionContext?) async throws -> SharedPayload {
        let providers = context?.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] } ?? []

        var title: String?
        var textParts: [String] = []
        var url: String?
        var attachments: [ExternalCaptureAttachmentDraft] = []

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let item = try? await provider.loadItem(for: UTType.url.identifier) {
                if let value = item as? URL {
                    url = url ?? value.absoluteString
                    title = title ?? value.host
                    textParts.append(value.absoluteString)
                } else if let value = item as? String {
                    url = url ?? value
                    textParts.append(value)
                }
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let item = try? await provider.loadItem(for: UTType.plainText.identifier) {
                if let value = item as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    textParts.append(value)
                }
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
               let attachment = try? await imageAttachment(from: provider) {
                attachments.append(attachment)
            }
        }

        let text = textParts.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return SharedPayload(
            title: title,
            text: text.isEmpty ? "Shared to Mory." : text,
            url: url,
            attachments: attachments
        )
    }

    private func imageAttachment(from provider: NSItemProvider) async throws -> ExternalCaptureAttachmentDraft {
        let item = try await provider.loadItem(for: UTType.image.identifier)
        let filename = "shared-image-\(UUID().uuidString).jpg"

        if let url = item as? URL {
            let data = try Data(contentsOf: url)
            let storedFileName = try ExternalCaptureAttachmentFileStore().saveImage(data: data, preferredFilename: url.lastPathComponent)
            return ExternalCaptureAttachmentDraft(
                filename: url.lastPathComponent,
                contentType: UTType.image.identifier,
                storedFileName: storedFileName,
                summary: "Shared image"
            )
        }

        if let image = item as? UIImage,
           let data = image.jpegData(compressionQuality: 0.9) {
            let storedFileName = try ExternalCaptureAttachmentFileStore().saveImage(data: data, preferredFilename: filename)
            return ExternalCaptureAttachmentDraft(
                filename: filename,
                contentType: UTType.jpeg.identifier,
                storedFileName: storedFileName,
                summary: "Shared image"
            )
        }

        if let data = item as? Data {
            let storedFileName = try ExternalCaptureAttachmentFileStore().saveImage(data: data, preferredFilename: filename)
            return ExternalCaptureAttachmentDraft(
                filename: filename,
                contentType: UTType.image.identifier,
                storedFileName: storedFileName,
                summary: "Shared image"
            )
        }

        throw ExternalCaptureInboxError.unsupportedImagePayload
    }
}

private extension NSItemProvider {
    func loadItem(for typeIdentifier: String) async throws -> NSSecureCoding {
        try await withCheckedThrowingContinuation { continuation in
            loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let item = item as? NSSecureCoding {
                    continuation.resume(returning: item)
                } else {
                    continuation.resume(throwing: ExternalCaptureInboxError.unsupportedPayload)
                }
            }
        }
    }
}
