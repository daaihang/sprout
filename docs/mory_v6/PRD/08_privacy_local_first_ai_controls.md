# 08. Privacy, Local Storage, Cloud Deep AI, And Controls

## 1. Privacy Position

Mory is local-first for memory storage and user-owned state. User memories should live on device by default.

Mory v6 is cloud-first for deep AI while the product is still proving the continuous intelligence loop. The local side should use Apple system capabilities and lightweight rules where they are reliable: Speech transcription, Vision OCR/classification, Core Spotlight semantic indexing, recurrence heuristics, and future optional Core ML hints.

V6 adds more intelligence, so privacy must become more explicit, not less.

## 2. Processing Categories

Settings should explain:

| Category | Location | Examples |
| --- | --- | --- |
| Local storage | Device | Records, artifacts, graph, questions, board layout |
| Local/system intelligence | Device | Speech, Vision OCR/classification, Core Spotlight, Core ML hints, recurrence rules |
| OS semantic index | Device | Core Spotlight searchable items |
| Cloud AI | Mory Go server to provider | Deep record analysis, reflection, transcript refinement, question candidates, chapter naming, future photo multimodal semantics |
| Remote push | Mory Go server and APNs | Generic notification delivery |

## 3. User Controls

Required controls:

- Local/system intelligence on/off where the OS allows it.
- Cloud AI analysis on/off or ask each time when the privacy UI ships.
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
- Avoid sending binary media unless separately approved; the first photo semantic endpoint should use local labels/OCR/metadata as a placeholder before cloud multimodal upload is explicitly approved.

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
Apple system features, recurrence detection, and search indexing can happen on device.
Deep intelligence currently uses Mory's backend so the app does not maintain two competing full AI systems.
You can turn cloud AI and notifications off.
```

## 8. Acceptance Criteria

- User can understand local vs cloud processing.
- User can disable cloud AI.
- User can disable semantic indexing.
- User can delete local intelligence data.
- Remote notification content avoids sensitive details by default.
- Debug logs do not expose raw memory content in production.
