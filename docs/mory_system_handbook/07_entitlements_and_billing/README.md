# Entitlements And Billing

This document defines future gating language and likely product boundaries. It is not implemented as a billing system yet.

## Terms

| Term | Meaning |
| --- | --- |
| Feature Gate | Whether a user can access a feature. |
| Entitlement Boundary | The product right granted by a subscription or purchase. |
| Quota Gate | Usage limit such as monthly AI calls or context depth. |
| Paywall Cut Point | The moment a user sees upgrade UI. |
| Server-Enforced Gate | A restriction enforced by the server, required for AI/cost protection. |
| Client UX Gate | Lock/upgrade UI; not sufficient as the only enforcement. |

## Suggested Free vs Pro Matrix

| Feature | Free | Pro | Enforcement |
| --- | --- | --- | --- |
| Text/photo/audio/link capture | Available | Available | Client only for UX, no server needed |
| Local library/timeline/search | Available | Available | Client |
| Basic auto context | Available | Available | Client permissions |
| Journaling import | Available | Available | Client capability |
| Share/AppIntent import | Available | Available | Client capability |
| v7 cloud analysis | Limited quota | Higher quota | Server |
| Full-history context pack | Limited/recent window | Deeper retrieval | Server and client |
| Rich PersonProfile portrait | Basic fields | Full portrait/evidence | Server and client |
| Graph/Arc/Reflection depth | Basic | Full | Server and client |
| Smart notifications | Basic reminders | Contextual AI reminders | Server and client |
| Export | Basic | Full export | Client/server depending target |

## Required Architecture Before Launch

1. Server entitlement response must include plan, quota, limits, and renewal/expiry state.
2. iOS must cache entitlement state for offline UX but never trust it for paid AI usage.
3. Analyze, reflection, question, notification suggestion, and transcript refinement endpoints need server-side quota gates.
4. Client must show downgrade behavior clearly when quota expires.

## Current Status

`backend_only`

Subscription verify exists as a server endpoint and iOS client call family, but there is no coherent product gating model yet.

## Gap

Do not ship paid plans until this document is converted into implemented entitlement checks and user-facing paywall rules.
