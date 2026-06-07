# 04. SwiftUI Home Masonry And UI System

## 1. Goal

Replace the home `List` surface with a native SwiftUI spatial board that supports user-owned layout and AI suggestions.

## 2. Current Gap

Current `HomeScreen` uses:

```text
List
  Section
    HomeBoardSection
      ForEach(board.items)
```

`CompositionItem` already has ordering and presentation hints:

```text
userSortIndex
zIndex
rotationDegrees
scale
isHidden
```

The UI should derive masonry frames at render time instead of persisting spatial coordinates.

## 3. Recommended SwiftUI Architecture

Use:

```text
ScrollView
  HomeBoardMasonryLayout(metrics: .default)
    ForEach(items)
      HomeBoardCard(...)
```

Native APIs:

- `Layout` protocol for masonry placement.
- Measured subview height for adaptive cards.
- `ViewThatFits` for card internals.
- `Menu` for card actions.
- `Button` and native controls for actions.

Avoid:

- `List` for the main board.
- `LazyVGrid` as the primary layout if adaptive masonry columns are needed.
- Pixel-level persisted frames.
- Freeform canvas in v6 alpha.

## 4. Why Custom `Layout`

`LazyVGrid` is excellent for regular grids, but weak for waterfall placement with adaptive card heights.

`Grid` supports explicit row/column structure, but is less suited to shortest-column placement.

Custom `Layout` is the native SwiftUI solution for:

- Fixed column width with responsive column count.
- Adaptive card heights.
- Shortest-column placement.
- Stable sizing.
- User-owned ordering.
- Future edit mode.

## 5. Board Layers

View structure:

```text
HomeScreen
  HomeBoardScrollView
    UserBoardSection
      HomeBoardMasonryLayout
    AssistantSuggestionSection
      SuggestionRail/Masonry
```

User board and suggestions should be visually related but semantically separate.

## 6. Card Action Model

Actions:

- Open.
- Pin/unpin.
- Hide.
- Dismiss.
- Add suggestion to board.
- Less like this.
- More like this.
- Explain why.

Use native `Menu` for normal mode. Use edit mode for ordering and future visual decoration controls.

## 7. Card Component Model

Recommended files:

```text
Features/Home/Layout/HomeBoardMasonryLayout.swift
Features/Home/Layout/HomeBoardItemLayout.swift
Domain/BoardLayout/MoryMasonryLayout.swift
Features/Home/Cards/HomeMemoryCard.swift
Features/Home/Cards/HomeQuestionCard.swift
Features/Home/Cards/HomeSystemCard.swift
Features/Home/Cards/HomeChapterCandidateCard.swift
Features/Home/Cards/HomeSuggestionCard.swift
```

## 8. Accessibility

Every card needs:

- Accessibility label.
- Accessibility hint for primary action.
- Custom actions for pin/hide/dismiss when useful.
- Dynamic Type layout checks.
- Reduce Motion support for board transitions.

## 9. Layout Algorithm

Initial packing:

```text
for item in sortedItems:
  clamp span to available columns
  find first row where span fits
  place item
```

Rules:

- Pinned/user-placed items sort before suggestions.
- User order is respected.
- Suggested cards never occupy user-owned positions unless accepted.
- Hidden cards are excluded.
- Oversized cards clamp to column count.

## 10. Persistence

Persist:

- Card key.
- Board key.
- Width columns.
- Height units.
- User order.
- Pinned state.
- Hidden state.
- Dismissed state.
- Last user updated time.

Do not persist:

- Pixel frames.
- Animation state.
- Transient drag state.

## 11. Acceptance Criteria

- Home no longer looks like a generic list.
- Board supports responsive masonry column counts.
- Fixed column width and adaptive card heights are respected.
- User preferences persist.
- AI suggestions do not alter user-owned layout.
- VoiceOver and Dynamic Type remain usable.
