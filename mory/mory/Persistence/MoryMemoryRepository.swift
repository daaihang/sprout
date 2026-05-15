import Foundation
import SwiftData

@MainActor
final class MoryMemoryRepository: MoryMemoryRepositorying {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func createMemory(from draft: MemoryCaptureDraft) throws -> MemorySummary {
        let now = Date.now
        let recordID = UUID()
        let normalizedText = draft.rawText.trimmedOrNil ?? "Untitled Memory"
        let artifactTitle = draft.title?.trimmedOrNil ?? normalizedText.firstMeaningfulLine ?? "Untitled Memory"
        let artifactSummary = normalizedText

        let artifact = Artifact(
            recordID: recordID,
            kind: .text,
            title: artifactTitle,
            summary: artifactSummary,
            textContent: normalizedText,
            payload: .text(normalizedText),
            metadata: [:],
            createdAt: now,
            updatedAt: now
        )

        let recordShell = RecordShell(
            id: recordID,
            createdAt: now,
            updatedAt: now,
            captureSource: draft.captureSource,
            rawText: normalizedText,
            userMood: draft.mood?.trimmedOrNil,
            userIntensity: nil,
            inputContext: draft.inputContext?.trimmedOrNil,
            artifactIDs: [artifact.id]
        )

        try upsert(recordShell: recordShell)
        try upsert(artifact: artifact)
        try save()

        return makeMemorySummary(record: recordShell, artifacts: [artifact])
    }

