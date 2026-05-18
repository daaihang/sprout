# 07. Testing, Observability, And Rollout

## 1. Goal

V6 adds a lot of intelligence. It must be observable and testable or it will feel random.

## 2. Test Categories

### 2.1 Unit Tests

Add tests for:

- Clarification question builder.
- Entity profile updater.
- Graph delta applier.
- Job deduplication.
- Question cooldown.
- Notification policy.
- Home board signal ranking.
- Core Spotlight item builder.

### 2.2 Repository Tests

Add tests for:

- Store mapper roundtrip.
- Question answer persistence.
- Entity profile upsert.
- Delete memory invalidation.
- Refresh pipeline stale question behavior.
- Home board includes questions when eligible.

### 2.3 UI Tests

Add or manually verify:

- Home question card appears.
- User can answer relationship question.
- User can dismiss question.
- Search fallback still works.
- Settings AI controls visible.
- Dynamic Type on grid cards.

### 2.4 Go Tests

Add tests for:

- New intelligence endpoints.
- Rate limit behavior.
- Notification preference storage.
- APNs client mock.
- Privacy-safe logging if testable.

## 3. Observability

Internal diagnostics should show:

- Pending intelligence jobs.
- Failed intelligence jobs.
- Generated questions.
- Dismissed questions.
- Entity profiles.
- Graph deltas.
- Home board signals.
- Spotlight index status.
- Notification intents.

Do not require Debug for normal use, but Debug should help explain behavior.

## 4. Product Debug Copy

For internal builds, each AI-derived card should show:

- Kind.
- Reason.
- Priority.
- Source record IDs.
- Target ID.
- Whether cloud AI was used.
- Confidence.
- User preference impact.

## 5. Rollout Plan

### Phase 0: Documentation And Tooling

- Land v6 docs.
- Restore Go toolchain.
- Confirm iOS tests pass.
- Confirm clean git ignore state.

### Phase 1: Domain And Persistence

- Add domain models.
- Add SwiftData stores.
- Add mappers.
- Add repository methods.
- Add tests.

### Phase 2: First Intelligence Loop

- Person entity profile.
- Relationship clarification question.
- Home card.
- Answer flow.
- Profile update.

### Phase 3: Home Grid

- Custom SwiftUI Layout.
- Fixed card spans.
- User layer vs suggestion layer.
- Pin/hide/dismiss/resize.

### Phase 4: Semantic Search

- Spotlight index builder.
- Index updates.
- CSUserQuery search path.
- Fallback merger.

### Phase 5: Notifications And Daily Questions

- Daily question engine.
- Notification preferences.
- Local notifications.
- Remote push only if needed.

### Phase 6: Multimedia Views

- Film gallery.
- Storage jar.
- Sticker wall.
- Chapter panels.

## 6. Acceptance Commands

iOS:

```bash
xcodebuild -project /Users/z14/Documents/sprout/mory/mory.xcodeproj -scheme mory -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project /Users/z14/Documents/sprout/mory/mory.xcodeproj -scheme mory -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
jq empty /Users/z14/Documents/sprout/mory/mory/Localizable.xcstrings
plutil -lint /Users/z14/Documents/sprout/mory/mory/Info.plist
```

Go:

```bash
cd /Users/z14/Documents/sprout/server
go test ./...
```

Docs:

```bash
find /Users/z14/Documents/sprout/docs/mory_v6 -type f | sort
git diff --check
```

## 7. Release Readiness

V6 beta should not ship unless:

- Capture remains reliable.
- Existing memories open correctly.
- User layout persists.
- Questions can be answered and dismissed.
- Cloud AI settings exist.
- Search fallback works.
- Local data clearing clears intelligence stores.
- New migrations do not destroy v5 data.

