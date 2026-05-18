import Foundation

struct SearchResultMerger {
    func merge(
        fallback: SearchSnapshot,
        semanticMemoryIDs: [UUID],
        memories: [MemorySummary],
        limit: Int?
    ) -> SearchSnapshot {
        guard !semanticMemoryIDs.isEmpty else {
            var result = fallback
            result.semanticSearchStatus = .succeeded(resultCount: 0)
            return result
        }

        let memoryIndex = Dictionary(uniqueKeysWithValues: memories.map { ($0.id, $0) })
        var seen = Set<UUID>()
        var mergedMemories: [SearchMemoryResultSnapshot] = []

        for id in semanticMemoryIDs {
            guard let memory = memoryIndex[id], seen.insert(id).inserted else { continue }
            mergedMemories.append(SearchMemoryResultSnapshot(memory: memory))
        }

        for result in fallback.memories {
            guard seen.insert(result.id).inserted else { continue }
            mergedMemories.append(result)
        }

        if let limit {
            mergedMemories = Array(mergedMemories.prefix(limit))
        }

        var result = fallback
        result.memories = mergedMemories
        result.semanticMemoryIDs = semanticMemoryIDs
        result.semanticSearchStatus = .succeeded(resultCount: semanticMemoryIDs.count)
        result.retrievalSources = unique(fallback.retrievalSources + [.spotlight])
        return result
    }

    private func unique(_ sources: [SearchRetrievalSource]) -> [SearchRetrievalSource] {
        var seen = Set<SearchRetrievalSource>()
        return sources.filter { seen.insert($0).inserted }
    }
}
