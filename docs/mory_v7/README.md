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

## 3. Implementation Status

v7 is complete as a local architecture, debug, and testable foundation.

Completed implementation areas:

- `SelfProfile` and identity-aware local context pack construction.
- Entity resolution, correction events, not-same blocking, and person merge/split mutation.
- Person profile persistence, evidence-backed portrait refresh, and profile mutation actions.
- Structured affect snapshots, affect corrections, tone hints, and Journaling suggestion draft mapping.
- External capture inbox foundation for App Intent, Share, and Journaling-originated drafts.
- Analyze v7 production replacement, bounded context payloads, native server proposal output, and debug request/response inspection.
- BGTask registration, background URLSession infrastructure, silent-push handling, local/APNs notification routing, and notification policy tests.
- Eval/debug coverage for context packs, affect correction recurrence, graph delta apply, merge recovery, BGTask scheduling, and notification routing.

Post-v7 production hardening remains separate from the v7 foundation:

- real Apple Journaling Suggestions entitlement and picker UX,
- full Share extension capture surface and App Intent phrase/device validation,
- real-device APNs/background telemetry and soak testing,
- public release privacy review with real user data handling.

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

v7 followed the intended order:

1. Context and identity data contracts.
2. Persistence and mutation boundaries.
3. Debug surfaces and deterministic tests.
4. Background orchestration.
5. User-facing UI polish later.

The shipped v7 baseline intentionally prioritizes business logic, repository boundaries, debug inspection, and tests over polished end-user UI.
