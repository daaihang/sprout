# Mory v7

## 1. Purpose

Mory v7 upgrades the product from continuous memory intelligence to identity-aware long-term personal memory.

v6 proved that Mory can create records, artifacts, graph links, entity profiles, daily questions, notification intents, search surfaces, arcs, and reflections. v7 connects those pieces into a durable personal model:

- who the user is,
- who other people are,
- what entities mean over time,
- which memories should be recalled before AI analysis,
- how corrections change the graph,
- how mood and tone become structured evidence,
- how background jobs and notifications keep the system useful without requiring the app to be open.

## 2. v7 Thesis

The main v7 problem is not "make the model smarter." The problem is that Mory does not yet provide the model with enough structured long-term context, and it does not yet turn user correction into durable future behavior.

The target behavior:

```text
new memory
  -> identity-aware context retrieval
  -> privacy-gated context pack
  -> context-aware AI analysis
  -> proposals, not trusted facts
  -> user correction or policy confirmation
  -> durable graph/profile/mood/job updates
  -> future analysis reads those updates
```

## 3. Current v6 Gap Summary

Current verified gaps:

- Analyze payload is centered on the current record, current artifacts, and up to 20 known entities.
- Entity profiles, user answers, arcs, reflections, semantic search hits, and similar memories are not fed back into the next Analyze call as structured context.
- Person entities do not yet have the same merge/split management lifecycle that place profiles have.
- There is no dedicated local self profile for "me", "I", "my roommate", "my mother", or other first-person relationship language.
- Mood is too thin: free text plus optional intensity cannot reliably support longitudinal emotion or tone analysis.
- Daily questions and notification prep are still foreground/launch dominated.
- Remote push and local notification foundations exist, but v7 needs a unified proactive orchestration loop.

## 4. Document Map

PRD:

- [00 v7 PRD Index](PRD/00_v7_prd_index.md)
- [01 Product Thesis](PRD/01_v7_product_thesis.md)
- [02 User Value And Decision Questions](PRD/02_user_value_and_decision_questions.md)
- [03 Controls Correction And Privacy](PRD/03_controls_correction_and_privacy.md)
- [04 System Context And Journaling Suggestions](PRD/04_system_context_and_journaling_suggestions.md)
- [05 Notification And Retention Scenarios](PRD/05_notification_and_retention_scenarios.md)

Architecture:

- [00 v7 Architecture Index](Architecture/00_v7_architecture_index.md)
- [01 Identity And Self Profile](Architecture/01_identity_and_self_profile.md)
- [02 Entity Resolution And Correction](Architecture/02_entity_resolution_and_correction.md)
- [03 Person Profile And Portrait](Architecture/03_person_profile_and_portrait.md)
- [04 Analysis Context Pack](Architecture/04_analysis_context_pack.md)
- [05 Structured Mood And Affect](Architecture/05_structured_mood_and_affect.md)
- [06 Background AI Notification Orchestration](Architecture/06_background_ai_notification_orchestration.md)
- [07 Cloud Contracts v7](Architecture/07_cloud_contracts_v7.md)
- [08 GraphDelta v2 And Mutations](Architecture/08_graph_delta_v2_and_mutations.md)
- [09 Jobs Recomputation And Invalidations](Architecture/09_jobs_recomputation_and_invalidations.md)
- [10 Eval Observability And Debug](Architecture/10_eval_observability_and_debug.md)
- [11 Phase Implementation Backlog](Architecture/11_phase_implementation_backlog.md)
- [12 Current v6 Gap Matrix](Architecture/12_current_v6_gap_matrix.md)
- [13 Data Model Catalog](Architecture/13_data_model_catalog.md)
- [14 Privacy Security And Local First](Architecture/14_privacy_security_and_local_first.md)
- [15 iOS Capability Matrix](Architecture/15_ios_capability_matrix.md)
- [16 Context Pack Examples](Architecture/16_context_pack_examples.md)
- [17 Identity Correction Examples](Architecture/17_identity_correction_examples.md)
- [18 Repository And UI Boundaries](Architecture/18_repository_and_ui_boundaries.md)
- [19 Testing Acceptance Matrix](Architecture/19_testing_acceptance_matrix.md)

## 5. Delivery Order

Do not start with polished UI.

Implementation order:

1. Context and identity data contracts.
2. Persistence and mutation boundaries.
3. Debug surfaces and deterministic tests.
4. Background orchestration.
5. User-facing UI polish.
