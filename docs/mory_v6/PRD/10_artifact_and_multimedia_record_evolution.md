# 10. Artifact And Multimedia Record Evolution

## 1. Purpose

V6 should keep the user's mental model simple:

> A memory is one complete record.

Internally, Mory can store many artifacts. Externally, users should not feel that their memory has been scattered into database fragments.

This document defines how artifacts evolve in V6 without breaking the product feeling.

## 2. Current Product Decision

User-visible surface:

- One record.
- One title.
- One body or narrative.
- One set of attachments and context.
- One memory detail page.

Internal structure:

- One `RecordShell`.
- Many `Artifact` items.
- Many context candidates.
- Many graph references.
- Optional intelligence jobs and questions.

The user should see the complete memory first. Artifact-level structure can appear only when it helps editing, search, or rich layout.

## 3. Artifact Is Extensible

Artifacts should support multiple instances of the same kind.

Examples:

- A record can contain three photos.
- A record can contain two audio clips.
- A record can contain a text note and a refined transcript.
- A record can contain location, weather, music, calendar, link, and contact context together.
- A future long-form record can contain ordered sections.

This means V6 must avoid one-field-per-kind assumptions.

Bad:

```text
record.photo
record.audio
record.location
```

Better:

```text
record.artifacts: [Artifact]
artifact.kind
artifact.position
artifact.role
artifact.visibility
```

## 4. Context As Artifact

Context can be represented as artifact-like material, but the UI should distinguish source from authored content.

Recommended vocabulary:

| Concept | User Meaning | System Meaning |
| --- | --- | --- |
| Text | What I wrote or said | User-authored or refined language artifact |
| Photo | Visual memory | Photo artifact with metadata |
| Audio | Original voice material | Audio artifact plus transcript relationship |
| Location | Where it happened | Context artifact or structured context attachment |
| Weather | Background condition | Auto-collected context artifact |
| Music | What was playing | Auto-collected context artifact |
| Calendar | What was scheduled | Context artifact, opt-in |

Context artifacts should not feel equal to the user's main memory text. They are supporting evidence.

## 5. Artifact Roles

V6 should add `artifact.role`.

Recommended initial roles:

```text
primaryText
transcript
refinedTranscript
photo
audioSource
locationContext
weatherContext
musicContext
linkPreview
decision
todo
quote
systemEvidence
```

Role is not the same as kind.

Example:

```text
kind: text
role: refinedTranscript
```

This lets Mory treat a refined voice transcript differently from a typed note while still using text rendering.

## 6. Artifact Ordering

V6 should prepare for ordered artifacts.

Fields:

```text
recordID
artifactID
position
sectionID
displayMode
createdAt
updatedAt
```

Why:

- Long memory entries can become multimedia articles.
- Photo essays can preserve user order.
- Voice transcript can sit below audio source.
- Context chips can remain grouped at the end.

## 7. Multimedia Article Mode

Future mode:

> A memory can become a composed multimedia article when the user chooses to arrange it.

This should not be the default input burden.

Article mode can support:

- Ordered text sections.
- Inline photos.
- Audio clips.
- Captions.
- Location cards.
- Weather/music context footer.
- AI-proposed outline.
- User-controlled reordering.

AI may suggest structure, but cannot split a user's record into separate memories without explicit confirmation.

## 8. AI Editing Rules

Allowed without separate confirmation if user enabled voice refinement:

- Add punctuation.
- Remove filler words.
- Remove repeated words.
- Smooth obvious speech disfluency.
- Generate a suggested title.
- Preserve original transcript/audio source.

Needs confirmation:

- Rewriting meaning.
- Splitting content into multiple memories.
- Extracting a decision or todo as an actionable object.
- Marking a person relationship.
- Creating a chapter or life stage.

Never:

- Delete original user material.
- Replace the only source text without an undo path.
- Hide source evidence for an AI-derived claim.

## 9. Detail Page Implications

Memory detail should be organized as:

1. Header.
2. User-authored narrative.
3. Attachments.
4. Context.
5. AI suggestions and questions.
6. Related people/places/themes.
7. Debug/provenance only in developer mode.

Artifact-level controls:

- Delete attachment.
- Reorder attachment if in article/edit mode.
- Show original transcript.
- Accept refined transcript.
- Revert to original.
- Mark context as wrong.

## 10. Search Implications

Search should index:

- Record title.
- User body.
- Transcript.
- Refined transcript.
- Photo labels/OCR if available.
- Context labels.
- Entity names and aliases.
- Chapter names.

Search results should show one record result, not separate artifact rows by default.

Artifact matches can be highlighted inside the result:

```text
Matched photo OCR
Matched transcript
Matched place context
```

## 11. Home Card Implications

Home card content should be selected by card type.

Examples:

- Photo card uses best photo artifact.
- Question card references an entity/profile/question.
- Yesterday panel summarizes records.
- Location card uses place context.
- Long article card uses title, lead paragraph, and cover artifact.

Home cards should never expose artifact storage vocabulary.

## 12. Acceptance Criteria

- A record can contain multiple artifacts of the same kind.
- The user sees one whole memory in normal detail view.
- Context appears as supporting material, not fragmented memory rows.
- Voice refinement preserves source material.
- Future article mode can be added without changing the capture data contract again.
- Search can explain which artifact matched while still returning the containing record.
