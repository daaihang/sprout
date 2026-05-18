# Mory v6 Documentation Set

> Status: draft baseline  
> Updated: 2026-05-18  
> Scope: Continuous Memory Intelligence, AI-native product experience, local-first intelligence, semantic search, notifications, spatial home board, and V6 implementation architecture

## 1. Version Positioning

Mory v6 is the release where Mory moves from an AI-assisted memory app to an AI-native personal memory system.

v3 defined the memory ontology. v4 expanded capture and analysis. v5 productized the shell, capture, settings, and public beta surfaces. v6 adds the missing continuous layer:

- Mory keeps organizing after capture.
- Mory asks useful questions when information is incomplete.
- Mory maintains long-lived people, place, theme, decision, and chapter context.
- Mory searches like a memory system, not just a string filter.
- Mory can notify the user without overwhelming them.
- Mory respects user-controlled home layout while suggesting new cards.

The core shift:

```text
V5: Capture-time analysis
V6: Continuous memory intelligence
```

## 2. Product Thesis

Mory should feel like a quiet, user-controlled memory desk that keeps preparing useful material in the background.

Everyday open state:

1. Yesterday's memories are organized and ready to review.
2. Today's board is stable, personal, and user-owned.
3. Mory suggests new cards without disturbing the user's layout.
4. Questions, reminders, and notifications are useful but frequency-controlled.
5. Users can view memories as a board, list, timeline, film gallery, storage jar, sticker wall, or archive surface.

Mory is not a chat AI product. Its AI-native behavior should appear as organization, suggestions, search, questions, background preparation, and evidence-based reflections.

## 3. Documentation Structure

### PRD

1. [00_v6_prd_index.md](PRD/00_v6_prd_index.md)
2. [01_product_thesis_and_ai_native_definition.md](PRD/01_product_thesis_and_ai_native_definition.md)
3. [02_experience_principles_and_user_controls.md](PRD/02_experience_principles_and_user_controls.md)
4. [03_home_memory_desktop.md](PRD/03_home_memory_desktop.md)
5. [04_continuous_intelligence_questions.md](PRD/04_continuous_intelligence_questions.md)
6. [05_notifications_and_daily_questions.md](PRD/05_notifications_and_daily_questions.md)
7. [06_search_and_retrieval.md](PRD/06_search_and_retrieval.md)
8. [07_memory_views_and_archives.md](PRD/07_memory_views_and_archives.md)
9. [08_privacy_local_first_ai_controls.md](PRD/08_privacy_local_first_ai_controls.md)
10. [09_acceptance_metrics_and_release_scope.md](PRD/09_acceptance_metrics_and_release_scope.md)
11. [10_artifact_and_multimedia_record_evolution.md](PRD/10_artifact_and_multimedia_record_evolution.md)
12. [11_ai_governance_review_and_editing_boundaries.md](PRD/11_ai_governance_review_and_editing_boundaries.md)
13. [12_interaction_inventory_and_ui_acceptance.md](PRD/12_interaction_inventory_and_ui_acceptance.md)

### Architecture

1. [00_v6_architecture_index.md](Architecture/00_v6_architecture_index.md)
2. [01_continuous_intelligence_layer.md](Architecture/01_continuous_intelligence_layer.md)
3. [02_domain_model_extensions.md](Architecture/02_domain_model_extensions.md)
4. [03_swiftdata_repository_migration.md](Architecture/03_swiftdata_repository_migration.md)
5. [04_swiftui_home_grid_and_ui_system.md](Architecture/04_swiftui_home_grid_and_ui_system.md)
6. [05_core_ml_and_core_spotlight.md](Architecture/05_core_ml_and_core_spotlight.md)
7. [06_background_jobs_notifications_and_go_server.md](Architecture/06_background_jobs_notifications_and_go_server.md)
8. [07_testing_observability_rollout.md](Architecture/07_testing_observability_rollout.md)
9. [08_project_file_plan.md](Architecture/08_project_file_plan.md)
10. [09_go_server_api_contracts.md](Architecture/09_go_server_api_contracts.md)
11. [10_settings_preferences_and_feature_flags.md](Architecture/10_settings_preferences_and_feature_flags.md)
12. [11_phase_implementation_backlog.md](Architecture/11_phase_implementation_backlog.md)

## 4. Non-Negotiable V6 Outcomes

