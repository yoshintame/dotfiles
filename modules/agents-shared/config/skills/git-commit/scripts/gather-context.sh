#!/usr/bin/env bash
# gather-context.sh — collect everything the git-commit skill needs in one shot.
#
# Also provisions a per-session private git index so concurrent Claude sessions
# in the same repo can stage and commit independently without stepping on each
# other's staged files.
#
# Usage: gather-context.sh [--index PATH] [REPO]
#   --index PATH   Reuse an existing private index path (idempotent across calls).
#   REPO           Path to repo (default: $PWD).

set -uo pipefail

INDEX_ARG=""
REPO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --index)
      INDEX_ARG="${2:-}"
      shift 2
      ;;
    --index=*)
      INDEX_ARG="${1#--index=}"
      shift
      ;;
    *)
      REPO="$1"
      shift
      ;;
  esac
done
REPO="${REPO:-$PWD}"

git_cmd() { git -C "$REPO" "$@"; }
git_priv() { GIT_INDEX_FILE="$PRIV_INDEX" git -C "$REPO" "$@"; }
git_shared() { (unset GIT_INDEX_FILE; git -C "$REPO" "$@"); }

if ! git_cmd rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: $REPO is not a git work tree" >&2
  exit 1
fi

GIT_DIR=$(git_cmd rev-parse --git-dir)
case "$GIT_DIR" in
  /*) ;;
  *)  GIT_DIR="$REPO/$GIT_DIR" ;;
esac

SESSIONS_DIR="$GIT_DIR/claude-sessions"
mkdir -p "$SESSIONS_DIR"

if [ -n "$INDEX_ARG" ]; then
  PRIV_INDEX="$INDEX_ARG"
elif [ -n "${GIT_INDEX_FILE:-}" ]; then
  PRIV_INDEX="$GIT_INDEX_FILE"
else
  PRIV_INDEX=$(mktemp "$SESSIONS_DIR/idx-XXXXXXXX")
fi

if [ ! -s "$PRIV_INDEX" ]; then
  GIT_INDEX_FILE="$PRIV_INDEX" git_cmd read-tree HEAD
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

section "PRIVATE INDEX (this session)"
printf 'path: %s\n' "$PRIV_INDEX"
cat <<EOF
Use this index for ALL git commands in this commit flow. Each Bash call is a
fresh shell, so prefix every command inline:

  GIT_INDEX_FILE=$PRIV_INDEX git add -- path/to/file
  GIT_INDEX_FILE=$PRIV_INDEX git diff --cached
  GIT_INDEX_FILE=$PRIV_INDEX git commit-edit "type(scope): subject"

Do NOT run plain "git add" or "git commit" — those touch the shared index and
may collide with other Claude sessions running in this repo.
EOF

section "SHARED INDEX (other sessions / user)"
SHARED_STAT=$(git_shared diff --cached --stat 2>/dev/null || true)
if [ -z "$SHARED_STAT" ]; then
  echo "(shared index is clean — matches HEAD)"
else
  echo "WARNING: the shared .git/index has staged changes that do NOT belong to this session."
  echo "Treat these files as off-limits. Do not 'git add' or 'git restore --staged' them."
  echo
  printf '%s\n' "$SHARED_STAT"
fi

section "BRANCH"
printf 'current: %s\n' "$BRANCH"
[ -n "$JIRA" ] && printf 'jira:    %s\n' "$JIRA"
[ -n "$BASE" ] && printf 'base:    %s\n' "$BASE"

section "STATUS (working tree)"
git_cmd status --short

section "STAGED DIFF — private index (--stat)"
git_priv diff --cached --stat

section "STAGED DIFF — private index (full)"
PRIV_DIFF=$(git_priv diff --cached)
if [ -z "$PRIV_DIFF" ]; then
  echo "(nothing staged in private index yet — stage with: GIT_INDEX_FILE=$PRIV_INDEX git add -- <paths>)"
else
  printf '%s\n' "$PRIV_DIFF"
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
