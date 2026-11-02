#!/usr/bin/env bash
set -eu

[ -n "${CLAUDE_ENV_FILE:-}" ] || exit 0

dir="$(jq -r '.new_cwd // .cwd // empty')"
[ -n "$dir" ] || exit 0

case "$dir" in
  "$HOME"/Development/work/vtb/repos/* | "$HOME"/Development/work/vtb/libs/*) tz=Europe/Moscow ;;
  *) tz="$(git -C "$dir" config --get vtb.tz 2>/dev/null || true)" ;;
esac

if [ -n "$tz" ]; then
  printf 'export TZ=%s\n' "$tz" >> "$CLAUDE_ENV_FILE"
else
  printf 'unset TZ\n' >> "$CLAUDE_ENV_FILE"
fi
