import Foundation

@MainActor
protocol ExternalCaptureInboxStoring {
    func upsert(_ item: ExternalCaptureInboxItem) throws
    func fetch(status: ExternalCaptureInboxStatus?, limit: Int?) throws -> [ExternalCaptureInboxItem]
    func fetch(id: UUID) throws -> ExternalCaptureInboxItem?
    func clear() throws
}

@MainActor
final class ExternalCaptureInboxDefaultsStore: ExternalCaptureInboxStoring {
    private let defaults: UserDefaults
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard, scope: MoryLocalDataScope = .legacy) {
        self.defaults = defaults
        self.key = Self.storageKey(for: scope)
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func upsert(_ item: ExternalCaptureInboxItem) throws {
        var items = try load()
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        try save(items)
    }

    func fetch(status: ExternalCaptureInboxStatus?, limit: Int?) throws -> [ExternalCaptureInboxItem] {
        let filtered = try load()
            .filter { item in
                guard let status else { return true }
                return item.status == status
            }
            .sorted { $0.receivedAt > $1.receivedAt }
        guard let limit else { return filtered }
        return Array(filtered.prefix(max(0, limit)))
    }

    func fetch(id: UUID) throws -> ExternalCaptureInboxItem? {
        try load().first { $0.id == id }
    }

    func clear() throws {
        defaults.removeObject(forKey: key)
    }

    static func storageKey(for scope: MoryLocalDataScope) -> String {
        switch scope {
        case .legacy:
            return "mory.externalCaptureInbox.legacy.v1"
        case let .owner(ownerID):
            return "mory.externalCaptureInbox.owner.\(ownerID).v1"
        }
    }

    private func load() throws -> [ExternalCaptureInboxItem] {
        guard let data = defaults.data(forKey: key), !data.isEmpty else { return [] }
        return try decoder.decode([ExternalCaptureInboxItem].self, from: data)
    }

    private func save(_ items: [ExternalCaptureInboxItem]) throws {
        let data = try encoder.encode(items)
        defaults.set(data, forKey: key)
    }
}
