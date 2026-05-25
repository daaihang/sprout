import OSLog
import Sentry
import SwiftUI

private let diLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mory", category: "di")

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

private struct NotificationOrchestratorKey: EnvironmentKey {
    @MainActor
    static let defaultValue = NotificationOrchestrator(policy: NotificationPolicy())
}

private struct LocalDataDiagnosticsKey: EnvironmentKey {
    static let defaultValue: MoryLocalDataDiagnostics? = nil
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

    var notificationOrchestrator: NotificationOrchestrator {
        get { self[NotificationOrchestratorKey.self] }
        set { self[NotificationOrchestratorKey.self] = newValue }
    }

    var localDataDiagnostics: MoryLocalDataDiagnostics? {
        get { self[LocalDataDiagnosticsKey.self] }
        set { self[LocalDataDiagnosticsKey.self] = newValue }
    }
}

@MainActor
private final class MissingMemoryRepository: MoryMemoryRepositorying {
    private func fail<T>() -> T {
        let msg = "Memory repository dependency was not injected."
        diLog.critical("\(msg)")
        SentrySDK.capture(error: NSError(domain: "MoryDI", code: -1, userInfo: [NSLocalizedDescriptionKey: msg]))
        fatalError(msg)
    }

    func createMemory(from draft: MemoryCaptureDraft) async throws -> MemorySummary { fail() }
    func applyMemoryMutation(recordID: UUID, mutation: MemoryMutationDraft, refreshPolicy: MemoryMutationRefreshPolicy) async throws -> MemoryMutationResult { fail() }
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
    func fetchArtifactOriginRepairPreview() throws -> ArtifactOriginRepairPreview { fail() }
    func backfillMissingArtifactOrigins(_ origin: CaptureArtifactOrigin) throws -> ArtifactOriginRepairResult { fail() }
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
    func fetchMemoryDetailPresentationPreference(recordID: UUID) throws -> MemoryDetailPresentationPreference? { fail() }
    func saveMemoryDetailPresentationPreference(_ preference: MemoryDetailPresentationPreference) throws { let _: Void = fail() }
    func clearMemoryDetailPresentationPreference(recordID: UUID) throws { let _: Void = fail() }
    func fetchIntelligencePreferences() throws -> IntelligencePreferences { fail() }
    func saveIntelligencePreferences(_ preferences: IntelligencePreferences) throws { let _: Void = fail() }
    func fetchV6FeatureFlags() throws -> V6FeatureFlags { fail() }
    func saveV6FeatureFlags(_ flags: V6FeatureFlags) throws { let _: Void = fail() }
    func fetchSelfProfile() throws -> SelfProfile? { fail() }
    func upsertSelfProfile(_ profile: SelfProfile) throws { let _: Void = fail() }
    func ensureSelfProfile() throws -> SelfProfile { fail() }
    func fetchEntityProfile(entityID: UUID) throws -> EntityProfile? { fail() }
    func fetchEntityProfiles(kind: EntityKind?, limit: Int?) throws -> [EntityProfile] { fail() }
    func upsertEntityProfile(_ profile: EntityProfile) throws { let _: Void = fail() }
    func fetchPersonProfile(entityID: UUID) throws -> PersonProfile? { fail() }
    func fetchPersonProfiles(limit: Int?) throws -> [PersonProfile] { fail() }
    func upsertPersonProfile(_ profile: PersonProfile) throws { let _: Void = fail() }
    func refreshPersonProfile(entityID: UUID, now: Date) throws -> PersonProfile? { fail() }
    func applyPersonProfileMutation(_ mutation: PersonProfileMutation) throws -> PersonProfile { fail() }
    func deletePersonProfilePortrait(entityID: UUID) throws -> PersonProfile { fail() }
    func fetchAffectSnapshot(id: UUID) throws -> AffectSnapshot? { fail() }
    func fetchAffectSnapshots(recordID: UUID?, limit: Int?) throws -> [AffectSnapshot] { fail() }
    func upsertAffectSnapshot(_ snapshot: AffectSnapshot) throws { let _: Void = fail() }
    func applyAffectCorrection(_ correction: AffectCorrection) throws -> AffectSnapshot { fail() }
    func fetchPlaceProfile(id: UUID) throws -> PlaceProfile? { fail() }
    func fetchPlaceProfiles(limit: Int?) throws -> [PlaceProfile] { fail() }
    func upsertPlaceProfile(_ profile: PlaceProfile) throws { let _: Void = fail() }
    func renamePlaceProfile(id: UUID, displayName: String, aliases: [String]) throws -> PlaceProfile { fail() }
    func mergePlaceProfiles(primaryID: UUID, mergingIDs: [UUID], displayName: String?) throws -> PlaceProfile { fail() }
    func splitPlaceProfile(id: UUID, movingArtifactIDs: [UUID], displayName: String) throws -> PlaceProfile { fail() }
    func fetchPlaceProfileArtifacts(id: UUID) throws -> [Artifact] { fail() }
    func mergePersonEntities(primaryID: UUID, mergingIDs: [UUID], displayName: String?) throws -> EntityProfile { fail() }
    func splitPersonEntity(id: UUID, movingRecordIDs: [UUID], displayName: String, aliases: [String]) throws -> EntityProfile { fail() }
    func fetchCorrectionEvents(kind: CorrectionEventKind?, limit: Int?) throws -> [CorrectionEvent] { fail() }
    func upsertCorrectionEvent(_ event: CorrectionEvent) throws { let _: Void = fail() }
    func reverseCorrectionEvent(_ id: UUID, reversedAt: Date) throws { let _: Void = fail() }
    func fetchEntityTombstones(limit: Int?) throws -> [EntityTombstone] { fail() }
    func fetchClarificationQuestions(status: ClarificationQuestionStatus?, limit: Int?) throws -> [ClarificationQuestion] { fail() }
    func upsertClarificationQuestion(_ question: ClarificationQuestion) throws { let _: Void = fail() }
    func answerClarificationQuestion(_ id: UUID, answer: ClarificationAnswer) throws { let _: Void = fail() }
    func dismissClarificationQuestion(_ id: UUID) throws { let _: Void = fail() }
    func fetchNotificationIntents(status: NotificationIntentStatus?, limit: Int?) throws -> [NotificationIntent] { fail() }
    func upsertNotificationIntent(_ intent: NotificationIntent) throws { let _: Void = fail() }
    func fetchNotificationManagementEvents(kind: NotificationManagementEventKind?, limit: Int?) throws -> [NotificationManagementEvent] { fail() }
    func upsertNotificationManagementEvent(_ event: NotificationManagementEvent) throws { let _: Void = fail() }
    func enqueueExternalCapture(_ request: ExternalCaptureRequest, receivedAt: Date) throws -> ExternalCaptureInboxItem { fail() }
    func enqueueJournalingSuggestion(_ suggestion: JournalingSuggestionDraft, receivedAt: Date) throws -> ExternalCaptureInboxItem { fail() }
    func fetchExternalCaptureInbox(status: ExternalCaptureInboxStatus?, limit: Int?) throws -> [ExternalCaptureInboxItem] { fail() }
    func dismissExternalCaptureInboxItem(_ id: UUID) throws { let _: Void = fail() }
    func markExternalCaptureInboxItemImported(_ id: UUID, recordID: UUID) throws { let _: Void = fail() }
    func createMemoryFromExternalCaptureInboxItem(_ id: UUID) async throws -> MemorySummary { fail() }
    func fetchIntelligenceJobs(status: IntelligenceJobStatus?, limit: Int?) throws -> [IntelligenceJob] { fail() }
    func upsertIntelligenceJob(_ job: IntelligenceJob) throws { let _: Void = fail() }
    func fetchGraphDeltas(applied: Bool?, limit: Int?) throws -> [GraphDelta] { fail() }
    func upsertGraphDelta(_ delta: GraphDelta) throws { let _: Void = fail() }
    func markGraphDeltaApplied(_ id: UUID, appliedAt: Date) throws { let _: Void = fail() }
    func rejectGraphDelta(_ id: UUID, note: String?) throws { let _: Void = fail() }
    func applyGraphDelta(_ id: UUID) throws { let _: Void = fail() }
    func fetchQualityTuningPreference() throws -> QualityTuningPreference { fail() }
    func saveQualityTuningPreference(_ preference: QualityTuningPreference) throws { let _: Void = fail() }
    func runQualityTuningScenario(_ request: QualityTuningRunRequest) async throws -> QualityTuningRunReport { fail() }
    func seedDebugFixture() async throws -> DebugMemoryFixtureSnapshot { fail() }
    func fetchDebugFixtureSnapshot(recordID: UUID) throws -> DebugMemoryFixtureSnapshot? { fail() }
}

