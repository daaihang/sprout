# 09. Acceptance Metrics And Release Scope

## 1. V6 Success Definition

V6 succeeds when Mory feels useful even when the user has not just written something.

The product should show signs of continuous preparation:

- Questions waiting.
- People/place/theme profiles getting clearer.
- Search retrieving by meaning.
- Yesterday panel ready.
- Home suggestions useful but controlled.
- Notifications appearing at a user-acceptable cadence.

## 2. P0 Scope

Required for v6 core:

- Intelligence domain models.
- SwiftData stores.
- Post-analysis job creation.
- Clarification question queue.
- Entity profile extension for people.
- Home card for clarification question.
- User answer flow.
- Settings controls for AI and notification frequency.
- Core Spotlight indexing foundation.

## 3. P1 Scope

Strongly recommended:

- SwiftUI home grid layout.
- Fixed card sizes.
- Semantic search using Core Spotlight.
- Daily question engine.
- Local notification scheduling.
- Voice transcript refinement endpoint.
- Chapter candidates.
- Go API contract for V6 intelligence candidates.

## 4. P2 Scope

Future-friendly:

- Film gallery.
- Storage jar.
- Sticker wall.
- Remote APNs sending.
- Core ML model integration beyond rules.
- Full chapter editing.
- Board edit mode drag and resize polish.

## 5. Product Metrics

| Metric | Target |
| --- | --- |
| Question answer rate | > 30% of shown clarification questions |
| Question dismissal repeat rate | Dismissed question does not reappear within cooldown |
| Search success | User opens a result after semantic search in > 40% of non-empty searches |
| Home suggestion adoption | > 15% of suggestion cards are added/opened |
| Notification disable rate | Does not exceed 25% after opt-in |
| Cloud AI clarity | User can find processing settings in one or two taps |

## 6. Technical Metrics

| Metric | Target |
| --- | --- |
| Home first render | < 1 second for existing data |
| Local question generation | < 500 ms for normal library size |
| Core Spotlight indexing | Incremental update after save |
| Analysis failure recovery | Failed jobs visible and retryable |
| Migration safety | Existing v5 data opens without destructive migration |
| Tests | Full iOS tests pass; Go tests pass when toolchain available |

## 7. Release Gates

Block v6 beta if:

- Existing capture breaks.
- Existing memory detail breaks.
- Memories search entry cannot open.
- User layout is silently lost.
- AI modifies original content without preserving source.
- Question cards cannot be dismissed.
- Cloud AI setting is missing.
- SwiftData migration fails on existing data.

Acceptable beta limitations:

- Only person profiles are enriched in first beta.
- Core ML starts with local rules if model is not ready.
- Remote push can be staged after local notifications.
- Drag reorder can be edit-mode only.
- Multimedia views can ship one at a time.
