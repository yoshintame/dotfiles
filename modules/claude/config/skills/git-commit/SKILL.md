---
name: git-commit
description: Generates Conventional Commits messages by analyzing staged changes and repo commit history. Use when the user says "commit", "git commit", or asks to commit changes.
license: MIT
metadata:
  version: 3.1.0
---

# Git Commit

## Rules

- Commit message **in English only**
- Subject line under 100 characters
- **Do not push** — only commit
- **Do not ask the user why** — infer from the diff and conversation
- **Never** add "Co-Authored-By: Claude" or "Generated with Claude Code"

## Workflow

**Always run this first, before any other git command:**

```bash
~/.claude/skills/git-commit/scripts/gather-context.sh
```

It returns branch, status, full staged diff, `--stat`, last 50 commits, base-branch divergence, pre-extracted Jira ticket, and any detected commit-convention configs. Use its output to drive everything below. If you still need more after that, run whatever git/Read commands you actually need.

1. **Stage** — if nothing is staged, pick **only** the files (or parts of files) that relate to the current task. Use `git add -p` to stage individual hunks when a file contains both relevant and unrelated changes. Keep commits atomic. If unsure which changes belong together, list the modified files and ask the user.

2. **Match style** — infer conventions from RECENT COMMITS. If REPO COMMIT CONVENTIONS detected a commitlint config or CONTRIBUTING.md, **read it** — repo-enforced rules override inferred ones.

3. **Write the message** in Conventional Commits format:

   ```
   type(scope): subject under 100 chars

   - bullet describing change
   - another bullet

   Refs: PROJ-123
   ```

   Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`. Scope: infer from changed files and existing commit scopes in the repo. Body only when the subject is insufficient — always bullets, never paragraphs. Append `Refs:` with the Jira ticket from the script's BRANCH section **or** from conversation context if you already know it.

4. **Open the editor** with the pre-filled message:

   ```bash
   git commit-edit "<message>"
   ```

   Run this with `run_in_background: true` — it opens the user's IDE editor, the user finalizes by saving. Do not wait for output.
