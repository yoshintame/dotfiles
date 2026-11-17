#!/bin/sh
set -eu

export PATH=/opt/homebrew/bin:/usr/bin:/bin
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_BUNDLE_DUMP_NO_GO=1
export HOMEBREW_BUNDLE_DUMP_NO_NPM=1

BF="$1"
TMP="$(mktemp)"

brew bundle dump --force --file="$TMP"

MAS_APPS=0
if command -v mas >/dev/null 2>&1; then
  MAS_APPS=$(mas list 2>/dev/null | grep -c . || true)
fi

if [ "$MAS_APPS" -gt 0 ] && ! grep -q '^mas ' "$TMP"; then
  echo "dump-brewfile: mas lists $MAS_APPS apps but brew bundle dump has no mas entries; keeping existing Brewfile" >&2
  rm -f "$TMP"
  exit 1
fi

if grep -q '^brew ' "$TMP" && grep -q '^cask ' "$TMP"; then
  mv "$TMP" "$BF"
else
  echo "dump-brewfile: brew bundle dump produced no brew/cask entries; keeping existing Brewfile" >&2
  rm -f "$TMP"
  exit 1
fi
