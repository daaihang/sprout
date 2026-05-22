# 18. Repository And UI Boundaries

## 1. Purpose

The user may use one AI agent for architecture/business code and another for UI. v7 must define boundaries so UI work cannot accidentally own durable intelligence logic.

## 2. Ownership Rules

| Layer | Owns | Must not own |
| --- | --- | --- |
| Domain models | identity, profile, affect, mutation types | SwiftUI layout |
| Repository | durable mutations, transactions, invalidation | visual presentation |
| Infrastructure | AI contracts, background jobs, notification scheduling | user-facing copy polish |
| View models | display state, actions, loading/error mapping | trusted graph facts |
| SwiftUI views | layout and interaction controls | merge/split/profile business rules |
| Debug UI | inspect, replay, manually trigger | hidden production-only state |

## 3. Architecture Agent Scope

Architecture/business-code work should implement:

- models,
- repositories,
- mutation APIs,
- context pack builder,
- resolver,
- job scheduler,
- notification policy,
- server contracts,
- tests,
- debug hooks.

## 4. UI Agent Scope

UI work can implement:

- cards,
- sheets,
- detail panels,
- profile edit surfaces,
- context pack viewers,
- notification settings UI,
- correction controls.

UI must call domain actions such as:

- `applyCorrectionEvent`,
- `proposeEntityMerge`,
- `applyGraphMutation`,
- `updatePersonProfileField`,
- `setAffectCorrection`,
- `prepareNotificationIntent`.

UI must not:

- directly rewrite graph links,
- merge entities locally in view state,
- construct cloud payloads,
- bypass privacy gate,
- persist AI proposals as facts.

## 5. View Model Contract Pattern

```swift
struct PersonProfileViewState {
    var profile: PersonProfile
    var proposals: [GraphProposal]
    var evidence: [ProfileFieldEvidence]
    var canEdit: Bool
}

enum PersonProfileAction {
    case editField(ProfileFieldEdit)
    case acceptProposal(UUID)
    case rejectProposal(UUID)
    case markFieldWrong(String)
    case mergeWith(UUID)
    case split(SplitDraft)
}
```

View model maps action to repository mutation. It does not perform mutation itself.

## 6. Debug-First UI

Before final UI polish, v7 should expose:

- context pack viewer,
- profile diff viewer,
- graph mutation ledger,
- notification trace,
- job dashboard.

These views can be plain. Their job is correctness and inspectability.

## 7. Acceptance Criteria

- A UI-only change cannot change graph/profile semantics.
- Repository tests cover all durable intelligence actions.
- Debug UI can replay or inspect without owning business logic.
- Architecture and UI agents can work in parallel with stable contracts.
