---
name: handoff
description: Generate a handoff / init-prompt file for the next session from the current session's context.
---

## Input

One argument: a short description of what the next session does. If none is given, ask — never guess.

## Save it, don't print it

Derive a short ascii kebab-slug from the description, then:

```
bun ~/.claude/skills/handoff/scripts/handoff-path.ts <slug>
```

It creates `~/.claude/handoffs/<cwd>/<slug>.md` and prints the absolute path. Write the handoff there. Then reply with one inline clickable link to that path and nothing else — no copy of the content in chat.

The file is an editable artifact: the user opens it, selects parts, and asks for fixes. Apply those with Edit on the file; do not regenerate the whole thing.

## What goes in the file

From the live conversation, not the session JSONL. Include only blocks that apply, shortest first:

- **Goal** — `# Init: <one-line goal>`. If a stage skill was named, reference it here as `/skill-name`.
- **Context** — what's done, current state, what's merged.
- **Must-read first** — the load-bearing block: absolute file paths, `/skill` references, vault notes to load before acting.
- **Working tree** — repo, branch, worktree, uncommitted (code sessions only).
- **Task** — what to do, linking the plan doc by path.
- **Conventions** — only non-default ones (e.g. `/git-commit`, TDD).
- **Scope-guards** — only session-specific don'ts; stage guards live in the referenced skill.

## Rules

- Don't duplicate what already lives in a PRD, plan, ADR, issue, commit, or diff — reference it by absolute path or URL.
