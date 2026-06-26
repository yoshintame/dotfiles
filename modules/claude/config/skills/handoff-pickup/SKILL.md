---
name: handoff-pickup
description: Pick up an open handoff file in a new session — stamps consumed metadata and loads the body as context.
---

## Input

One argument: the absolute path to a handoff `.md` file (as produced by `/handoff-create`).

## Run the script

```
bun ~/.claude/skills/handoff-pickup/scripts/handoff-pickup.ts <absolute-path>
```

The script appends the current session to the file's `consumed_by` / `consumed_at` lists (inline YAML arrays), sets `status: consumed`, and prints the handoff body to stdout. That body is your starting context — follow its must-read first, then carry out the task.

Multiple sessions can pick up the same handoff; each gets appended. Same session rerunning is a no-op (already in the list). The only refusal is the creator picking up its own file (exit 2) — a handoff is not for the session that wrote it.
