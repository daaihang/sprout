import Foundation

protocol BackgroundOperationStoring {
    func fetchRuns(status: BackgroundOperationStatus?, limit: Int?) throws -> [BackgroundOperationRun]
    func fetchEvents(runID: UUID?, limit: Int?) throws -> [BackgroundOperationEvent]
    func upsertRun(_ run: BackgroundOperationRun) throws
    func upsertEvent(_ event: BackgroundOperationEvent) throws
}

@MainActor
final class BackgroundOperationMemoryStore: BackgroundOperationStoring {
    private var runs: [BackgroundOperationRun] = []
    private var events: [BackgroundOperationEvent] = []

    func fetchRuns(status: BackgroundOperationStatus?, limit: Int?) throws -> [BackgroundOperationRun] {
        let filtered = runs
            .filter { run in
                guard let status else { return true }
                return run.status == status
            }
            .sorted { $0.startedAt > $1.startedAt }
        return limited(filtered, limit: limit)
    }

    func fetchEvents(runID: UUID?, limit: Int?) throws -> [BackgroundOperationEvent] {
        let filtered = events
            .filter { event in
                guard let runID else { return true }
                return event.runID == runID
            }
            .sorted { $0.startedAt > $1.startedAt }
        return limited(filtered, limit: limit)
    }

    func upsertRun(_ run: BackgroundOperationRun) throws {
        if let index = runs.firstIndex(where: { $0.id == run.id }) {
            runs[index] = run
        } else {
            runs.append(run)
        }
    }

    func upsertEvent(_ event: BackgroundOperationEvent) throws {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.append(event)
        }
    }
}

@MainActor
final class BackgroundOperationDefaultsStore: BackgroundOperationStoring {
    private struct Payload: Codable {
        var runs: [BackgroundOperationRun]
        var events: [BackgroundOperationEvent]
    }

    private let defaults: UserDefaults
    private let key: String
    private let maxRuns: Int
    private let maxEvents: Int

    init(
        ownerID: String,
        defaults: UserDefaults = .standard,
        maxRuns: Int = 120,
        maxEvents: Int = 600
    ) {
        self.defaults = defaults
        self.key = "mory.background.operations.\(Self.sanitized(ownerID)).v1"
        self.maxRuns = maxRuns
        self.maxEvents = maxEvents
    }

    func fetchRuns(status: BackgroundOperationStatus?, limit: Int?) throws -> [BackgroundOperationRun] {
        let filtered = load().runs
            .filter { run in
                guard let status else { return true }
                return run.status == status
            }
            .sorted { $0.startedAt > $1.startedAt }
        return limited(filtered, limit: limit)
    }

    func fetchEvents(runID: UUID?, limit: Int?) throws -> [BackgroundOperationEvent] {
        let filtered = load().events
            .filter { event in
                guard let runID else { return true }
                return event.runID == runID
            }
            .sorted { $0.startedAt > $1.startedAt }
        return limited(filtered, limit: limit)
    }

    func upsertRun(_ run: BackgroundOperationRun) throws {
        var payload = load()
        if let index = payload.runs.firstIndex(where: { $0.id == run.id }) {
            payload.runs[index] = run
        } else {
            payload.runs.append(run)
        }
        payload.runs = Array(payload.runs.sorted { $0.startedAt > $1.startedAt }.prefix(maxRuns))
        save(payload)
    }

    func upsertEvent(_ event: BackgroundOperationEvent) throws {
        var payload = load()
        if let index = payload.events.firstIndex(where: { $0.id == event.id }) {
            payload.events[index] = event
        } else {
            payload.events.append(event)
        }
        payload.events = Array(payload.events.sorted { $0.startedAt > $1.startedAt }.prefix(maxEvents))
        save(payload)
    }

    private func load() -> Payload {
        guard
            let data = defaults.data(forKey: key),
            let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else {
            return Payload(runs: [], events: [])
        }
        return payload
    }

    private func save(_ payload: Payload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: key)
    }

    private static func sanitized(_ ownerID: String) -> String {
        ownerID.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : "_"
        }.joined()
    }
}

private func limited<T>(_ values: [T], limit: Int?) -> [T] {
    guard let limit, limit >= 0 else { return values }
    return Array(values.prefix(limit))
}
