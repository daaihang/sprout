# Mory v5 Full Documentation Set

> Status: draft baseline
> Updated: 2026-05-17
> Scope: UI/UX productization, public beta readiness, account/settings, navigation, visual system, and presentation architecture

## 1. Version Positioning

Mory v5 is the product experience release.

The app already has the core intelligence loop: capture a memory, preserve its source artifacts, analyze it, update the graph, promote storylines, and surface reflections. v5 turns that functional core into a public-beta-quality app that feels coherent, fast, intentional, and understandable to real users.

The primary question for v5 is not "can the system analyze memories?" It is:

> Can a user open Mory every day, understand what the app is showing, quickly add life material, trust the account/privacy controls, and feel that the interface is worthy of the intelligence underneath?

## 2. Product Thesis

Mory should feel like a personal memory surface, not a database browser.

The app should present living material in three simple places:

1. **Today**: what matters now, what was just captured, what needs attention.
2. **Memories**: the user's complete personal memory library, searchable and browsable.
3. **Insights**: AI-derived storylines, reflections, people, places, themes, and decisions.

Everything else supports these three surfaces:

- A two-row bottom area: quick capture toolbar above the tab bar.
- A top navigation layer for date, search, notifications, account, and contextual actions.
- A dedicated Account / Settings area for identity, permissions, privacy, preferences, language, data controls, and diagnostics.
- A design system that makes different object types visually distinct without becoming ornamental.

## 3. Documentation Structure

### PRD

1. [00_v5_prd_index.md](PRD/00_v5_prd_index.md)
2. [01_product_positioning_and_goals.md](PRD/01_product_positioning_and_goals.md)
3. [02_users_jobs_and_success_metrics.md](PRD/02_users_jobs_and_success_metrics.md)
4. [03_information_architecture.md](PRD/03_information_architecture.md)
5. [04_today_experience.md](PRD/04_today_experience.md)
6. [05_capture_and_quick_input.md](PRD/05_capture_and_quick_input.md)
7. [06_memories_library.md](PRD/06_memories_library.md)
8. [07_insights_experience.md](PRD/07_insights_experience.md)
9. [08_account_settings_privacy.md](PRD/08_account_settings_privacy.md)
10. [09_onboarding_permissions_and_empty_states.md](PRD/09_onboarding_permissions_and_empty_states.md)
11. [10_public_beta_acceptance.md](PRD/10_public_beta_acceptance.md)

### Architecture

1. [00_v5_architecture_index.md](Architecture/00_v5_architecture_index.md)
2. [01_presentation_architecture.md](Architecture/01_presentation_architecture.md)
3. [02_navigation_and_routing.md](Architecture/02_navigation_and_routing.md)
4. [03_design_system_tokens.md](Architecture/03_design_system_tokens.md)
5. [04_today_board_presentation_engine.md](Architecture/04_today_board_presentation_engine.md)
6. [05_capture_presentation_components.md](Architecture/05_capture_presentation_components.md)
7. [06_account_settings_data_model.md](Architecture/06_account_settings_data_model.md)
8. [07_accessibility_localization_and_motion.md](Architecture/07_accessibility_localization_and_motion.md)
9. [08_rollout_test_and_migration_plan.md](Architecture/08_rollout_test_and_migration_plan.md)
10. [09_project_structure_health.md](Architecture/09_project_structure_health.md)

## 4. Non-Negotiable v5 Outcomes

| Area | Required Outcome |
|------|------------------|
| Navigation | Bottom tabs reduced to Today / Memories / Insights |
| Quick capture | Bottom quick input supports tap-to-text and press-hold voice capture |
| Today | Board uses typed cards, explainable rules, and visible grouping |
| Memories | Library supports timeline browsing, search, artifact filters, and detail navigation |
| Insights | Storylines, reflections, people, themes, places, and decisions are unified |
| Account / Settings | Productized page exists outside Debug |
| Permissions | User can understand and manage required capabilities |
| Privacy | Local-first and AI request behavior are explained plainly |
| Visual system | Cards, toolbar, type, color, spacing, and empty states are deliberate |
| Accessibility | Dynamic Type, VoiceOver labels, contrast, and motion reduction are supported |
| Public beta | App can be used without Debug knowledge |

## 5. v5 Boundaries

v5 is not a full new data model release. It is allowed to add local preference models and presentation-specific state, but it should not rewrite the memory ontology or AI contract unless a UI requirement cannot be solved otherwise.

Allowed:

- New presentation stores.
- New settings/preference models.
- New route system.
- New reusable view components.
- New UI copy and localization.
- New debug observability for presentation rules.

Avoid:

- Rewriting the AI pipeline for visual reasons.
- Making LLM calls to decide homepage layout.
- Introducing social, subscription, or cloud sync as part of the UI pass.
- Shipping a beautiful interface that hides broken capture, settings, or privacy flows.

## 6. Release Shape

v5 should ship in three visible increments:

1. **v5.0-alpha.1: Navigation and Shell**
   - Three tabs.
   - Top navigation model.
   - Two-row bottom capture area.
   - Account / Settings skeleton.

2. **v5.0-alpha.2: Surfaces and Components**
   - Today Board visual redesign.
   - Memories library redesign.
   - Insights overview redesign.
   - Capture components polished.

3. **v5.0-beta.1: Public Beta Polish**
   - Permissions and onboarding.
   - Empty states.
   - Accessibility.
   - Localization.
   - Performance pass.
   - Manual QA checklist complete.
