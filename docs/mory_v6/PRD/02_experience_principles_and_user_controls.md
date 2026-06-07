# 02. Experience Principles And User Controls

## 1. Control Principle

The user owns the memory space. Mory may suggest, but must not disturb user-curated layout without permission.

This is the central v6 UX rule.

## 2. AI Action Boundaries

| Action | Allowed Without Confirmation | Requires Confirmation | Not Allowed |
| --- | --- | --- | --- |
| Analyze captured text | Yes | No | No |
| Add retrieval terms | Yes | No | No |
| Create suggested question | Yes | No | No |
| Create entity candidate | Yes | No | No |
| Confirm relationship | No | Yes | No |
| Merge people | No | Yes | No |
| Rename user-authored content | No | Yes | No |
| Refine voice transcript | Yes, if user enabled | User can review | No silent replacement of original |
| Generate title | Yes as suggestion | User can edit | No destructive overwrite |
| Split record into multiple memories | No | Yes | No silent split |
| Move user board cards | No | Yes in edit mode | No silent rearrange |

## 3. User Preference Model

V6 should expose preference controls for:

- Notification frequency.
- Daily question cadence.
- Question tone.
- AI cloud usage.
- Local intelligence usage.
- Sensitive topics.
- Board suggestion density.
- Home card type preferences.
- Voice transcript refinement.
- Semantic search.

Suggested settings:

```text
AI & Memory Intelligence
- Local intelligence: on/off
- Cloud reflection: ask / on / off
- Voice transcript refinement: on/off
- Semantic search: on/off
- Daily question cadence: off / weekly / daily / smart
- Notification frequency: off / low / standard / active
- Question style: journaling / revisit / reflective / life organization / evidence-based
- Sensitive topics: avoid notifications / allow in app only / allow all
```

## 4. Notification Control

User statement from product direction:

> I can choose not to use it, but it should exist.

Therefore V6 should provide all major intelligent notification capabilities, but defaults should be conservative.

Suggested default:

- Notifications disabled until user opts in during onboarding or Settings.
- Daily question default: smart, at most one per day.
- Revisit notifications default: low.
- Processing failure notifications default: enabled if push permission granted.
- Sensitive topics default: in-app only.

## 5. Board Control

Home board should support:

- Pin.
- Hide.
- Dismiss.
- Change card detail level where the content type supports it.
- Add suggested card.
- Remove suggested card.
- Edit board mode.
- Reset AI suggestions.
- Reduce more/less of a card category.

Masonry cards should use fixed column width and adaptive height:

```text
Simple: compact capsule.
Standard: media or 2-4 lines of text.
Detailed: expanded text where the type supports it.
```

Dragging should not conflict with long-press menus. If direct drag is unstable, use an explicit edit mode:

```text
Normal mode:
  tap = open
  long press = menu

Edit mode:
  drag = reorder
  menu = detail level / media merge / delete
  tap outside = exit edit mode
```

## 6. Content Integrity

Mory should preserve:

- Original user text.
- Original voice transcript where available.
- Refined transcript as a derived field.
- AI-generated title as editable derived metadata.
- AI interpretations as separate objects.

Recommended mental model:

```text
User content is source.
AI output is interpretation.
User confirmation turns interpretation into trusted memory structure.
```

## 7. Artifact Visibility

Users should see complete memories, not fragmented artifacts.

Artifact structure remains internal and detail-level:

```text
Memory
- Main text
- Photos
- Voice
- Location
- Weather
- Music
- Link
- Derived title
- Derived summary
- Related people/themes/stages
```

The product should not make users feel they are managing a database of artifacts. Artifact visibility is useful in detail views, export, source transparency, and debugging.

## 8. Correction Experience

Users need lightweight correction paths:

- This person is the same as...
- This person is not the same as...
- This person is my...
- Do not ask about this again.
- This chapter is wrong.
- This title is wrong.
- Hide this card type.
- More like this.
- Less like this.

Corrections should write structured local state, not just free text feedback.
