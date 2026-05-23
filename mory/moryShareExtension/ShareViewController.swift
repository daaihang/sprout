import Foundation
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private var didStart = false
    private var pendingOpenURL: URL?

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
                errorMessage: payload.errorMessage,
                attachments: payload.attachments
            )
            let item = try ExternalCaptureInboxWriter().enqueue(request)
            await openHostApp(for: item.id)
        } catch {
            await showFailure(error)
        }
    }

    private func openHostApp(for itemID: UUID) async {
        var components = URLComponents()
        components.scheme = "mory"
        components.host = "external-capture"
        components.queryItems = [
            URLQueryItem(name: "id", value: itemID.uuidString),
            URLQueryItem(name: "action", value: "compose")
        ]
        guard let url = components.url else {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }

        pendingOpenURL = url
        let didOpen = await tryOpenHostApp(url)
        if !didOpen {
            try? ExternalCaptureInboxWriter().markLaunchFailed(itemID: itemID, reason: "Unable to open Mory from share extension.")
            await showOpenFallback(url: url)
            return
        }
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func tryOpenHostApp(_ url: URL) async -> Bool {
        let contextOpenSucceeded = await withCheckedContinuation { continuation in
            extensionContext?.open(url) { success in
                continuation.resume(returning: success)
            }
        }
        if contextOpenSucceeded {
            return true
        }
        return await MainActor.run {
            openHostAppViaResponderChain(url)
        }
    }

    @MainActor
    private func showOpenFallback(url: URL) {
        renderStatusView(
            title: "Saved to Mory",
            message: "Open Mory to finish this memory.",
            primaryTitle: "Open Mory",
            primaryAction: { [weak self] in
                Task {
                    guard let self else { return }
                    let didOpen = await self.tryOpenHostApp(url)
                    if didOpen {
                        self.extensionContext?.completeRequest(returningItems: nil)
                    }
                }
            },
            secondaryTitle: "Done",
            secondaryAction: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        )
    }

    @MainActor
    private func showFailure(_ error: Error) {
        renderStatusView(
            title: "Mory could not read this share",
            message: error.localizedDescription,
            primaryTitle: "Done",
            primaryAction: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            },
            secondaryTitle: nil,
            secondaryAction: nil
        )
    }

    @MainActor
    private func renderStatusView(
        title: String,
        message: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String?,
        secondaryAction: (() -> Void)?
    ) {
        view.subviews.forEach { $0.removeFromSuperview() }
        view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let primaryButton = UIButton(type: .system)
        primaryButton.setTitle(primaryTitle, for: .normal)
        primaryButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        primaryButton.addAction(UIAction { _ in primaryAction() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, primaryButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 14

        if let secondaryTitle, let secondaryAction {
            let secondaryButton = UIButton(type: .system)
            secondaryButton.setTitle(secondaryTitle, for: .normal)
            secondaryButton.addAction(UIAction { _ in secondaryAction() }, for: .touchUpInside)
            stack.addArrangedSubview(secondaryButton)
        }

        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @MainActor
    private func openHostAppViaResponderChain(_ url: URL) -> Bool {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: selector) {
                current.perform(selector, with: url)
                return true
            }
            responder = current.next
        }
        return false
    }
}

private struct SharedPayload {
    var title: String?
    var text: String
    var url: String?
    var attachments: [ExternalCaptureAttachmentDraft]
    var attachmentErrors: [String]

    var errorMessage: String? {
        attachmentErrors.isEmpty ? nil : attachmentErrors.joined(separator: "\n")
    }
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
        var attachmentErrors: [String] = []

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

            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                do {
                    attachments.append(try await imageAttachment(from: provider))
                } catch {
                    attachmentErrors.append("Image attachment failed: \(error.localizedDescription)")
                }
            }
        }

        let text = textParts.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return SharedPayload(
            title: title,
            text: text.isEmpty ? "Shared to Mory." : text,
            url: url,
            attachments: attachments,
            attachmentErrors: attachmentErrors
        )
    }

    private func imageAttachment(from provider: NSItemProvider) async throws -> ExternalCaptureAttachmentDraft {
        let filename = "shared-image-\(UUID().uuidString).jpg"

        if let data = try? await provider.loadDataRepresentation(for: .image) {
            let storedFileName = try ExternalCaptureAttachmentFileStore().saveImage(data: data, preferredFilename: filename)
            return ExternalCaptureAttachmentDraft(
                filename: filename,
                contentType: UTType.image.identifier,
                storedFileName: storedFileName,
                summary: "Shared image"
            )
        }

        if let file = try? await provider.loadFileRepresentationData(for: .image) {
            let storedFileName = try ExternalCaptureAttachmentFileStore().saveImage(data: file.data, preferredFilename: file.filename)
            return ExternalCaptureAttachmentDraft(
                filename: file.filename,
                contentType: UTType.image.identifier,
                storedFileName: storedFileName,
                summary: "Shared image"
            )
        }

        if let image = try? await provider.loadUIImage(),
           let data = image.jpegData(compressionQuality: 0.9) {
            let storedFileName = try ExternalCaptureAttachmentFileStore().saveImage(data: data, preferredFilename: filename)
            return ExternalCaptureAttachmentDraft(
                filename: filename,
                contentType: UTType.jpeg.identifier,
                storedFileName: storedFileName,
                summary: "Shared image"
            )
        }

        let item = try await provider.loadItem(for: UTType.image.identifier)
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
    struct LoadedFileData {
        var data: Data
        var filename: String
    }

    func loadItem(for typeIdentifier: String) async throws -> NSSecureCoding {
        try await withCheckedThrowingContinuation { continuation in
            loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let item {
                    continuation.resume(returning: item)
                } else {
                    continuation.resume(throwing: ExternalCaptureInboxError.unsupportedPayload)
                }
            }
        }
    }

    func loadDataRepresentation(for type: UTType) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            loadDataRepresentation(forTypeIdentifier: type.identifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: ExternalCaptureInboxError.unsupportedPayload)
                }
            }
        }
    }

    func loadFileRepresentationData(for type: UTType) async throws -> LoadedFileData {
        try await withCheckedThrowingContinuation { continuation in
            loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                do {
                    if let error {
                        throw error
                    }
                    guard let url else {
                        throw ExternalCaptureInboxError.unsupportedPayload
                    }
                    let data = try Data(contentsOf: url)
                    continuation.resume(returning: LoadedFileData(data: data, filename: url.lastPathComponent))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func loadUIImage() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            loadObject(ofClass: UIImage.self) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let image = object as? UIImage {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: ExternalCaptureInboxError.unsupportedImagePayload)
                }
            }
        }
    }
}
