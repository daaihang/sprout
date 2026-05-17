# 00. v5 Architecture Index

## 1. Purpose

This architecture set defines how to implement the v5 UI/UX release without destabilizing the memory intelligence core.

v5 architecture is presentation-first:

- Build a stable app shell.
- Introduce reusable presentation components.
- Keep business objects stable.
- Add settings/preference models where necessary.
- Make debug observability available for internal builds.

## 2. Architecture Documents

| Document | Purpose |
|----------|---------|
| 01 Presentation Architecture | Defines feature layering, view models, presentation snapshots, and reusable component boundaries |
| 02 Navigation And Routing | Defines global routes, three-tab shell, modal capture, settings presentation, and detail stacks |
| 03 Design System Tokens | Defines typography, color, spacing, card language, controls, icons, motion, and theming |
| 04 Today Board Presentation Engine | Defines how rule engine output becomes visual cards and how user preferences affect UI |
| 05 Capture Presentation Components | Defines quick toolbar, composer components, voice state machine, link/photo/location/music UI |
| 06 Account Settings Data Model | Defines settings screens, local preference storage, sync-ready keys, and account state mapping |
| 07 Accessibility Localization And Motion | Defines accessibility, Dynamic Type, VoiceOver, localization, reduced motion, and text fitting |
| 08 Rollout Test And Migration Plan | Defines implementation phases, testing, manual QA, and migration safety |
| 09 Project Structure Health | Defines file placement rules, size guardrails, split priorities, and structure-only commit policy |

## 3. Layering Rules

The presentation layer may depend on:

- Domain models.
- Repository protocols.
- Presentation snapshots.
- Local preference stores.

The presentation layer must not:

- Directly mutate SwiftData store objects.
- Reimplement AI gate logic.
- Call LLM services for layout.
- Depend on Debug-only state.

## 4. Directory Direction

Recommended structure:

```text
mory/mory/
  App/
    MoryRootView.swift
    MoryAppDependencies.swift
  DesignSystem/
    MoryColors.swift
    MoryTypography.swift
    MorySpacing.swift
    MoryCardStyle.swift
    MoryControls.swift
  Features/
    Today/
    Memories/
    Insights/
    Capture/
      Components/
    Settings/
    Shared/
  Domain/
    Composition/
    Preferences/
  Persistence/
  Infrastructure/
  Debug/
```

## 5. Implementation Philosophy

1. Split UI by user surface, not by storage object.
2. Move repeated card/control styling into DesignSystem.
3. Use route enums instead of nested NavigationLinks in complex boards.
4. Keep capture state explicit and testable.
5. Store user preferences locally with sync-ready metadata.
6. Use debug pages to observe product rules, not to compensate for missing UI.
7. Keep structure-only refactors separate from UI and behavior changes.
