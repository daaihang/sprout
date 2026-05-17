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
    func appendArtifacts(recordID: UUID, drafts: [CaptureArtifactDraft]) async throws -> MemorySummary? { fail() }
    func updateMemory(recordID: UUID, draft: MemoryEditDraft) async throws -> MemoryDetailSnapshot? { fail() }
    func deleteMemory(recordID: UUID) throws { let _: Void = fail() }
    func refreshMemoryPipeline(recordID: UUID) async throws { let _: Void = fail() }
    func fetchRecentMemories(limit: Int?) throws -> [MemorySummary] { fail() }
    func fetchMemoryLibrary(filter: MemoryLibraryFilter, limit: Int?) throws -> MemoryLibrarySnapshot { fail() }
    func fetchTimeline(granularity: TimelineGranularity, limit: Int?) throws -> TimelineSnapshot { fail() }
    func fetchHomeBoard(for date: Date, limit: Int) throws -> HomeBoardSnapshot { fail() }
    func fetchHomeBoardDebugSnapshot(for date: Date, limit: Int) throws -> HomeBoardDebugSnapshot { fail() }
    func updateHomeBoardItemPreference(_ item: HomeBoardItemSnapshot, action: HomeBoardPreferenceAction) throws { let _: Void = fail() }
    func fetchMemoryDetail(recordID: UUID) throws -> MemoryDetailSnapshot? { fail() }
    func fetchRecordAnalysis(recordID: UUID) throws -> RecordAnalysisSnapshot? { fail() }
    func fetchPipelineStatus(recordID: UUID) throws -> MemoryPipelineStatusSnapshot? { fail() }
    func fetchPipelineStatusSummaries(limit: Int?) throws -> [PipelineStatusSummary] { fail() }
    func search(query: String, limit: Int?) throws -> SearchSnapshot { fail() }
    func fetchEntityDetails(kind: EntityKind, limit: Int?) throws -> [EntityDetailSnapshot] { fail() }
    func fetchEntityDetail(entityID: UUID) throws -> EntityDetailSnapshot? { fail() }
    func fetchPeopleSummaries(limit: Int?) throws -> [PersonMemorySummary] { fail() }
    func fetchPersonDetail(entityID: UUID) throws -> PersonDetailSnapshot? { fail() }
    func fetchThemeSummaries(limit: Int?) throws -> [ThemeMemorySummary] { fail() }
    func fetchGraphOverview(limitPerKind: Int?, edgeLimit: Int?) throws -> GraphOverviewSnapshot { fail() }
    func fetchInsightsPresentation(limitPerSection: Int?) throws -> InsightsPresentationSnapshot { fail() }
    func fetchTemporalArcs(limit: Int?) throws -> [TemporalArc] { fail() }
    func fetchTemporalArcSummaries(limit: Int?) throws -> [TemporalArcSummarySnapshot] { fail() }
    func fetchTemporalArcDetail(arcID: UUID) throws -> TemporalArcDetailSnapshot? { fail() }
    func acceptTemporalArc(arcID: UUID) async throws { let _: Void = fail() }
    func archiveTemporalArc(arcID: UUID) async throws { let _: Void = fail() }
    func mergeTemporalArc(arcID: UUID) async throws -> TemporalArcDetailSnapshot? { fail() }
    func fetchReflections(limit: Int?) throws -> [ReflectionSnapshot] { fail() }
    func fetchReflectionSummaries(limit: Int?) throws -> [ReflectionSummarySnapshot] { fail() }
    func fetchReflectionDetail(reflectionID: UUID) throws -> ReflectionDetailSnapshot? { fail() }
    func saveReflection(reflectionID: UUID) async throws { let _: Void = fail() }
    func dismissReflection(reflectionID: UUID) async throws { let _: Void = fail() }
    func archiveReflection(reflectionID: UUID) async throws { let _: Void = fail() }
    func fetchDebugDiagnostics(targetType: DebugAnalysisTarget, targetID: UUID?) throws -> DebugDiagnosticsSnapshot { fail() }
    func rerunDebugPipeline(targetType: DebugAnalysisTarget, targetID: UUID?, mode: DebugRebuildMode) async throws { let _: Void = fail() }
    func seedDebugFixtures(count: Int) async throws -> [DebugMemoryFixtureSnapshot] { fail() }
    func clearDebugFixtures() throws { let _: Void = fail() }
    func clearAllLocalData() throws { let _: Void = fail() }
    func fetchUserSettingsPreference() throws -> UserSettingsPreference { fail() }
    func saveUserSettingsPreference(_ preference: UserSettingsPreference) throws { let _: Void = fail() }
    func fetchQualityTuningPreference() throws -> QualityTuningPreference { fail() }
    func saveQualityTuningPreference(_ preference: QualityTuningPreference) throws { let _: Void = fail() }
    func runQualityTuningScenario(_ request: QualityTuningRunRequest) async throws -> QualityTuningRunReport { fail() }
    func seedDebugFixture() async throws -> DebugMemoryFixtureSnapshot { fail() }
    func fetchDebugFixtureSnapshot(recordID: UUID) throws -> DebugMemoryFixtureSnapshot? { fail() }
}
