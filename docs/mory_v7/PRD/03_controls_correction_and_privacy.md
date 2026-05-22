# 03. Controls, Correction, And Privacy

## 1. User Correction Is A Core Product Surface

v7 correction actions are domain events, not UI-only edits.

Required actions:

- "This is me."
- "This is not me."
- "These people are the same."
- "These are different people."
- "This label refers to multiple people."
- "This relationship changed."
- "This profile summary is wrong."
- "This was a joke."
- "This was serious."
- "Do not use this topic for suggestions."
- "This decision is resolved."

Each action must produce durable state:

- `CorrectionEvent`,
- `GraphDelta`,
- profile field update,
- invalidation/recompute job where needed.

## 2. Explainability

Every profile, mood inference, merge proposal, arc, and reflection should show:

- source memory IDs,
- source artifact IDs,
- evidence snippets,
- confidence,
- last updated time,
- whether user confirmed it.

## 3. Privacy Controls

Required controls:

- cloud AI off,
- local/system intelligence off where possible,
- history context sharing off,
- rich notification previews off,
- sensitive topics suppressed,
- Journaling Suggestions disabled,
- semantic search disabled,
- delete local intelligence data,
- export local data.

## 4. Local-First Boundary

Local-only by default:

- self profile,
- relationship labels,
- sensitive topic labels,
- correction history,
- full graph,
- full memory text,
- profile edit history.

Cloud AI may receive:

- current memory summary,
- bounded evidence snippets,
- profile summaries needed for the task,
- source IDs for provenance,
- no binary media unless separately enabled.

## 5. Notification Safety

Sensitive content should default to in-app only.

Remote push copy should be generic unless the user enables rich previews.
