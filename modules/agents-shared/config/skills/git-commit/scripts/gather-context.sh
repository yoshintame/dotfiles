#!/usr/bin/env bash
# gather-context.sh — collect everything the git-commit skill needs in one shot.

set -uo pipefail

REPO="${1:-$PWD}"
git_cmd() { git -C "$REPO" "$@"; }

if ! git_cmd rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: $REPO is not a git work tree" >&2
  exit 1
fi

section() {
  printf '\n=== %s ===\n' "$1"
}

BRANCH=$(git_cmd branch --show-current 2>/dev/null || echo "(detached)")
JIRA=$(printf '%s' "$BRANCH" | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' | head -n1 || true)

BASE=""
for candidate in main master trunk develop; do
  if git_cmd rev-parse --verify --quiet "refs/heads/$candidate" >/dev/null; then
    BASE="$candidate"
    break
  fi
done

section "BRANCH"
printf 'current: %s\n' "$BRANCH"
[ -n "$JIRA" ] && printf 'jira:    %s\n' "$JIRA"
[ -n "$BASE" ] && printf 'base:    %s\n' "$BASE"

section "STATUS"
git_cmd status --short

section "STAGED DIFF (--stat)"
git_cmd diff --staged --stat

section "STAGED DIFF (full)"
STAGED_DIFF=$(git_cmd diff --staged)
if [ -z "$STAGED_DIFF" ]; then
  echo "(nothing staged)"
else
  printf '%s\n' "$STAGED_DIFF"
fi

section "UNSTAGED DIFF (--stat)"
UNSTAGED_STAT=$(git_cmd diff --stat)
if [ -z "$UNSTAGED_STAT" ]; then
  echo "(no unstaged changes)"
else
  printf '%s\n' "$UNSTAGED_STAT"
fi

if [ -n "$BASE" ] && [ "$BRANCH" != "$BASE" ]; then
  section "BRANCH DIVERGENCE ($BASE..HEAD)"
  COUNT=$(git_cmd rev-list --count "$BASE..HEAD" 2>/dev/null || echo 0)
  printf 'commits ahead of %s: %s\n' "$BASE" "$COUNT"
  if [ "$COUNT" != "0" ]; then
    git_cmd log --oneline "$BASE..HEAD"
  fi
fi

section "RECENT COMMITS (last 50, oneline)"
git_cmd log --oneline -50

section "REPO COMMIT CONVENTIONS"
FOUND_CONVENTIONS=0
ROOT=$(git_cmd rev-parse --show-toplevel)
for f in \
  .commitlintrc .commitlintrc.json .commitlintrc.yaml .commitlintrc.yml \
  .commitlintrc.js .commitlintrc.cjs commitlint.config.js commitlint.config.cjs \
  commitlint.config.mjs commitlint.config.ts \
  .gitmessage .github/commit-convention.md CONTRIBUTING.md CONTRIBUTING.rst
do
  if [ -f "$ROOT/$f" ]; then
    printf 'found: %s\n' "$f"
    FOUND_CONVENTIONS=1
  fi
done
[ "$FOUND_CONVENTIONS" = "0" ] && echo "(none detected — infer from recent commits)"
