# 01. v7 Product Thesis

## 1. Positioning

Mory belongs to personal knowledge management, personal memory augmentation, digital life log, and AI reflection.

The category difference:

- Notes store what the user wrote.
- Journals help the user write today.
- Mory should connect fragments across time, people, mood, places, decisions, and artifacts.

## 2. The v7 Problem

Current analysis can describe a memory, but it often cannot behave like it knows the user's long-term life context.

The main reason is architectural:

- Analyze sees the current memory and a light entity list.
- It does not receive profile-level facts.
- It does not receive a ranked history pack.
- It does not receive correction history.
- It does not receive structured mood evidence.
- It does not treat the user as a stable self entity.

Therefore v7 must build the missing long-term intelligence layer.

## 3. Product Principle

Mory should not infer permanent truths from one memory.

Instead:

```text
thin evidence -> low-confidence proposal
repeated evidence -> stronger candidate
user correction -> trusted signal
trusted signal -> future context
```

## 4. What v7 Must Feel Like

The user should notice that:

- Mory remembers that "Alex from work" and "Alex from the lobby" are different when evidence says so.
- Mory can ask whether "roommate" refers to one person or a group.
- Mory knows that "my mom" is personally important without treating "mom" as a generic tag.
- Mory can notice that a repeated decision thread has changed.
- Mory can distinguish "I was joking" from "I was actually upset" after the user corrects it.
- Mory can surface a useful question even when the user has not opened the app recently.

## 5. Non-Goals

v7 should not:

- upload the full private memory library by default,
- make the server a full memory database,
- make AI output trusted facts without policy or confirmation,
- build polished UI before data contracts and correction actions exist,
- rely on background execution as if iOS allowed unlimited work.
