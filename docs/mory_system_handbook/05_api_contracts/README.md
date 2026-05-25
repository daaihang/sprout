# API Contracts

This catalog lists the active server endpoints and the iOS client families that call them.

## Server Routes

| Method | Path | Purpose | Auth |
| --- | --- | --- | --- |
| GET | `/healthz` | Health check | No |
| GET | `/metrics` | Text metrics | No |
| POST | `/auth/apple` | Apple auth exchange | No |
| POST | `/auth/refresh` | Refresh token | Refresh token |
| POST | `/api/auth/refresh` | Refresh token alias | Refresh token |
| POST | `/api/analysis/preview` | Legacy preview | No |
| POST | `/api/analysis/records` | Legacy analyze | Bearer |
| POST | `/api/analyze/v7` | Production v7 analysis | Bearer |
| POST | `/api/reflections/generate` | Generate reflection | Bearer |
| POST | `/api/reflections/replay` | Replay reflection | Bearer |
| POST | `/api/intelligence/refine-transcript` | Voice transcript refinement | Bearer |
| POST | `/api/intelligence/suggest-questions` | Daily/clarification questions | Bearer |
| POST | `/api/intelligence/suggest-chapters` | Chapter/story suggestions | Bearer |
| POST | `/api/intelligence/analyze-photo` | Photo semantic analysis endpoint | Bearer |
| POST | `/api/intelligence/suggest-notification-intent` | Notification intent suggestion | Bearer |
| POST | `/api/intelligence/eval` | Provider eval/debug | Bearer |
| POST | `/api/me/onboarding/complete` | Onboarding completion | Bearer |
| GET | `/api/subscription/verify` | Subscription status | Bearer |
| POST | `/api/push/register` | APNs token and notification preferences | Bearer |
| POST | `/api/push/enqueue` | Queue remote push | Bearer |
| POST | `/api/push/delivery-writeback` | Delivery/interaction writeback | Bearer |

## iOS Client Families

| File Family | Main Calls |
| --- | --- |
| `MoryAPIClient+Auth` | Apple auth, refresh |
| `MoryAPIClient+Analyze` | legacy analyze, v7 analyze, reflection generate/replay |
| `MoryAPIClient+Notifications` | transcript refine, questions, chapters, photo analysis, notification suggestion |
| `MoryAPIClient+Push` | push register/enqueue/writeback |
| `MoryAPIClient+Eval` | provider eval, server metrics |

## Authentication And 401 Handling

Authenticated endpoints use Bearer access tokens. Refresh uses the refresh token as Bearer. Recent auth handling clears credentials and moves the app to unauthenticated when refresh fails, but every feature document should still specify where a cloud failure appears to users.

## Analyze v7 Contract Role

`/api/analyze/v7` is the production new-memory analysis path. Legacy `/api/analysis/records` remains present but should not be the main new-memory path.

v7 request includes current record/artifacts and context pack inputs. v7 response includes analysis plus affect, graph delta, profile, merge/split, arc, reflection, question, and quality proposal families.

## Current API Gaps

1. Subscription verify exists, but entitlement and quota are not integrated into feature gates.
2. External Capture and Journaling are local/app-side and have no server contract.
3. Error status is technically captured but not always translated into product guidance.
4. OpenAPI is not guaranteed to cover every v7-native proposal shape in enough detail for client implementation without code inspection.
