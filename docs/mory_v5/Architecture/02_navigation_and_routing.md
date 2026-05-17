# 02. Navigation And Routing

## 1. Goal

Navigation must be predictable.

Complex SwiftUI boards should not embed many nested NavigationLinks. v5 should use typed routes for primary surfaces and detail destinations.

## 2. App Route Types

Recommended route model:

```swift
enum AppTab: Hashable {
    case today
    case memories
    case insights
}

enum AppRoute: Hashable, Identifiable {
    case memory(UUID)
    case artifact(UUID)
    case storyline(UUID)
    case reflection(UUID)
    case entity(UUID)
    case settings(SettingsRoute?)
    case capture(CaptureMode)
}
```

Feature-specific routes can wrap or map into `AppRoute`.

## 3. Tab Stack Policy

Each tab owns its own NavigationStack:

- Today stack.
- Memories stack.
- Insights stack.

The selected tab should preserve its local navigation path while switching tabs.

Capture:

- Presented modally.
- Does not modify tab path unless save action explicitly opens saved memory.

Settings:

- Presented modally from top account button.
- Can deep link to section.

## 4. Today Routing

Card tap mapping:

| Card | Route |
|------|-------|
| Memory | `.memory(recordID)` |
| Storyline | `.storyline(arcID)` |
| Reflection | `.reflection(reflectionID)` |
| Context Cluster | `.memories(filter: sourceRecordIDs/context)` future route |
| Pending Action | `.memory(recordID)` |
| System Prompt | action, not detail route |

Rule:

- One tap opens exactly one destination.
- One back returns to Today.

## 5. Memories Routing

Routes:

- Memory list.
- Search results.
- Memory detail.
- Artifact detail.
- Related insight detail.

Memory detail may navigate to:

- Artifact.
- Storyline.
- Reflection.
- Entity.

## 6. Insights Routing

Routes:

- Insights home.
- Storylines list.
- Reflections list.
- People list.
- Places list.
- Themes list.
- Decisions list.
- Detail for each.

Insight details may navigate to source memory details.

## 7. Settings Routing

Settings routes:

- Account.
- Permissions.
- Privacy.
- Capture preferences.
- Appearance.
- Language.
- Data.
- Diagnostics.

Settings should use a local NavigationStack inside the sheet.

## 8. Acceptance Criteria

- Three tab stacks are stable.
- Details do not create extra list destinations.
- Capture does not pollute navigation history.
- Settings is reachable globally.
- Debug routes remain internal.

