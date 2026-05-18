import CoreSpotlight
import Foundation

@MainActor
protocol SpotlightIndexServicing: AnyObject {
    var isIndexingAvailable: Bool { get }
    func indexItems(_ items: [CSSearchableItem]) async throws
    func deleteItems(identifiers: [String]) async throws
    func deleteDomain(_ domainIdentifier: String) async throws
    func searchMemoryIDs(query: String, limit: Int) async throws -> [UUID]
}

@MainActor
final class NoopSpotlightIndexService: SpotlightIndexServicing {
    var isIndexingAvailable: Bool { false }

    func indexItems(_ items: [CSSearchableItem]) async throws {
    }

    func deleteItems(identifiers: [String]) async throws {
    }

    func deleteDomain(_ domainIdentifier: String) async throws {
    }

    func searchMemoryIDs(query: String, limit: Int) async throws -> [UUID] {
        []
    }
}

@MainActor
final class DefaultSpotlightIndexService: SpotlightIndexServicing {
    private let index: CSSearchableIndex

    init(index: CSSearchableIndex = .default()) {
        self.index = index
    }

    var isIndexingAvailable: Bool {
        CSSearchableIndex.isIndexingAvailable()
    }

    func indexItems(_ items: [CSSearchableItem]) async throws {
        guard isIndexingAvailable, !items.isEmpty else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            index.indexSearchableItems(items) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func deleteItems(identifiers: [String]) async throws {
        guard isIndexingAvailable, !identifiers.isEmpty else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            index.deleteSearchableItems(withIdentifiers: identifiers) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func deleteDomain(_ domainIdentifier: String) async throws {
        guard isIndexingAvailable else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            index.deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func searchMemoryIDs(query: String, limit: Int) async throws -> [UUID] {
        guard isIndexingAvailable, let query = query.trimmedOrNil else { return [] }
        guard #available(iOS 16.0, *) else { return [] }

        let context = CSUserQueryContext()
        context.maxResultCount = max(limit, 1)
        context.enableRankedResults = true
        if #available(iOS 18.0, *) {
            context.disableSemanticSearch = false
            context.maxRankedResultCount = max(limit, 1)
        }

        let userQuery = CSUserQuery(userQueryString: query, userQueryContext: context)
        var ids: [UUID] = []
        var seen = Set<UUID>()

        for try await response in userQuery.responses {
            guard ids.count < limit else { break }
            guard case let .item(item) = response else { continue }
            guard let memoryID = SpotlightSearchableItemIdentifier.parseMemoryID(from: item.item.uniqueIdentifier) else { continue }
            guard item.item.domainIdentifier == SpotlightSearchableItemIdentifier.memoryDomain else { continue }
            guard seen.insert(memoryID).inserted else { continue }
            ids.append(memoryID)
        }

        return ids
    }
}
