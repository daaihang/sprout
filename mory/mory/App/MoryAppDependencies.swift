import SwiftUI

private struct MemoryRepositoryKey: EnvironmentKey {
    @MainActor
    static let defaultValue: any MoryMemoryRepositorying = MissingMemoryRepository()
}

private struct CloudIntelligenceServiceKey: EnvironmentKey {
    static let defaultValue: any CloudIntelligenceServing = MissingCloudIntelligenceService()
}

private struct RemotePushSyncServiceKey: EnvironmentKey {
    @MainActor
    static let defaultValue: any RemotePushSyncing = MissingRemotePushSyncService()
}

extension EnvironmentValues {
    var memoryRepository: any MoryMemoryRepositorying {
        get { self[MemoryRepositoryKey.self] }
        set { self[MemoryRepositoryKey.self] = newValue }
    }

    var cloudIntelligenceService: any CloudIntelligenceServing {
        get { self[CloudIntelligenceServiceKey.self] }
        set { self[CloudIntelligenceServiceKey.self] = newValue }
    }

    var remotePushSyncService: any RemotePushSyncing {
        get { self[RemotePushSyncServiceKey.self] }
        set { self[RemotePushSyncServiceKey.self] = newValue }
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
    func updateHomeBoardItemPreferences(_ updates: [(item: HomeBoardItemSnapshot, action: HomeBoardPreferenceAction)]) throws { let _: Void = fail() }
    func fetchMemoryDetail(recordID: UUID) throws -> MemoryDetailSnapshot? { fail() }
    func fetchArtifact(id: UUID) throws -> Artifact? { fail() }
    func fetchRecordAnalysis(recordID: UUID) throws -> RecordAnalysisSnapshot? { fail() }
    func fetchPipelineStatus(recordID: UUID) throws -> MemoryPipelineStatusSnapshot? { fail() }
    func fetchPipelineStatusSummaries(limit: Int?) throws -> [PipelineStatusSummary] { fail() }
    func search(query: String, limit: Int?) throws -> SearchSnapshot { fail() }
    func searchSemanticFirst(query: String, limit: Int?) async throws -> SearchSnapshot { fail() }
    func rebuildSpotlightIndex() async throws -> SpotlightIndexReport { fail() }
    func deleteSpotlightIndex() async throws -> SpotlightIndexReport { fail() }
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
    func fetchIntelligencePreferences() throws -> IntelligencePreferences { fail() }
    func saveIntelligencePreferences(_ preferences: IntelligencePreferences) throws { let _: Void = fail() }
    func fetchV6FeatureFlags() throws -> V6FeatureFlags { fail() }
    func saveV6FeatureFlags(_ flags: V6FeatureFlags) throws { let _: Void = fail() }
    func fetchEntityProfile(entityID: UUID) throws -> EntityProfile? { fail() }
    func fetchEntityProfiles(kind: EntityKind?, limit: Int?) throws -> [EntityProfile] { fail() }
    func upsertEntityProfile(_ profile: EntityProfile) throws { let _: Void = fail() }
    func fetchPlaceProfile(id: UUID) throws -> PlaceProfile? { fail() }
    func fetchPlaceProfiles(limit: Int?) throws -> [PlaceProfile] { fail() }
    func upsertPlaceProfile(_ profile: PlaceProfile) throws { let _: Void = fail() }
    func renamePlaceProfile(id: UUID, displayName: String, aliases: [String]) throws -> PlaceProfile { fail() }
    func mergePlaceProfiles(primaryID: UUID, mergingIDs: [UUID], displayName: String?) throws -> PlaceProfile { fail() }
    func splitPlaceProfile(id: UUID, movingArtifactIDs: [UUID], displayName: String) throws -> PlaceProfile { fail() }
    func fetchPlaceProfileArtifacts(id: UUID) throws -> [Artifact] { fail() }
    func fetchClarificationQuestions(status: ClarificationQuestionStatus?, limit: Int?) throws -> [ClarificationQuestion] { fail() }
    func upsertClarificationQuestion(_ question: ClarificationQuestion) throws { let _: Void = fail() }
    func answerClarificationQuestion(_ id: UUID, answer: ClarificationAnswer) throws { let _: Void = fail() }
    func dismissClarificationQuestion(_ id: UUID) throws { let _: Void = fail() }
    func fetchNotificationIntents(status: NotificationIntentStatus?, limit: Int?) throws -> [NotificationIntent] { fail() }
    func upsertNotificationIntent(_ intent: NotificationIntent) throws { let _: Void = fail() }
    func fetchIntelligenceJobs(status: IntelligenceJobStatus?, limit: Int?) throws -> [IntelligenceJob] { fail() }
    func upsertIntelligenceJob(_ job: IntelligenceJob) throws { let _: Void = fail() }
    func fetchGraphDeltas(applied: Bool?, limit: Int?) throws -> [GraphDelta] { fail() }
    func upsertGraphDelta(_ delta: GraphDelta) throws { let _: Void = fail() }
    func markGraphDeltaApplied(_ id: UUID, appliedAt: Date) throws { let _: Void = fail() }
    func fetchQualityTuningPreference() throws -> QualityTuningPreference { fail() }
    func saveQualityTuningPreference(_ preference: QualityTuningPreference) throws { let _: Void = fail() }
    func runQualityTuningScenario(_ request: QualityTuningRunRequest) async throws -> QualityTuningRunReport { fail() }
    func seedDebugFixture() async throws -> DebugMemoryFixtureSnapshot { fail() }
    func fetchDebugFixtureSnapshot(recordID: UUID) throws -> DebugMemoryFixtureSnapshot? { fail() }
}

private struct MissingCloudIntelligenceService: CloudIntelligenceServing {
    private func fail<T>() -> T {
        fatalError("Cloud intelligence dependency was not injected.")
    }