    func fetchRecordShells() throws -> [RecordShell] {
        let descriptor = FetchDescriptor<RecordShellStore>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.domainModel)
    }

    func fetchRecentMemories(limit: Int? = nil) throws -> [MemorySummary] {
        let records = try fetchRecordShells()
        let summaries = try records.map { record in
            let artifacts = try fetchArtifacts(recordID: record.id)
            return makeMemorySummary(record: record, artifacts: artifacts)
        }

        guard let limit else { return summaries }
        return Array(summaries.prefix(limit))
    }

    func fetchHomeBoard(for date: Date, limit: Int = 8) throws -> HomeBoardSnapshot {
        let memories = try fetchRecentMemories(limit: limit)
        let boardStore = try ensureHomeBoard(for: date)
        let compositionStore = try ensureHomeComposition(for: boardStore)
        let itemStores = try ensureHomeBoardItems(
            boardStore: boardStore,
            compositionStore: compositionStore,
            memories: memories
        )

        let memoriesByRecordID = Dictionary(uniqueKeysWithValues: memories.map { ($0.record.id, $0) })
        let items = itemStores
            .sorted { $0.zIndex < $1.zIndex }
            .map { store in
                HomeBoardItemSnapshot(
                    compositionItem: store.domainModel,
                    memory: memoriesByRecordID[store.targetID]
                )
            }

        return HomeBoardSnapshot(
            board: boardStore.domainModel,
            composition: compositionStore.domainModel,
            items: items
        )
    }

    func fetchArtifacts(recordID: UUID) throws -> [Artifact] {
        let descriptor = FetchDescriptor<ArtifactStore>(
            predicate: #Predicate { $0.recordID == recordID },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.domainModel)
    }

    func fetchRecordShell(id: UUID) throws -> RecordShell? {
        let descriptor = FetchDescriptor<RecordShellStore>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first?.domainModel
    }

    func fetchMemoryDetail(recordID: UUID) throws -> MemoryDetailSnapshot? {
        guard let record = try fetchRecordShell(id: recordID) else {
            return nil
        }

        return MemoryDetailSnapshot(
            record: record,
            artifacts: try fetchArtifacts(recordID: recordID),
            analysis: try fetchRecordAnalysis(recordID: recordID)
        )
    }

    func fetchRecordAnalysis(recordID: UUID) throws -> RecordAnalysisSnapshot? {
        let descriptor = FetchDescriptor<RecordAnalysisSnapshotStore>(
            predicate: #Predicate { $0.recordID == recordID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first?.domainModel
    }

    func search(query: String, limit: Int? = nil) throws -> SearchSnapshot {
        let needle = query.normalizedSearchTerm
        guard let needle else {
            return SearchSnapshot(query: query, memories: [], entities: [], arcs: [], reflections: [])
        }

        let memories = try fetchRecentMemories(limit: nil)
            .filter { memory in
                [
                    memory.title,
                    memory.summaryText,
                    memory.record.rawText,
                    memory.record.userMood ?? ""
                ].containsSearchTerm(needle)
            }

        let entities = try modelContext.fetch(
            FetchDescriptor<EntityNodeStore>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        )
        .map(\.domainModel)
        .filter { entity in
            [entity.displayName, entity.canonicalName, entity.summary].containsSearchTerm(needle)
        }

        let arcs = try modelContext.fetch(
            FetchDescriptor<TemporalArcStore>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        )
        .map(\.domainModel)
        .filter { arc in
            [arc.title, arc.summary, arc.dominantTheme ?? "", arc.dominantEntityName ?? ""].containsSearchTerm(needle)
                || arc.themeLabels.containsSearchTerm(needle)
                || arc.entityNames.containsSearchTerm(needle)
        }

        let reflections = try modelContext.fetch(
            FetchDescriptor<ReflectionSnapshotStore>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
        .map(\.domainModel)
        .filter { reflection in
            [reflection.title, reflection.body, reflection.evidenceSummary].containsSearchTerm(needle)
        }

        return SearchSnapshot(
            query: query,
            memories: applyLimit(limit, to: memories),
            entities: applyLimit(limit, to: entities),
            arcs: applyLimit(limit, to: arcs),
            reflections: applyLimit(limit, to: reflections)
        )
    }

    func fetchPeopleSummaries(limit: Int? = nil) throws -> [PersonMemorySummary] {
        let personEntities = try modelContext.fetch(
            FetchDescriptor<EntityNodeStore>(
                predicate: #Predicate { $0.kindRawValue == "person" },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        ).map(\.domainModel)

        let links = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>()).map(\.domainModel)
        let artifacts = try modelContext.fetch(FetchDescriptor<ArtifactStore>()).map(\.domainModel)
        let analyses = try modelContext.fetch(
            FetchDescriptor<RecordAnalysisSnapshotStore>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        ).map(\.domainModel)
        let reflections = try modelContext.fetch(
            FetchDescriptor<ReflectionSnapshotStore>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        ).map(\.domainModel)
        let memories = try fetchRecentMemories(limit: nil)
        let memoriesByRecordID = Dictionary(uniqueKeysWithValues: memories.map { ($0.record.id, $0) })

        let summaries = personEntities.map { entity in
            let artifactIDs = Set(links.filter { $0.entityID == entity.id }.map(\.artifactID))
            let relatedArtifacts = artifacts.filter { artifactIDs.contains($0.id) }
            let relatedRecordIDs = Array(Set(relatedArtifacts.map(\.recordID)))
            let relatedMemories = relatedRecordIDs.compactMap { memoriesByRecordID[$0] }
                .sorted { $0.record.updatedAt > $1.record.updatedAt }
            let themeLabels = Array(
                Set(
                    analyses
                        .filter { relatedRecordIDs.contains($0.recordID) }
                        .flatMap(\.themes)
                )
            )
            .sorted()
            let reflectionCount = reflections.filter { $0.sourceEntityIDs.contains(entity.id) }.count

            return PersonMemorySummary(
                entity: entity,
                artifactCount: relatedArtifacts.count,
                relatedMemories: Array(relatedMemories.prefix(3)),
                themeLabels: Array(themeLabels.prefix(3)),
                reflectionCount: reflectionCount
            )
        }

        return applyLimit(limit, to: summaries)
    }

    func fetchTemporalArcs(limit: Int? = nil) throws -> [TemporalArc] {
        let arcs = try modelContext.fetch(
            FetchDescriptor<TemporalArcStore>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        ).map(\.domainModel)
        return applyLimit(limit, to: arcs)
    }

    func fetchReflections(limit: Int? = nil) throws -> [ReflectionSnapshot] {
        let reflections = try modelContext.fetch(
            FetchDescriptor<ReflectionSnapshotStore>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        ).map(\.domainModel)
        return applyLimit(limit, to: reflections)
    }

    func upsert(recordShell: RecordShell) throws {
        let descriptor = FetchDescriptor<RecordShellStore>(predicate: #Predicate { $0.id == recordShell.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: recordShell)
        } else {
            modelContext.insert(RecordShellStore(domainModel: recordShell))
        }
    }

    func upsert(artifact: Artifact) throws {
        let descriptor = FetchDescriptor<ArtifactStore>(predicate: #Predicate { $0.id == artifact.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: artifact)
        } else {
            modelContext.insert(ArtifactStore(domainModel: artifact))
        }
    }

    func save() throws {
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }

    private func ensureHomeBoard(for date: Date) throws -> BoardStore {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let boardKey = homeBoardKey(for: startOfDay)
        let descriptor = FetchDescriptor<BoardStore>()

        if let existing = try modelContext.fetch(descriptor).first(where: { $0.boardKey == boardKey }) {
            existing.title = "Today"
            existing.subtitle = startOfDay.formatted(date: .abbreviated, time: .omitted)
            existing.boardDate = startOfDay
            existing.updatedAt = Date.now
            return existing
        }

        let board = BoardStore(
            id: UUID(),
            boardKey: boardKey,
            kindRawValue: BoardKind.homeDay.rawValue,
            title: "Today",
            subtitle: startOfDay.formatted(date: .abbreviated, time: .omitted),
            boardDate: startOfDay,
            createdAt: Date.now,
            updatedAt: Date.now
        )
        modelContext.insert(board)
        try save()
        return board
    }

    private func ensureHomeComposition(for boardStore: BoardStore) throws -> CompositionStore {
        let descriptor = FetchDescriptor<CompositionStore>()

        if let existing = try modelContext.fetch(descriptor).first(where: {
            $0.boardID == boardStore.id && $0.compositionKey == "home-main"
        }) {
            return existing
        }

        let composition = CompositionStore(
            id: UUID(),
            boardID: boardStore.id,
            compositionKey: "home-main",
            title: "Primary Memory Space",
            sortOrder: 0,
            createdAt: Date.now,
            updatedAt: Date.now
        )
        modelContext.insert(composition)
        try save()
        return composition
    }

    private func ensureHomeBoardItems(
        boardStore: BoardStore,
        compositionStore: CompositionStore,
        memories: [MemorySummary]
    ) throws -> [CompositionItemStore] {
        let descriptor = FetchDescriptor<CompositionItemStore>(sortBy: [SortDescriptor(\.zIndex, order: .forward)])
        var existingItems = try modelContext.fetch(descriptor).filter { $0.boardID == boardStore.id }
        let existingRecordIDs = Set(existingItems.map(\.targetID))

        for (index, memory) in memories.enumerated() where !existingRecordIDs.contains(memory.record.id) {
            let layout = homeLayoutPattern(index: existingItems.count + index)
            let item = CompositionItemStore(
                id: UUID(),
                boardID: boardStore.id,
                boardKey: boardStore.boardKey,
                compositionID: compositionStore.id,
                compositionKey: compositionStore.compositionKey,
                itemKey: "record-\(memory.record.id.uuidString)",
                targetTypeRawValue: CompositionTargetType.record.rawValue,
                targetID: memory.record.id,
                widthColumns: layout.widthColumns,
                heightUnits: layout.heightUnits,
                zIndex: layout.zIndex,
                rotationDegrees: layout.rotationDegrees,
                scale: layout.scale,
                isHidden: false,
                updatedAt: Date.now
            )
            modelContext.insert(item)
            existingItems.append(item)
        }

        if modelContext.hasChanges {
            compositionStore.updatedAt = Date.now
            boardStore.updatedAt = Date.now
            try save()
            existingItems = try modelContext.fetch(descriptor).filter { $0.boardID == boardStore.id }
        }

        let memoryIDs = Set(memories.map(\.record.id))
        return existingItems.filter { memoryIDs.contains($0.targetID) }
    }

    private func homeBoardKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "home-day-%04d-%02d-%02d", year, month, day)
    }

    private func homeLayoutPattern(index: Int) -> (widthColumns: Int, heightUnits: Int, zIndex: Int, rotationDegrees: Double, scale: Double) {
        let patterns: [(Int, Int, Double, Double)] = [
            (2, 2, -1.2, 1.00),
            (1, 1, 0.8, 0.98),
            (1, 1, -0.4, 1.00),
            (2, 1, 1.0, 1.02),
            (1, 2, -0.8, 0.99),
            (1, 1, 0.3, 1.00),
        ]
        let pattern = patterns[index % patterns.count]
        return (
            widthColumns: pattern.0,
            heightUnits: pattern.1,
            zIndex: index,
            rotationDegrees: pattern.2,
            scale: pattern.3
        )
    }

    private func makeMemorySummary(record: RecordShell, artifacts: [Artifact]) -> MemorySummary {
        MemorySummary(
            record: record,
            primaryArtifact: preferredPrimaryArtifact(from: artifacts),
            artifactCount: artifacts.count
        )
    }

    private func preferredPrimaryArtifact(from artifacts: [Artifact]) -> Artifact? {
        artifacts.first(where: { $0.kind == .text && $0.textContent.normalizedNonEmpty != nil })
            ?? artifacts.first(where: { $0.summary.normalizedNonEmpty != nil })
            ?? artifacts.first
    }

    private func applyLimit<T>(_ limit: Int?, to values: [T]) -> [T] {
        guard let limit else { return values }
        return Array(values.prefix(limit))
    }
}

private extension String {
    var normalizedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var normalizedSearchTerm: String? {
        normalizedNonEmpty?.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

private extension Array where Element == String {
    func containsSearchTerm(_ needle: String) -> Bool {
        contains { value in
            value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .contains(needle)
        }
    }
}
