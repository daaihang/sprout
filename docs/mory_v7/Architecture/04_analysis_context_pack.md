# 04. Analysis Context Pack

## 1. Problem

Current Analyze is single-record centered. The cloud model receives current `record_shell`, current artifacts, and lightweight known entity names. It does not receive:

- related historical memories,
- Profile summaries,
- SelfProfile,
- Arc summaries,
- Reflection evidence,
- user corrections,
- negative entity signals,
- prior similar decisions.

This is the main reason AI analysis feels not personal or long-term.

Current constraints to preserve in the gap matrix:

- no week/month historical packet,
- known entities are not full profiles,
- Profile answers are written locally but not fed into the next Analyze call,
- Arc/Reflection are mostly post-processing instead of Analyze input,
- semantic search exists for users but not as a pre-Analyze retriever,
- multimodal summaries can be too thin for strong interpretation.

## 2. Goal

Before every AI call, build a bounded, explainable, privacy-gated `AnalysisContextPack`.

```swift
struct AnalysisContextPack: Codable, Sendable {
    var packID: UUID
    var targetRecordID: UUID
    var selfBrief: SelfContextBrief?
    var relatedProfiles: [KnownProfileBrief]
    var relatedMemories: [RelatedMemoryBrief]
    var relatedArcs: [RelatedArcBrief]
    var priorReflections: [PriorReflectionBrief]
    var correctionSignals: [CorrectionSignalBrief]
    var affectHistory: [AffectHistoryBrief]
    var privacyDecisions: [ContextPrivacyDecision]
    var budget: ContextBudgetReport
    var builtAt: Date
}
```

## 3. Retrieval Sources

| Source | Query signal | Purpose |
| --- | --- | --- |
| Recent memories | time window 7/30 days | continuity and recency |
| Semantic search | text, entities, mood, themes | similar experiences and decisions |
| Entity graph | people/place/theme ids | relationship and place context |
| Profiles | self/person/place/theme | stable personal context |
| Arcs | current open arcs, similar completed arcs | longer story structure |
| Reflections | prior insights with evidence | avoid repeating shallow insights |
| Corrections | not same person, tone correction, do-not-track | prevent repeated mistakes |
| Negative signals | ignored questions, rejected merges | reduce annoying prompts |

## 4. Ranking

`ContextRanker` scores each candidate:

```text
score =
  semantic_similarity
  + entity_overlap
  + recency_weight
  + salience_weight
  + user_confirmed_weight
  + open_decision_weight
  + affect_similarity_weight
  - sensitivity_penalty
  - repeated_rejected_signal_penalty
```

The pack should usually include 5-12 historical evidence items, not a raw week/month dump.

## 5. Budget

`ContextBudgeter` enforces:

- hard max token/character budget,
- per-source caps,
- no single source dominates,
- snippets instead of full raw content,
- provenance IDs for every snippet.

Suggested initial caps:

| Block | Cap |
| --- | --- |
| Current record | full shell + bounded artifacts |
| Self brief | 600-1000 chars |
| Profiles | 5-8 profiles |
| Related memories | 5-12 memories |
| Arcs/reflections | 3-6 items |
| Corrections | 5-10 compact signals |
| Affect history | trends, not raw timeline |

## 6. Privacy Gate

`PrivacyGate` runs after ranking and before payload serialization.

It can:

- drop sensitive sources,
- redact names,
- convert full text into local summary,
- keep source local and send only id/classification,
- block cloud analyze and force local-only queue.

All drops are recorded in `privacyDecisions` for debug.

## 7. Payload Shape

Server request should add:

```json
{
  "record_shell": {},
  "artifacts": [],
  "known_entities": [],
  "context_pack": {
    "self_brief": {},
    "known_profiles": [],
    "related_memories": [],
    "related_arcs": [],
    "prior_reflections": [],
    "correction_signals": [],
    "affect_history": [],
    "budget_report": {}
  }
}
```

Legacy Analyze remains supported until v7 migration completes.

## 8. Debug Surface

Add `Context Pack Viewer`:

- why each item was included,
- score breakdown,
- privacy decision,
- token budget,
- payload preview,
- cloud/local boundary,
- replay Analyze with same pack.

## 9. Acceptance Criteria

- New Analyze calls can include bounded history evidence.
- Related Profile fields are included as summaries, not raw full objects.
- Context pack works even if semantic search is disabled.
- Privacy setting can disable all historical evidence in cloud payload.
- Tests cover rank, budget, privacy gate, and provenance.
