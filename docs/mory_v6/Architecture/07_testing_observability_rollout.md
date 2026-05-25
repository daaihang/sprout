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

Current implementation status:

- The in-app Diagnostics route now includes a V6 Debug Center spine:
  - Cloud Intelligence Debug can manually run transcript refinement, question suggestion, chapter/stage suggestion, and photo semantic placeholder analysis. It shows decoded results, provider/model metadata, token usage where returned, request IDs, and the latest transport error trace where available. Notification generation is inspected in Notification Management instead of Cloud Intelligence Debug.
  - Job Queue Debug shows intelligence jobs, notification intents, graph deltas, status/kind counts, due pending jobs, cloud-required jobs, and manual worker/recovery actions.
  - Semantic Search Debug runs exact local search, semantic-first Core Spotlight search, Spotlight rebuild, and Spotlight delete while showing retrieval sources and semantic status.
  - Home Board Debug exposes memory desktop rule inputs, card layers, spans, reasons, source records, and preference actions before the formal UI polish pass.
- The Debug Center intentionally uses plain native List/Form-style controls. It is a business/data observability tool, not the final V6 visual system.

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
- Internal Debug Center can explain cloud intelligence, job queue, semantic search, home board, and notification behavior without requiring direct database inspection.
