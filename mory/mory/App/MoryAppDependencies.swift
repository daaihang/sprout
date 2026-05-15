import SwiftUI

private struct MemoryRepositoryKey: EnvironmentKey {
    @MainActor
    static let defaultValue: any MoryMemoryRepositorying = MissingMemoryRepository()
}

extension EnvironmentValues {
    var memoryRepository: any MoryMemoryRepositorying {
        get { self[MemoryRepositoryKey.self] }
        set { self[MemoryRepositoryKey.self] = newValue }
    }
}

@MainActor
private final class MissingMemoryRepository: MoryMemoryRepositorying {
    private func fail<T>() -> T {
        fatalError("Memory repository dependency was not injected.")
    }

    func createMemory(from draft: MemoryCaptureDraft) async throws -> MemorySummary { fail() }
    func refreshMemoryPipeline(recordID: UUID) async throws { let _: Void = fail() }
    func fetchRecentMemories(limit: Int?) throws -> [MemorySummary] { fail() }
    func fetchHomeBoard(for date: Date, limit: Int) throws -> HomeBoardSnapshot { fail() }
    func fetchMemoryDetail(recordID: UUID) throws -> MemoryDetailSnapshot? { fail() }
    func fetchRecordAnalysis(recordID: UUID) throws -> RecordAnalysisSnapshot? { fail() }
    func fetchPipelineStatus(recordID: UUID) throws -> MemoryPipelineStatusSnapshot? { fail() }
    func fetchPipelineStatusSummaries(limit: Int?) throws -> [PipelineStatusSummary] { fail() }
    func search(query: String, limit: Int?) throws -> SearchSnapshot { fail() }
    func fetchEntityDetails(kind: EntityKind, limit: Int?) throws -> [EntityDetailSnapshot] { fail() }
    func fetchEntityDetail(entityID: UUID) throws -> EntityDetailSnapshot? { fail() }
    func fetchPeopleSummaries(limit: Int?) throws -> [PersonMemorySummary] { fail() }
    func fetchThemeSummaries(limit: Int?) throws -> [ThemeMemorySummary] { fail() }
    func fetchGraphOverview(limitPerKind: Int?, edgeLimit: Int?) throws -> GraphOverviewSnapshot { fail() }
    func fetchTemporalArcs(limit: Int?) throws -> [TemporalArc] { fail() }
    func fetchTemporalArcSummaries(limit: Int?) throws -> [TemporalArcSummarySnapshot] { fail() }
    func fetchReflections(limit: Int?) throws -> [ReflectionSnapshot] { fail() }
    func fetchReflectionSummaries(limit: Int?) throws -> [ReflectionSummarySnapshot] { fail() }
    func seedDebugFixture() async throws -> DebugMemoryFixtureSnapshot { fail() }
    func fetchDebugFixtureSnapshot(recordID: UUID) throws -> DebugMemoryFixtureSnapshot? { fail() }
}
