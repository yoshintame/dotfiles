---
name: git-commit
description: Generates Conventional Commits messages by analyzing staged changes and repo commit history. Use when the user says "commit", "git commit", or asks to commit changes.
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git branch:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git commit-edit*), Read
license: MIT
metadata:
  version: 2.0.0
---

# Git Commit

Generate Conventional Commits messages by studying the repo's existing commit style and analyzing staged changes.

**Language:** Commit message **only in English.**

## Critical Rules

- **Subject line MUST be under 100 characters**
- **Do NOT push** — only commit
- **Do NOT ask the user why** — infer intent from the diff and conversation context
- **NEVER** include "Generated with Claude Code" or any Claude Code URL
- **NEVER** include "Co-Authored-By: Claude <noreply@anthropic.com>"

## Workflow

### 1. Gather Context

```bash
git diff --staged
git status
git branch --show-current
git log --oneline -20
```

### 2. Stage Relevant Changes

If there are no staged changes, or if the user asks to select what to commit:

- Review `git status` and `git diff` (unstaged) to understand all modified files
- Based on the conversation context and the work done in this session, determine which files belong to this logical commit
- Stage only those files using `git add <file>` for each relevant file
- If only part of a file belongs to this commit, use `git add -p <file>` to stage specific hunks
- If unsure which changes belong together, list the modified files and ask the user which to include
- Keep commits atomic — one logical change per commit

### 3. Study Repo Commit Style (from step 1 log)

Analyze the last 20 commits to match the project's conventions:

- Typical scopes used (e.g. `auth`, `api`, `ui`, `wiki`)
- How subject lines are worded
- Whether body is used and how detailed it is
- Any patterns in formatting

**Adapt your message to fit the existing style.**

### 4. Extract Jira Ticket (optional)

If the branch name contains a Jira ticket ID (e.g. `PROJ-123-feature-name`, `feature/PROJ-123`), add `Refs: PROJ-123` at the end of the commit body.

### 5. Generate Commit Message

Write a Conventional Commits message:

```
type(scope): concise subject line (under 100 chars)

[Optional body — only if the change is non-trivial]

[Optional] Refs: PROJ-123
```

**Types:** feat, fix, docs, style, refactor, test, chore, perf, ci

**Scope:** infer from changed files and existing commit scopes in the repo.

**Body:** include only when the subject line alone doesn't tell the full story. Use bullet points (`-`) to list changes — never write a wall of text as a single paragraph.

### 6. Open commit in editor with pre-filled message

Use the `git commit-edit` subcommand to open the editor with the generated message. It handles `GIT_EDITOR` override automatically (Claude Code sandbox sets `GIT_EDITOR=true` — the script reads `core.editor` from git config instead).

```bash
git commit-edit "<generated commit message>"
```

**IMPORTANT:** Run this command with `run_in_background: true`. This ensures the Bash tool does not block waiting for the editor. The editor will open in the user's IDE with the pre-filled commit message. The user reviews it, optionally edits, saves and closes the file to complete the commit.

**Do not wait for the result or ask for confirmation — the editor flow handles it.**

## Important Notes

- **Match the repo style** — existing commits are your best guide.
- **Commit message in English only** — subject, body, and all sections.
- **Never skip the "why" question** — User context is crucial.
- **Use bullet points in body** — never write paragraph-style descriptions.
- **Reference Jira tickets** when found in branch name (`Refs: PROJ-123`).
- **Be specific** in technical summaries.
- **Think about the reader** — someone reading this in 6 months.
- **No co-authors** — Never add "Co-Authored-By" or mention Claude Code.
