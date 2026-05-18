# 04. Continuous Intelligence Questions

## 1. Purpose

V6 introduces continuous intelligence: Mory keeps understanding after capture.

The current v5 pattern is:

```text
Save record
  -> Analyze once
  -> Update graph/arc/reflection
  -> Display results
```

V6 pattern:

```text
Save record
  -> Analyze once
  -> Generate intelligence jobs
  -> Enrich entities, places, themes, decisions, chapters
  -> Ask clarification questions when needed
  -> Apply user answers as graph/profile updates
  -> Keep home/search/insights fresh
```

## 2. Long-Tail Analysis Targets

### 2.1 People

Questions:

- Who is this person to you?
- What else do you call them?
- Is this the same person as another entity?
- Are they related to a recurring theme?
- Has the relationship changed over time?

Profile fields:

- Display name.
- Canonical name.
- Aliases.
- Relationship to user.
- Mention count.
- First mentioned at.
- Last mentioned at.
- Common contexts.
- Related themes.
- Related places.
- Related chapters.
- Confidence.
- Confirmation state.

### 2.2 Places

Questions:

- Is this a meaningful place?
- Is this home/work/school/favorite place?
- Should nearby captures be grouped?
- Is this place tied to a person or stage?

### 2.3 Themes

Questions:

- Is this a recurring theme or a one-off tag?
- Should this theme be used in future search and board cards?
- Is this theme sensitive?

### 2.4 Decisions

Questions:

- Is this a decision, a thought, or a todo?
- Is it still open?
- What changed after this decision?
- Should Mory revisit it later?

### 2.5 Chapters

Questions:

- Is a stage forming?
- What evidence supports the chapter?
- Should the chapter be saved?
- What should the chapter be called?
- Has the chapter ended?

## 3. Question Queue

Questions are first-class objects.

Each question should include:

```text
id
kind
prompt
targetType
targetID
sourceRecordIDs
sourceArtifactIDs
candidateAnswers
priority
reason
status
createdAt
expiresAt
answeredAt
dismissedAt
askCount
sensitivity
```

## 4. Question Kinds

| Kind | Example |
| --- | --- |
| entityRelationship | "Who is Alex to you?" |
| entityAlias | "Do you also call Alex 'A. Chen'?" |
| entityMerge | "Are Alex and Alexander Chen the same person?" |
| placeMeaning | "Is this cafe a meaningful place?" |
| themeConfirmation | "Should 'career transition' be tracked as a theme?" |
| decisionStatus | "Is this decision still open?" |
| chapterCandidate | "Does this feel like a new chapter?" |
| dailyReflection | "What was the most important part of yesterday?" |
| revisit | "Do you want to revisit this place/person?" |

## 5. Answer Types

Questions should support:

- Single choice.
- Multi-choice.
- Short text.
- Skip.
- Do not ask again.
- Not the same.
- Merge.
- Confirm.
- Edit suggested label.

## 6. Answer Effects

User answers should write structured updates:

```text
Question answer
  -> GraphDelta
  -> EntityProfile update
  -> Search index update
  -> Home board refresh
```

They should not become unstructured notes unless the user explicitly adds text to a memory.

## 7. Question Ranking

Prioritize:

1. Questions that unlock many future memories.
2. Questions that resolve ambiguity.
3. Questions with recent context.
4. Questions tied to user-pinned people/places/themes.
5. Questions with high confidence and low sensitivity.

Down-rank:

- Repeatedly dismissed topics.
- Sensitive topics if notifications are restricted.
- Questions with weak evidence.
- Questions asked too recently.

## 8. UX Rules

- Ask one or two questions at a time.
- Do not create a long questionnaire.
- Every question needs a reason or evidence.
- Questions should be answerable in seconds.
- A dismissed question should not immediately reappear.
- Questions can appear on home, entity detail, memory detail, or daily review.

## 9. Acceptance Criteria

- New person entities can generate relationship or alias questions.
- Answering a question updates local profile/graph state.
- Dismissing a question persists.
- Questions appear as addable/dismissible home cards.
- Question history is visible enough for debugging.
- Sensitive questions respect user preferences.

