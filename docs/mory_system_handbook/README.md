# Mory System Handbook

This handbook is the source of truth for the current Mory product and architecture state. It is not a version plan like v3-v7. It answers what the app can do now, how data moves, where AI participates, what users can see, and what remains incomplete before launch.

## Current Conclusion

Mory currently has a functional local-first memory capture, record-facts, card arrangement, and Analysis foundation:

- In-app capture supports text, photo, video, audio, link, place, weather, music, todo, prompt-answer, person-context, and structured mood evidence.
- Apple Journaling Suggestions is modeled as typed evidence, then converted into normal `MemoryCaptureDraft` artifacts and `AffectSnapshotDraft` evidence.
- External Capture and Share use the same durable App Group envelope/recovery path and can seed the unified composer.
- Saving a memory writes `RecordShell + Artifact[] + ArtifactSemanticDigest[] + MemoryCardArrangement + AffectSnapshot[]` first, then records `.notScheduled` unless analysis is explicitly requested.
- Analysis is the production analysis path after memory save: context pack -> `/api/analyze` -> local proposal persistence and graph/profile updates.
- Card rendering is arrangement-driven: composer/detail/debug share the same recipe, size token, object metrics, and 6-column logical layout vocabulary.
- SelfProfile, EntityProfile, PersonProfile, AffectSnapshot, GraphDelta, Reflection, Arc, and clarification questions exist as separate concepts.

The main product problem is still visibility. Many capabilities are wired or usable, and Debug now has stronger acceptance surfaces, but users and product owners still need a product-level view of current state, provenance, AI timing, and remaining actions.

## Status Vocabulary

| Status | Meaning |
| --- | --- |
| `not_started` | No meaningful implementation exists. |
| `backend_only` | Model/API/persistence exists, but no user-facing path. |
| `debug_only` | Feature can be inspected or triggered only through Debug/diagnostics. |
| `wired` | Entry point and data path exist, but user experience or edge cases are incomplete. |
| `usable` | A real user can complete the main path, with known limitations. |
| `stable` | Main path, error handling, status visibility, and tests are reliable. |
| `polished` | Release-quality experience, copy, visual design, accessibility, and monitoring. |

## Reading Order

1. [Current Status](00_current_status/current_status.md)
2. [Feature Inventory Overview](01_feature_inventory/README.md)
3. [Capture Feature Matrix](01_feature_inventory/capture.md)
4. [AI Intervention Matrix](04_ai_intervention_matrix/README.md)
5. [Data Flow Matrix](03_data_flow_matrix/README.md)
6. [API Contracts](05_api_contracts/README.md)
7. [Database Catalog](06_database_catalog/README.md)
8. [Entitlements And Billing](07_entitlements_and_billing/README.md)
9. [Status And Debug Surfaces](08_status_and_debug_surfaces/README.md)
10. [Gap And Roadmap](09_gap_and_roadmap/README.md)

## Documentation Rule For Future Work

Every new feature or architecture change must update:

- the feature inventory file,
- the data flow matrix,
- the AI intervention matrix if AI participates,
- API/database catalogs when contracts or storage change,
- entitlement/billing matrix when access or quota may differ by plan.

If a feature cannot be explained through this handbook, it is not ready to be expanded.
