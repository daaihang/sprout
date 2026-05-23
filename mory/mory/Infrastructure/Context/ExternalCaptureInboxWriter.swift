import Foundation

@MainActor
struct ExternalCaptureInboxWriter {
    private let registry: LocalDataOwnerRegistry
    private let defaults: UserDefaults
    private let codec = ExternalCaptureInboxCodec()

    init(defaults: UserDefaults = .standard, baseDirectory: URL? = nil) {
        self.registry = LocalDataOwnerRegistry(baseDirectory: baseDirectory)
        self.defaults = defaults
    }

    init(registry: LocalDataOwnerRegistry, defaults: UserDefaults = .standard) {
        self.registry = registry
        self.defaults = defaults
    }

    func enqueue(_ request: ExternalCaptureRequest, receivedAt: Date = .now) throws -> ExternalCaptureInboxItem {
        let item = try codec.makeItem(from: request, now: receivedAt)
        try persist(item)
        return item
    }

    func enqueue(_ suggestion: JournalingSuggestionDraft, receivedAt: Date = .now) throws -> ExternalCaptureInboxItem {
        let item = try codec.makeItem(from: suggestion, now: receivedAt)
        try persist(item)
        return item
    }

    private func persist(_ item: ExternalCaptureInboxItem) throws {
        let store = ExternalCaptureInboxDefaultsStore(
            defaults: defaults,
            scope: registry.activeScopeForExternalCapture()
        )
        try store.upsert(item)
    }
}
