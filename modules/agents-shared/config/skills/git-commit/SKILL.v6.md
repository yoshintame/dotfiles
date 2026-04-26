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

2. Choose commit mode based on how the user invoked the skill:

   - With argument `auto` (e.g. the user typed `/git-commit auto`): commit without editor preview by passing `--auto`.
   - Otherwise (default): commit with the user's editor opened on the message for review.

3. Run the wrapper:

   ```bash
   git-commit-atomic [flags] "<message>" [<file>...] [-- <patch>...]
   ```

   - **Files** (positional, before `--`): staged whole from the worktree.
   - **Patches** (positional, after `--`): applied to an ephemeral index via `git apply --cached`.
   - The two halves combine into one commit, so you can mix them: `git-commit-atomic "msg" foo.md bar.md -- baz.diff`.

   Supported flags (must precede the message):

   | Flag | Effect |
   |---|---|
   | `--auto` | Skip the editor preview, commit verbatim. Pass when the user invoked with `auto`. |
   | `-s`, `--signoff` | Append `Signed-off-by` trailer from `user.name`/`user.email`. |
   | `-S`, `--gpg-sign[=<keyid>]` | GPG-sign the commit (forwarded to `git commit-tree`). |
   | `-n`, `--no-verify` | Accepted as a no-op — this wrapper uses git plumbing, hooks are never invoked. |
   | `--author "Name <email>"` | Override commit author. |
   | `--date <when>` | Override author date. |
   | `--allow-empty-message` | Don't abort if the post-edit message is empty. |

   Unknown flags are rejected: the plumbing flow does not honor most `git commit` flags (e.g. `-c`, `--fixup`, `--squash`), so silent pass-through would be misleading.

   The wrapper builds the commit on top of current `HEAD` and advances `HEAD` via atomic compare-and-swap, so it is race-safe under concurrent Claude sessions sharing the worktree. If a parallel session moves `HEAD` between snapshot and update, the wrapper retries with the new `HEAD`.

4. Do not run bare `git add`, `git commit`, or `git commit-edit`. Always use `git-commit-atomic`. Do not pass `GIT_INDEX_FILE=...`.

Do not push.