| Area | Required Outcome |
| --- | --- |
| AI-native posture | Mory continues organizing after capture without requiring the user to manually manage every structure. |
| User control | AI suggestions never destroy or reorder user-curated board layout without explicit action. |
| Home board | Today becomes a spatial memory desktop with fixed-size grid cards and suggestion layer. |
| Continuous intelligence | Entity enrichment, clarification questions, daily questions, revisit candidates, and background jobs exist as first-class objects. |
| Search | Core Spotlight semantic search is integrated while preserving current in-app search behavior as fallback. |
| Local-first intelligence | Core ML/local rules handle lightweight classification, salience, recurrence, and candidate generation where possible. |
| Server boundary | Go remains a light-state AI/auth/notification gateway and does not store the full private memory library. |
| Privacy | Settings clearly explain local processing, cloud AI processing, notification behavior, and user controls. |
| Notifications | Multiple notification types exist, but frequency, quiet hours, and topic sensitivity are user-controlled. |
| Views | Memories can be reviewed through multiple native-feeling views, not only Form/List screens. |
| Artifact evolution | Records stay whole to the user, while artifacts remain composable enough for multimedia article layouts. |
| Governance | AI suggestions are auditable, reversible, confidence-aware, and separated from user-authored truth. |
| Implementation control | V6 ships behind preferences and feature flags so alpha loops can be validated without destabilizing v5. |

## 5. V6 Boundaries

Allowed:

- New local SwiftData stores for intelligence jobs, question queue, entity profiles, graph deltas, notification preferences, and layout preferences.
- New Core Spotlight indexing service.
- New local Core ML or rules-based signal extraction layer.
- New Go endpoints for transcript refinement, intelligence candidates, chapter suggestions, and notification intent support.
- New SwiftUI home grid layout and memory view modes.

Avoid:

- Turning Mory into a multi-turn chatbot.
- Letting AI directly mutate user-authored memory content.
- Sending the full local memory library to the server by default.
- Making LLMs directly choose precise visual layout.
- Forcing users into AI suggestions that overwrite their own organization.
- Rewriting the whole v5 stack before the continuous intelligence loop is proven.

## 6. Release Shape

V6 should ship in staged increments:

1. **v6.0-alpha.1: Intelligence Foundation**
   - Intelligence domain models.
   - SwiftData stores.
   - Repository methods.
   - Post-analysis job creation.
   - First clarification question cards.

2. **v6.0-alpha.2: Home Memory Desktop**
   - SwiftUI grid layout.
   - User board layer and assistant suggestion layer.
   - Fixed card sizes.
   - Pin, hide, dismiss, and resize.

3. **v6.0-alpha.3: Semantic Retrieval**
   - Core Spotlight indexing.
   - CSUserQuery-based semantic search where available.
   - Search fallback.
   - Engagement feedback.

4. **v6.0-beta.1: Notifications And Daily Questions**
   - Daily question engine.
   - Notification preferences.
   - Local notification support.
   - Go APNs preparation if remote push is needed.

5. **v6.0-beta.2: Multimedia Memory Views**
   - Film gallery.
   - Storage jar view.
   - Sticker wall.
   - Chapter and yesterday panels.

6. **v6.0-rc: Privacy, Quality, And Migration**
   - Settings complete.
   - Real-device smoke.
   - Local quality batch.
   - Go tests.
   - Migration safety review.

## 7. First Engineering Direction

The first implementation should not start with the full home grid, Core ML model bundle, and notification system at once.

Start with the smallest user-visible continuous loop:

```text
capture mentions a person
  -> existing analysis creates entity evidence
  -> V6 job enriches entity profile
  -> Mory asks a relationship or alias question
  -> user answers from a small native card
  -> graph/profile/search/home all improve
```

This loop proves the V6 thesis:

- Mory keeps working after capture.
- The user is not forced to manually organize.
- AI asks only when missing information blocks future value.
- User confirmation becomes durable structure.
- The app becomes useful even when the user does not add a new record that day.

## 8. Implementation Guardrails

- Keep V6 as a new layer until the loop is stable.
- Do not remove v5 record, artifact, graph, arc, and reflection objects.
- Do not make the Go server a full memory store.
- Do not allow LLM output to write trusted graph state without a `GraphDelta` policy.
- Do not let AI resize or reorder pinned home cards.
- Do not introduce custom UI chrome where native SwiftUI components already express the control clearly.
- Do not treat Core ML as mandatory for every device on day one; rules and cached signals must have a fallback.
