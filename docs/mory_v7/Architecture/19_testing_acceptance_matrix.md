# 19. Testing Acceptance Matrix

## 1. Purpose

v7 needs tests before prompt tuning and UI polish. This matrix defines minimum coverage by module.

## 2. Unit Tests

| Module | Required tests |
| --- | --- |
| `SelfReferenceResolver` | me/not-me, alias, role phrases, negative evidence |
| `EntityResolutionService` | same person, not same person, role bucket, ambiguous label |
| `ContextPackBuilder` | includes related memories, profiles, arcs, corrections |
| `ContextRanker` | semantic/entity/recency/salience scoring |
| `ContextBudgeter` | caps per block, avoids one-source dominance |
| `PrivacyGate` | include/summarize/redact/local-only/block |
| `AffectSnapshotMapper` | VAD/PAD mapping, labels, tone hints |
| `GraphMutationApplier` | merge, split, tombstone, undo |
| `InvalidationPlanner` | edit/delete/question/merge recompute |
| `NotificationPolicy` | quiet hours, max per day, sensitivity, cooldown |

## 3. Integration Tests

| Flow | Expected outcome |
| --- | --- |
| create memory -> build context pack -> Analysis | payload has bounded evidence and provenance |
| answer relationship question -> future Analyze | profile/correction signal appears in context |
| merge two people -> search/profile/arc update | stale references rewritten or invalidated |
| split role label -> clarification question | ambiguous bucket preserved |
| affect correction -> future tone analysis | correction signal included |
| Journaling Suggestion -> save draft | context evidence and affect source persisted |
| BGAppRefresh -> daily question | candidate prepared and policy-gated |
| APNs ready push -> fetch result | notification interaction writes back |

## 4. Golden Fixtures

Fixture categories:

- first week sparse data,
- one-month relationship history,
- job decision arc,
- two Alex people,
- roommate role label,
- self alias confusion,
- joking complaint,
- real irritation,
- sensitive health topic,
- deleted source memory,
- wrong merge recovery.

## 5. Build And Runtime Checks

Before merging v7 implementation:

- targeted unit tests pass,
- affected integration tests pass,
- iOS simulator smoke path passes for capture/save/detail/debug,
- server `go test ./...` passes when contracts change,
- no background task identifiers missing from Info.plist,
- no entitlement-dependent UI shown without capability gate.

## 6. Documentation Checks

Each Phase PR must update:

- v7 phase backlog status,
- current gap matrix if gap changes,
- data model catalog if model changes,
- cloud contract doc if payload changes,
- privacy doc if cloud/local boundary changes.

## 7. Exit Criteria By Phase

| Phase | Exit criteria |
| --- | --- |
| Phase 1 | context pack skeleton builds and can be inspected |
| Phase 2 | identity correction and person merge/split work at repository level |
| Phase 3 | person profile portrait job produces evidence-backed proposals |
| Phase 4 | affect snapshot and Journaling evidence are persisted |
| Phase 5 | production new-memory pipeline uses Analysis context pack and persists proposals safely |
| Phase 6 | background/notification loop has policy, writeback, and debug traces |
| Phase 7 | eval fixtures, debug surfaces, and privacy/budget gates can measure regressions before production rollout |

## 8. Completion Evidence

v7 acceptance coverage is now in place for the architecture baseline:

- targeted eval fixtures: `MoryV7EvalTests`;
- context/retrieval/privacy tests: `AnalysisContextPackTests`;
- identity/correction tests: `EntityResolutionServiceTests`;
- structured mood tests: `AffectSnapshotTests`;
- background/runtime tests: `BackgroundOperationOrchestratorTests`, `BackgroundTaskCoordinatorTests`, `RuntimeOperationsCoordinatorTests`;
- notification trigger/routing/policy/writeback tests: `NotificationOrchestratorTests`, `NotificationDeliveryRouterTests`, `LocalNotificationSchedulerTests`, `NotificationSettingsServiceTests`, `NotificationInteractionServiceTests`;
- push tests: `RemotePushSyncServiceTests` plus Go `server/internal/push` tests;
- cloud contract tests: `AnalysisContractTests`.

The remaining production tasks are real-device APNs/background soak, real-user telemetry, App Store capability checks, and polished user-facing UI.

## 9. Non-Acceptance

v7 is not acceptable if:

- AI directly mutates trusted graph state,
- context pack uploads full history,
- user correction does not affect future analysis,
- notifications expose sensitive content,
- UI implements merge/split without repository mutation,
- background behavior only works when Home is opened.