private struct MissingCloudIntelligenceService: CloudIntelligenceServing {
    private func fail<T>() -> T {
        let msg = "Cloud intelligence dependency was not injected."
        diLog.critical("\(msg)")
        SentrySDK.capture(error: NSError(domain: "MoryDI", code: -2, userInfo: [NSLocalizedDescriptionKey: msg]))
        fatalError(msg)
    }

    func refineTranscript(_ payload: MoryAPIClient.TranscriptRefinementPayload) async throws -> MoryAPIClient.TranscriptRefinementResponse { fail() }
    func suggestQuestions(_ payload: MoryAPIClient.QuestionSuggestionPayload) async throws -> MoryAPIClient.QuestionSuggestionResponse { fail() }
    func suggestChapters(_ payload: MoryAPIClient.ChapterSuggestionPayload) async throws -> MoryAPIClient.ChapterSuggestionResponse { fail() }
    func analyzePhotoSemantics(_ payload: MoryAPIClient.PhotoSemanticAnalysisPayload) async throws -> MoryAPIClient.PhotoSemanticAnalysisResponse { fail() }
    func runProviderEval() async throws -> MoryAPIClient.CloudIntelligenceEvalResponse { fail() }
}

@MainActor
private final class MissingRemotePushSyncService: RemotePushSyncing {
    func registerSystemRemoteNotificationsIfNeeded(repository: any MoryMemoryRepositorying) {}
    func syncRegistrationIfPossible(repository: any MoryMemoryRepositorying, force: Bool) async {}
    func enqueueRemoteNotificationIntent(_ intent: NotificationIntent) async throws -> MoryAPIClient.PushEnqueueResponse {
        let msg = "Remote push sync dependency was not injected."
        diLog.critical("\(msg)")
        SentrySDK.capture(error: NSError(domain: "MoryDI", code: -3, userInfo: [NSLocalizedDescriptionKey: msg]))
        fatalError(msg)
    }
    func writeBackInteraction(_ event: NotificationInteractionEvent) async {}
    func fetchDebugSnapshot(repository: any MoryMemoryRepositorying) async -> RemotePushDebugSnapshot {
        RemotePushDebugSnapshot(
            ownerID: nil,
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
        let msg = "Remote push sync dependency was not injected."
        diLog.critical("\(msg)")
        SentrySDK.capture(error: NSError(domain: "MoryDI", code: -3, userInfo: [NSLocalizedDescriptionKey: msg]))
        fatalError(msg)
    }
    func prepareForLocalDataOwner(_ ownerID: String) {}
}
