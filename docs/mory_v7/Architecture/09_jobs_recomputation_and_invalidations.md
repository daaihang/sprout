# 09. Jobs, Recomputation, And Invalidations

## 1. Problem

Long-term intelligence creates derived data. When the user edits a memory, deletes an artifact, answers a question, or merges people, old derived insights may become stale.

v7 needs explicit invalidation and recomputation policy.

## 2. Derived Data Classes

| Derived data | Source | Invalidated by |
| --- | --- | --- |
| Analysis summary | record + artifacts + context pack | memory edit, artifact edit, context policy change |
| Entity links | analysis + resolver | memory edit, entity correction, merge/split |
| PersonProfile | entity links + evidence | new mention, correction, memory delete, merge/split |
| Arc | related memories/entities | record delete/edit, entity merge/split, new high-salience memory |
| Reflection | arc + evidence | arc update, correction, source delete |
| Search index | record/artifact/analysis/profile | any source text/profile/link mutation |
| Notification intent | profile/reflection/question/policy | interaction, quiet hours, sensitive change, source stale |

## 3. Job Types

```swift
enum IntelligenceJobKind: String, Codable, Sendable {
    case analyzeRecordV7
    case buildContextPack
    case resolveEntities
    case refreshPersonProfile
    case refreshSelfProfile
    case refreshArc
    case refreshReflection
    case rebuildSearchIndex
    case prepareNotificationIntent
    case syncRemotePushState
}
```

## 4. Invalidation Events

```swift
enum InvalidationEventKind: String, Codable, Sendable {
    case memoryCreated
    case memoryEdited
    case memoryDeleted
    case artifactEdited
    case questionAnswered
    case entityMerged
    case entitySplit
    case profileEdited
    case affectCorrected
    case privacyPolicyChanged
}
```

## 5. Recompute Policy

Rules:

- recompute smallest affected scope first,
- mark stale immediately,
- batch low-priority recompute,
- keep user-visible old result with stale badge if safe,
- remove or hide unsafe stale results,
- avoid repeated cloud calls if local recompute is enough.

## 6. Background Execution

Job scheduler chooses execution mode:

| Job | Preferred mode |
| --- | --- |
| small local invalidation | foreground/launch recovery |
| daily question preparation | BGAppRefresh + launch fallback |
| profile/arc recompute | BGProcessing + foreground fallback |
| cloud analyze | foreground if immediate, background URLSession/server job if deferred |
| remote push state | BGAppRefresh + APNs callback |

## 7. Debug Surface

Add job dashboard:

- pending jobs,
- stale objects,
- last failure,
- retry count,
- source invalidation event,
- background eligibility,
- manual run action.

## 8. Acceptance Criteria

- Editing/deleting a memory invalidates dependent profiles/arcs/reflections.
- Entity merge/split schedules all required rewrites and recomputes.
- Jobs are idempotent and bounded.
- Debug UI can explain why an insight is stale.
