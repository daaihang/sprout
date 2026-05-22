# 03. Person Profile And Portrait

## 1. Problem

Current `EntityProfile` is useful but too thin for relationship memory. It stores aliases, relationship text, mention count, context labels, source ids, and confidence. It does not yet model relationship history, interaction patterns, emotional valence, or AI portrait evidence.

v7 separates generic entity storage from person-level understanding.

## 2. PersonProfile

```swift
struct PersonProfile: Codable, Hashable, Sendable {
    var entityID: UUID
    var displayName: String
    var canonicalName: String?
    var aliases: [String]
    var roleLabels: [String]
    var relationshipToUser: RelationshipDescriptor?
    var relationshipHistory: [RelationshipChange]
    var relationshipStrength: Double?
    var importanceScore: Double?
    var interactionFrequency: InteractionFrequency?
    var commonPlaceIDs: [UUID]
    var commonThemeIDs: [UUID]
    var commonDecisionIDs: [UUID]
    var emotionalPattern: PersonAffectPattern?
    var recentChangeSummary: String?
    var userNotes: String?
    var aiPortrait: PersonPortrait?
    var fieldEvidence: [ProfileFieldEvidence]
    var fieldConfidence: [String: Double]
    var sensitivity: ProfileSensitivity
    var lastReviewedAt: Date?
    var updatedAt: Date
}
```

## 3. Person Portrait

`PersonPortrait` is a summarized, evidence-backed view of a person in the user's life.

It may include:

- who this person appears to be,
- relationship trajectory,
- recent interaction pattern,
- recurring contexts,
- affect pattern around this person,
- open uncertainties,
- suggested clarification questions.

It must not include unsupported psychological claims.

## 4. Evidence Rules

Every generated profile field needs:

- source memory ids,
- source artifact ids if applicable,
- evidence snippets,
- generated/confirmed status,
- confidence,
- last refreshed timestamp.

Profile UI and debug tools must show “why Mory thinks this”.

## 5. Refresh Job

`PersonPortraitRefreshJob` runs when:

- new memory mentions the person,
- user answers relationship/alias/same-person question,
- entity merge/split occurs,
- user edits/deletes source memory,
- profile becomes stale.

Inputs:

- current `PersonProfile`,
- related memories from context pack retrieval,
- related arcs/reflections,
- correction events,
- self profile boundary.

Outputs:

- profile update proposal,
- question proposal,
- no-op with reason,
- stale evidence invalidation.

## 6. Edit And Revoke

Users must be able to:

- edit display name,
- add/remove alias,
- change relationship,
- mark profile field wrong,
- hide sensitive relationship from cloud analysis,
- delete AI portrait summary,
- split or merge person,
- freeze profile from automatic AI updates.

Each action writes a mutation/correction event and triggers recompute where needed.

## 7. Acceptance Criteria

- Person profiles are thicker than generic entities.
- AI portrait is proposal-backed and evidence-backed.
- User edits survive future enrichment.
- Profile refresh jobs are deterministic enough for tests.
- Sensitive person fields are excluded from cloud payload unless explicitly allowed.
