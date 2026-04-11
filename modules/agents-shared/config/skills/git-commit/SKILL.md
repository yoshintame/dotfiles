---
name: git-commit
description: Generates Conventional Commits messages by analyzing staged changes and repo commit history. Use when the user says "commit", "git commit", or asks to commit changes.
license: MIT
metadata:
  version: 4.0.0
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

It returns branch, status, full staged diff, `--stat`, last 50 commits, base-branch divergence, pre-extracted Jira ticket, and any detected commit-convention configs. Use its output to drive everything below. If you still need more after that, run whatever git or Read commands you actually need.

1. Stage only the files or hunks that belong to the current task. Keep commits atomic.
2. Match the repo's existing style from recent commits and any commitlint or contributing config.
3. Write the message in Conventional Commits format:

   ```text
   type(scope): subject under 100 chars

   - bullet describing change
   - another bullet

   Refs: PROJ-123
   ```

4. Open the editor with the pre-filled message:

   ```bash
   git commit-edit "<message>"
   ```

Do not push after committing.
