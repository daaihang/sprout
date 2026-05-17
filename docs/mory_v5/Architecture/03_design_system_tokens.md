# 03. Design System Tokens

## 1. Goal

v5 needs a design system that is warm, calm, readable, and scalable.

It should prevent every feature screen from inventing its own colors, spacing, card radius, and button style.

## 2. Design Personality

Mory should feel:

- Personal.
- Calm.
- Intelligent.
- Trustworthy.
- Lightly tactile.
- More like a living notebook than an enterprise dashboard.

Avoid:

- Generic iOS List-only interface.
- Overuse of gradients.
- Huge hero marketing layouts inside the app.
- Decorative cards inside cards.
- Purple/blue monotone dominance.
- Low-contrast pastel text.

## 3. Typography

Recommended roles:

| Role | Usage |
|------|-------|
| Display | Empty states and major landing moments only |
| Title | Screen title and section hero |
| Headline | Card title and row title |
| Body | Memory content |
| Caption | Metadata, chips, source counts |
| Monospace Caption | Debug/internal IDs only |

Rules:

- Do not scale font size with viewport width.
- Support Dynamic Type.
- Avoid negative letter spacing.
- Keep compact cards compact.

## 4. Color

Semantic colors:

- Background.
- Surface.
- Elevated surface.
- Text primary.
- Text secondary.
- Border.
- Accent.
- Warning.
- Error.
- Success.

Card families:

| Card | Accent Direction |
|------|------------------|
| Memory | Soft blue/neutral |
| Storyline | Deep green or plum accent |
| Reflection | Teal/gold accent |
| System Prompt | Warm amber |
| Context Cluster | Green/earth accent |
| Pending Action | Red/orange only when action needed |

Rules:

- Use accents sparingly.
- Do not make the app one hue.
- Maintain contrast.

## 5. Spacing

Base spacing scale:

- 4
- 8
- 12
- 16
- 20
- 24
- 32

Rules:

- Card internal padding: 12-16.
- Screen horizontal padding: 16.
- Toolbar icon button minimum: 44x44.
- Chip height stable.
- Board card dimensions stable enough to avoid layout jumps.

## 6. Shape

Defaults:

- Cards: 8px radius, unless platform style demands slightly more.
- Buttons: platform default or 8px radius.
- Chips: capsule allowed for metadata.
- Modals: system sheet.

Avoid:

- Cards inside cards.
- Over-rounded everything.
- Decorative blobs/orbs.

## 7. Icons

Use SF Symbols consistently.

Required icon roles:

- Text capture.
- Voice capture.
- More artifact.
- Settings.
- Search.
- Filter.
- Memory.
- Storyline.
- Reflection.
- Person.
- Place.
- Theme.
- Decision.
- Permission.

Rules:

- Icon-only buttons need accessibility labels.
- Use tooltips/help text where platform supports.

## 8. Motion

Motion can support:

- Recording state.
- Card insertion.
- Toolbar expansion.
- Save confirmation.

Rules:

- Respect Reduce Motion.
- Avoid distracting loops.
- Recording state must not rely on animation alone.

## 9. Acceptance Criteria

- Shared token files exist.
- Primary screens use shared card/control styles.
- Dynamic Type does not break primary flows.
- Color contrast passes basic review.
- Toolbar and cards do not shift size due to changing text.

