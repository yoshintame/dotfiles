---
name: git-commit
description: Generates Conventional Commits messages by analyzing staged changes and repo commit history. Use when the user says "commit", "git commit", or asks to commit changes.
license: MIT
metadata:
  version: 5.0.0
---

# Git Commit

## Rules

- Commit message in English only
- Subject line under 100 characters
- Do not push, only commit
- Do not ask the user why, infer from the diff and conversation
- Never add AI attribution lines

## Workflow

Always run this first, before any other git command:

```bash
if [ -x "$HOME/.agents/skills/git-commit/scripts/gather-context.sh" ]; then
  "$HOME/.agents/skills/git-commit/scripts/gather-context.sh"
else
  "$HOME/.claude/skills/git-commit/scripts/gather-context.sh"
fi
```

The output includes a `PRIVATE INDEX (this session)` section with a path and
ready-to-copy command examples. **Follow it literally**: prefix every git
command in this commit flow with `GIT_INDEX_FILE=<that path>` inline. Bash tool
calls don't share env between invocations, so the prefix must be on every call.
Never run a bare `git add` or `git commit` — you'll collide with other Claude
sessions in the same repo.

Then:

1. Stage only the files or hunks that belong to the current task.
2. Stage them only into the private index.
3. Keep commits atomic.
4. Match the repo's existing style from recent commits and any commitlint /
   contributing config surfaced by gather-context.
5. Write the message in Conventional Commits format:

   ```text
   type(scope): subject under 100 chars

   - bullet describing change
   - another bullet

   Refs: PROJ-123
   ```

6. Commit with the private index:

   ```bash
   GIT_INDEX_FILE=<path> git commit-edit "<message>"
   ```

Do not push.
