import Foundation
import SwiftData

struct MemorySummary: Identifiable, Hashable, Sendable {
    let record: RecordShell
    let primaryArtifact: Artifact?
    let artifactCount: Int

    var id: UUID { record.id }

    var title: String {
        if let artifactTitle = primaryArtifact?.title.normalizedNonEmpty {
            return artifactTitle
        }
        return record.rawText.firstMeaningfulLine ?? "Untitled Memory"
    }

    var summaryText: String {
        if let artifactSummary = primaryArtifact?.summary.normalizedNonEmpty {
            return artifactSummary
        }
        return record.rawText.normalizedNonEmpty ?? "No summary yet"
    }
}

struct MemoryDetailSnapshot: Hashable, Sendable {
    let record: RecordShell
    let artifacts: [Artifact]
}

@MainActor
final class MoryMemoryRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
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
            return MemorySummary(
                record: record,
                primaryArtifact: preferredPrimaryArtifact(from: artifacts),
                artifactCount: artifacts.count
            )
        }

        guard let limit else { return summaries }
        return Array(summaries.prefix(limit))
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
            artifacts: try fetchArtifacts(recordID: recordID)
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

    func save() throws {
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }

    private func preferredPrimaryArtifact(from artifacts: [Artifact]) -> Artifact? {
        artifacts.first(where: { $0.kind == .text && $0.textContent.normalizedNonEmpty != nil })
            ?? artifacts.first(where: { $0.summary.normalizedNonEmpty != nil })
            ?? artifacts.first
    }
}

private extension String {
    var normalizedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var firstMeaningfulLine: String? {
        split(whereSeparator: { $0.isNewline })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }
}
