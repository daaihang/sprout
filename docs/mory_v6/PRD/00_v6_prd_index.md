# Mory v6 PRD Index

## 1. Purpose

This PRD set defines Mory v6 as the Continuous Memory Intelligence release.

It answers:

- What does "AI-native" mean for Mory?
- How active should Mory be?
- How does Mory keep user control while becoming more intelligent?
- What should the home board become?
- What should daily questions, notifications, search, and long-tail analysis feel like?
- What must not be changed by AI?

## 2. Canonical Product Decision

Mory v6 should become:

> A local-first AI-native personal memory desk that keeps organizing, asking, retrieving, and preparing memory surfaces while preserving user control.

Mory is not:

- A chat assistant.
- A therapy bot.
- A generic note database.
- A social product.
- A cloud-first personal data store.

## 3. PRD Documents

| Document | Role |
| --- | --- |
| [01 Product Thesis And AI-Native Definition](01_product_thesis_and_ai_native_definition.md) | Defines the v6 product identity and AI-native bar. |
| [02 Experience Principles And User Controls](02_experience_principles_and_user_controls.md) | Defines control, consent, editing, notification, and AI boundaries. |
| [03 Home Memory Desktop](03_home_memory_desktop.md) | Defines the board, grid, yesterday panel, today suggestions, and user layout controls. |
| [04 Continuous Intelligence Questions](04_continuous_intelligence_questions.md) | Defines long-tail analysis, entity enrichment, question queue, and graph corrections. |
| [05 Notifications And Daily Questions](05_notifications_and_daily_questions.md) | Defines notification types, daily question tone, cadence, and quiet controls. |
| [06 Search And Retrieval](06_search_and_retrieval.md) | Defines semantic search, traditional search, memory Q&A boundary, and result surfaces. |
| [07 Memory Views And Archives](07_memory_views_and_archives.md) | Defines list, timeline, film gallery, storage jar, sticker wall, and multimedia article paths. |
| [08 Privacy Local-First AI Controls](08_privacy_local_first_ai_controls.md) | Defines local/cloud processing rules, settings copy, sensitive topics, and server boundaries. |
| [09 Acceptance Metrics And Release Scope](09_acceptance_metrics_and_release_scope.md) | Defines phased scope, release gates, metrics, and beta limitations. |
| [10 Artifact And Multimedia Record Evolution](10_artifact_and_multimedia_record_evolution.md) | Defines artifact extensibility, whole-record UX, context artifacts, and future article mode. |
| [11 AI Governance Review And Editing Boundaries](11_ai_governance_review_and_editing_boundaries.md) | Defines truth levels, confirmation rules, evidence, audit, and AI editing limits. |
| [12 Interaction Inventory And UI Acceptance](12_interaction_inventory_and_ui_acceptance.md) | Defines surface-by-surface UX behavior, SwiftUI-native expectations, and UI acceptance checks. |

## 4. Product Principles

1. The user's memory layout is owned by the user.
2. AI can suggest, prepare, and explain, but should not silently rewrite the user's life.
3. AI should be felt through organization, retrieval, and timely questions, not through constant chat.
4. Local intelligence should do the cheap, private, repetitive work.
5. Server AI should be reserved for deeper reasoning, reflection, chapter naming, and language transformation.
6. Every AI-derived item should have evidence, confidence, and a visible exit path.
7. The app should be useful when the user writes nothing new.
8. Notifications should be available, but frequency and tone must be user-controlled.

## 5. Open Product Decisions

These remain open and should be resolved during v6 planning or early alpha:

- Exact notification default frequency.
- Whether remote push should send only generic wake-up copy or include user-visible question text.
- Whether user-resized card dimensions are synced later through CloudKit.
- Whether AI-generated chapter titles are auto-suggested only or can be auto-created in low-risk cases.
- Whether "Ask my memories" appears as search enhancement, not a separate tab.
- Whether article mode is an explicit edit mode in v6 or a v6.x follow-up.
- Whether home drag sorting ships in edit mode only from the first grid release.
