# 02. Entity Resolution And Correction

## 1. Problem

v6 graph reuse is mostly text equality based: same kind + same display/canonical/alias. This is not enough for personal memory.

Common failures:

- `Alex` and `Alexander Chen` may be the same person.
- `Alex` may also be two different people.
- `舍友` is a role, not necessarily one person.
- `我妈` should resolve through `SelfProfile`, not a new generic person.
- A wrong merge can poison future Profile, Arc, Reflection, and notification triggers.

v7 needs a first-class `EntityResolutionService` plus correction ledger.

## 2. Resolution Types

| Type | Meaning | Example |
| --- | --- | --- |
| `samePersonCandidate` | two entities may be the same person | `Alex` + `Alexander Chen` |
| `notSameDecision` | user/system knows two entities are different | two different coworkers named Alex |
| `roleLabel` | text describes a role relative to user | `舍友`, `老板`, `导师` |
| `ambiguousEntityBucket` | label points to multiple possible people | `舍友` could be A or B |
| `mergeCandidate` | enough evidence to propose merge | same name, same place, same relationship |
| `splitCandidate` | one entity likely contains multiple people | `Alex` appears as boyfriend and coworker |
| `tombstone` | old entity id retained after merge/split for history | merged duplicate |

## 3. EntityResolutionService

```swift
protocol EntityResolutionService {
    func resolve(
        mentions: [EntityMention],
        context: EntityResolutionContext
    ) async throws -> EntityResolutionResult
}
```

Context:

- current record text and artifacts,
- `SelfProfile`,
- existing `EntityProfileV2` records,
- recent correction events,
- co-occurring people/places/themes,
- related memory snippets,
- negative merge evidence.

Result:

- resolved entity links,
- ambiguous buckets,
- merge/split candidates,
- questions to ask user,
- confidence per decision.

## 4. CorrectionEvent

Corrections are domain data. They are not view-only flags.

```swift
enum CorrectionEventKind: String, Codable, Sendable {
    case markAsMe
    case notMe
    case sameEntity
    case notSameEntity
    case splitEntity
    case roleLabel
    case roleLabelMapsToPerson
    case relationshipChanged
    case profileFieldIncorrect
    case doNotTrackTopic
    case affectCorrection
}
```

Each event stores:

- actor: user / local policy / AI proposal accepted,
- target ids,
- source memory ids,
- freeform note,
- timestamp,
- reversibility metadata.

## 5. Merge Policy

AI may produce `mergeCandidate`, but only policy can apply it.

Auto-apply is allowed only when:

- same canonical id from trusted source, or
- user explicitly confirms, or
- local deterministic rule is high confidence and reversible.

Everything else becomes a proposal.

Merge must rewrite:

- entity nodes,
- edges,
- artifact links,
- profile source ids,
- Arc source entity ids,
- Reflection evidence entity ids,
- notification intent references,
- search index payloads.

The old id becomes a tombstone pointing to the survivor.

## 6. Split Policy

Split is required for overloaded labels.

Example:

```text
Entity "舍友"
  evidence A: cooking, apartment, person Lily
  evidence B: rent payment, apartment, person Max
```

v7 should create:

- `roleLabel`: roommate,
- `ambiguousEntityBucket`: roommate group,
- concrete person links only where evidence supports them.

Split must preserve source memory provenance so older memories are not silently rewritten without audit.

## 7. Questions Generated From Resolution

Supported question shapes:

- “这里的 Alex 是不是你之前提到的 Alexander Chen?”
- “你说的舍友是 Lily、Max，还是暂时不确定?”
- “这个人是你自己吗?”
- “这两个人不是同一个，对吗?”
- “这个关系现在变了吗?”

Every question must support:

- fixed candidates,
- freeform answer,
- `not sure`,
- `do not ask again for this label`.

## 8. Acceptance Criteria

- Person merge/split exists at repository mutation level, not just UI.
- Role labels can remain unresolved without becoming wrong people.
- Negative evidence prevents repeated bad merges.
- User corrections feed future Analyze context packs.
- Graph rewrite has unit tests for links, edges, profiles, arcs, reflections, notifications, and search index invalidation.
