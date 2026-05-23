import Foundation

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
        var normalized = request
        normalized.version = ExternalCaptureRequest.currentVersion
        normalized.receivedAt = request.receivedAt ?? receivedAt
        let payloadData = try encoder.encode(normalized)
        let item = ExternalCaptureInboxItem(
            payloadKind: .externalCapture,
            sourceKind: .shareSheet,
            title: normalized.title,
            summary: normalized.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? normalized.attachments.first?.summary ?? "Shared to Mory"
                : String(normalized.text.prefix(160)),
            payloadData: payloadData,
            receivedAt: receivedAt,
            updatedAt: receivedAt,
            errorMessage: normalized.diagnostics.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? normalized.errorMessage
                : normalized.diagnostics.joined(separator: "\n")
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
        let defaults = try appGroupDefaults()
        defaults.set(data, forKey: Self.storageKey)
        defaults.synchronize()
    }

    private func appGroupDefaults() throws -> UserDefaults {
        guard let defaults = MorySharedContainers.appGroupDefaults else {
            throw ExternalCaptureInboxError.appGroupUnavailable
        }
        return defaults
    }

    private static let storageKey = "mory.externalCaptureInbox.v2"
}
