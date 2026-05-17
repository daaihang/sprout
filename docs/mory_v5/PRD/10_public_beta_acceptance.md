# 10. Public Beta Acceptance

## 1. Purpose

This document defines the v5 public beta readiness bar.

The public beta should feel unfinished only in the sense that more features are coming. It should not feel unfinished because navigation, capture, settings, or privacy controls are missing.

## 2. Release Gates

### 2.1 Product Gates

- [ ] App has exactly three public tabs: Today, Memories, Insights.
- [ ] Quick capture toolbar appears above tab bar.
- [ ] Tap text capture works from all tabs.
- [ ] Press-hold voice capture works from all tabs.
- [ ] Account / Settings is reachable from all tabs.
- [ ] Today Board uses typed cards and real data.
- [ ] Memories supports browsing, detail, search, and filters.
- [ ] Insights unifies storylines, reflections, people, places, themes, decisions.
- [ ] Public app does not require Debug knowledge.

### 2.2 Trust Gates

- [ ] Privacy explanation exists.
- [ ] Permission states are visible.
- [ ] Denied permissions have recovery paths.
- [ ] Sign out exists.
- [ ] Data export/delete local data controls exist or are clearly staged.
- [ ] AI-derived surfaces show source memory access.

### 2.3 Technical Gates

- [ ] Full iOS test passes.
- [ ] Core quality batch can run in local test mode.
- [ ] App launches on simulator and real device.
- [ ] No blocking SwiftData migration failure.
- [ ] No known recording stop deadlock.
- [ ] No orphan derived data appears in product UI.

### 2.4 UX Gates

- [ ] Main UI no longer looks like a default List prototype.
- [ ] Empty states are polished.
- [ ] Cards have distinct visual language.
- [ ] Buttons have clear icons/labels.
- [ ] Text fits at standard and large Dynamic Type.
- [ ] VoiceOver labels exist for toolbar controls.
- [ ] Reduced Motion is respected.

## 3. Manual Smoke Test

### 3.1 New User

1. Install app.
2. Sign in or local mode.
3. Reach Today.
4. Add text memory.
5. Add voice memory.
6. Open Memories.
7. Search for text.
8. Open Settings.
9. Inspect permissions.
10. Sign out or verify account state.

### 3.2 Returning User

1. Relaunch app.
2. Confirm account/session persists.
3. Open Today.
4. Pin/hide/dismiss a board card.
5. Relaunch and confirm preference persists.
6. Open Insights.
7. Open storyline/reflection and inspect sources.

### 3.3 Failure Recovery

1. Disable microphone permission.
2. Attempt voice capture.
3. Confirm recovery copy.
4. Disable location permission.
5. Open composer.
6. Confirm capture still works.
7. Force or simulate analysis failure.
8. Confirm retry path.

## 4. Release Blockers

Block public beta if:

- Voice capture can get stuck.
- Settings is missing.
- User cannot sign out or understand account state.
- Permissions are invisible outside Debug.
- Today card tap navigates to wrong destination.
- Deleting/editing memories leaves visible stale insights.
- Main UI still exposes raw debug structure.
- Full iOS test fails.

## 5. Acceptable Beta Limitations

Allowed for beta:

- Some advanced filters incomplete.
- Some insight categories sparse.
- No drag-and-drop board layout.
- No cloud sync.
- No subscription.
- No share extension.
- Some visual polish still improving.

Not allowed for beta:

- Missing capture.
- Missing settings.
- Missing privacy explanation.
- Broken navigation.
- Recording deadlock.
- Unrecoverable failed analysis.

