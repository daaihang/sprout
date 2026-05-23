# 11. Phase Implementation Backlog

## Phase 0: Documentation And Gap Matrix

Goal:

- align v7 target with current v6 code truth,
- document architecture before UI work.

Deliverables:

- v7 README/PRD/Architecture docs,
- current gap matrix,
- Phase backlog,
- acceptance criteria.

Exit criteria:

- docs cover identity, retrieval, correction, mood, background, notifications, cloud contracts, mutation, recompute, eval.

Completion evidence:

- v7 README, PRD docs, and Architecture docs exist under `docs/mory_v7/`.
- current v6 gap matrix exists in `12_current_v6_gap_matrix.md`.
- phase backlog exists in this document.
- acceptance and test matrix exists in `19_testing_acceptance_matrix.md`.
- identity, retrieval, correction, mood, background, notifications, cloud contracts, graph mutation, recompute, privacy, and eval are covered by dedicated v7 docs.
- Phase 1 is the first runtime implementation phase; Phase 0 intentionally does not add `SelfProfile`, `AnalysisContextPack`, or other runtime business models.

## Phase 1: SelfProfile + AnalysisContextPack Skeleton

Goal:

- add the long-term context spine without changing final UI.

Deliverables:

- `SelfProfile` model,
- `SelfReferenceResolver`,
- `AnalysisContextPack`,
- `ContextPackBuilder`,
- `ContextRanker`,
- `ContextBudgeter`,
- `PrivacyGate`,
- debug context pack viewer.

Tests:

- self-reference,
- context ranking,
- privacy drops,
- semantic-search-disabled fallback,
- no full-history payload.

Completion evidence:

- `SelfProfile` domain model and SwiftData-backed `SelfProfileStore` are implemented locally.
- repository APIs can fetch, upsert, and create the default self profile.
- `SelfReferenceResolver`, `AnalysisContextPack`, `ContextPackBuilder`, `ContextRanker`, `ContextBudgeter`, and `PrivacyGate` are implemented as Phase 1 local runtime services.
- Debug Center includes an `Analysis Context Pack` viewer for latest-memory pack inspection.
- Phase 1 tests cover self-reference, repository roundtrip, ranking, privacy drop, semantic-disabled fallback, and budget cap behavior.
- Analyze payload and cloud contracts remained unchanged in Phase 1; the context pack became inspectable locally first and is consumed by production Analyze v7 as of Phase 5 production replacement.

## Phase 2: Entity Resolution + GraphDelta v2

Goal:

- make identity corrections durable.

Deliverables:

- `EntityResolutionService`,
- `CorrectionEvent`,
- merge/split proposals,
- person merge/split repository mutation,
- tombstones,
- mutation ledger.

Tests:

- same person candidate,
- not-same negative evidence,
- role label bucket,
- merge rewrite,
- split rewrite,
- undo/recompute.

Completion evidence:

- `CorrectionEvent` and `EntityTombstone` are implemented as persisted domain data with SwiftData stores and mappers.
- `DefaultEntityResolutionService` is implemented with same-person candidate detection, not-same correction blocking, and role-label ambiguous buckets.
- repository-level person mutations (`mergePersonEntities`, `splitPersonEntity`) are implemented and rewrite links/edges/arcs/reflections/question targets/home signals.
- merge writes tombstones and reversible correction events; split writes reversible correction events.
- mutation flow schedules bounded recompute jobs (`entityEnrichment`, `chapterCandidate`) for affected entities/records.
- `GraphDeltaApplier` supports `.entityMerge` operation generation from clarification answers.
- tests cover same-person candidate, not-same blocking, role-label buckets, merge rewrite, split rewrite, and recompute job scheduling.

## Phase 3: PersonProfile + Portrait Jobs

Goal:

- turn people from flat entities into evidence-backed profiles.

Deliverables:

- `PersonProfile`,
- `PersonPortrait`,
- profile field evidence,
- portrait refresh job,
- user edit/freeze/revoke actions,
- profile diff viewer.

Tests:

- profile refresh after new memory,
- correction prevents overwritten user edit,
- source deletion invalidates field,
- sensitive field excluded from cloud.

Completion evidence:

