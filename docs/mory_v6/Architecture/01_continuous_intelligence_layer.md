# 01. Continuous Intelligence Layer

## 1. Goal

The Continuous Intelligence Layer turns Mory from capture-time analysis into an ongoing memory system.

It should run after existing pipeline events, app foreground events, background refreshes, user corrections, and scheduled daily review windows.

## 2. Placement

New directories:

```text
mory/mory/Domain/Intelligence/
mory/mory/Infrastructure/Intelligence/
mory/mory/Features/Intelligence/
```

The layer should not live inside SwiftUI views or the existing analysis executor.

## 3. Core Flow

```text
Record analysis completes
  -> IntelligenceScheduler receives recordID
  -> Scheduler extracts local signals
  -> Scheduler creates jobs
  -> Job processor runs deterministic/local work first
  -> Optional cloud AI requests are queued or gated
  -> Outputs create questions, profiles, graph deltas, search index updates, and board signals
```

## 4. Job Types

Initial job types:

```text
postAnalysisEntityEnrichment
aliasCandidateDetection
relationshipClarification
placeMeaningDetection
themeConfirmation
decisionStatusCheck
chapterCandidateGeneration
dailyQuestionPreparation
semanticIndexUpdate
notificationIntentPreparation
transcriptRefinement
```

## 5. Job Lifecycle

```text
pending
running
waitingForUser
completed
failed
cancelled
superseded
```

Rules:

- Jobs must be idempotent.
- Jobs must have stable target keys.
- Jobs must not create duplicate questions for the same unresolved target.
- Jobs must be retryable.
- Jobs must not block capture.
- Failed jobs can show a pending action card if user-relevant.

## 6. Scheduling Triggers

| Trigger | Jobs |
| --- | --- |
| Memory created | Semantic index update, post-analysis after pipeline |
| Pipeline completed | Entity enrichment, question generation, chapter candidate |
| Memory edited | Re-index, invalidate stale questions, re-run relevant jobs |
| User answered question | Apply graph delta, update profile, refresh home |
| App foreground | Retry pending local jobs, refresh daily question eligibility |
| Background refresh | Prepare daily question, update index, schedule local notifications |
| Settings changed | Recompute notification eligibility and local/cloud AI behavior |

## 7. Scheduler Rules

Scheduler should enforce:

- Cloud AI disabled means no server intelligence request.
- Local intelligence disabled means no local enrichment beyond core pipeline.
- Notification disabled means no notification intent scheduling.
- Sensitive topics respect preference.
- Question cooldown is enforced.
- User-hidden card categories reduce future card priority.

## 8. Output Types

Jobs can output:

- `EntityProfile`
- `ClarificationQuestion`
- `GraphDelta`
- `HomeBoardSignal`
- `NotificationIntent`
- `SemanticIndexUpdate`
- `ChapterCandidate`
- `TranscriptRefinement`

## 9. Integration With Existing Pipeline

Do not add V6 logic directly into `AnalysisExecutor`.

Preferred integration point:

```text
MoryMemoryRepository.refreshMemoryPipeline(recordID:)
  -> existing runArchitecturePipeline(...)
  -> mark pipeline completed
  -> intelligenceScheduler.enqueuePostAnalysisJobs(recordID:)
```

Reason:

- Existing pipeline remains testable.
- V6 jobs can be retried independently.
- Future background processing can call the scheduler without re-running full AI analysis.

## 10. Failure Handling

Failure policy:

- Local deterministic failures are logged and retried with backoff.
- Cloud AI failures become `failed` jobs with visible retry only if user-facing.
- Search indexing failures should not block UI.
- Notification scheduling failures should not block home.
- Duplicate jobs should be coalesced.

## 11. Minimal V6 Alpha Behavior

The first alpha should implement:

1. On pipeline completion, find new person entities.
2. Create or update `EntityProfile`.
3. If relationship is unknown, create `ClarificationQuestion`.
4. Show question on Home.
5. Let user answer relationship.
6. Persist answer to profile.

