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
- Analyze payload and cloud contracts remain unchanged; v7 cloud consumption starts in Phase 5.

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

## Phase 5: Analyze v7 Contract + Context-Aware Reflection

Goal:

- connect context pack to cloud AI safely.

Deliverables:

- `/api/analyze/v7`,
- v7 request/response models,
- proposal-first response mapper,
- context-aware reflection contract,
- dual-run debug mode.

Tests:

- legacy Analyze compatibility,
- proposal mapping,
- low-context uncertainty flags,
- privacy redaction in payload,
- reflection evidence coverage.

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

## Overall Phase Status

| Phase | Current status | Gap |
| --- | --- | --- |
| Phase 0 | completed | docs/gap matrix completed; implementation starts at Phase 1 |
| Phase 1 | completed | local SelfProfile persistence and inspectable context pack skeleton are implemented; Analyze v7 integration starts at Phase 5 |
| Phase 2 | not started | place has partial precedent, person missing |
| Phase 3 | not started | current EntityProfile too thin |
| Phase 4 | not started | mood is free text; Journaling Suggestions absent |
| Phase 5 | not started | legacy Analyze still current-record centered |
| Phase 6 | not started | no BGTask/background URLSession production loop |
| Phase 7 | not started | eval fixtures and debug surfaces missing |
