# 17. Identity Correction Examples

## 1. Purpose

Identity errors are high-risk in a personal memory system. This document defines expected correction behavior for common Mory cases.

## 2. “This Is Me”

Case:

```text
AI created a person entity named "Zoe", but Zoe is the user.
```

User action:

- “这是我自己”

Domain effect:

- write `CorrectionEvent.markAsMe`,
- add alias to `SelfProfile` if user confirms,
- tombstone or rewrite wrong person link,
- recompute affected profiles/arcs/reflections,
- future resolver maps Zoe to self only when context supports it.

## 3. “This Is Not Me”

Case:

```text
"小周" sometimes means the user, sometimes another person.
```

User action:

- “这不是我”

Domain effect:

- write negative self evidence,
- keep alias ambiguous if needed,
- avoid global alias merge.

## 4. Same Person

Case:

```text
Alex, Alexander, and Alex Chen are the same person.
```

User action:

- confirm same person.

Domain effect:

- create merge mutation,
- choose survivor id,
- rewrite links/edges/profiles,
- add aliases,
- tombstone loser ids,
- enqueue profile and search recompute.

## 5. Not Same Person

Case:

```text
Alex the coworker and Alex the friend are different people.
```

User action:

- “不是同一个人”

Domain effect:

- write `CorrectionEvent.notSameEntity`,
- store negative edge between ids,
- prevent future automatic merge,
- ask disambiguation when context is unclear.

## 6. Role Label

Case:

```text
"舍友" appears without name.
```

Expected behavior:

- create role label,
- link to ambiguous bucket,
- do not create concrete person if evidence is insufficient,
- ask user only when useful.

Possible user answer:

- “是 Lily”
- “是 Max”
- “他们都有”
- “不确定”
- “以后别问这个”

## 7. Relationship Changed

Case:

```text
"我和他现在不算朋友了。"
```

Expected behavior:

- propose relationship change,
- preserve relationship history,
- do not overwrite old relationship as if it never existed,
- mark field evidence and date range.

## 8. Wrong Profile Field

Case:

```text
Mory says Alex is a roommate, but Alex is a coworker.
```

User action:

- edit profile field or mark wrong.

Domain effect:

- write correction,
- update field with user-confirmed source,
- lower trust in conflicting AI evidence,
- future profile job must not overwrite without stronger confirmation.

## 9. Do Not Track Topic

Case:

```text
User does not want a relationship/topic analyzed.
```

Domain effect:

- write sensitive boundary,
- omit from cloud context pack,
- suppress notification prompts,
- keep raw memory unless user deletes it.

## 10. Acceptance Criteria

- Corrections are append-only and auditable.
- Resolver reads negative evidence.
- Merge/split can be undone or marked non-reversible.
- Profile jobs respect user-confirmed fields.
- UI can be simple, but domain actions must be complete.
