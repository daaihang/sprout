# 07. Cloud Contracts v7

## 1. Problem

v6 server contracts already have useful concepts such as `EvidenceSnippet` and profile summaries for some flows, but legacy `/api/analyze` is still centered on the current record. v7 needs a context-aware contract while keeping local-first privacy.

## 2. Contract Principle

Cloud AI should output proposals, not trusted facts.

Allowed outputs:

- analysis summary,
- emotion/affect proposal,
- entity/profile update proposal,
- merge/split candidate,
- arc candidate,
- reflection candidate,
- clarification question candidate,
- notification intent candidate.

Repository/policy decides what is applied.

## 3. `/api/analyze/v7`

Request:

```json
{
  "client_request_id": "uuid",
  "record_shell": {},
  "artifacts": [],
  "mood_evidence": [],
  "context_pack": {
    "self_brief": {},
    "known_profiles": [],
    "related_memories": [],
    "related_arcs": [],
    "prior_reflections": [],
    "correction_signals": [],
    "privacy_decisions": [],
    "budget_report": {}
  },
  "client_capabilities": {
    "supports_profile_proposals": true,
    "supports_merge_candidates": true,
    "supports_affect_snapshot": true
  }
}
```

Response:

```json
{
  "analysis": {},
  "affect_proposals": [],
  "graph_delta_proposals": [],
  "profile_update_proposals": [],
  "merge_split_candidates": [],
  "arc_candidates": [],
  "reflection_candidates": [],
  "question_candidates": [],
  "quality": {
    "confidence": 0.0,
    "uncertainty_reasons": [],
    "needs_user_check": []
  }
}
```

## 4. Profile Update Proposal

```json
{
  "proposal_id": "uuid",
  "target_entity_id": "uuid",
  "profile_kind": "person",
  "field": "relationshipToUser",
  "proposed_value": "roommate",
  "confidence": 0.72,
  "evidence": [
    { "source_record_id": "uuid", "snippet": "..." }
  ],
  "requires_confirmation": true
}
```

## 5. Merge/Split Candidate

```json
{
  "candidate_id": "uuid",
  "kind": "same_person",
  "source_entity_ids": ["uuid"],
  "target_entity_id": "uuid",
  "confidence": 0.64,
  "positive_evidence": [],
  "negative_evidence": [],
  "question": "这里的 Alex 是你之前提到的 Alexander Chen 吗?"
}
```

## 6. Context-Aware Reflection

Reflection requests should include:

- linked arc summary,
- evidence snippets,
- counter-evidence,
- previous reflection summaries,
- user correction signals,
- sensitivity flags.

It should not send only `linked_arc_id`.

## 7. Quality And Conservatism

The model should stay conservative when evidence is weak, but v7 should improve early value by showing bounded, evidence-backed “possible connection” instead of forcing life-pattern claims.

Response quality flags:

- `thin_context`,
- `ambiguous_identity`,
- `low_mood_confidence`,
- `needs_user_tone_check`,
- `sensitive_content_redacted`,
- `insufficient_longitudinal_evidence`.

## 8. Migration

Migration path:

1. keep legacy `/api/analyze`,
2. add `/api/analyze/v7`,
3. add iOS feature flag,
4. compare output in debug dual-run,
5. ship v7 contract for new analyses,
6. backfill only selected records where useful.

## 9. Acceptance Criteria

- Analyze payload can include context pack.
- Server never requires full local database.
- All AI-created durable updates arrive as proposals.
- v7 response maps cleanly into `GraphDeltaV2`.
- Legacy Analyze still works while v7 flag is off.
