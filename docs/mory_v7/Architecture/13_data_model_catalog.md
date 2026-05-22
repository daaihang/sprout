# 13. Data Model Catalog

## 1. Purpose

v7 adds several domain models. This catalog defines ownership so business code does not collapse into UI-only state.

## 2. New Core Models

| Model | Owner | Persistence | Purpose |
| --- | --- | --- | --- |
| `SelfProfile` | Domain/Intelligence | local SwiftData or repository-backed store | user本人档案 |
| `PersonProfile` | Domain/Intelligence | local persisted profile | relationship/person portrait |
| `AnalysisContextPack` | Infrastructure/Analysis | persisted debug snapshot, not always long-term | Analyze input evidence package |
| `ContextEvidence` | Domain/Capture/Context | attached to record/artifact | source-aware context |
| `AffectSnapshot` | Domain/Capture/Intelligence | record-linked persisted model | structured mood/tone |
| `CorrectionEvent` | Domain/Intelligence | append-only local ledger | user correction as durable signal |
| `GraphProposal` | Domain/Intelligence | pending proposal store | AI/local untrusted candidate |
| `GraphMutation` | Domain/Intelligence | audit/mutation log | trusted applied graph change |
| `GraphTombstone` | Domain/Intelligence | graph metadata | old id after merge/split |
| `InvalidationEvent` | Infrastructure/Jobs | job/recompute store | stale derived data trigger |
| `NotificationInteractionEvent` | Infrastructure/Notifications | notification store | retention/ranking feedback |

## 3. Extended Existing Models

| Existing model | v7 extension |
| --- | --- |
| `RecordShell` | keep raw mood; link to `AffectSnapshot` and context evidence |
| `Artifact` | preserve source/provenance and entity links after mutation |
| `EntityNode` | add identity state, tombstone pointer, resolution metadata |
| `EntityProfile` | evolve or wrap into `EntityProfileV2`; person-specific fields move to `PersonProfile` |
| `HomeBoardCard` | consume proposals/insights; should not own intelligence state |
| `NotificationIntent` | add routing source, sensitivity, interaction writeback |
| `IntelligenceJob` | add v7 job kinds and invalidation source |

## 4. ContextEvidence

```swift
struct ContextEvidence: Codable, Hashable, Sendable {
    var id: UUID
    var recordID: UUID?
    var source: ContextEvidenceSource
    var kind: ContextEvidenceKind
    var summary: String
    var structuredPayload: Data?
    var confidence: Double?
    var userSelected: Bool
    var privacyClass: PrivacyClass
    var createdAt: Date
}
```

Source examples:

- location,
- weather,
- music,
- photo OCR,
- audio transcript,
- Journaling Suggestion,
- App Intent,
- Share Sheet,
- user input,
- local ML.

## 5. GraphProposal

```swift
struct GraphProposal: Codable, Hashable, Sendable {
    var id: UUID
    var kind: GraphMutationKind
    var targetIDs: [UUID]
    var proposedValue: Data?
    var evidence: [EvidenceSnippet]
    var confidence: Double
    var requiresUserConfirmation: Bool
    var source: ProposalSource
    var status: ProposalStatus
    var createdAt: Date
}
```

Proposal statuses:

- pending,
- autoApplied,
- accepted,
- rejected,
- expired,
- superseded.

## 6. CorrectionEvent

`CorrectionEvent` is append-only. It should be cheap to query by target entity, record, affect snapshot, or question.

Important indexes:

- `targetEntityID`,
- `sourceRecordID`,
- `kind`,
- `createdAt`,
- `reversedAt`.

## 7. PrivacyClass

```swift
enum PrivacyClass: String, Codable, Sendable {
    case normal
    case relationshipSensitive
    case healthSensitive
    case locationSensitive
    case identitySensitive
    case localOnly
}
```

Cloud payload builders consult `PrivacyClass` before serialization.

## 8. Migration Strategy

Initial migration should be additive:

1. keep old fields,
2. add new optional models,
3. populate from new records first,
4. backfill only summaries and low-risk fields,
5. keep debug comparison between legacy and v7 analysis.

## 9. Model Boundary Rules

- SwiftUI view models may present, not own, identity facts.
- Repository mutations own durable graph/profile changes.
- AI responses become proposals before trusted state.
- Debug snapshots can store payload previews, but respect privacy settings.
- Deleting/editing source records invalidates derived models.
