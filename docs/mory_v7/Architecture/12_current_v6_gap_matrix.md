# 12. Current v6 Gap Matrix

## 1. Purpose

This document maps the current v6 code and docs into v7 implementation gaps. It exists so v7 work does not drift into vague “smarter AI” language.

## 2. AI Analyze Context

| Current | Impact | v7 fix |
| --- | --- | --- |
| Analyze request is centered on `record_shell`, artifacts, and known entities | model sees the current memory more than the user's life history | `AnalysisContextPack` |
| known entities are capped and lightweight | people are names, not relationship profiles | `KnownProfileBrief` and `PersonProfile` |
| artifacts can be compacted before Analyze | weak evidence makes prompt conservative | source-aware snippets and budget report |
| profile answers are persisted locally but not sent next time | user correction does not strongly personalize future analysis | correction signals in context pack |
| Arc/Reflection are post-processing | model cannot reason from prior arcs while analyzing new record | related arc/reflection briefs |
| semantic search is user-facing | similar memories are not automatically recalled for analysis | pre-Analyze retrieval |

Relevant code:

- `mory/mory/Infrastructure/Analysis/Pipeline/AnalysisRecordPayloadBuilder.swift`
- `mory/mory/Infrastructure/Analysis/Pipeline/AnalysisExecutor.swift`
- `mory/mory/Persistence/Repositories/MoryMemoryRepository.swift`
- `server/internal/ai/types.go`

## 3. Identity And Entity Lifecycle

| Current | Impact | v7 fix |
| --- | --- | --- |
| graph entity reuse is mostly name/alias equality | same-name and alias ambiguity persist | `EntityResolutionService` |
| person merge/split is not first-class | wrong people cannot be repaired cleanly | GraphDelta v2 merge/split |
| place has more management than people | relationship memory is weaker than place memory | person profile management path |
| no dedicated self profile | “我/自己/我的...” does not anchor analysis | `SelfProfile` |
| role labels can become entities | “舍友” can be wrong as one person | role label + ambiguous bucket |
| no negative merge evidence | rejected mistakes can recur | `CorrectionEvent.notSameEntity` |

Relevant code:

- `mory/mory/Infrastructure/Analysis/Graph/GraphUpdater.swift`
- `mory/mory/Domain/Intelligence/IntelligenceModels.swift`
- `mory/mory/Infrastructure/Intelligence/GraphDeltaApplier.swift`
- `mory/mory/Features/Settings/PlaceProfileManagementView.swift`

## 4. Person Profile

| Current | Impact | v7 fix |
| --- | --- | --- |
| `EntityProfile` has basic aliases/relationship/counts | not enough for long-term relationship insight | `PersonProfile` |
| enrichment is deterministic aggregation | no profile portrait or relationship trajectory | portrait refresh job |
| no field-level evidence UI | hard to trust or correct AI profile | profile field evidence |
| user edits can be overwritten by derived updates | correction trust is weak | freeze/revoke/edit policy |

Relevant code:

- `mory/mory/Domain/Intelligence/IntelligenceModels.swift`
- `mory/mory/Infrastructure/Intelligence/EntityEnrichmentService.swift`

## 5. Mood And Tone

| Current | Impact | v7 fix |
| --- | --- | --- |
| capture mood is free text | cannot trend reliably | `AffectSnapshot.valence/arousal/dominance` |
| AI emotion is label/intensity/confidence | cannot represent multiple simultaneous feelings | labels + vector |
| tone is not first-class | joking vs real irritation is fragile | tone hints + appraisal |
| no affect correction event | mistakes do not train local personalization | `AffectCorrectionEvent` |
| no Journaling Suggestions mood source | missing user-recorded system mood evidence | `journalSuggestionStateOfMind` |

Relevant code:

- `mory/mory/Domain/Memory/RecordShell.swift`
- `mory/mory/Infrastructure/Analysis/Pipeline/RecordAnalysisSnapshotMapper.swift`

## 6. Questions And Feedback

| Current | Impact | v7 fix |
| --- | --- | --- |
| question enum is broader than writeback effects | product promise exceeds current mutation logic | `QuestionAnswerEffects` |
| freeform mainly for alias | many questions cannot capture real user answer | freeform all question types |
| no complete lifecycle/cooldown model | stale or repeated questions possible | `QuestionLifecycle` |
| answers do not strongly shape Analyze context | feedback loop remains shallow | correction signals and profile briefs |

Relevant code:

- `mory/mory/Infrastructure/Intelligence/ClarificationQuestionBuilder.swift`
- `mory/mory/Features/Intelligence/ClarificationQuestionCard.swift`
- `mory/mory/Infrastructure/Intelligence/GraphDeltaApplier.swift`

## 7. Background And Notifications

