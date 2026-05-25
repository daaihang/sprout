import Foundation

struct ExternalCaptureComposeHandoff: Codable, Hashable, Sendable {
    var itemID: UUID
    var createdAt: Date

    init(itemID: UUID, createdAt: Date = .now) {
        self.itemID = itemID
        self.createdAt = createdAt
    }
}

struct ExternalCaptureComposeHandoffStore {
    private static let key = "mory.externalCapture.composeHandoff.v1"

    private let defaults: UserDefaults?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults? = MorySharedContainers.appGroupDefaults) {
        self.defaults = defaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func save(_ handoff: ExternalCaptureComposeHandoff) {
        guard let data = try? encoder.encode(handoff) else { return }
        defaults?.set(data, forKey: Self.key)
        defaults?.synchronize()
    }

    func load() -> ExternalCaptureComposeHandoff? {
        guard let data = defaults?.data(forKey: Self.key), !data.isEmpty else { return nil }
        return try? decoder.decode(ExternalCaptureComposeHandoff.self, from: data)
    }

    func consume() -> ExternalCaptureComposeHandoff? {
        let handoff = load()
        defaults?.removeObject(forKey: Self.key)
        defaults?.synchronize()
        return handoff
    }
}
