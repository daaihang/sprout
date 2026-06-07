# 03. Home Memory Desktop

## 1. Purpose

The v6 home surface is a memory desktop, not a list.

It should answer:

- What is stable on my board?
- What did Mory organize since yesterday?
- What does Mory suggest adding today?
- What needs confirmation?
- What is forming into a pattern, stage, or chapter?
- What should I revisit?

## 2. Two-Layer Home Model

V6 home has two layers:

### 2.1 User Board Layer

Owned by the user.

Contains:

- Pinned cards.
- Manually ordered masonry cards.
- Manually ordered cards.
- Accepted AI cards.
- User-hidden card preferences.

AI should not automatically reorder this layer.

### 2.2 Assistant Suggestion Layer

Prepared by Mory.

Contains:

- Addable suggested cards.
- Daily question.
- Clarification questions.
- Yesterday ready panel.
- Revisit candidates.
- Stage forming candidates.
- Processing completion or failure.

The user can add, dismiss, or reduce suggestions.

## 3. Board Masonry

Home should use fixed-column masonry with adaptive column caps:

```text
Compact iPhone: 1-2 columns
Wide iPhone / iPad: more columns as width allows
Mac / very wide: broader masonry without phone-density columns
```

Card density:

```text
Simple: compact capsule for signals and short actions.
Standard: default media cards and short memory content.
Detailed: expanded text, summaries, and rich context cards.
```

## 4. Card Categories

### 4.1 User Content Cards

- Memory.
- Photo memory.
- Voice memory.
- Link memory.
- Music/context memory.
- Multi-artifact memory.

### 4.2 Intelligence Cards

- Clarification question.
- Daily question.
- Entity profile completion.
- Alias confirmation.
- Stage forming.
- Chapter candidate.
- Revisit card.

### 4.3 System Cards

- Yesterday organized.
- Processing complete.
- Processing failed.
- Permission recovery.
- Onboarding guidance.
- Notification setup.

### 4.4 Collection Cards

- Film strip.
- Storage jar.
- Sticker cluster.
- Place cluster.
- Person cluster.
- Theme cluster.

## 5. Yesterday Panel

The yesterday panel should appear when:

- Yesterday had memories.
- Analysis or local organization completed.
- At least one useful summary, cluster, question, or collection exists.

It should not appear as a generic recap if there is no useful content.

Panel actions:

- Open yesterday board.
- Add a suggested card to today.
- Review questions from yesterday.
- Save or dismiss generated chapter/reflection.

## 6. Today Suggestions

Suggestions should be visually separate from user-owned layout.

Examples:

- "Add yesterday photo strip"
- "Confirm who Alex is"
- "A work-stress pattern may be forming"
- "You mentioned the same cafe 3 times"
- "A new chapter candidate is ready"

The action should be explicit:

```text
Add to board
Review
Dismiss
Less like this
```

## 7. Layout Conflict Rules

Mory must not:

- Move pinned cards silently.
- Reorder user-ordered cards silently.
- Reinsert hidden cards.
- Replace accepted cards with new AI variants.

Mory may:

- Suggest a new card in the suggestion layer.
- Mark a card as stale.
- Offer a layout cleanup action.
- Suggest resizing when content does not fit.

## 8. SwiftUI UX Requirements

Home should be implemented with native SwiftUI patterns:

- `ScrollView` for board surface.
- Custom `Layout` for grid packing.
- `ViewThatFits` for compact card internals.
- Native `Menu` for card actions.
- Native `Button` styles where possible.
- `matchedTransitionSource` only when it improves clarity.
- Dynamic Type and VoiceOver support.
- Reduce Motion support.

Avoid:

- Nested cards.
- Arbitrary decorative backgrounds.
- Default List as the main home surface.
- One-note palettes.
- Text that overflows its adaptive-height card.

## 9. Acceptance Criteria

- Home is not implemented as a generic `List`.
- User layout persists.
- AI suggestions do not disturb user layout.
- Cards support fixed column width with adaptive height.
- The board adapts columns by available width instead of fixed legacy column modes.
- Every AI-derived card has reason and source access.
- User can dismiss/reduce suggestion categories.
- Empty and low-data states still lead to capture.
