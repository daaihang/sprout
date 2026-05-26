# 10. Eval, Observability, And Debug

## 1. Problem

Personal long-term AI cannot be tuned only by prompt feeling. v7 needs measurable evals and debug surfaces for identity, retrieval, mood, and notification quality.

## 2. Eval Metrics

| Metric | Meaning |
| --- | --- |
| entity merge precision | accepted merges that were correct |
| erroneous merge rate | wrong merges per proposal/apply |
| split recovery rate | overloaded entities resolved after correction |
| self-reference accuracy | “我/自己/我的...” mapped correctly |
| context pack hit rate | useful historical item included |
| context pack noise rate | irrelevant or sensitive item included |
| profile usefulness | user keeps/edits/rejects profile fields |
| correction recurrence | same mistake repeated after correction |
| reflection evidence coverage | reflections backed by real snippets |
| affect correction rate | mood/tone proposals corrected by user |
| notification conversion | notification opened/answered/snoozed/dismissed |
| notification regret | user suppresses or marks notification bad |

## 3. Golden Sets

Maintain local test fixtures:

- same-name people,
- alias merge,
- role labels (`舍友`, `老板`, `导师`),
- self-reference,
- joking vs irritated transcript,
- sparse first-day memory,
- sensitive private topic,
- deleted/edited source memory,
- wrong merge undo.

## 4. Debug Surfaces

Required debug tools:

- `Context Pack Viewer`,
- `Entity Resolution Inspector`,
- `Person Profile Diff Viewer`,
- `Self Profile Inspector`,
- `Affect Snapshot Inspector`,
- `Graph Mutation Ledger`,
- `Job Queue Dashboard`,
- `Notification Intent Trace`,
- `Cloud Payload Preview`.

These are business/debug surfaces, not final UI polish.

## 5. Observability Events

Log structured events:

- context pack built,
- item included/excluded with reason,
- proposal generated,
- proposal accepted/rejected,
- correction written,
- mutation applied/failed,
- recompute scheduled/completed,
- notification candidate routed/suppressed,
- background task started/expired/completed.

No raw sensitive content in telemetry.

## 6. Test Requirements

Unit tests:

- context rank/budget/privacy,
- entity resolver same/not-same,
- merge/split rewrite,
- self-reference resolver,
- affect snapshot mapping,
- correction event effects.

Integration tests:

- memory create -> context pack -> analyze proposal -> graph mutation,
- question answer -> profile update -> future context pack,
- merge/split -> recompute -> search/index refresh,
- notification intent -> local/APNs routing policy.

Manual simulator checks:

- debug payload preview,
- local notification scheduling,
- launch recovery fallback,
- no UI crash when proposals are empty.

## 7. Acceptance Criteria

- Every v7 AI decision can show its evidence or uncertainty.
- Wrong identity/mood decisions can be corrected and measured.
- Background/notification failures are visible.
- Evals exist before prompt tuning becomes the main lever.

## 8. Implementation Status

v7 completion covers the development baseline for this layer:

- golden tests exist for sparse first-day context, graph delta apply/idempotence, person merge recovery, and affect correction recurrence into future context packs;
- context pack, identity resolution, affect mapping, notification routing, BGTask scheduling, and local notification policy have targeted tests;
- Debug Center surfaces can inspect context packs, affect snapshots, clarification questions, pending GraphDeltas, BGTask scheduling, notification routing, and cloud/debug payloads;
- privacy controls are enforced through local-first storage, budgeted context packs, sensitive-history redaction/drop decisions, and proposal-based Analysis output.

Post-v7 production observability should add real-user aggregate metrics for notification conversion/regret and privacy audit reporting. These are release-hardening tasks, not blockers for the v7 architecture baseline.
