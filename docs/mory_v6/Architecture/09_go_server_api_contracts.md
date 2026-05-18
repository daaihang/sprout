# 09. Go Server API Contracts

## 1. Goal

Define V6 server API additions while preserving the local-first boundary.

The Go server should remain:

- Auth gateway.
- AI provider gateway.
- Notification sender.
- Quota/rate-limit authority.
- Light-state preference store.

It should not become:

- Full memory database.
- Full graph database.
- Search index host.
- Home layout store.

## 2. Contract Principles

- Send minimum necessary context.
- Prefer record IDs and short evidence snippets over full libraries.
- Do not log raw content.
- Make every cloud AI call explicit in client settings.
- Keep schemas versioned.
- Include model/provider metadata in responses for audit.

## 3. Endpoint: Refine Transcript

```text
POST /api/intelligence/refine-transcript
```

Request:

```json
{
  "schemaVersion": 1,
  "locale": "zh-Hans",
  "recordID": "uuid",
  "audioArtifactID": "uuid",
  "rawTranscript": "string",
  "style": "clean_spoken_memory",
  "allowTitle": true
}
```

Response:

```json
{
  "schemaVersion": 1,
  "refinedTranscript": "string",
  "suggestedTitle": "string",
  "edits": [
    {
      "kind": "punctuation",
      "summary": "Added punctuation and sentence breaks"
    }
  ],
  "provider": "openai",
  "model": "string",
  "requestID": "string"
}
```

Rules:

- Preserve meaning.
- Do not add facts.
- Return empty title if insufficient content.
- Never return a separate memory split in v6.

## 4. Endpoint: Suggest Questions

```text
POST /api/intelligence/suggest-questions
```

Request:

```json
{
  "schemaVersion": 1,
  "locale": "zh-Hans",
  "target": {
    "type": "entity",
    "id": "uuid",
    "kind": "person"
  },
  "evidence": [
    {
      "recordID": "uuid",
      "artifactID": "uuid",
      "snippet": "Alex mentioned the meeting again",
      "createdAt": "2026-05-18T10:00:00Z"
    }
  ],
  "knownProfile": {
    "displayName": "Alex",
    "aliases": [],
    "relationshipToUser": null
  },
  "userPreferences": {
    "allowSensitiveQuestions": false,
    "questionTone": "evidence_based"
  }
}
```

Response:

```json
{
  "schemaVersion": 1,
  "questions": [
    {
      "kind": "entityRelationship",
      "prompt": "Who is Alex to you?",
      "reason": "Alex appeared in several recent memories.",
      "candidateAnswers": ["friend", "coworker", "family", "other"],
      "confidence": 0.82,
      "sensitivity": "normal"
    }
  ],
  "provider": "openai",
  "model": "string",
  "requestID": "string"
}
```

Rules:

- Server returns candidates only.
- Client persists `ClarificationQuestion`.
- Client decides whether to surface.
- Client applies answers locally through `GraphDelta`.

## 5. Endpoint: Suggest Chapters

```text
POST /api/intelligence/suggest-chapters
```

Request:

```json
{
  "schemaVersion": 1,
  "locale": "zh-Hans",
  "timeWindow": {
    "start": "2026-05-01T00:00:00Z",
    "end": "2026-05-18T23:59:59Z"
  },
  "signals": [
    {
      "kind": "theme",
      "label": "career transition",
      "recordCount": 7,
      "salience": 0.74
    }
  ],
  "evidenceSnippets": [
    {
      "recordID": "uuid",
      "snippet": "I updated my resume again today."
    }
  ]
}
```

Response:

```json
{
  "schemaVersion": 1,
  "chapterCandidates": [
    {
      "title": "Looking For The Next Role",
      "summary": "A possible work transition chapter is forming.",
      "evidenceRecordIDs": ["uuid"],
      "confidence": 0.77,
      "requiresConfirmation": true
    }
  ],
  "provider": "openai",
  "model": "string",
  "requestID": "string"
}
```

## 6. Endpoint: Notification Preferences

```text
POST /api/notifications/register-preferences
```

Request:

```json
{
  "schemaVersion": 1,
  "deviceID": "string",
  "apnsToken": "string",
  "locale": "zh-Hans",
  "timeZone": "Asia/Shanghai",
  "preferences": {
    "enabled": true,
    "dailyQuestion": true,
    "backgroundDone": true,
    "stageForming": true,
    "revisit": true,
    "maxPerDay": 2,
    "quietHoursStart": "22:30",
    "quietHoursEnd": "08:00",
    "richPreviews": false
  }
}
```

Response:

```json
{
  "ok": true,
  "serverTime": "2026-05-18T10:00:00Z"
}
```

## 7. Endpoint: Notification Intent

```text
POST /api/notifications/intents
```

This endpoint is only needed if remote push is approved.

Request:

```json
{
  "schemaVersion": 1,
  "deviceID": "string",
  "intent": {
    "kind": "dailyQuestion",
    "privacyLevel": "generic",
    "title": "Mory",
    "body": "A question is ready for today.",
    "deepLink": "mory://question/uuid",
    "scheduledAt": "2026-05-18T18:30:00Z"
  }
}
```

Server should reject rich private content unless user enabled rich previews.

## 8. Error Schema

```json
{
  "error": {
    "code": "quota_exceeded",
    "message": "Quota exceeded",
    "requestID": "string",
    "retryAfterSeconds": 3600
  }
}
```

Use consistent codes:

```text
invalid_request
unauthorized
quota_exceeded
rate_limited
provider_unavailable
model_failed
privacy_blocked
```

## 9. Rate Limit Requirements

- Anonymous preview endpoint should have strict IP limit.
- Authenticated transcript refinement should have tier-based quota.
- Chapter suggestions should be lower frequency than transcript refinement.
- Notification endpoints should be authenticated.
- Failed provider calls should not consume full user quota if no useful response is returned.

## 10. OpenAPI Requirements

Update:

```text
server/openapi.yaml
```

Add:

- Request/response schemas.
- Auth requirements.
- Error schema.
- Privacy notes.
- Rate-limit headers.

## 11. Server Tests

Required tests:

- Invalid request rejects without provider call.
- Privacy-blocked request rejects.
- Rate-limited request rejects.
- Provider failure maps to stable error.
- OpenAPI examples validate.
- Notification preference write/read round trip.

## 12. Client Integration Rule

iOS must treat server output as candidate material.

Server response:

```text
candidate question/chapter/refinement
```

Client responsibility:

```text
store source
store candidate
apply policy
ask user if needed
persist accepted state
index accepted/searchable result
```