    func refineTranscript(_ payload: MoryAPIClient.TranscriptRefinementPayload) async throws -> MoryAPIClient.TranscriptRefinementResponse { fail() }
    func suggestQuestions(_ payload: MoryAPIClient.QuestionSuggestionPayload) async throws -> MoryAPIClient.QuestionSuggestionResponse { fail() }
    func suggestChapters(_ payload: MoryAPIClient.ChapterSuggestionPayload) async throws -> MoryAPIClient.ChapterSuggestionResponse { fail() }
    func analyzePhotoSemantics(_ payload: MoryAPIClient.PhotoSemanticAnalysisPayload) async throws -> MoryAPIClient.PhotoSemanticAnalysisResponse { fail() }
    func suggestNotificationIntent(_ payload: MoryAPIClient.NotificationIntentSuggestionPayload) async throws -> MoryAPIClient.NotificationIntentSuggestionResponse { fail() }
    func runProviderEval() async throws -> MoryAPIClient.CloudIntelligenceEvalResponse { fail() }
}

@MainActor
private final class MissingRemotePushSyncService: RemotePushSyncing {
    func registerSystemRemoteNotificationsIfNeeded(repository: any MoryMemoryRepositorying) {}
    func syncRegistrationIfPossible(repository: any MoryMemoryRepositorying, force: Bool) async {}
    func enqueueRemoteNotificationIntent(_ intent: NotificationIntent) async throws -> MoryAPIClient.PushEnqueueResponse {
        fatalError("Remote push sync dependency was not injected.")
    }
    func writeBackInteraction(_ event: NotificationInteractionEvent) async {}
    func fetchDebugSnapshot(repository: any MoryMemoryRepositorying) async -> RemotePushDebugSnapshot {
        RemotePushDebugSnapshot(
            deviceID: "",
            timezone: "",
            hasAPNSToken: false,
            apnsTokenPreview: nil,
            hasRegistrationDigest: false,
            pendingWritebackCount: 0,
            pendingIntentCount: 0,
            scheduledIntentCount: 0,
            remoteIntentCount: 0
        )
    }
    func fetchServerMetricsText() async throws -> String {
        fatalError("Remote push sync dependency was not injected.")
    }
}
