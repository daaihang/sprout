import Foundation

@MainActor
protocol MemoryCaptureRepositorying {
    func createMemory(from draft: MemoryCaptureDraft) async throws -> MemorySummary
    func applyMemoryMutation(recordID: UUID, mutation: MemoryMutationDraft, refreshPolicy: MemoryMutationRefreshPolicy) async throws -> MemoryMutationResult
    func appendArtifacts(recordID: UUID, drafts: [CaptureArtifactDraft]) async throws -> MemorySummary?
    func updateMemory(recordID: UUID, draft: MemoryEditDraft) async throws -> MemoryDetailSnapshot?
    func deleteMemory(recordID: UUID) throws
    func refreshMemoryPipeline(recordID: UUID) async throws
}

@MainActor
protocol MemoryLibraryRepositorying {
    func fetchRecentMemories(limit: Int?) throws -> [MemorySummary]
    func fetchMemoryLibrary(filter: MemoryLibraryFilter, limit: Int?) throws -> MemoryLibrarySnapshot
    func fetchTimeline(granularity: TimelineGranularity, limit: Int?) throws -> TimelineSnapshot
    func fetchHomeBoard(for date: Date, limit: Int) throws -> HomeBoardSnapshot
    func fetchHomeBoardDebugSnapshot(for date: Date, limit: Int) throws -> HomeBoardDebugSnapshot
    func updateHomeBoardItemPreference(_ item: HomeBoardItemSnapshot, action: HomeBoardPreferenceAction) throws
    func updateHomeBoardItemPreferences(_ updates: [(item: HomeBoardItemSnapshot, action: HomeBoardPreferenceAction)]) throws
    func fetchMemoryDetail(recordID: UUID) throws -> MemoryDetailSnapshot?
    func fetchArtifact(id: UUID) throws -> Artifact?
    func fetchArtifactOriginRepairPreview() throws -> ArtifactOriginRepairPreview
    func backfillMissingArtifactOrigins(_ origin: CaptureArtifactOrigin) throws -> ArtifactOriginRepairResult
    func fetchRecordAnalysis(recordID: UUID) throws -> RecordAnalysisSnapshot?
    func fetchPipelineStatus(recordID: UUID) throws -> MemoryPipelineStatusSnapshot?
    func fetchPipelineStatusSummaries(limit: Int?) throws -> [PipelineStatusSummary]
    func search(query: String, limit: Int?) throws -> SearchSnapshot
    func searchSemanticFirst(query: String, limit: Int?) async throws -> SearchSnapshot
    func rebuildSpotlightIndex() async throws -> SpotlightIndexReport
    func deleteSpotlightIndex() async throws -> SpotlightIndexReport
}

@MainActor
protocol MemoryProfileGraphRepositorying {
    func fetchEntityDetails(kind: EntityKind, limit: Int?) throws -> [EntityDetailSnapshot]
    func fetchEntityDetail(entityID: UUID) throws -> EntityDetailSnapshot?
    func fetchPeopleSummaries(limit: Int?) throws -> [PersonMemorySummary]
    func fetchPersonDetail(entityID: UUID) throws -> PersonDetailSnapshot?
    func fetchThemeSummaries(limit: Int?) throws -> [ThemeMemorySummary]
    func fetchGraphOverview(limitPerKind: Int?, edgeLimit: Int?) throws -> GraphOverviewSnapshot
    func fetchInsightsPresentation(limitPerSection: Int?) throws -> InsightsPresentationSnapshot
    func fetchEntityProfile(entityID: UUID) throws -> EntityProfile?
    func fetchEntityProfiles(kind: EntityKind?, limit: Int?) throws -> [EntityProfile]
    func upsertEntityProfile(_ profile: EntityProfile) throws
    func fetchPersonProfile(entityID: UUID) throws -> PersonProfile?
    func fetchPersonProfiles(limit: Int?) throws -> [PersonProfile]
    func upsertPersonProfile(_ profile: PersonProfile) throws
    func refreshPersonProfile(entityID: UUID, now: Date) throws -> PersonProfile?
    func applyPersonProfileMutation(_ mutation: PersonProfileMutation) throws -> PersonProfile
    func deletePersonProfilePortrait(entityID: UUID) throws -> PersonProfile
    func fetchPlaceProfile(id: UUID) throws -> PlaceProfile?
    func fetchPlaceProfiles(limit: Int?) throws -> [PlaceProfile]
    func upsertPlaceProfile(_ profile: PlaceProfile) throws
    func renamePlaceProfile(id: UUID, displayName: String, aliases: [String]) throws -> PlaceProfile
    func mergePlaceProfiles(primaryID: UUID, mergingIDs: [UUID], displayName: String?) throws -> PlaceProfile
    func splitPlaceProfile(id: UUID, movingArtifactIDs: [UUID], displayName: String) throws -> PlaceProfile
    func fetchPlaceProfileArtifacts(id: UUID) throws -> [Artifact]
    func mergePersonEntities(primaryID: UUID, mergingIDs: [UUID], displayName: String?) throws -> EntityProfile
    func splitPersonEntity(id: UUID, movingRecordIDs: [UUID], displayName: String, aliases: [String]) throws -> EntityProfile
    func fetchCorrectionEvents(kind: CorrectionEventKind?, limit: Int?) throws -> [CorrectionEvent]
    func upsertCorrectionEvent(_ event: CorrectionEvent) throws
    func reverseCorrectionEvent(_ id: UUID, reversedAt: Date) throws
    func fetchEntityTombstones(limit: Int?) throws -> [EntityTombstone]
}