- `PersonProfile`, `PersonPortrait`, `RelationshipChange`, `PersonAffectPattern`, and `ProfileFieldEvidence` are implemented as local v7 domain models.
- `PersonProfileStore` is registered in the SwiftData schema with mapper support and repository APIs for fetch/upsert/refresh/mutation/delete portrait.
- `.personProfileRefresh` jobs are scheduled after analysis, executed by `IntelligenceJobWorker`, and enqueued after person merge/split recompute events.
- repository refresh builds deterministic, evidence-backed local portraits from entity profiles, related records, common context labels, related places/themes/decisions, and existing user-confirmed fields.
- user-confirmed relationship edits survive later refreshes; profile field updates write `CorrectionEvent.kind.profileFieldUpdated`.
- deleting source memories invalidates stale person profile evidence and removes profiles that no longer have sources unless the user has explicitly retained or edited them.
- Debug Center includes a data-only `Person Profiles` inspector with refresh and cloud-safe brief inspection.
- sensitive and cloud-hidden profiles are redacted by `PersonProfileContextBrief` before future cloud context usage.
- Cloud AI portrait proposals and formal polished profile UI remain outside Phase 3; Analyze v7 payload consumption is implemented in Phase 5.

## Phase 4: Structured Mood + Context Sources

Goal:

- replace thin mood with structured affect and stronger context sources.

Deliverables:

- `AffectSnapshot`,
- VAD/PAD mapper,
- tone hints,
- appraisal,
- affect correction events,
- Journaling Suggestions service,
- App Intent/Share capture drafts.

Tests:

- joking vs irritated fixtures,
- user correction updates future context,
- Journaling `StateOfMind` maps as evidence,
- fallback when entitlement/OS is unavailable.

Completion evidence:

- `AffectSnapshot`, `AffectAppraisal`, `AffectEvidence`, `AffectSnapshotDraft`, and `AffectCorrection` are implemented as local v7 domain models.
- `AffectSnapshotStore` is registered in the SwiftData schema with mapper support and repository APIs for fetch/upsert/correction.
- new memories persist structured affect from explicit drafts or from legacy `MemoryCaptureDraft.mood` fallback.
- mood edits replace the user-freeform affect snapshot so legacy capture and structured affect stay aligned.
- affect corrections write `CorrectionEvent.kind.affectCorrection`, mark snapshots as user-confirmed, and update the self profile expression-pattern signal.
- `AnalysisContextPackBuilder` now prefers structured affect history and falls back to legacy mood text when no snapshot exists.
- `JournalingSuggestionContextService` converts user-selected suggestion drafts into normal memory capture drafts and maps `StateOfMind` as affect evidence.
- Debug Center includes a data-only `Affect Snapshots` inspector for persisted affect, correction events, and Journaling Suggestions fallback state.
- Apple Journaling Suggestions entitlement, real system picker UI, App Intents, and Share extension remain outside Phase 4 and continue as post-v7 product/platform work. Cloud Analyze consumption is implemented in Phase 5.

## Phase 5: Analyze v7 Contract + Context-Aware Reflection

Goal:

- connect context pack to cloud AI safely.

Deliverables:

- `/api/analyze/v7`,
- v7 request/response models,
- proposal-first response mapper,
- context-aware reflection/proposal contract,
- production v7 request/response debug traces.

Tests:

- production cutover away from legacy Analyze,
- proposal mapping,
- low-context uncertainty flags,
- privacy redaction in payload,
- reflection evidence coverage.

Completion evidence:

- iOS has `AnalyzeV7RequestPayload`, `AnalyzeV7ResponseEnvelope`, and `AnalyzeV7ResponseMapper` for bounded context-pack and structured mood transport.
- iOS new-memory analysis builds an `AnalysisContextPack`, sends `/api/analyze/v7`, treats the mapped v7 analysis as authoritative, and no longer calls legacy `analysisService.analyze(...)` in the production pipeline.
- Server exposes `/api/analyze/v7`, validates schema version 7, forwards context evidence into a provider-native v7 prompt/parser path, and returns analysis plus proposal-first v7 output.
- v7 proposals are persisted locally through policy/staging boundaries: affect snapshots, graph deltas, arc candidates, reflection candidates, and question candidates.
- v7 quality flags identify thin context, insufficient longitudinal evidence, privacy redaction, missing structured mood evidence, and tone checks.
- Contract tests cover request payload privacy/budget contents, proposal mapping, low-context decode behavior, and server route metadata.

## Phase 6: Background And Notification Reliability

Goal:

- reduce “open app first” dependency.

Deliverables:

- BGTask registration,
- BGAppRefresh daily question path,
- BGProcessing recompute path,
- background URLSession for deferred network,
- APNs ready-intent path,
- unified local/remote notification router,
- notification trace debug.

Tests:

- scheduled task handler smoke,
- launch recovery fallback,
- quiet hours/max-per-day policy,
- sensitive preview suppression,
- remote push writeback.

