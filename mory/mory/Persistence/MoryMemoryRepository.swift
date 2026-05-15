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
        let captureArtifacts = buildArtifacts(from: draft, recordID: recordID, createdAt: now)
        let normalizedText = resolvedRecordRawText(from: draft, artifacts: captureArtifacts)

        let recordShell = RecordShell(
            id: recordID,
            createdAt: now,
            updatedAt: now,
            captureSource: draft.captureSource,
            rawText: normalizedText,
            userMood: draft.mood?.trimmedOrNil,
            userIntensity: nil,
            inputContext: draft.inputContext?.trimmedOrNil,
            artifactIDs: captureArtifacts.map(\.id)
        )

        try upsert(recordShell: recordShell)
        try captureArtifacts.forEach { try upsert(artifact: $0) }
        try save()

        return makeMemorySummary(record: recordShell, artifacts: captureArtifacts)
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

    func seedDebugFixture() throws -> DebugMemoryFixtureSnapshot {
        let now = Date.now
        let draft = MemoryCaptureDraft(
            title: "Late train, quiet insight",
            rawText: "Missed the express home after dinner with Linh and ended up walking twenty minutes in the rain. It felt frustrating at first, but the walk made the next quarter plan click into place.",
            mood: "reflective",
            inputContext: "post-dinner voice memo transcribed to text",
            captureSource: .manual
        )
        let memory = try createMemory(from: draft)

        let analysis = RecordAnalysisSnapshot(
            recordID: memory.record.id,
            summary: "A disrupted commute turned into a planning insight after a rain walk.",
            themes: ["transition", "career planning", "weather"],
            emotionInterpretation: "Frustration softened into clarity and forward motion.",
            salienceScore: 0.86,
            retrievalTerms: ["Linh", "rain walk", "quarter plan", "late train"],
            entityMentions: [
                EntityReference(kind: .person, name: "Linh", confidence: 0.98),
                EntityReference(kind: .theme, name: "career planning", confidence: 0.84),
                EntityReference(kind: .place, name: "Downtown station", confidence: 0.72),
            ],
            candidateEdges: [
                CandidateEntityEdge(
                    from: EntityReference(kind: .person, name: "Linh"),
                    to: EntityReference(kind: .theme, name: "career planning"),
                    relationKind: .mentionedWith,
                    confidence: 0.71
                )
            ],
            followUpCandidates: [
                FollowUpCandidate(prompt: "Capture the quarter plan outline before tomorrow morning.", reason: "The insight is still fresh.")
            ],
            reflectionHint: "This record may become part of a broader transition arc.",
            createdAt: now
        )
        try upsert(recordAnalysis: analysis)

        let person = EntityNode(
            kind: .person,
            displayName: "Linh",
            summary: "Friend connected to planning and grounding conversations.",
            createdAt: now,
            updatedAt: now,
            confidence: 0.98
        )
        let theme = EntityNode(
            kind: .theme,
            displayName: "Career Planning",
            summary: "Quarter planning and transition decisions.",
            createdAt: now,
            updatedAt: now,
            confidence: 0.84
        )
        let place = EntityNode(
            kind: .place,
            displayName: "Downtown Station",
            summary: "Transit node associated with the rain walk.",
            createdAt: now,
            updatedAt: now,
            confidence: 0.72
        )
        try upsert(entityNode: person)
        try upsert(entityNode: theme)
        try upsert(entityNode: place)

        let artifactIDs = memory.record.artifactIDs
        let links = artifactIDs.flatMap { artifactID in
            [
                ArtifactEntityLink(artifactID: artifactID, entityID: person.id, confidence: 0.98, source: "debug-fixture", createdAt: now),
                ArtifactEntityLink(artifactID: artifactID, entityID: theme.id, confidence: 0.84, source: "debug-fixture", createdAt: now),
                ArtifactEntityLink(artifactID: artifactID, entityID: place.id, confidence: 0.72, source: "debug-fixture", createdAt: now),
            ]
        }
        try links.forEach { try upsert(artifactEntityLink: $0) }

        let edge = EntityEdge(
            fromEntityID: person.id,
            toEntityID: theme.id,
            relationKind: .mentionedWith,
            weight: 1,
            firstSeenAt: now,
            lastSeenAt: now,
            evidenceCount: 1,
            sourceArtifactIDs: artifactIDs,
            sourceRecordIDs: [memory.record.id]
        )
        try upsert(entityEdge: edge)

        let arc = TemporalArc(
            title: "Quarter Pivot",
            summary: "A small travel disruption surfaced a larger planning transition already forming.",
            status: .accepted,
            dominantTheme: "career planning",
            dominantEntityName: "Linh",
            themeLabels: ["career planning", "transition"],
            entityNames: ["Linh", "Downtown Station"],
            sourceRecordIDs: [memory.record.id],
            sourceArtifactIDs: artifactIDs,
            sourceEntityIDs: [person.id, theme.id, place.id],
            startDate: now.addingTimeInterval(-86_400),
            endDate: now,
            intensityScore: 0.74,
            clusterStrength: 0.68,
            createdAt: now,
            updatedAt: now
        )
        try upsert(temporalArc: arc)

        let reflection = ReflectionSnapshot(
            type: .record,
            title: "Disruption became direction",
            body: "The missed train mattered less than what the slower walk created: space to notice that the quarter plan was already emotionally decided.",
            evidenceSummary: "Grounded in the rain walk capture, the transit disruption, and the planning theme linkage.",
            confidence: 0.81,
            status: .saved,
            linkedTemporalArcID: arc.id,
            sourceRecordIDs: [memory.record.id],
            sourceArtifactIDs: artifactIDs,
            sourceEntityIDs: [person.id, theme.id, place.id],
            createdAt: now,
            savedAt: now
        )
        try upsert(reflection: reflection)

        try save()

        guard let snapshot = try fetchDebugFixtureSnapshot(recordID: memory.record.id) else {
            throw CocoaError(.coderInvalidValue)
        }
        return snapshot
    }

    func fetchDebugFixtureSnapshot(recordID: UUID) throws -> DebugMemoryFixtureSnapshot? {
        guard let record = try fetchRecordShell(id: recordID) else {
            return nil
        }

        let artifacts = try fetchArtifacts(recordID: recordID)
        let analysis = try fetchRecordAnalysis(recordID: recordID)
        let links = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>()).map(\.domainModel)
            .filter { link in artifacts.contains(where: { $0.id == link.artifactID }) }
        let entityIDs = Set(links.map(\.entityID))
        let entities = try modelContext.fetch(FetchDescriptor<EntityNodeStore>()).map(\.domainModel)
            .filter { entityIDs.contains($0.id) }
        let edges = try modelContext.fetch(FetchDescriptor<EntityEdgeStore>()).map(\.domainModel)
            .filter { $0.sourceRecordIDs.contains(recordID) }
        let arcs = try modelContext.fetch(FetchDescriptor<TemporalArcStore>()).map(\.domainModel)
            .filter { $0.sourceRecordIDs.contains(recordID) }
        let reflections = try modelContext.fetch(FetchDescriptor<ReflectionSnapshotStore>()).map(\.domainModel)
            .filter { reflection in
                reflection.sourceRecordIDs.contains(recordID)
                    || arcs.contains(where: { $0.id == reflection.linkedTemporalArcID })
            }

        return DebugMemoryFixtureSnapshot(
            recordID: record.id,
            recordTitle: record.rawText.firstMeaningfulLine ?? "Debug Fixture",
            chain: DebugMemoryChainSnapshot(
                record: record,
                artifacts: artifacts,
                analysis: analysis,
                entities: entities,
                edges: edges,
                links: links,
                arcs: arcs,
                reflections: reflections
            )
        )
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

    func upsert(recordAnalysis: RecordAnalysisSnapshot) throws {
        let descriptor = FetchDescriptor<RecordAnalysisSnapshotStore>(predicate: #Predicate { $0.id == recordAnalysis.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: recordAnalysis)
        } else {
            modelContext.insert(RecordAnalysisSnapshotStore(domainModel: recordAnalysis))
        }
    }

    func upsert(entityNode: EntityNode) throws {
        let descriptor = FetchDescriptor<EntityNodeStore>(predicate: #Predicate { $0.id == entityNode.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: entityNode)
        } else {
            modelContext.insert(EntityNodeStore(domainModel: entityNode))
        }
    }

    func upsert(entityEdge: EntityEdge) throws {
        let descriptor = FetchDescriptor<EntityEdgeStore>(predicate: #Predicate { $0.id == entityEdge.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: entityEdge)
        } else {
            modelContext.insert(EntityEdgeStore(domainModel: entityEdge))
        }
    }

    func upsert(artifactEntityLink: ArtifactEntityLink) throws {
        let descriptor = FetchDescriptor<ArtifactEntityLinkStore>(predicate: #Predicate { $0.id == artifactEntityLink.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: artifactEntityLink)
        } else {
            modelContext.insert(ArtifactEntityLinkStore(domainModel: artifactEntityLink))
        }
    }

    func upsert(temporalArc: TemporalArc) throws {
        let descriptor = FetchDescriptor<TemporalArcStore>(predicate: #Predicate { $0.id == temporalArc.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: temporalArc)
        } else {
            modelContext.insert(TemporalArcStore(domainModel: temporalArc))
        }
    }

    func upsert(reflection: ReflectionSnapshot) throws {
        let descriptor = FetchDescriptor<ReflectionSnapshotStore>(predicate: #Predicate { $0.id == reflection.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: reflection)
        } else {
            modelContext.insert(ReflectionSnapshotStore(domainModel: reflection))
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

    private func buildArtifacts(from draft: MemoryCaptureDraft, recordID: UUID, createdAt: Date) -> [Artifact] {
        let explicitArtifacts = draft.artifacts.map { artifactDraft in
            makeArtifact(from: artifactDraft, fallbackTitle: draft.title, recordID: recordID, createdAt: createdAt)
        }

        if explicitArtifacts.isEmpty {
            return [
                Artifact(
                    recordID: recordID,
                    kind: .text,
                    title: draft.title?.trimmedOrNil ?? draft.rawText.firstMeaningfulLine ?? "Untitled Memory",
                    summary: draft.rawText.trimmedOrNil ?? "Untitled Memory",
                    textContent: draft.rawText.trimmedOrNil ?? "Untitled Memory",
                    payload: .text(draft.rawText.trimmedOrNil ?? "Untitled Memory"),
                    metadata: [:],
                    createdAt: createdAt,
                    updatedAt: createdAt
                )
            ]
        }

        return explicitArtifacts
    }

    private func resolvedRecordRawText(from draft: MemoryCaptureDraft, artifacts: [Artifact]) -> String {
        if let rawText = draft.rawText.trimmedOrNil {
            return rawText
        }

        let artifactSummary = artifacts
            .compactMap { artifact in
                artifact.textContent.trimmedOrNil
                    ?? artifact.summary.trimmedOrNil
                    ?? artifact.title.trimmedOrNil
            }
            .joined(separator: "\n")
            .trimmedOrNil

        return artifactSummary
            ?? draft.artifacts.map(\.captureSummary).joined(separator: "\n").trimmedOrNil
            ?? draft.title?.trimmedOrNil
            ?? "Untitled Memory"
    }

    private func makeArtifact(
        from draft: CaptureArtifactDraft,
        fallbackTitle: String?,
        recordID: UUID,
        createdAt: Date
    ) -> Artifact {
        switch draft {
        case let .text(title, body):
            let resolvedBody = body.trimmedOrNil ?? "Untitled Memory"
            return Artifact(
                recordID: recordID,
                kind: .text,
                title: title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? resolvedBody.firstMeaningfulLine ?? "Untitled Memory",
                summary: resolvedBody,
                textContent: resolvedBody,
                payload: .text(resolvedBody),
                metadata: [:],
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .photo(title, summary, filename):
            let resolvedSummary = summary.trimmedOrNil ?? "Photo capture"
            return Artifact(
                recordID: recordID,
                kind: .photo,
                title: title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? "Photo",
                summary: resolvedSummary,
                textContent: resolvedSummary,
                payload: .media(ArtifactMediaRef(filename: filename, mimeType: "image/jpeg")),
                mediaRef: ArtifactMediaRef(filename: filename, mimeType: "image/jpeg"),
                metadata: [:],
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .audio(title, summary, filename):
            let resolvedSummary = summary.trimmedOrNil ?? "Audio capture"
            return Artifact(
                recordID: recordID,
                kind: .audio,
                title: title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? "Audio",
                summary: resolvedSummary,
                textContent: resolvedSummary,
                payload: .media(ArtifactMediaRef(filename: filename, mimeType: "audio/m4a")),
                mediaRef: ArtifactMediaRef(filename: filename, mimeType: "audio/m4a"),
                metadata: [:],
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .location(title, summary, latitude, longitude):
            let resolvedSummary = summary.trimmedOrNil ?? "Location capture"
            var metadata: [String: String] = [:]
            if let latitude { metadata["latitude"] = String(latitude) }
            if let longitude { metadata["longitude"] = String(longitude) }
            return Artifact(
                recordID: recordID,
                kind: .location,
                title: title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? "Location",
                summary: resolvedSummary,
                textContent: resolvedSummary,
                payload: .metadata(metadata),
                metadata: metadata,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .link(title, url, note):
            let resolvedSummary = note?.trimmedOrNil ?? url
            return Artifact(
                recordID: recordID,
                kind: .link,
                title: title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? url,
                summary: resolvedSummary,
                textContent: resolvedSummary,
                payload: .metadata(["url": url]),
                metadata: ["url": url],
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .todo(title, note):
            let resolvedSummary = note?.trimmedOrNil ?? title
            return Artifact(
                recordID: recordID,
                kind: .note,
                title: title,
                summary: resolvedSummary,
                textContent: resolvedSummary,
                payload: .metadata(["todo": "true"]),
                metadata: ["todo": "true"],
                createdAt: createdAt,
                updatedAt: createdAt
            )
        }
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