| Gap | Status | Resolution |
| --- | --- | --- |
| launch/home recovery is primary; BGTask missing | ✅ resolved | `BackgroundTaskCoordinator` registers `BGProcessingTask` + `BGAppRefreshTask`; `MoryAppDelegate` handles expiry callbacks |
| no background URLSession pipeline | ✅ resolved | `BackgroundURLSessionInfrastructure` provides `BackgroundURLSessionCompletionStore`, `BackgroundURLSessionDelegate`, `MoryAPIClient.backgroundSession` |
| APNs not fully connected to proactive intent production | ✅ resolved | `NotificationDeliveryRouter` routes intents to remote (APNS) or local channel through the Push domain `PushNotificationEnqueuing` port |
| local notifications exist; no unified local/remote router | ✅ resolved | `NotificationDeliveryRouter` upserts intent + routes to the Push enqueuer or `LocalNotificationScheduler` |
| daily question weak outside foreground | ✅ resolved | `BGAppRefreshTask` and foreground refresh enter `BackgroundOperationOrchestrator`, which prepares daily questions when cloud intelligence is available |

Relevant code:

- `mory/mory/Infrastructure/Background/BackgroundOperationOrchestrator.swift`
- `mory/mory/Infrastructure/Background/BackgroundTaskCoordinator.swift`
- `mory/mory/Infrastructure/Background/BackgroundURLSessionInfrastructure.swift`
- `mory/mory/Infrastructure/Intelligence/Jobs/IntelligenceJobWorker.swift`
- `mory/mory/Infrastructure/Intelligence/Jobs/IntelligenceJobRecoveryService.swift`
- `mory/mory/Infrastructure/Notifications/NotificationDeliveryRouter.swift`
- `mory/mory/Infrastructure/Push/RemotePushSyncService.swift`
- `mory/mory/App/MoryAppDelegate.swift`

## 8. Multimodal Context

| Current | Impact | v7 fix |
| --- | --- | --- |
| location/weather/music capture exists | useful but not enough for long-term reasoning | context evidence source registry |
| photo analysis is compact | visual evidence may be too thin | richer evidence + provenance |
| speech failure can remove voice evidence | mood/tone quality drops | explicit uncertainty/failure evidence |
| Journaling Suggestions real picker absent | missing system-curated context until entitlement is granted | ✅ resolved by entitlement, device picker adapter, and V2 Journaling evidence mapping |
| Share extension target not built | app-external capture still lacks full system share surface | ✅ resolved by Share Extension handoff-first confirmation flow + V2 App Group handoff store |

Relevant code:

- `mory/mory/Infrastructure/Context/ContextAutoCollector.swift`
- `mory/mory/Infrastructure/Analysis/Artifacts/PhotoArtifactProcessor.swift`
- `mory/mory/Infrastructure/Analysis/Artifacts/AudioTranscriptionService.swift`

## 9. Evaluation

| Current | Impact | v7 fix |
| --- | --- | --- |
| prompt tuning can become subjective | hard to know if personalization improved | golden fixtures |
| no identity quality metrics | wrong merges can hide | merge precision/error rate |
| no context pack hit/noise metrics | retrieval may add irrelevant context | context pack eval |
| notification feedback is not enough | retention tuning can become spammy | interaction writeback metrics |

## 10. v7 Priority Order

1. `SelfProfile` and `AnalysisContextPack`.
2. `EntityResolutionService` and `CorrectionEvent`.
3. Person merge/split and GraphDelta v2.
4. `PersonProfile` + portrait job.
5. `AffectSnapshot` and tone correction.
6. Analysis cloud contract.
7. BGTask/background URLSession/APNs orchestration.
8. Eval/debug/privacy audit.

## 11. v7 Completion Status

The gaps above were the implementation source of truth for v7. As of v7 foundation completion:

| Area | Status | Boundary |
| --- | --- | --- |
| Self profile and context pack | ✅ complete | consumed by the production Analysis path for new memories |
| Entity resolution and correction | ✅ complete | user-facing UI polish remains later |
| Person merge/split and portrait jobs | ✅ complete | cloud AI portrait proposals remain later |
| Structured affect and tone correction | ✅ complete | Journaling `StateOfMind` is mapped as affect evidence; real-device validation remains later |
| External capture inbox | ✅ complete | Share Extension writes V2-only pending drafts; App Intent phrase validation remains later |
| Analysis contract | ✅ complete | production new-memory pipeline uses `/api/analyze`; old versioned and preview Analyze routes are no longer registered |
| BGTask/background URLSession/APNs routing | ✅ complete | real-device soak and telemetry remain later |
| Runtime debug orchestration | ✅ complete | Debug has one `DebugRuntimeOperationsView`; it triggers formal orchestrators and no longer directly mutates jobs or GraphDeltas |
| Eval/debug/privacy gate | ✅ complete | real-user notification quality dashboard and public release privacy audit remain post-v7 production hardening |
