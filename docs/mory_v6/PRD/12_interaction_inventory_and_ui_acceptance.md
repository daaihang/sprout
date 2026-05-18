# 12. Interaction Inventory And UI Acceptance

## 1. Purpose

V6 touches almost every surface. This document lists expected interactions and UI acceptance criteria so implementation does not drift.

## 2. App Feeling

Mory should feel:

- Quiet.
- Organized.
- Native.
- Personal.
- Active without being pushy.
- Controllable.

The app should not feel:

- Like a chatbot shell.
- Like a debug database.
- Like a feed that moves without permission.
- Like a form-only admin tool.

## 3. Home Interactions

Home must support:

- Yesterday panel.
- Today board.
- User-pinned cards.
- Assistant-suggested cards.
- Fixed card sizes.
- Edit mode.
- Resize within supported sizes.
- Dismiss suggestion.
- Hide card type.
- "Show more like this" and "show less like this" preferences.

Gesture rules:

- Normal tap opens card target.
- Long press opens menu.
- Drag/reorder should only exist in edit mode if it conflicts with menu.
- Resize should use explicit controls, not ambiguous freeform gestures.

## 4. Capture Interactions

V6 keeps the v5 capture simplification:

- Bottom accessory is visible across tabs unless a later native-safe hiding path is proven.
- Camera shortcut remains fast.
- Center input opens unified composer.
- Voice shortcut can start simple and later grow back into richer press/record behavior.
- Right-side quick check-in remains one-tap context capture if present.

Capture should remain lower-cost than organization.

## 5. Unified Composer Interactions

Composer should support:

- Text input.
- Voice transcript seed.
- Photo attachment.
- Context candidates.
- Save.
- Cancel.
- Error recovery.

Style:

- Prefer native `NavigationStack`, `Form`, `Section`, `TextField`, `TextEditor`, `PhotosPicker`, `Button`, `Toggle`.
- Avoid custom card chrome until V6 visual system is intentionally defined.
- Use clear section titles only where they reduce ambiguity.

## 6. Memory Detail Interactions

Memory detail should support:

- Read complete memory.
- See attachments.
- See context.
- Open photo/audio/link.
- Edit title/body.
- Accept or reject AI suggestions.
- Answer related question.
- See related people/places/themes.
- Search within source material later if needed.

Artifact internals should not dominate the default reading experience.

## 7. Search Interactions

Search should support:

- Tab bar search entry.
- Auto-focus when search tab is selected intentionally.
- Keyboard opens when appropriate.
- Text search fallback.
- Semantic search where available.
- Results grouped by memory, people, places, themes, and chapters.
- Result explanation.

Search should not become multi-turn chat.

Allowed natural-language behavior:

- Query-like phrasing.
- Semantic result matching.
- Suggested filters.
- Follow-up question card after a result, if helpful.

Avoid:

- Chat transcript.
- AI persona response as primary result.
- Invented memories.

## 8. Daily Question Interactions

Daily question can appear:

- On home.
- In notification.
- In yesterday panel.
- In a lightweight sheet.

It should support:

- Answer.
- Skip.
- Change tone preference.
- Mute today's questions.
- See why asked.

Tone preferences:

- Journal prompt.
- Memory revisit.
- Life organization.
- Evidence-based follow-up.
- Reflective/psychological.

## 9. Notification Interactions

Notification types:

- Background task completed.
- Daily question.
- Repeated person/theme.
- Stage forming.
- Important person/place revisit.

Controls:

- Master toggle.
- Per-type toggle.
- Frequency cap.
- Quiet hours.
- Sensitive-topic restriction.
- Preview privacy.

Notification tap should deep link to:

- Question card.
- Memory detail.
- Home panel.
- Chapter candidate.
- Search result.

Current implementation checkpoint:

- Local notification payloads carry intent, kind, target type, and target ID metadata.
- Opening a local notification currently routes to the nearest available tab: Today, Memories, Insights, or Search.
- Exact navigation to a specific question card, memory detail, chapter candidate, or search result is still pending because those tabs do not yet expose shared path-based navigation state.

## 10. Archive View Interactions

Views:

- List.
- Timeline.
- Film gallery.
- Storage jar.
- Sticker wall.
- Chapters.

Rules:

- Each view should use the same underlying memory objects.
- Switching views should not create duplicate state.
- Filters should carry between compatible views when possible.
- Empty states should explain the view, not the whole product.

## 11. Settings Interactions

Settings must expose:

- Local AI.
- Cloud AI.
- Voice refinement.
- Search indexing.
- Notifications.
- Daily question tone.
- Sensitive topic handling.
- Home suggestion preferences.
- Data export/delete.

Settings should use native grouped forms and plain copy.

## 12. Accessibility Acceptance

V6 UI must support:

- Dynamic Type.
- VoiceOver labels.
- Reduced Motion.
- Color contrast.
- Hit targets.
- Keyboard focus for search.
- Meaningful notification copy.

Home grid cards must not become unreadable at large text sizes. If needed, card content should reduce metadata before reducing legibility.

## 13. SwiftUI Native Acceptance

Prefer:

- `NavigationStack`.
- `.searchable`.
- `LazyVGrid` or custom `Layout` for grid.
- `Form` for settings and composer.
- `Menu` for compact actions.
- `PhotosPicker`.
- `LocalAuthentication` later for sensitive surfaces if needed.
- `matchedTransitionSource` only where it improves clarity.

Avoid:

- Custom list rows with unexplained border chrome.
- Nested cards inside cards.
- Manual gesture complexity where edit mode is clearer.
- Hiding native bars with brittle overlays.

## 14. Visual Acceptance

Home:

- Spatial and card-like.
- No random feed motion.
- Suggested cards are visually distinct from pinned cards.
- Dense enough to feel useful.

Composer:

- Native and predictable.
- No decorative friction.

Search:

- Fast and keyboard-first.

Memory views:

- More expressive than forms, but still grounded in system interactions.

## 15. Acceptance Criteria

- Every V6 surface has a defined empty, loading, ready, error, and permission-denied state.
- Home supports user control before AI control.
- Search works without semantic indexing.
- Notifications can be fully silenced.
- Daily questions can be skipped without punishment.
- AI suggestions always have dismiss paths.
- SwiftUI implementation avoids fragile overlay hacks for major navigation surfaces.