@MainActor
protocol MemoryIntelligenceRepositorying {
    func fetchSelfProfile() throws -> SelfProfile?
    func upsertSelfProfile(_ profile: SelfProfile) throws
    func ensureSelfProfile() throws -> SelfProfile
    func fetchAffectSnapshot(id: UUID) throws -> AffectSnapshot?
    func fetchAffectSnapshots(recordID: UUID?, limit: Int?) throws -> [AffectSnapshot]
    func upsertAffectSnapshot(_ snapshot: AffectSnapshot) throws
    func applyAffectCorrection(_ correction: AffectCorrection) throws -> AffectSnapshot
    func fetchClarificationQuestions(status: ClarificationQuestionStatus?, limit: Int?) throws -> [ClarificationQuestion]
    func upsertClarificationQuestion(_ question: ClarificationQuestion) throws
    func answerClarificationQuestion(_ id: UUID, answer: ClarificationAnswer) throws
    func dismissClarificationQuestion(_ id: UUID) throws
    func fetchIntelligenceJobs(status: IntelligenceJobStatus?, limit: Int?) throws -> [IntelligenceJob]
    func upsertIntelligenceJob(_ job: IntelligenceJob) throws
    func fetchGraphDeltas(applied: Bool?, limit: Int?) throws -> [GraphDelta]
    func upsertGraphDelta(_ delta: GraphDelta) throws
    func markGraphDeltaApplied(_ id: UUID, appliedAt: Date) throws
    func rejectGraphDelta(_ id: UUID, note: String?) throws
    /// Applies a stored GraphDelta's operations to the entity graph (profile + node + optional merge).
    /// Idempotent: does nothing if `delta.appliedAt` is already set.
    func applyGraphDelta(_ id: UUID) throws
    func fetchTemporalArcs(limit: Int?) throws -> [TemporalArc]
    func fetchTemporalArcSummaries(limit: Int?) throws -> [TemporalArcSummarySnapshot]
    func fetchTemporalArcDetail(arcID: UUID) throws -> TemporalArcDetailSnapshot?
    func acceptTemporalArc(arcID: UUID) async throws
    func archiveTemporalArc(arcID: UUID) async throws
    func mergeTemporalArc(arcID: UUID) async throws -> TemporalArcDetailSnapshot?
    func fetchReflections(limit: Int?) throws -> [ReflectionSnapshot]
    func fetchReflectionSummaries(limit: Int?) throws -> [ReflectionSummarySnapshot]
    func fetchReflectionDetail(reflectionID: UUID) throws -> ReflectionDetailSnapshot?
    func saveReflection(reflectionID: UUID) async throws
    func dismissReflection(reflectionID: UUID) async throws
    func archiveReflection(reflectionID: UUID) async throws
    func fetchQualityTuningPreference() throws -> QualityTuningPreference
    func saveQualityTuningPreference(_ preference: QualityTuningPreference) throws
    func runQualityTuningScenario(_ request: QualityTuningRunRequest) async throws -> QualityTuningRunReport
}

@MainActor
protocol MemorySettingsRepositorying {
    func fetchUserSettingsPreference() throws -> UserSettingsPreference
    func saveUserSettingsPreference(_ preference: UserSettingsPreference) throws
    func fetchMemoryDetailPresentationPreference(recordID: UUID) throws -> MemoryDetailPresentationPreference?
    func saveMemoryDetailPresentationPreference(_ preference: MemoryDetailPresentationPreference) throws
    func clearMemoryDetailPresentationPreference(recordID: UUID) throws
    func fetchIntelligencePreferences() throws -> IntelligencePreferences
    func saveIntelligencePreferences(_ preferences: IntelligencePreferences) throws
    func fetchV6FeatureFlags() throws -> V6FeatureFlags
    func saveV6FeatureFlags(_ flags: V6FeatureFlags) throws
}

@MainActor
protocol ExternalCaptureRepositorying {
    func enqueueExternalCapture(_ request: ExternalCaptureRequest, receivedAt: Date) throws -> ExternalCaptureInboxItem
    func enqueueJournalingSuggestion(_ suggestion: JournalingSuggestionDraft, receivedAt: Date) throws -> ExternalCaptureInboxItem
    func fetchExternalCaptureInbox(status: ExternalCaptureInboxStatus?, limit: Int?) throws -> [ExternalCaptureInboxItem]
    func dismissExternalCaptureInboxItem(_ id: UUID) throws
    func markExternalCaptureInboxItemImported(_ id: UUID, recordID: UUID) throws
    func createMemoryFromExternalCaptureInboxItem(_ id: UUID) async throws -> MemorySummary
}

