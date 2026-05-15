# 07. Naming Glossary

## 1. Purpose

This glossary freezes the canonical product language for `Mory v3`.

## 2. Canonical Terms

- `RecordShell`: the local capture root for one memory entry.
- `Artifact`: a normalized capture payload attached to a record.
- `ArtifactKind`: the canonical artifact vocabulary: `text | photo | audio | music | link | location | weather | todo | document`.
- `Board`: a spatial container for the home surface.
- `Composition`: the layout plan that arranges items on a board.
- `CompositionItem`: one positioned item inside a composition.
- `EntityNode`: a persistent semantic entity in the graph.
- `EntityEdge`: a relationship between semantic entities.
- `ArtifactEntityLink`: the bridge between artifacts and entities.
- `TemporalArc`: a phase-level memory span across time.
- `ReflectionSnapshot`: a persisted reflection object derived from memory and arcs.
- `CaptureSource`: the origin of a memory capture.
- `PipelineStatus`: the current analysis pipeline state for a record.

## 3. Usage Rule

Use these names in documentation, code, UI labels, and tests.

Additional boundary rule:

- `person mention`, `decision fragment`, and similar semantic interpretations are not `ArtifactKind`; they belong to analysis and graph outputs.
