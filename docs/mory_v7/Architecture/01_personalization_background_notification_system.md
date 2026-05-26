# 01. Personalization, Background, And Notification System (v7)

> Status: retained as the v7 current-state gap overview. The canonical implementation specs are now split across `01_identity_and_self_profile.md` through `11_phase_implementation_backlog.md`.

## 1. Goal

v7 goal is to fix one product problem:

> AI analysis currently feels local and short-term, but not yet personal and long-term.

This document defines architecture changes for backend, AI, and notification loops to close that gap.

## 2. Current State (Verified In Code)

### 2.1 Analysis Context Is Narrow

- Record analysis request only contains current `record_shell`, current artifacts, and known entities.
- There is no explicit history bundle (no week/month timeline package) in analyze payload.
- Known entities are capped by pipeline-side recent nodes (`prefix(20)`).
- Artifact text is compacted aggressively before cloud analysis; long body/attachment content can be reduced before the model sees it.
- Existing `EntityProfile` fields such as `relationshipToUser`, `mentionCount`, `commonContextLabels`, and user descriptions are not packaged as Profile-level context for Analyze.

Code:

- `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Analysis/Pipeline/AnalysisRecordPayloadBuilder.swift`
- `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Analysis/Pipeline/AnalysisExecutor.swift`
- `/Users/z14/Documents/sprout/server/internal/ai/types.go`

### 2.2 Daily Question Evidence Is Also Narrow

- Daily question suggestion uses `fetchRecentMemories(limit: 6)`.
- Evidence snippet is compacted text only.
- The current question payload does not consistently carry a real `knownProfile` brief.
- Trigger is mainly app-launch/home-refresh path.

Code:

- `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Intelligence/DailyQuestionSuggestionService.swift`
- `/Users/z14/Documents/sprout/mory/mory/Features/Home/HomeScreen.swift`
- `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Intelligence/Jobs/IntelligenceJobRecoveryService.swift`
- `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Intelligence/Jobs/IntelligenceJobWorker.swift`
- `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Background/BackgroundOperationOrchestrator.swift`

### 2.3 Background Orchestration Is System-Scheduled And Centrally Routed

- `BackgroundTaskCoordinator` registers `BGProcessingTask` and `BGAppRefreshTask`, then delegates work to `BackgroundOperationOrchestrator`.
- Silent push, background URLSession completion, app launch, foreground refresh, pipeline completion, APNs token updates, and notification preference changes all enter the same background orchestrator. Background records the run and calls Intelligence/Notification/Push through ports; it does not own those domains' business logic.
- Background URLSession infrastructure exists for deferred network transport; real-device reliability validation remains required.

Code signal:

- `BGTaskScheduler`, `BGAppRefreshTaskRequest`, `BGProcessingTaskRequest`, and `URLSessionConfiguration.background` are present under `Infrastructure/Background`.

### 2.4 Remote Push Foundation Exists, But Proactive Loop Is Partial

- iOS can register APNs token and sync preferences.
- Go server can queue and deliver push intents, and write back delivery events.
- App-side proactive generation is routed through the background domain; the remaining gap is real-device soak and product-level status explanation.

Code:

- `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Notifications/RemotePushSyncService.swift`
- `/Users/z14/Documents/sprout/server/internal/http/handlers.go`
- `/Users/z14/Documents/sprout/server/internal/notification/push_delivery_worker.go`

### 2.5 Entity Identity Lifecycle Is Incomplete

- Person merge/split workflow is not first-class (place has merge/split, person does not).
- Name matching still relies on direct name/alias equality in graph update.
- User self-profile (`me`) is missing as a dedicated domain object.

Code:

- `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Analysis/Graph/GraphUpdater.swift`
- `/Users/z14/Documents/sprout/mory/mory/Persistence/Repositories/MoryMemoryRepository.swift`
- `/Users/z14/Documents/sprout/mory/mory/Domain/Intelligence/IntelligenceModels.swift`

### 2.6 Mood Data Is Not Structured Enough

