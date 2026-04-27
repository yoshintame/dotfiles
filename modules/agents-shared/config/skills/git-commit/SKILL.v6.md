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

   The wrapper has two execution paths:

   - **Default (no `--auto`)** — delegates to `git commit -e`. The user's real editor opens for message review, repo `pre-commit` / `commit-msg` / `post-commit` hooks fire, lint and test gates run as configured. Race-safety: `.git/index.lock` (git-native), no CAS against `HEAD` movement. Suitable for the typical interactive single-session commit.
   - **`--auto`** — builds the commit on top of `HEAD` in an ephemeral `GIT_INDEX_FILE` under `$GIT_DIR`, then advances `HEAD` via atomic compare-and-swap (`commit-tree` + `update-ref HEAD <new> <expected>`). On lost CAS the wrapper retries with the new `HEAD` snapshot. Race-safe under parallel Claude sessions sharing the worktree, but hooks are NOT executed (plumbing flow). Suitable when the user invoked the skill with `auto`, or when concurrent sessions are involved.

   Supported flags (must precede the message):

   | Flag | Effect |
   |---|---|
   | `--auto` | Take the CAS path; skip editor preview. Pass when the user invoked with `auto`. |
   | `-s`, `--signoff` | Append `Signed-off-by` trailer (forwarded to `git commit -s` in editor mode; manually appended in `--auto`). |
   | `-S`, `--gpg-sign[=<keyid>]` | GPG-sign the commit. |
   | `-n`, `--no-verify` | In editor mode: forwarded to `git commit --no-verify` (skips hooks). In `--auto`: no-op (hooks aren't run anyway). |
   | `--author "Name <email>"` | Override commit author via `GIT_AUTHOR_NAME`/`EMAIL`. |
   | `--date <when>` | Override author date via `GIT_AUTHOR_DATE`. |
   | `--allow-empty-message` | Don't abort on empty post-edit message. |

   Unknown flags are rejected with exit 2: the plumbing path does not honor most `git commit` flags (e.g. `-c`, `--fixup`, `--squash`, `--reuse-message`), so silent pass-through would be misleading.

4. Do not run bare `git add`, `git commit`, or `git commit-edit`. Always use `git-commit-atomic`. Do not pass `GIT_INDEX_FILE=...`.

Do not push.
