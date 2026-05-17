# 04. Today Experience

## 1. Purpose

Today is the user's living memory surface.

It should answer:

- What did I capture recently?
- What is currently processing?
- What seems important today?
- What patterns are active?
- What reflection deserves attention?
- What should I do next?

Today should not look like a generic list. It should feel like a curated board with typed cards and clear reasons.

## 2. Board Composition

Today Board contains typed cards:

| Card Type | Purpose | Primary Action |
|-----------|---------|----------------|
| Memory | Recent or high-signal memory | Open memory detail |
| Storyline | Active accepted storyline | Open storyline detail |
| Reflection | Suggested insight | Open reflection detail, save/dismiss |
| System Prompt | Empty state, permission prompt, onboarding prompt | Perform action |
| Context Cluster | Repeated place/music/context pattern | Open filtered memories |
| Pending Action | Failed/running processing state | Open memory or retry |

## 3. Card Selection Rules

Today Board uses deterministic code rules. AI-derived data may influence ranking, but an LLM must not directly choose the layout.

Inputs:

- Recent memories.
- Filtered graph context.
- Accepted storylines.
- Suggested reflections.
- Pipeline status.
- Local board preferences.
- Context artifacts.
- Analysis salience.

Ranking:

1. Pinned cards.
2. System critical cards: failed processing, required action.
3. Today's memories.
4. Recent 24-hour memories.
5. High salience memories.
6. Memories with context.
7. Memories with graph links.
8. Active storylines.
9. Suggested reflections.
10. Repeated context clusters.
11. Noncritical system prompts.

Filtering:

- Hidden cards do not appear.
- Dismissed system/reflection cards do not appear.
- Saved reflections do not appear as suggested cards.
- Orphan targets do not appear.
- Storylines appear only when accepted and recently active.

## 4. Card Visual Language

### 4.1 Memory Card

Content:

- Title or first meaningful line.
- Short excerpt.
- Timestamp.
- Context chips: place, weather, music.
- Processing state if relevant.

Visual:

- Quiet card.
- Text-first.
- Context chips are small and scannable.

### 4.2 Storyline Card

Content:

- Storyline title.
- Summary.
- Source memory count.
- Recent update.
- Status.

Visual:

- Slightly more structured.
- Uses connected-line or phase icon.
- Shows evidence count prominently.

### 4.3 Reflection Card

Content:

- Reflection title.
- Short body.
- Source count.
- Save/dismiss affordance.

Visual:

- Insightful but restrained.
- Must not look like promotional content.
- Needs source transparency.

### 4.4 System Prompt Card

Content:

- Clear title.
- One-sentence explanation.
- Single action.

Visual:

- Distinct from content cards.
- Must not pretend to be AI insight.

### 4.5 Context Cluster Card

Content:

- Cluster title: place/music/theme.
- Count of related memories.
- Date range.
- Example memory title.

Visual:

- Grouping-oriented.
- Compact.

### 4.6 Pending Action Card

Content:

- Processing state.
- Failed stage if available.
- Retry/open action.

Visual:

- Clear but not alarming unless user action is needed.

## 5. Personalization

User controls:

- Pin.
- Unpin.
- Hide.
- Dismiss.

Rules:

- Pin applies to stable card key.
- Hide applies to memory/storyline/context cards.
- Dismiss applies to system/reflection prompts.
- User preferences are local-first and sync-ready.
- Deleted targets automatically invalidate preferences.

Not in v5:

- Free drag-and-drop layout.
- Manual card creation.
- LLM-customized board layout.

## 6. Empty States

### 6.1 No Memories

Show:

- Friendly explanation.
- Primary capture button.
- Optional voice capture hint.
- Privacy reassurance.

Do not show:

- Empty technical sections.
- Graph terminology.

### 6.2 Few Memories

Show:

- Recent memories.
- System prompt encouraging capture variety.
- Optional permissions prompt if context is unavailable.

### 6.3 Processing In Progress

Show:

- Saved memory immediately.
- Processing card or inline status.
- No blocking spinner that hides the saved memory.

### 6.4 Failed Processing

Show:

- Failed processing card.
- Reason in user-friendly terms.
- Retry action.
- Debug details only in internal builds.

## 7. Debug Observability

Internal builds must expose:

- Board input counts.
- Preference counts.
- Visible card order.
- Card kind.
- Priority.
- Reason.
- Target type and ID.
- Source record IDs.

This debug view is for engineering confidence only and must not be required for public use.

## 8. Acceptance Criteria

- Today renders useful cards with real local data.
- Card types are visually distinct.
- Every AI-derived card has source access.
- Pin/hide/dismiss persists.
- Returning from card detail requires one back action.
- Empty state leads to capture.
- Failed processing is visible and recoverable.