- Legacy capture still keeps `userMood`, but Phase 4 now persists record-linked `AffectSnapshot` rows for structured affect.
- Analysis emotion mainly maps to one label/intensity/confidence.
- No multi-axis affect model for robust longitudinal reasoning.
- Tone ambiguity is not represented as first-class data, so joking, venting, sarcasm, serious irritation, and exhaustion can collapse into the same label.

Code:

- `/Users/z14/Documents/sprout/mory/mory/Domain/Capture/RecordShell.swift`
- `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Analysis/Pipeline/AnalysisRecordResponseMapper.swift`

### 2.7 Daily Question Answer UX Is Limited

- Most question types only provide fixed candidate options.
- Freeform text input is only implemented for `entityAlias`.
- Non-alias questions can become effectively unanswerable when candidate answers are empty.

Code:

- `/Users/z14/Documents/sprout/mory/mory/Features/Intelligence/ClarificationQuestionCard.swift`

### 2.8 Multimodal Evidence Is Useful But Thin

- Photo processing produces compact tags/OCR summaries, not full visual scene understanding.
- Speech transcription failure can leave no text evidence for analysis.
- Weather/music/place context improves capture but does not replace identity-aware retrieval.
- Phase 4 includes a local `JournalingSuggestionContextService` and fallback diagnostics; the Apple entitlement and real system picker remain pending.

Code:

- `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Analysis/Artifacts/PhotoArtifactProcessor.swift`
- `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Analysis/Artifacts/AudioTranscriptionService.swift`
- `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Context/ContextAutoCollector.swift`
- `/Users/z14/Documents/sprout/mory/mory/mory.entitlements`

### 2.9 Prompt And Quality Gates Are Conservative

- Server prompts intentionally avoid overclaiming from one weak record.
- Local quality gates reduce false reflections but can also weaken first-day perceived value.
- v7 should keep conservatism, but surface evidence-backed possibilities and ask lightweight corrections earlier.

Code:

- `/Users/z14/Documents/sprout/server/internal/ai/prompt.go`
- `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Analysis/Quality/ContentQualityPolicies.swift`

### 2.10 v6 Contracts Are Ahead Of Legacy Analyze

- Some v6 flows already model evidence snippets and profile summaries.
- Legacy Analyze has not yet adopted the same context-aware contract.

Code:

- `/Users/z14/Documents/sprout/server/internal/ai/v6_types.go`
- `/Users/z14/Documents/sprout/server/internal/ai/types.go`

## 3. Why Personalization Feels Weak

Main causes:

1. The model sees too little historical context per analysis call.
2. Entity identity is not stable enough across aliases/same-name people/self-reference.
3. Feedback loop from question answer -> profile -> future prompt is still shallow.
4. Trigger model is foreground-biased (open app to prepare work).
5. Mood signal is too low-dimensional for speech tone ambiguity and longitudinal patterning.

## 4. v7 Architecture Additions

## 4.1 Context Assembly Layer (new)

Add `ContextAssemblyService` before every cloud AI call:

- build multiple context windows:
  - short window: recent 7 days,
  - medium window: recent 30 days,
  - long anchors: key arcs/decisions/people summaries.
- produce bounded token budget packages:
  - `record_context_brief`,
  - `entity_context_brief`,
  - `decision_context_brief`.
- add provenance IDs for all evidence snippets.

Output is still privacy-minimized summaries, not full local database upload.

## 4.2 Identity Layer v2 (new)

Add dedicated identity modules:

- `UserSelfProfile`:
  - aliases for self-reference (`我`, nickname, legal name),
  - stable `self_entity_id`.
- `EntityIdentityResolver`:
  - merge proposal scoring (name, alias, context overlap, relation graph),
  - split proposal scoring for overloaded labels (`舍友`, same-name contacts).
- `EntityMutationQueue`:
  - merge/split/apply/revert operations with audit trail.

`PlaceProfile` currently has manual merge/split; v7 extends this lifecycle to person/theme/decision identities.

## 4.3 Mood Model v2 (new structured schema)

Introduce `MoodVector` for each memory:

- `valence`: [-1, 1]
- `arousal`: [0, 1]
- `dominance`: [0, 1]
- `primary_emotions`: fixed taxonomy labels + score
- `confidence`: [0, 1]
- `source`: user/manual, speech-model, text-model, fused
- `humor_or_sarcasm_likelihood`: [0, 1]

