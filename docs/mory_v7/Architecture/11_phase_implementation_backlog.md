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
| Phase 0 | in progress | docs being expanded |
| Phase 1 | not started | requires model + builder |
| Phase 2 | not started | place has partial precedent, person missing |
| Phase 3 | not started | current EntityProfile too thin |
| Phase 4 | not started | mood is free text; Journaling Suggestions absent |
| Phase 5 | not started | legacy Analyze still current-record centered |
| Phase 6 | not started | no BGTask/background URLSession production loop |
| Phase 7 | not started | eval fixtures and debug surfaces missing |
