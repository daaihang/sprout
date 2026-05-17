# 01. Presentation Architecture

## 1. Goal

v5 needs a cleaner presentation architecture so the UI can become polished without creating fragile giant SwiftUI files.

## 2. Presentation Layers

### 2.1 App Shell

Owns:

- Three-tab structure.
- Global quick capture toolbar.
- Settings presentation.
- Global route coordination.

Does not own:

- Feature-specific data loading.
- AI logic.
- Capture internals.

### 2.2 Feature Screens

Feature screens:

- TodayScreen.
- MemoriesScreen.
- InsightsScreen.
- SettingsScreen.
- CaptureComposerView.

Each feature should:

- Load its own snapshot.
- Render reusable components.
- Expose actions upward only when needed.

### 2.3 Components

Reusable component groups:

- Board cards.
- Memory rows.
- Insight rows.
- Context chips.
- Permission rows.
- Quick toolbar controls.
- Empty states.
- Loading/error/retry surfaces.

### 2.4 Presentation Snapshots

Use snapshots to decouple UI from repository internals:

- `TodayPresentationSnapshot`
- `MemoryLibrarySnapshot`
- `InsightsPresentationSnapshot`
- `SettingsSnapshot`
- `CaptureDraftPresentationState`

Snapshots should be value types and Sendable where practical.

## 3. View Model Strategy

SwiftUI views may use lightweight state directly for simple screens.

Use a view model when:

- State machine has more than four states.
- Multiple async tasks can overlap.
- A view owns permission/request/retry behavior.
- UI needs derived presentation state.

Required view models:

- QuickCaptureToolbarModel.
- AudioCaptureModel.
- SettingsViewModel.
- TodayViewModel or TodayDataController.

Optional:

- MemoriesFilterModel.
- InsightsFilterModel.

## 4. Avoiding Large Files

Targets:

- Primary screens under 350 lines.
- Complex components under 200 lines.
- State machines in separate files.
- Design tokens in shared files.

Files currently above this threshold should be split gradually:

- Home screen.
- Capture composer.
- Memory detail.
- Debug diagnostics can remain larger if internal only, but new debug sections should be extracted when practical.

## 5. Data Flow

Standard flow:

```text
Repository -> Domain Snapshot -> Presentation Snapshot -> View Components
```

Actions:

```text
View -> ViewModel/Feature Controller -> Repository -> Reload Snapshot
```

Rules:

- Product UI consumes filtered repository methods.
- Debug UI may consume raw diagnostics.
- Mutations reload the affected snapshot after save.

## 6. Error Handling

Public UI errors should be:

- Short.
- Recoverable.
- Not raw JSON.
- Not raw server stack traces.

Internal builds may expose raw traces in Debug.

## 7. Acceptance Criteria

- App shell can host three tabs and global toolbar.
- Settings is independent from Debug.
- Capture components are reusable.
- Today card rendering does not duplicate ranking rules.
- UI files are split enough for safe visual iteration.

