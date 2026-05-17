# 00. v5 PRD Index

## 1. Purpose

This PRD set defines the full v5 product experience for Mory.

v5 focuses on UI/UX productization. It transforms the app from a functional memory engine with visible debug-era surfaces into a coherent public beta experience. This document set is written as a standalone product specification and includes the product boundaries needed to understand the target state.

## 2. Core Product Promise

Mory helps people capture moments, preserve context, and rediscover patterns in their life.

The v5 interface must make that promise obvious:

- Capture should feel immediate.
- The homepage should feel alive.
- The library should feel trustworthy.
- Insights should feel earned, not random.
- Settings should make privacy and control visible.

## 3. PRD Documents

| Document | Purpose |
|----------|---------|
| 01 Product Positioning And Goals | Defines the version purpose, success criteria, scope, non-goals, and risks |
| 02 Users Jobs And Success Metrics | Defines target users, jobs-to-be-done, behavioral success metrics, and public beta signals |
| 03 Information Architecture | Defines the three-tab app structure, top nav, bottom capture toolbar, global routes, and object hierarchy |
| 04 Today Experience | Defines Today Board behavior, card taxonomy, ranking, grouping, actions, and empty states |
| 05 Capture And Quick Input | Defines bottom toolbar, text capture, voice capture, composer, artifacts, and context candidates |
| 06 Memories Library | Defines timeline/library browsing, filters, search, memory detail, and artifact detail |
| 07 Insights Experience | Defines storylines, reflections, people, themes, places, decisions, and insight states |
| 08 Account Settings Privacy | Defines account, identity, permissions, privacy, language, export, deletion, and diagnostics |
| 09 Onboarding Permissions And Empty States | Defines first-run, progressive permission requests, education, empty states, and recovery paths |
| 10 Public Beta Acceptance | Defines acceptance gates, QA checklist, release blockers, and readiness thresholds |

## 4. Product Surfaces

v5 has three primary surfaces:

1. **Today**
   - Daily board.
   - Recent captures.
   - Active storylines.
   - Suggested reflections.
   - System prompts.
   - Pending processing states.

2. **Memories**
   - Complete library.
   - Timeline.
   - Search.
   - Artifact filters.
   - Memory detail.
   - Corrections and rerun status.

3. **Insights**
   - Storylines.
   - Reflections.
   - People.
   - Places.
   - Themes.
   - Decisions.
   - Relationship and pattern surfaces.

Supporting surfaces:

- Quick capture toolbar.
- Full composer.
- Account / Settings.
- Onboarding.
- Permission manager.
- Debug tools for internal builds only.

## 5. Design Principles

1. **Use the product, not the database**
   - Users should see memories, moments, and insights, not implementation objects.

2. **One clear place for each job**
   - Today is for now.
   - Memories is for finding.
   - Insights is for understanding.
   - Settings is for control.

3. **AI must show its receipts**
   - Storylines and reflections should reveal source memories.
   - Cards should not imply certainty when evidence is weak.

4. **Capture should be faster than thinking**
   - The user should be able to add a text note or voice thought from the bottom toolbar without navigating away first.

5. **Local-first trust must be visible**
   - Privacy should not be hidden in legal copy.
   - The app should explain what stays local and what is sent for AI processing.

6. **Beautiful, but not precious**
   - The app should feel crafted, warm, and calm.
   - It must still support dense reading, correction, and repeated use.

## 6. Public Beta Definition

v5 public beta is acceptable when:

- A new user can understand the app within two minutes.
- A returning user can capture in under five seconds.
- A user can find a previous memory without understanding graph terminology.
- A user can see why an insight appeared.
- A user can change permissions and account state without Debug.
- A user can recover from failed analysis without developer help.

## 7. Out Of Scope

The following are outside v5 unless separately approved:

- Subscription/paywall.
- Social sharing.
- Full cloud sync.
- Widgets.
- Apple Watch.
- HealthKit.
- Siri/App Intents.
- Fully customizable drag-and-drop dashboard.
- LLM-generated layout.
