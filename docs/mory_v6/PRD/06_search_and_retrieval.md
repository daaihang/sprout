# 06. Search And Retrieval

## 1. Purpose

Search should feel like asking the user's own memory, without becoming a chat product.

V6 search should combine:

- Current structured search.
- Core Spotlight semantic search.
- Graph-aware retrieval.
- Traditional exact search.
- Saved result navigation.

## 2. Current Gap

Current search is string contains scoring:

```text
title contains query
summary contains query
rawText contains query
entity/arc/reflection fields contain query
```

This is useful but not semantic. It cannot reliably answer:

- "that cafe I kept visiting before launch"
- "times I talked about protecting mornings"
- "records about feeling stuck at work"
- "people connected to career transition"

## 3. V6 Search Model

Search should have layered retrieval:

```text
User query
  -> Core Spotlight semantic query where available
  -> Local graph/entity query
  -> Exact string fallback
  -> Result merger and ranker
  -> Search UI sections
```

## 4. Result Types

Search results should include:

- Memories.
- People.
- Places.
- Themes.
- Decisions.
- Chapters.
- Reflections.
- Media/artifact previews.
- Questions.

## 5. Search UI

Search lives at the top of Memories instead of a standalone bottom tab.

It should not become a multi-turn chat screen.

Allowed:

- Natural-language queries.
- Suggested searches.
- Search chips.
- Result grouping.
- "Related memories" expansions.
- "Refine search" filters.

Avoid:

- Chat transcript UI.
- AI persona responses.
- Generated answers without source results.
- Hidden retrieval behavior.

## 6. Query Suggestions

Suggested searches can include:

- Recent people.
- Repeated places.
- Open decisions.
- Current chapters.
- Frequently mentioned themes.
- "Yesterday"
- "This week"
- "Photos"
- "Voice notes"

## 7. Engagement Feedback

When supported by Core Spotlight, selection/focus events should feed ranking:

- User selected result.
- User ignored repeated result.
- User changed query after result.
- User saved result to board.

This feedback should improve ranking without exposing private content to the server.

## 8. Acceptance Criteria

- Existing exact search remains available as fallback.
- Core Spotlight index can be rebuilt locally.
- Semantic search returns memories by meaning when OS supports it.
- Search results open correct detail screens.
- Result types are visually distinct.
- AI-generated or semantic results show enough source context.
