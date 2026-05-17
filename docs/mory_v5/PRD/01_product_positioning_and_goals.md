# 01. Product Positioning And Goals

## 1. Version Positioning

v5 is the release where Mory becomes a usable public beta product.

The app should no longer feel like a set of engineering screens connected to a powerful backend. It should feel like a calm personal memory companion with a clear structure, a fast capture path, and meaningful surfaces for review.

## 2. Product Promise

Mory turns everyday fragments into a living memory system.

Users can:

- Save thoughts, photos, recordings, links, places, weather, and music context.
- Revisit memories through a clean library.
- See storylines and reflections that are grounded in real captured evidence.
- Control account, permissions, privacy, language, and local data.

## 3. v5 Goals

### 3.1 P0 Goals

| Goal | Requirement | Acceptance |
|------|-------------|------------|
| Three-tab navigation | App uses Today / Memories / Insights as primary tabs | No public build shows seven product tabs |
| Quick capture | Bottom toolbar supports tap text entry and press-hold voice entry | User can start capture from any tab |
| Today redesign | Today Board shows typed, grouped, explainable cards | Memory, arc, reflection, system, pending, and cluster cards are visually distinct |
| Account / Settings | Product settings page exists outside Debug | User can view account state, permissions, privacy, language, data controls |
| Public beta onboarding | First-run flow explains local-first capture and optional permissions | User can skip noncritical permissions and still capture |
| UI foundation | Shared visual system exists | Buttons, cards, typography, colors, spacing, and empty states are consistent |

### 3.2 P1 Goals

| Goal | Requirement | Acceptance |
|------|-------------|------------|
| Memories library | Library supports timeline, search, artifact filters, and detail navigation | User can find memories by text, context, artifact type, or date |
| Insights overview | Insights unifies storylines, reflections, people, places, themes, decisions | User can understand available insight categories from one screen |
| Source transparency | AI-derived items expose source memories and confidence signals | User can inspect why an insight exists |
| Permission recovery | Denied permissions have recovery instructions | Settings offers direct system settings link |
| Presentation observability | Debug shows board/card rules for internal builds | Product behavior can be audited without reading code |

### 3.3 P2 Goals

| Goal | Requirement | Acceptance |
|------|-------------|------------|
| Multi-select media polish | Multiple photos and multiple context candidates have clear UI | User can remove/reorder before save |
| User preference tuning | User-facing tone/detail/frequency preferences | Preferences stored locally with sync-ready keys |
| Data export polish | Export includes memories, artifacts metadata, arcs, reflections, settings | User can create a readable local archive |
| Advanced empty states | Empty states adapt to user history and permission state | Empty screens lead to concrete action |

## 4. Non-Goals

v5 should not:

- Redesign the AI model contract.
- Add cloud sync as a release dependency.
- Add subscription or paywall surfaces.
- Add social features.
- Turn Today Board into a freeform design canvas.
- Use an LLM to choose layout dynamically.
- Hide unfinished core flows behind beautiful UI.

## 5. Success Metrics

### 5.1 Activation

| Metric | Target |
|--------|--------|
| First memory capture completion | > 80% of new users who enter the app |
| Time from app open to first capture start | < 10 seconds median |
| Permission denial recovery | User can still capture text/audio/link without location/music/weather |

### 5.2 Engagement

| Metric | Target |
|--------|--------|
| Daily board visible useful cards | At least 3 after sufficient data exists |
| Capture toolbar usage | > 50% of captures initiated from bottom toolbar |
| Memory detail source inspection | Users can reach source artifacts from AI-derived surfaces |

### 5.3 Trust

| Metric | Target |
|--------|--------|
| Settings discoverability | Account/settings reachable from top nav in one tap |
| Privacy clarity | User can see local-first and AI request explanation in Settings |
| Insight explainability | Each reflection/storyline shows source memory count and source access |

### 5.4 Quality

| Metric | Target |
|--------|--------|
| Crash-free public beta sessions | > 99% |
| Main screen first render | < 1 second from authenticated launch on recent iPhone |
| Capture save perceived latency | Immediate local save, background analysis state visible |

## 6. Release Risks

| Risk | Why It Matters | Mitigation |
|------|----------------|------------|
| Beautiful UI hides missing controls | Public beta users need account/privacy controls | Build Settings early |
| Capture toolbar causes audio bugs | Voice capture is a primary entry path | Use robust recording state machine |
| Today Board feels random | AI cards need trust | Show reason/source and type-specific cards |
| Too many visual styles | Memory app becomes noisy | Use restrained token system |
| Settings becomes a dumping ground | Users cannot find controls | Group by Account, Capture, Permissions, Privacy, Data, Debug |

## 7. Launch Definition

v5 can enter public beta when:

1. Three-tab app shell is complete.
2. Quick capture works reliably.
3. Account / Settings exists and covers privacy/permissions/data.
4. Today, Memories, and Insights are visually coherent.
5. Debug-only surfaces are not required for normal use.
6. Full iOS tests pass.
7. Manual simulator and real-device smoke tests pass.

