# Database Catalog

This catalog summarizes local SwiftData stores and server SQLite tables relevant to product behavior.

## iOS SwiftData Stores

| Store | Purpose | Sensitivity |
| --- | --- | --- |
| `RecordShellStore` | Captured memory shell | Personal |
| `ArtifactStore` | Text/media/context artifacts | Personal, may contain sensitive media/text |
| `ArtifactSemanticDigestStore` | Local semantic digest for media/text-derived evidence such as OCR, caption, labels, transcript, duration, and media dimensions | Personal, may contain sensitive derived text |
| `MemoryCardArrangementStore` | User-authored card layout for composer/detail/today desk rendering: visual recipe, size token, order, stack/group, grid placement, nudge, rotation, and z-index | Product state/personal presentation |
| `RecordAnalysisSnapshotStore` | AI analysis summary/themes/entities | Personal/AI-derived |
| `MemoryPipelineStatusStore` | Analysis request/status/error traces | Debug-sensitive |
| `SelfProfileStore` | User's own profile | Highly sensitive |
| `PersonProfileStore` | Rich person profiles | Sensitive relationship data |
| `AffectSnapshotStore` | Structured mood/affect evidence | Highly sensitive |
| `PlaceProfileStore` | Place profiles | Location-sensitive |
| `EntityNodeStore` | Graph nodes | Personal graph |
| `EntityEdgeStore` | Graph relationships | Personal graph |
| `ArtifactEntityLinkStore` | Artifact-to-entity evidence | Personal graph |
| `EntityProfileStore` | Generic entity profiles | Personal |
| `CorrectionEventStore` | User corrections/rejects | Personal preference and correction history |
| `EntityTombstoneStore` | Merge/delete replacement records | Graph integrity |
| `ClarificationQuestionStore` | Questions for user | Personal |
| `IntelligenceJobStore` | Local intelligence/background jobs | Operational |
| `GraphDeltaStore` | Staged/applied graph proposals | AI-derived |
| `ReflectionSnapshotStore` | Reflections | Personal/AI-derived |
| `TemporalArcStore` | Story arcs | Personal/AI-derived |
| `NotificationIntentStore` | Local notification intents | Operational/personal |
| Preference stores | Settings, detail presentation, quality, home board, intelligence | User settings |
| Composition stores | Home board/composition signals | Product state |

## Server SQLite Tables

| Table | Purpose |
| --- | --- |
| `push_tokens` | APNs token, device id, notification preferences |
| `push_deliveries` | Queued/delivered remote push intents |
| `push_delivery_events` | Delivery/open/action writeback events |
| `user_profiles` | Server-side onboarding/profile account state |

## Data Ownership Rules

- Local memory, artifact, semantic digest, arrangement, self profile, people profile, affect, and graph data are the primary product truth.
- Card object metrics are derived render policy, not stored fact data.
- Server is currently used for auth, AI inference, subscription verification, metrics, and push delivery.
- Sensitive local data should not be sent unless included in a context pack or specific request path.
- Context pack privacy gates must be treated as product-critical, not just prompt tuning.

## Deletion And Migration Concerns

When deleting a memory, all dependent artifacts, analysis, graph links, affect snapshots, reflections, jobs, questions, and status must be considered. When merging/splitting people or places, links, profiles, source IDs, arcs, reflections, and tombstones must remain consistent.

## Current Database Gaps

1. There is no single product-level provenance table for import sessions.
2. Billing entitlements are not stored locally as a first-class feature gate snapshot.
3. Server subscription status is not integrated into local feature access decisions.
4. Some AI/debug trace fields are stored in pipeline status and should be treated as debug-sensitive.
