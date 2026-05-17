# 08. Rollout, Test, And Migration Plan

## 1. Rollout Phases

### Phase A: Shell And Settings

Deliver:

- Three-tab shell.
- Global quick toolbar placeholder.
- Account / Settings skeleton.
- Settings route model.
- Basic design tokens.

Tests:

- Build.
- Navigation smoke.
- Settings opens from each tab.

### Phase B: Quick Capture

Deliver:

- Tap text capture.
- Press-hold voice capture state machine.
- Composer presentation cleanup.
- Permission recovery.

Tests:

- Audio state unit tests.
- Capture save regression.
- Manual simulator voice capture.

### Phase C: Surface Redesign

Deliver:

- Today Board visual system.
- Memories library visual system.
- Insights landing and lists.
- Type-specific cards.

Tests:

- Today board rule tests.
- Snapshot/manual visual QA.
- Navigation route tests.

### Phase D: Public Beta Polish

Deliver:

- Onboarding.
- Empty states.
- Settings data/export/privacy.
- Accessibility.
- Localization.
- Real device smoke.

Tests:

- Full iOS tests.
- Local quality batch.
- Real device permissions.
- Public beta checklist.

## 2. Migration Safety

Allowed schema changes:

- Settings preference store.
- Additional presentation preference stores.
- Non-destructive fields with defaults.

Avoid:

- Destructive memory schema changes.
- Rewriting derived data format for UI-only reasons.
- Required cloud migration.

## 3. Test Commands

Core:

```bash
xcodebuild -project /Users/z14/Documents/sprout/mory/mory.xcodeproj -scheme mory -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Targeted:

```bash
xcodebuild -project /Users/z14/Documents/sprout/mory/mory.xcodeproj -scheme mory -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:moryTests/MoryMemoryRepositoryCompositionTests test
```

Local quality batch:

```bash
touch /tmp/mory-run-local-quality-batch.flag
xcodebuild -project /Users/z14/Documents/sprout/mory/mory.xcodeproj -scheme mory -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:moryTests/QualityTuningLocalBatchTests test
rm -f /tmp/mory-run-local-quality-batch.flag
```

## 4. Manual QA Matrix

| Area | Must Verify |
|------|-------------|
| Shell | Three tabs, global settings, global capture |
| Capture | Text, voice, photo, link, location, context |
| Today | Card rendering, pin/hide/dismiss, navigation |
| Memories | List, search, filters, detail, edit/rerun |
| Insights | Storylines, reflections, people, places, themes, decisions |
| Settings | Account, permissions, privacy, language, appearance, data |
| Accessibility | Dynamic Type, VoiceOver labels, Reduce Motion |
| Real device | Permissions, MusicKit, WeatherKit, Speech, microphone, photos |

## 5. Release Criteria

v5 public beta requires:

- Full iOS tests passing.
- No release-blocking voice capture bugs.
- No public dependency on Debug.
- Settings complete enough for account/privacy/permissions.
- Today Board understandable without developer explanation.
- Capture path fast and reliable.

