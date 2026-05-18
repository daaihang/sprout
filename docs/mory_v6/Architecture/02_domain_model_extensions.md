# 02. Domain Model Extensions

## 1. Goal

Add new domain models without changing the meaning of existing core models.

Keep:

- `RecordShell` as capture event shell.
- `Artifact` as content material.
- `EntityNode` and `EntityEdge` as graph primitives.
- `TemporalArc` as current stage/storyline object.
- `ReflectionSnapshot` as high-value explanation object.

Add:

- `EntityProfile`
- `ClarificationQuestion`
- `IntelligenceJob`
- `GraphDelta`
- `HomeBoardSignal`
- `NotificationIntent`
- `IntelligencePreference`

## 2. EntityProfile

Purpose:

Stores long-lived user-confirmed or system-inferred profile data for an entity.

Suggested shape:

```swift
struct EntityProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var entityID: UUID
    var kind: EntityKind
    var displayName: String
    var canonicalName: String
    var aliases: [String]
    var relationshipToUser: EntityRelationshipToUser?
    var userDescription: String?
    var mentionCount: Int
    var firstMentionedAt: Date?
    var lastMentionedAt: Date?
    var commonContextLabels: [String]
    var sourceRecordIDs: [UUID]
    var confirmationState: IntelligenceConfirmationState
    var confidence: Double?
    var createdAt: Date
    var updatedAt: Date
}
```

`EntityNode` remains the graph node. `EntityProfile` is the user-facing, enrichment-friendly profile.

## 3. Relationship Enum

Initial controlled relationship options:

```swift
enum EntityRelationshipToUser: String, Codable, CaseIterable, Sendable {
    case family
    case partner
    case friend
    case coworker
    case manager
    case directReport
    case classmate
    case client
    case acquaintance
    case creator
    case publicFigure
    case other
    case unknown
}
```

Do not overfit in v6. User description can hold nuance.

## 4. ClarificationQuestion

Purpose:

Represents a structured question Mory wants to ask the user.

Suggested shape:

```swift
struct ClarificationQuestion: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: ClarificationQuestionKind
    var prompt: String
    var targetType: ClarificationTargetType
    var targetID: UUID
    var sourceRecordIDs: [UUID]
    var sourceArtifactIDs: [UUID]
    var candidateAnswers: [ClarificationAnswerOption]
    var priority: Double
    var reason: String
    var sensitivity: QuestionSensitivity
    var status: ClarificationQuestionStatus
    var createdAt: Date
    var expiresAt: Date?
    var answeredAt: Date?
    var dismissedAt: Date?
    var askCount: Int
}
```

## 5. IntelligenceJob

Purpose:

Tracks background or deferred intelligence work.

Suggested shape:

```swift
struct IntelligenceJob: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: IntelligenceJobKind
    var targetType: IntelligenceTargetType
    var targetID: UUID
    var status: IntelligenceJobStatus
    var priority: Double
    var attemptCount: Int
    var lastError: String?
    var scheduledAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var updatedAt: Date
    var dedupeKey: String
    var requiresCloudAI: Bool
}
```

## 6. GraphDelta

Purpose:

Represents structured changes derived from AI, local rules, or user confirmation.

Suggested shape:

```swift
struct GraphDelta: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var source: GraphDeltaSource
    var operations: [GraphDeltaOperation]
    var confidence: Double?
    var requiresUserConfirmation: Bool
    var appliedAt: Date?
    var createdAt: Date
}
```

Operations:

```text
addAlias
setRelationship
mergeEntity
addEdge
updateEdgeWeight
createChapterCandidate
markDecisionStatus
```

## 7. HomeBoardSignal

Purpose:

Passes intelligent suggestion signals into the existing HomeBoardRuleEngine without coupling it directly to every intelligence store.

Suggested fields:

```text
id
kind
targetType
targetID
sourceRecordIDs
title
subtitle
priority
reason
suggestedWidthColumns
suggestedHeightUnits
createdAt
expiresAt
```

## 8. NotificationIntent

Purpose:

Represents a local or remote notification candidate.

Suggested fields:

```text
id
kind
title
body
privacyLevel
targetType
targetID
scheduledAt
status
deliveryChannel
createdAt
deliveredAt
dismissedAt
```

## 9. Confirmation State

Common enum:

```swift
enum IntelligenceConfirmationState: String, Codable, Sendable {
    case inferred
    case suggested
    case userConfirmed
    case userRejected
    case stale
}
```

## 10. Model Boundary Rules

- `EntityProfile` can reference `EntityNode`, but does not replace it.
- `ClarificationQuestion` can reference any domain object by target type and ID.
- `GraphDelta` is the bridge between AI/local suggestions and trusted graph state.
- User answers should update profiles and graph through deltas, not by ad hoc view code.
- Notification intents should not store full private memory text unless the user enables rich previews.

