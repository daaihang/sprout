# 09. Go Server API Contracts

## 1. Goal

Define V6 server API additions while preserving the local-storage and data-minimization boundary.

The Go server should remain:

- Auth gateway.
- AI provider gateway.
- Cloud deep-intelligence gateway.
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
- Make every cloud AI call explicit in code paths and later visible in client settings.
- Keep schemas versioned.
- Include model/provider metadata in responses for audit.

## 3. Endpoint: Refine Transcript

```text
POST /api/intelligence/refine-transcript
```

Request:

```json
{
  "schema_version": 1,
  "locale": "zh-Hans",
  "record_id": "uuid",
  "audio_artifact_id": "uuid",
  "raw_transcript": "string",
  "style": "clean_spoken_memory",
  "allow_title": true
}
```

Response:

```json
{
  "schema_version": 1,
  "refined_transcript": "string",
  "suggested_title": "string",
  "edits": [
    {
      "kind": "punctuation",
      "summary": "Added punctuation and sentence breaks"
    }
  ],
  "meta": {
    "provider": "openai",
    "model": "string",
    "request_id": "string"
  }
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
  "schema_version": 1,
  "locale": "zh-Hans",
  "target": {
    "type": "entity",
    "id": "uuid",
    "kind": "person"
  },
  "evidence": [
    {
      "record_id": "uuid",
      "artifact_id": "uuid",
      "snippet": "Alex mentioned the meeting again",
      "created_at": "2026-05-18T10:00:00Z"
    }
  ],
  "known_profile": {
    "display_name": "Alex",
    "aliases": [],
    "relationship_to_user": null
  },
  "user_preferences": {
    "allow_sensitive_questions": false,
    "question_tone": "evidence_based"
  }
}
```

Response:

```json
{
  "schema_version": 1,
  "questions": [
    {
      "kind": "entityRelationship",
      "prompt": "Who is Alex to you?",
      "reason": "Alex appeared in several recent memories.",
      "candidate_answers": ["friend", "coworker", "family", "other"],
      "confidence": 0.82,
      "sensitivity": "normal"
    }
  ],
  "meta": {
    "provider": "openai",
    "model": "string",
    "request_id": "string"
  }
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
  "schema_version": 1,
  "locale": "zh-Hans",
  "time_window": {
    "start": "2026-05-01T00:00:00Z",
    "end": "2026-05-18T23:59:59Z"
  },
  "signals": [
    {
      "kind": "theme",
      "label": "career transition",
      "record_count": 7,
      "salience": 0.74
    }
  ],
  "evidence_snippets": [
    {
      "record_id": "uuid",
      "snippet": "I updated my resume again today."
    }
  ]
}
```

Response:

```json
{
  "schema_version": 1,
  "chapter_candidates": [
    {
      "title": "Looking For The Next Role",
      "summary": "A possible work transition chapter is forming.",
      "evidence_record_ids": ["uuid"],
      "confidence": 0.77,
      "requires_confirmation": true
    }
  ],
  "meta": {
    "provider": "openai",
    "model": "string",
    "request_id": "string"
  }
}
```

## 6. Endpoint: Analyze Photo Semantics

```text
POST /api/intelligence/analyze-photo
```

This is the V6 placeholder for future cloud multimodal analysis. The first implementation does not upload image bytes by default. It sends local Vision labels, OCR text, caption hints, and metadata so the cloud model can produce a candidate semantic summary.

Request:

```json
{
  "schema_version": 1,
  "locale": "zh-Hans",
  "record_id": "uuid",
  "photo_artifact_id": "uuid",
  "local_labels": ["restaurant", "receipt"],
  "ocr_text": "Table 4 total 128",
  "caption_hint": "Dinner receipt",
  "metadata": {
    "source": "vision"
  }
}
```

Response:

```json
{
  "schema_version": 1,
  "semantic_summary": "A dinner receipt with restaurant context.",
  "suggested_title": "Dinner receipt",
  "tags": ["photo", "restaurant"],
  "objects": ["receipt"],
  "text_highlights": ["Table 4"],
  "safety": "normal",
  "confidence": 0.62,
  "meta": {
    "provider": "openai",
    "model": "string",
    "request_id": "string"
  }
}
```

Rules:

- Server returns candidate semantics only.
- Client decides whether and how to attach the candidate to the photo artifact.
- Binary image upload requires a later explicit product/privacy decision.

## 7. Endpoint: Notification Preferences

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

## 8. Endpoint: Notification Intent Suggestion

```text
POST /api/intelligence/suggest-notification-intent
```

This endpoint returns a candidate local or remote notification payload. It does not send a push by itself.

Request:

```json
{
  "schema_version": 1,
  "locale": "zh-Hans",
  "time_zone": "Asia/Shanghai",
  "trigger": "dailyQuestion",
  "recent_evidence": [
    {
      "record_id": "uuid",
      "snippet": "Work pressure appeared several evenings this week."
    }
  ],
  "question": {
    "kind": "dailyReflection",
    "prompt": "最近你几次在晚上提到工作压力，要不要补一句今天最卡的点？",
    "reason": "Repeated evening work-pressure evidence.",
    "candidate_answers": [],
    "confidence": 0.78,
    "sensitivity": "normal"
  },
  "preferences": {
    "max_per_day": 2,
    "quiet_hours_start": "22:00",
    "quiet_hours_end": "08:00",
    "rich_previews_enabled": false
  }
}
```

Response:

```json
{
  "schema_version": 1,
  "intent": {
    "kind": "dailyQuestion",
    "privacy_level": "generic",
    "title": "Mory",
    "body": "A question is ready for today.",
    "deep_link": "mory://questions"
  },
  "meta": {
    "provider": "openai",
    "model": "string",
    "request_id": "string"
  }
}
```

Rules:

- Client enforces quiet hours, max-per-day, sensitivity, and permission state.
- Rich private copy is only allowed when `rich_previews_enabled` is true.
- Generic copy is the default.

## 9. Endpoint: Remote Notification Intent

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

## 10. Error Schema

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

## 11. Rate Limit Requirements

- Anonymous preview endpoint should have strict IP limit.
- Authenticated transcript refinement should have tier-based quota.
- Chapter suggestions should be lower frequency than transcript refinement.
- Notification endpoints should be authenticated.
- Failed provider calls should not consume full user quota if no useful response is returned.

## 12. OpenAPI Requirements

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

## 13. Server Tests

Required tests:

- Invalid request rejects without provider call.
- Privacy-blocked request rejects.
- Rate-limited request rejects.
- Provider failure maps to stable error.
- OpenAPI examples validate.
- Notification preference write/read round trip.

## 14. Client Integration Rule

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
