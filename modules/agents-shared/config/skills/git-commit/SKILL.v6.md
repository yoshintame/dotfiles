---
name: git-commit
description: Generates Conventional Commits messages by analyzing staged changes and repo commit history. Use when the user says "commit", "git commit", or asks to commit changes.
license: MIT
metadata:
  version: 6.0.0
---

# Git Commit

## Rules

- Commit message in English only
- Subject line under 100 characters, Conventional Commits format: `type(scope): subject`
- Body uses bullets only — no prose paragraphs, no lead-in sentences
- Do not push, only commit
- Do not ask the user why, infer from the diff and conversation
- Never add AI attribution lines

## Workflow

1. Run the read-only context helper:

   ```bash
   git commit-context
   ```

   Output includes branch info, working-tree status, worktree diff vs `HEAD`, branch divergence, recent-commits style, and detected repo commit conventions.

2. Commit using one of two atomic wrappers — both are race-safe under concurrent Claude sessions in the same worktree:

   File-level (default, ≥95% of cases):

   ```bash
   git-commit-atomic "<message>" path1 path2 path3
   ```

   Stages the listed paths and commits them via git's `--only` mode (`git commit -m msg -- paths`). Builds the tree from current `HEAD` plus the worktree contents of the listed paths, ignoring any unrelated entries another session may have left in the shared `.git/index`. Retries on `index.lock` collisions automatically.

   Hunk-level (rare; only when the agent has pre-built patches):

   ```bash
   git-commit-hunks "<message>" patch1.diff patch2.diff
   ```

   Applies the patches into an ephemeral index and updates `HEAD` via atomic compare-and-swap (`commit-tree` + `update-ref HEAD <new> <expected>`). If a parallel session moves `HEAD` between snapshot and commit, the wrapper retries with the new snapshot.

3. Do not run bare `git add` or `git commit`. Always use the wrappers above. Do not pass `GIT_INDEX_FILE=...`.

Do not push.
