# User Journeys

This section describes what the user expects to happen from start to finish. These flows are product-facing; implementation details live in the data and AI matrices.

## Journey: Normal New Memory

```mermaid
flowchart LR
    A["Open composer"] --> B["Type or add cards"]
    B --> C["Review staged cards"]
    C --> D["Save"]
    D --> E["Local memory appears"]
    E --> F["Analysis runs in background"]
    F --> G["Memory detail status and Insights outputs become available"]
```

Current state: the memory appears after local save, but analysis status is not presented as a coherent user journey.

## Journey: Voice Memory

```mermaid
flowchart LR
    A["Record voice"] --> B["Composer opens with transcript/audio"]
    B --> C["Optional cloud transcript refinement"]
    C --> D["User edits text"]
    D --> E["Save"]
    E --> F["Analysis"]
```

Current risk: transcript refinement can apply after the user starts editing.

## Journey: Journaling Suggestion

```mermaid
flowchart LR
    A["Tap Journaling"] --> B["Apple picker"]
    B --> C["Typed evidence bundle"]
    C --> D["Normal composer cards"]
    D --> E["Save normal memory"]
    E --> F["Analysis uses artifacts and affect"]
```

Current risk: imported evidence is visible as cards, but original bundle/session provenance is not fully user-visible.

## Journey: Share To Mory

```mermaid
flowchart LR
    A["Share Sheet"] --> B["Mory extension"]
    B --> C["Shared envelope/inbox"]
    C --> D["Open Mory composer"]
    D --> E["Save normal memory"]
    E --> F["Mark import as imported"]
```

Current risk: if handoff fails, recovery exists but the user may not understand where the content went.

## Journey: AI Review And Correction

```mermaid
flowchart LR
    A["Analysis completes"] --> B["Analysis/proposals stored"]
    B --> C["Settings review / People detail / Questions / Insights outputs"]
    C --> D["User applies or corrects"]
    D --> E["CorrectionEvent feeds future context"]
```

Current risk: apply path exists, but reject reason, undo, and evidence explanations are incomplete.
