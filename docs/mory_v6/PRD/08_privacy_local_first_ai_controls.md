# 08. Privacy, Local-First AI, And Controls

## 1. Privacy Position

Mory is local-first. User memories should live on device by default.

V6 adds more intelligence, so privacy must become more explicit, not less.

## 2. Processing Categories

Settings should explain:

| Category | Location | Examples |
| --- | --- | --- |
| Local storage | Device | Records, artifacts, graph, questions, board layout |
| Local intelligence | Device | Core ML signals, recurrence, search indexing |
| OS semantic index | Device | Core Spotlight searchable items |
| Cloud AI | Mory Go server to provider | Deep reflection, transcript refinement, chapter naming |
| Remote push | Mory Go server and APNs | Generic notification delivery |

## 3. User Controls

Required controls:

- Local intelligence on/off.
- Cloud AI analysis on/off or ask each time.
- Transcript refinement on/off.
- Rich notification previews on/off.
- Semantic search on/off.
- Rebuild search index.
- Delete local intelligence data.
- Delete local memories.
- Export local data.

## 4. Cloud AI Data Minimization

When sending to server AI:

- Send only required record/artifact text.
- Do not send full local library by default.
- Use known entities only when needed.
- Prefer local recurrence summaries over raw history.
- Use source IDs for provenance.
- Avoid sending binary media unless separately approved.

## 5. Server Boundary

Go server may store:

- User profile.
- Push token.
- Notification preferences.
- Delivery logs.
- Subscription tier.
- Lightweight request metadata.

Go server should not store by default:

- Full record body.
- Full artifact text.
- Full graph.
- Full search index.
- Full board layout.

## 6. Sensitive Topics

Sensitive topics should have:

- Conservative notification defaults.
- No diagnosis language.
- In-app first surfacing.
- User controls to suppress or reduce.
- Evidence-based language only.

## 7. Transparency Copy

Settings should include plain explanations:

```text
Mory stores your memories on this device.
Some AI features can send selected text and artifact summaries to Mory's backend and model providers.
Local intelligence, recurrence detection, and search indexing can happen on device.
You can turn cloud AI and notifications off.
```

## 8. Acceptance Criteria

- User can understand local vs cloud processing.
- User can disable cloud AI.
- User can disable semantic indexing.
- User can delete local intelligence data.
- Remote notification content avoids sensitive details by default.
- Debug logs do not expose raw memory content in production.