Completion evidence:

- `BackgroundTaskCoordinator` registers `BGProcessingTask` (ID: `dev.mory.intelligence.process`) and `BGAppRefreshTask` (ID: `dev.mory.intelligence.refresh`) before first runloop via `MoryAppDelegate`.
- `NotificationDeliveryRouter` routes `NotificationIntent` to `.local` or `.remote` channel based on APNS token presence in `PushDeviceRegistrationStore`.
- `BackgroundURLSessionInfrastructure` provides `BackgroundURLSessionCompletionStore`, `BackgroundURLSessionDelegate`, and a `MoryAPIClient.backgroundSession` static lazy property.
- `MoryAppDelegate` handles silent push `didReceiveRemoteNotification` and `handleEventsForBackgroundURLSession` callbacks.
- `Info.plist` includes `UIBackgroundModes: [fetch, processing]` and `BGTaskSchedulerPermittedIdentifiers` with both task IDs.
- Tests: `BackgroundTaskCoordinatorTests` (4 tests: nil-before-configure, configure stores repo, scheduleIfNeeded no-crash, reconfigure) and `NotificationDeliveryRouterTests` (2 tests: local channel when no token, remote channel when token present).

## Phase 7: Eval, Hardening, And Release Gate

Goal:

- make long-term intelligence measurable before broad release.

Deliverables:

- golden fixtures,
- identity eval,
- context pack eval,
- affect eval,
- notification quality dashboard,
- privacy audit,
- migration plan.

Exit criteria:

- user correction recurrence can be measured,
- wrong merge can be recovered,
- debug surfaces explain AI outputs,
- docs and code status match.

Completion evidence:

- `MoryV7EvalTests` covers sparse first-day context pack construction, GraphDelta apply/idempotence, person merge recovery, and affect correction appearing in future context pack affect history.
- `AnalysisContextPackTests`, `EntityResolutionServiceTests`, and `AffectSnapshotTests` cover context ranking/budget/privacy, self-reference CJK edge cases, not-same blocking, Chinese name matching, and note-less affect correction.
- `DebugAnalysisContextPackView`, `DebugAffectSnapshotView`, `DebugClarificationQuestionsView`, and Debug Center actions expose context payloads, affect snapshots, clarification answers/dismissal, pending GraphDelta application, BGTask scheduling, and notification traces for development inspection.
- `NotificationDeliveryRouterTests`, `LocalNotificationSchedulerTests`, `NotificationIntentPreparationServiceTests`, `NotificationInteractionServiceTests`, and `BackgroundTaskCoordinatorTests` cover local/APNs routing, policy, writeback, and BGTask scheduling boundaries.
- Privacy gates remain local-first: context packs are budgeted, sensitive records can be redacted/dropped, Analyze v7 is proposal-based, and AI output does not directly mutate trusted graph state.
- Native product wiring exists (without visual polish): `GraphDeltaReviewView`, `MemoryIntelligenceSettingsView`, `PersonProfileEditView`, `PersonMergeSplitView`, `StructuredMoodPickerSheet`, `JournalingSuggestionImportView`, and `ExternalCaptureDraftReviewView` are connected from Insights, Settings, People, Capture, and Debug entries.
- External capture now has a durable pending inbox: App Intent, Share, and Journaling-originated drafts can be queued as `ExternalCaptureInboxItem`, inspected from Settings/Debug, and imported through the normal memory creation path.
- v7 documentation now separates the completed architecture/debug/test baseline from post-v7 production release hardening.

## v7.1 Stabilization

Goal:

- stabilize the production Analyze v7 graph pipeline before adding new platform surfaces.

Completion evidence:

- `ArchitecturePipelineExecutor` now merges `GraphUpdater` analysis output with `PlaceProfileResolver` output before persistence.
- the production pipeline persists the complete graph view: `EntityNode`, `EntityEdge`, and `ArtifactEntityLink` from both analysis and place resolution.
- local temporal arc/reflection candidate building and promotion use the same complete graph view, so people/themes/decisions from text-only analysis are not dropped when no location artifact exists.
- `MoryMemoryRepositoryCompositionTests` now inject v7 cloud stubs by default, preserving hard cutover coverage instead of relying on legacy `RecordAnalysisServing`.
- regression coverage verifies text-only v7 analysis persists non-place entities, analysis links, and graph edges.

## Overall Phase Status

