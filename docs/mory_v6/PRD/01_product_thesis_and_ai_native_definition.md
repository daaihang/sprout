# 01. Product Thesis And AI-Native Definition

## 1. V6 Product Thesis

Mory v6 should feel like a memory desk that quietly keeps itself ready.

The user opens Mory and sees:

- Yesterday's memories are organized and ready to review.
- Today's board is available without being rearranged by the system.
- New suggested cards wait in a controlled suggestion area.
- Incomplete people, places, decisions, and stages have gentle questions.
- Search can retrieve by meaning, not just exact words.
- Notifications appear only within user-defined frequency and topic limits.

## 2. What AI-Native Means For Mory

For Mory, AI-native does not mean a chatbot UI. It means the product is organized around continuous interpretation and user-controlled memory evolution.

V6 should meet this bar:

| Capability | AI-assisted app | AI-native Mory |
| --- | --- | --- |
| Capture | Analyze once after save | Save immediately, analyze, then keep enriching over time |
| Home | Recent list or static cards | Spatial desk with user layout plus intelligent suggestions |
| Search | Keyword contains matching | Core Spotlight semantic retrieval plus graph-aware fallback |
| People | Extract name once | Maintain aliases, relationship, mention history, and open questions |
| Stages | Rule-created arcs | AI proposes chapters with evidence; rules gate; user confirms |
| Notifications | Generic reminders | Evidence-based memory prompts with frequency controls |
| Privacy | Hidden implementation detail | Visible local/cloud processing controls |

## 3. Product Feeling

Mory should feel:

- Quiet.
- Prepared.
- Personal.
- Evidence-based.
- Visually spatial.
- Respectful of user control.
- Capable of helping without needing the user to constantly manage it.

Mory should not feel:

- Like a default database browser.
- Like a chat assistant demanding attention.
- Like an AI therapist making strong claims.
- Like a feed that randomly changes every time the app opens.
- Like a system that rewrites the user's own memory.

## 4. Daily Open Experience

Default daily experience:

```text
Open app
  -> Today board appears in its last stable user-owned layout
  -> Yesterday panel shows "ready to review" if enough material exists
  -> Assistant suggestions appear as addable cards, not as forced rearrangements
  -> Daily question appears if enabled and not over frequency budget
  -> Background jobs show completion or failure only when useful
```

## 5. Core Promise

Mory v6 promises:

1. You do not need to manually organize everything.
2. You can still control what appears and where it lives.
3. The system can ask clarifying questions when it lacks context.
4. The system can remember relationships, names, places, themes, and stages.
5. The system can retrieve old material by meaning.
6. The system does not silently rewrite your original content.

## 6. Non-Goals

V6 should not:

- Add a multi-turn Ask tab.
- Replace the current memory ontology.
- Move all memory data to the server.
- Let an LLM decide precise board coordinates.
- Automatically split a record into multiple standalone memories unless the user confirms.
- Use psychological diagnosis language.
- Treat every record as worthy of a deep reflection.

## 7. AI Roles

### 7.1 Local AI And Local Rules

Local intelligence should handle:

- Lightweight classification.
- Salience hints.
- Recurrence detection.
- Recent/forgotten candidate detection.
- Embedding or semantic indexing where possible.
- Notification eligibility checks.
- Search indexing.

### 7.2 Server AI

Server AI should handle:

- Deep reflection.
- Chapter/title generation.
- Transcript refinement.
- Relationship and stage explanation when local evidence is insufficient.
- Complex language generation.

### 7.3 Deterministic Rules

Rules should handle:

- User preferences.
- Safety gates.
- Pin/hide/dismiss behavior.
- Notification frequency limits.
- Layout constraints.
- Evidence thresholds.
- Local fallback behavior.