Keep original raw mood text for user intent traceability.

This supports both:

- AI analysis reasoning,
- user quick-tap mood chips + optional custom note.

## 4.4 Background Orchestration Layer v2 (new)

Adopt a hybrid scheduler:

- `BGAppRefreshTask`: light tasks
  - fetch push state,
  - prepare one daily question candidate,
  - schedule local notification if needed.
- `BGProcessingTask`: heavier tasks
  - deferred intelligence jobs,
  - backlog compaction, index maintenance.
- background URL session:
  - long-running upload/download for AI related payloads when required.

Keep launch recovery as fallback path, not primary scheduler.

## 4.5 Notification Loop v2 (new)

Unify local and remote intent pipeline:

1. produce candidate intents,
2. policy gating,
3. channel routing:
   - local-only,
   - remote push,
   - in-app only sensitive.
4. interaction writeback,
5. ranking feedback into next candidate generation.

For daily question answer UX:

- all question kinds support `freeform` option in addition to fixed chips.

## 4.6 App-External Capture Triggers (new)

Add system entry points for "not opening app first" scenarios:

- App Intents / Shortcuts / Share extension capture.
- Optional location/music/time based reminder intents (respecting user opt-in).

This part is based on the iOS capabilities list provided for v7 planning and should be implemented with OS-version gating.

## 5. Capability Matrix (Current vs v7)

| Capability | Current | v7 target |
| --- | --- | --- |
| Analyze context window | Single-record centered | Multi-window context assembly |
| Daily question triggering | Home/launch dominated | Foreground + BGTask + remote assist |
| APNs backend pipeline | Exists | Keep + integrate with proactive scheduler |
| Entity merge/split | Place only (manual) | Person/theme/decision identity lifecycle |
| Self identity profile | Missing | `UserSelfProfile` with dedicated resolver |
| Mood representation | text + intensity + inferred label | structured `MoodVector` + fusion |
| Question answers | mostly fixed options | fixed options + freeform all kinds |
| App-external input | limited | App Intents/Shortcuts/Share paths |

## 6. Phase Plan (v7)

## Phase A: Context + Mood Foundation

- Add `ContextAssemblyService`.
- Add `MoodVector` schema + mapper.
- Keep old fields for backward compatibility.

Exit criteria:

- Analyze and question payloads include bounded context brief blocks.
- Mood fields survive migration and are queryable.

## Phase B: Identity Lifecycle

- Add `UserSelfProfile`.
- Add merge/split proposal engine and mutation queue for people/entities.
- Add debug screens for confirm/reject operations.

Exit criteria:

- Same-name and alias conflict cases can be corrected without raw DB edits.
- Clarification answers update identity state deterministically.

## Phase C: Background Reliability

- Register BG tasks and handlers.
- Move daily question prep + intent prep into scheduled tasks.
- Keep launch recovery for catch-up only.

Exit criteria:

- Question/intent generation occurs without requiring manual app-open loops.
- Failed jobs retry with bounded backoff and visible diagnostics.

## Phase D: Notification Loop Upgrade

- Unified channel router and feedback weighting.
- Add freeform answer route for all question cards.
- Strengthen sensitive-topic suppression and preview policy.

Exit criteria:

- Notification intent quality increases with interaction feedback.
- Daily question conversion improves without raising spam rate.

## 7. Testing And Observability Requirements

Required:

1. context assembly unit tests with token-budget constraints.
2. identity merge/split deterministic tests (same-name and alias cases).
3. BG task integration smoke tests (scheduled -> executed -> persisted effects).
4. notification policy regression tests (quiet hours, max/day, sensitivity).
5. mood model migration tests (old records remain readable).

Required metrics:

- question generation source: foreground vs background vs remote assist.
- context package size and truncation counts.
- identity merge/split accepted/rejected rates.
- notification sent/open/dismiss/answer funnel by kind.
- stale pending-job backlog count.

## 8. Non-Goals For This v7 Slice

- full server-side memory warehousing,
- replacing local-first storage boundary,
- cosmetic UI redesign before architecture stabilization.
