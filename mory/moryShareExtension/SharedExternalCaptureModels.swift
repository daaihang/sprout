import Foundation

private enum MorySharedContainers {
    static let appGroupIdentifier = "group.com.speculolabs.mory"
    static let externalCaptureAttachmentDirectoryName = "ExternalCaptureAttachments"
}

enum ExternalCaptureSourceKind: String, Codable {
    case shareSheet
}

enum ExternalCaptureAttachmentKind: String, Codable {
    case image
}

struct ExternalCaptureAttachmentDraft: Identifiable, Codable {
    var id: UUID = UUID()
    var kind: ExternalCaptureAttachmentKind = .image
    var filename: String
    var contentType: String
    var storedFileName: String?
    var summary: String?
}

struct ExternalCaptureRequest: Codable {
    var sourceKind: ExternalCaptureSourceKind
    var title: String?
    var text: String
    var url: String?
    var context: String?
    var affectDrafts: [String] = []
    var attachments: [ExternalCaptureAttachmentDraft] = []
}

enum ExternalCaptureInboxPayloadKind: String, Codable {
    case externalCapture
}

enum ExternalCaptureInboxStatus: String, Codable {
    case pending
}

struct ExternalCaptureInboxItem: Identifiable, Codable {
    var id: UUID = UUID()
    var payloadKind: ExternalCaptureInboxPayloadKind
    var sourceKind: ExternalCaptureSourceKind
    var title: String?
    var summary: String
    var payloadData: Data
    var status: ExternalCaptureInboxStatus = .pending
    var receivedAt: Date
    var updatedAt: Date
    var importedRecordID: UUID?
    var dismissedAt: Date?
    var errorMessage: String?
}

enum ExternalCaptureInboxError: LocalizedError {
    case appGroupUnavailable
    case unsupportedPayload
    case unsupportedImagePayload
}

struct ExternalCaptureInboxWriter {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func enqueue(_ request: ExternalCaptureRequest, receivedAt: Date = .now) throws -> ExternalCaptureInboxItem {
        let payloadData = try JSONEncoder().encode(request)
        let item = ExternalCaptureInboxItem(
            payloadKind: .externalCapture,
            sourceKind: .shareSheet,
            title: request.title,
            summary: request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? request.attachments.first?.summary ?? "Shared to Mory"
                : String(request.text.prefix(160)),
            payloadData: payloadData,
            receivedAt: receivedAt,
            updatedAt: receivedAt
        )
        var items = try loadItems()
        items.append(item)
        try saveItems(items)
        return item
    }

    private func loadItems() throws -> [ExternalCaptureInboxItem] {
        let defaults = try appGroupDefaults()
        guard let data = defaults.data(forKey: Self.storageKey), !data.isEmpty else { return [] }
        return try decoder.decode([ExternalCaptureInboxItem].self, from: data)
    }

    private func saveItems(_ items: [ExternalCaptureInboxItem]) throws {
        let data = try encoder.encode(items)
        try appGroupDefaults().set(data, forKey: Self.storageKey)
    }

    private func appGroupDefaults() throws -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: MorySharedContainers.appGroupIdentifier) else {
            throw ExternalCaptureInboxError.appGroupUnavailable
        }
        return defaults
    }

    private static let storageKey = "mory.externalCaptureInbox.legacy.v1"
}

struct ExternalCaptureAttachmentFileStore {
    func saveImage(data: Data, preferredFilename: String) throws -> String {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: MorySharedContainers.appGroupIdentifier
        ) else {
            throw ExternalCaptureInboxError.appGroupUnavailable
        }
        let directory = container.appendingPathComponent(
            MorySharedContainers.externalCaptureAttachmentDirectoryName,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sanitized = preferredFilename
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let filename = "\(UUID().uuidString)-\(sanitized)"
        let url = directory.appendingPathComponent(filename, isDirectory: false)
        try data.write(to: url, options: .atomic)
        return filename
    }
}
