# 04. SwiftUI Home Grid And UI System

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

`CompositionItem` already has layout hints:

```text
widthColumns
heightUnits
zIndex
rotationDegrees
scale
isHidden
```

But the UI does not yet use them as a real grid.

## 3. Recommended SwiftUI Architecture

Use:

```text
ScrollView
  HomeBoardGridLayout(columns: 4 or 8)
    ForEach(items)
      HomeBoardCard(...)
        .layoutValue(key: HomeBoardSpanKey.self, value: span)
```

Native APIs:

- `Layout` protocol for packing.
- `LayoutValueKey` for span values.
- `ViewThatFits` for card internals.
- `Menu` for card actions.
- `Button` and native controls for actions.

Avoid:

- `List` for the main board.
- `LazyVGrid` as the primary layout if variable spans are needed.
- Pixel-level persisted frames.
- Freeform canvas in v6 alpha.

## 4. Why Custom `Layout`

`LazyVGrid` is excellent for regular grids, but weak for arbitrary card spans.

`Grid` supports explicit row/column structure, but is less suited to auto-packing dynamic board items.

Custom `Layout` is the native SwiftUI solution for:

- 4/8 column switching.
- Fixed span sizes.
- Auto-placement.
- Stable sizing.
- User-owned ordering.
- Future edit mode.

## 5. Board Layers

View structure:

```text
HomeScreen
  HomeBoardScrollView
    UserBoardSection
      HomeBoardGridLayout
    AssistantSuggestionSection
      SuggestionRail/Grid
```

User board and suggestions should be visually related but semantically separate.

## 6. Card Action Model

Actions:

- Open.
- Pin/unpin.
- Hide.
- Dismiss.
- Resize.
- Add suggestion to board.
- Less like this.
- More like this.
- Explain why.

Use native `Menu` for normal mode. Use edit mode for dragging/resizing.

## 7. Card Component Model

Recommended files:

```text
Features/Home/Grid/HomeBoardGridLayout.swift
Features/Home/Grid/HomeBoardSpan.swift
Features/Home/Grid/HomeBoardGridMetrics.swift
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
- Board supports 4-column and 8-column layouts.
- Fixed span sizes are respected.
- User preferences persist.
- AI suggestions do not alter user-owned layout.
- VoiceOver and Dynamic Type remain usable.