| Phase | Current status | Gap |
| --- | --- | --- |
| Phase 0 | completed | docs/gap matrix completed; implementation starts at Phase 1 |
| Phase 1 | completed | local SelfProfile persistence and inspectable context pack skeleton are implemented; production Analyze v7 consumes the context pack as of Phase 5 |
| Phase 2 | completed | entity resolution foundation, correction ledger, and person merge/split mutation are implemented; proposal consumption and cloud-context integration continue in Phase 5 |
| Phase 3 | completed | local PersonProfile persistence, deterministic portrait refresh jobs, mutation actions, evidence invalidation, and debug inspection are implemented; cloud AI portrait proposals remain Phase 5 |
| Phase 4 | completed | local structured affect persistence, correction events, context-pack affect history, Journaling draft mapping, and external capture inbox are implemented; real Apple picker entitlement and Share Extension paths are implemented as v7.2 platform work |
| Phase 5 | completed | production new-memory analysis is hard-cut over to Analyze v7 with context pack payloads, native server proposal output, local proposal persistence, and no legacy Analyze fallback |
| Phase 6 | completed | BGTask (BGProcessingTask + BGAppRefreshTask) + BackgroundURLSession + NotificationDeliveryRouter + silent push handler implemented; tests in BackgroundTaskCoordinatorTests + NotificationDeliveryRouterTests |
| Phase 7 | completed | eval fixtures, debug surfaces, privacy/budget gates, graph-delta apply inspection, clarification question inspection, BGTask/router tests, affect correction eval, and docs/code status reconciliation are complete; real-user telemetry and public release privacy review are post-v7 production hardening |
| v7.1 Stabilization | completed | production graph persistence and composition test baseline are stabilized; new platform capabilities remain post-v7 hardening |
| v7.2 Platform Context + Correction UX | completed | Journaling Suggestions entitlement/device picker adapter, Share Extension external inbox writing, App Shortcut phrase expansion, and GraphDelta reject/undo correction ledger are implemented; real-device validation remains production hardening |
| v7.3 Device Validation + Platform QA | completed | platform capture diagnostics and manual validation checklist are implemented in Settings/Debug; physical-device execution remains release hardening |

## Post-v7 Production Hardening

These items are intentionally outside the v7 foundation completion gate:

- run real-device APNs and background execution soak tests,
- add real-user notification quality telemetry once there are users,
- complete public release privacy review and App Store capability checks,
- execute the in-app Platform Capture Diagnostics checklist for Apple Journaling Suggestions picker, App Intent phrases, and Share Extension handoff on a physical device with developer capabilities enabled,
- polish user-facing UI for merge/split, correction, mood, notification controls, and external capture review.

## v7.2 Platform Context + Correction UX

Goal: move the first post-v7 platform feature into the real app path without creating new memory types.

Completion evidence:

- `com.apple.developer.journal.allow` is present in the app entitlements.
- The local iPhoneOS SDK symbols were checked before implementation: `JournalingSuggestionsPicker`, `JournalingSuggestion.content(forType:)`, `Location`, `Song`, `Workout`, `StateOfMind`, `Reflection`, and iOS 26 `EventPoster`.
- `AppleJournalingSuggestionAdapter` maps Apple-selected suggestions into existing `JournalingSuggestionDraft`, then into `MemoryCaptureDraft` with artifacts and `AffectSnapshot` evidence.
- Simulator and non-framework builds keep the fallback draft form because the local Simulator SDK does not include `JournalingSuggestions.framework`.
- `moryShareExtension` writes shared text, URLs, and image attachments into the external capture inbox through the app group, and the main app imports them through the normal memory creation path.
- `GraphDeltaReviewView` now supports reject and undo-reject through persisted `CorrectionEvent.kind.graphDeltaRejected` instead of view-only state.

## v7.3 Device Validation + Platform QA

Goal: make platform capture capabilities inspectable before real-device validation and product polish.

Completion evidence:

- `PlatformCaptureDiagnosticsService` produces a testable snapshot for Journaling Suggestions availability, App Group defaults/container, external attachment directory, Share Extension bundling, App Intents metadata, external inbox counts, and manual validation items.
- `PlatformCaptureDiagnosticsView` is reachable from `MemoryIntelligenceSettingsView` and Debug Center.
- the diagnostics view can seed a Share-style inbox item so external capture import can be validated through the normal pending inbox path.
- manual device checklist items are explicit for Apple Journaling picker import, Share Sheet handoff, and Siri/Shortcuts phrase validation.
- unit tests cover capability summaries, blocked/warning statuses, inbox counts, and the manual-device checklist.
- real-device execution is intentionally not claimed by this phase; it remains release hardening because it depends on a signed device build and enabled developer capabilities.