@MainActor
protocol BackgroundOperationRepositorying {
    func fetchBackgroundOperationRuns(status: BackgroundOperationStatus?, limit: Int?) throws -> [BackgroundOperationRun]
    func fetchBackgroundOperationEvents(runID: UUID?, limit: Int?) throws -> [BackgroundOperationEvent]
    func upsertBackgroundOperationRun(_ run: BackgroundOperationRun) throws
    func upsertBackgroundOperationEvent(_ event: BackgroundOperationEvent) throws
}

@MainActor
protocol BackgroundRuntimeRepositorying:
    BackgroundOperationRepositorying {}

@MainActor
protocol MemoryDebugRepositorying {
    func fetchDebugDiagnostics(targetType: DebugAnalysisTarget, targetID: UUID?) throws -> DebugDiagnosticsSnapshot
    func rerunDebugPipeline(targetType: DebugAnalysisTarget, targetID: UUID?, mode: DebugRebuildMode) async throws
    func seedDebugFixtures(count: Int) async throws -> [DebugMemoryFixtureSnapshot]
    func clearDebugFixtures() throws
    func clearAllLocalData() throws
    func seedDebugFixture() async throws -> DebugMemoryFixtureSnapshot
    func fetchDebugFixtureSnapshot(recordID: UUID) throws -> DebugMemoryFixtureSnapshot?
}

@MainActor
protocol AnalysisContextPackRepositorying:
    MemoryLibraryRepositorying,
    MemoryProfileGraphRepositorying,
    MemoryIntelligenceRepositorying,
    MemorySettingsRepositorying {}

@MainActor
protocol NotificationPreparationRepositorying: NotificationIntentRepositorying, NotificationManagementEventRepositorying {
    func fetchIntelligencePreferences() throws -> IntelligencePreferences
    func fetchV6FeatureFlags() throws -> V6FeatureFlags
    func fetchClarificationQuestions(status: ClarificationQuestionStatus?, limit: Int?) throws -> [ClarificationQuestion]
    func fetchRecentMemories(limit: Int?) throws -> [MemorySummary]
    func fetchPipelineStatusSummaries(limit: Int?) throws -> [PipelineStatusSummary]
    func fetchTemporalArcSummaries(limit: Int?) throws -> [TemporalArcSummarySnapshot]
    func fetchReflectionSummaries(limit: Int?) throws -> [ReflectionSummarySnapshot]
    func fetchEntityDetails(kind: EntityKind, limit: Int?) throws -> [EntityDetailSnapshot]
}

@MainActor
protocol DailyQuestionRepositorying: NotificationIntentRepositorying {
    func fetchIntelligencePreferences() throws -> IntelligencePreferences
    func fetchV6FeatureFlags() throws -> V6FeatureFlags
    func fetchClarificationQuestions(status: ClarificationQuestionStatus?, limit: Int?) throws -> [ClarificationQuestion]
    func upsertClarificationQuestion(_ question: ClarificationQuestion) throws
    func fetchRecentMemories(limit: Int?) throws -> [MemorySummary]
}

@MainActor
protocol IntelligenceRecoveryRepositorying: MemorySettingsRepositorying {
    func fetchIntelligenceJobs(status: IntelligenceJobStatus?, limit: Int?) throws -> [IntelligenceJob]
    func upsertIntelligenceJob(_ job: IntelligenceJob) throws
}

@MainActor
protocol IntelligenceJobRepositorying:
    MemoryCaptureRepositorying,
    MemoryLibraryRepositorying,
    MemoryProfileGraphRepositorying,
    MemoryIntelligenceRepositorying,
    MemorySettingsRepositorying,
    DailyQuestionRepositorying,
    NotificationPreparationRepositorying {}

@MainActor
protocol MoryMemoryRepositorying:
    MemoryCaptureRepositorying,
    MemoryLibraryRepositorying,
    MemoryProfileGraphRepositorying,
    MemoryIntelligenceRepositorying,
    MemorySettingsRepositorying,
    ExternalCaptureRepositorying,
    BackgroundOperationRepositorying,
    BackgroundRuntimeRepositorying,
    MemoryDebugRepositorying,
    AnalysisContextPackRepositorying,
    NotificationPreparationRepositorying,
    DailyQuestionRepositorying,
    IntelligenceRecoveryRepositorying,
    IntelligenceJobRepositorying,
    NotificationIntentRepositorying {}

protocol ReflectionAnalysisServing: Sendable {
    func generateReflection(
        record: RecordShell,
        artifacts: [Artifact],
        linkedArcID: UUID?,
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot?
}
