# 08. Graph Delta v2 And Mutations

## 1. Problem

v6 has GraphDelta concepts, but execution coverage is narrow. v7 needs a general mutation layer that can safely apply, reject, undo, and recompute identity/profile changes.

## 2. Mutation Types

```swift
enum GraphMutationKind: String, Codable, Sendable {
    case addEntity
    case updateEntityAlias
    case updateRelationshipToUser
    case mergeEntity
    case splitEntity
    case markAsSelf
    case addNegativeEvidence
    case updateProfileField
    case addProfilePortrait
    case updateAffectSnapshot
    case addArcCandidate
    case addReflectionCandidate
    case suppressTopic
}
```

## 3. Proposal vs Applied State

Separate tables/collections:

- `GraphProposal`: AI or local candidate not yet trusted.
- `GraphMutation`: accepted operation.
- `CorrectionEvent`: user signal that influences future proposals.
- `GraphTombstone`: old ids after merge/split.

This prevents AI from directly changing trusted graph state.

## 4. Transaction Boundary

Each mutation must run in one repository transaction:

1. validate inputs,
2. apply entity/profile/link changes,
3. write audit event,
4. mark affected derived data stale,
5. enqueue recompute jobs,
6. refresh search/index/notification references where needed.

## 5. Merge Rewrite

`mergeEntity(A, B -> Survivor)` must update:

- entity table,
- entity aliases,
- entity edges,
- artifact entity links,
- memory feature references,
- `PersonProfile` / `PlaceProfile` / `ThemeProfile`,
- profile evidence source ids,
- Arc source entity ids,
- Reflection evidence,
- notification intents,
- search index payload,
- correction history target ids.

Loser ids become tombstones.

## 6. Split Rewrite

`splitEntity(A -> A1, A2, ambiguousBucket)` must:

- create new entities,
- assign evidence-backed source records to concrete entities,
- keep uncertain records linked to bucket,
- write provenance for each reassignment,
- schedule profile recompute for all affected entities,
- ask clarification where evidence is insufficient.

## 7. Undo

Undo requires:

- inverse mutation where possible,
- tombstone retention,
- previous link snapshots,
- recompute queue after undo.

Not every mutation is fully reversible after subsequent edits; the UI/debug surface must show reversibility status.

## 8. Acceptance Criteria

- Merge/split works for person, place, theme, decision where supported.
- A wrong merge can be corrected without database reset.
- Derived Arc/Reflection/Profile/Search/Notification references do not remain stale.
- Tests cover merge, split, undo, and recompute enqueue.
