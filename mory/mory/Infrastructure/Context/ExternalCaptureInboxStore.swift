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
    private struct Backend {
        var defaults: UserDefaults
        var key: String
    }

    private let primary: Backend
    private let fallbacks: [Backend]
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        defaults: UserDefaults = .standard,
        scope: MoryLocalDataScope = .legacy,
        includeSharedLegacyFallback: Bool = false
    ) {
        self.primary = Backend(defaults: defaults, key: Self.storageKey(for: scope))
        if includeSharedLegacyFallback,
           let sharedDefaults = MorySharedContainers.appGroupDefaults {
            self.fallbacks = [
                Backend(defaults: sharedDefaults, key: Self.storageKey(for: .legacy))
            ]
        } else {
            self.fallbacks = []
        }
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func upsert(_ item: ExternalCaptureInboxItem) throws {
        let target = try backendContainingItem(id: item.id) ?? primary
        var items = try load(from: target)
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        try save(items, to: target)
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
        for backend in allBackends {
            backend.defaults.removeObject(forKey: backend.key)
        }
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
        var byID: [UUID: ExternalCaptureInboxItem] = [:]
        for backend in allBackends {
            for item in try load(from: backend) where byID[item.id] == nil {
                byID[item.id] = item
            }
        }
        return Array(byID.values)
    }

    private var allBackends: [Backend] {
        [primary] + fallbacks
    }

    private func backendContainingItem(id: UUID) throws -> Backend? {
        for backend in allBackends {
            if try load(from: backend).contains(where: { $0.id == id }) {
                return backend
            }
        }
        return nil
    }

    private func load(from backend: Backend) throws -> [ExternalCaptureInboxItem] {
        guard let data = backend.defaults.data(forKey: backend.key), !data.isEmpty else { return [] }
        return try decoder.decode([ExternalCaptureInboxItem].self, from: data)
    }

    private func save(_ items: [ExternalCaptureInboxItem], to backend: Backend) throws {
        let data = try encoder.encode(items)
        backend.defaults.set(data, forKey: backend.key)
    }
}
