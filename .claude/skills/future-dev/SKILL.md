---
name: future-dev
description: "Captures a future development idea as a detailed, Claude-ready task prompt. Creates tasks/DEV-NNN.md with a self-contained prompt and adds an indexed row to future-devs.md. Use when the user wants to log an idea/TODO to implement later, or says 'future-dev', 'lisa idee', 'pane mõte kirja', 'add a task', 'todo for later'."
argument-hint: "[the idea, in any language]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit
---

# future-dev — capture an idea as a Claude-ready task

The user is logging an idea to implement later. Turn their (possibly rough,
possibly Estonian) idea into a **detailed, self-contained prompt in English**
that a future Claude Code session can act on without further context.

## Workflow

1. **Determine the next DEV number.** Scan `tasks/` for `DEV-*.md` files, take
   the highest number, add 1. First task is `DEV-001`. Numbers are zero-padded
   to 3 digits and never reused.

2. **Understand the idea.** The user's input may be terse or in Estonian.
   Capture it verbatim for the "Idea (raw)" section, then expand it into a
   precise English task prompt.

3. **Gather codebase context.** Use Grep/Glob to find the relevant files for
   this idea (the production game lives in `ninja_clash/`). List concrete file
   paths the implementer should start from. Read `design/gdd/game-concept.md`
   or related design docs if the idea touches game design.

4. **Ask clarifying questions ONLY if genuinely blocked.** Prefer concise
   questions with a strong recommended default (the user typically accepts the
   recommended option). If the idea is clear enough to write a good prompt,
   skip questioning and proceed to the draft. Reasonable assumptions are fine —
   note them in the task under "Assumptions".

5. **Write the task file** to `tasks/DEV-NNN-<slug>.md` using the template
   below. The `<slug>` is a short kebab-case version of the title.

6. **Update the index** `future-devs.md`: replace the `_none yet_` placeholder
   row (if present) or append a new row to the table. Keep rows sorted by ID.

7. **Confirm before writing.** Per CLAUDE.md collaboration protocol, show a
   short draft/summary and ask "May I write this to tasks/DEV-NNN-<slug>.md and
   update future-devs.md?" before using Write/Edit.

## Task file template

```markdown
# DEV-NNN: [Concise title]

**Status:** 🔵 Backlog   **Priority:** [P1/P2/P3]   **Area:** [gameplay / UI / audio / VFX / systems / tooling / build]
**Created:** [today's date YYYY-MM-DD]

## Idea (raw)
[The user's original idea, verbatim, in whatever language they used.]

## Prompt for Claude
> Paste everything below into a fresh Claude Code session to start this task.

### Objective
[One paragraph: what to build or change, and the player-facing or technical
reason why.]

### Context
[Which game system this touches, the current behavior, and where it lives in
the codebase. Enough that a fresh session needs no extra explanation.]

### Relevant files
- `ninja_clash/<file>` — [why it matters / what to change here]

### Requirements
1. [Specific, testable requirement]
2. ...

### Constraints
- Godot 4.6 / GDScript (see `docs/engine-reference/godot/VERSION.md`).
- Follow CLAUDE.md: ask before writing files, keep gameplay values data-driven
  (no hardcoded tuning), match existing conventions in `ninja_clash/`.
- [Any task-specific constraints.]

### Assumptions
- [Any assumption made because the idea was underspecified. Empty if none.]

### Acceptance criteria
- [ ] [Testable success condition]
- [ ] ...

### Out of scope
- [What NOT to do in this task, to keep it focused.]
```

## Index row format

In `future-devs.md`, each task is one table row:

```markdown
| DEV-NNN | [Title] | [Area] | [P1/P2/P3] | 🔵 Backlog | [DEV-NNN](tasks/DEV-NNN-<slug>.md) |
```

## Notes
- The raw idea is preserved verbatim; the English prompt is the working
  artifact handed to Claude later.
- If the user later asks to start a logged task, read its `tasks/DEV-NNN-*.md`
  and follow the "Prompt for Claude" section, then update its status in both
  the task file and `future-devs.md`.
