#!/bin/sh
set -eu

export PATH=/opt/homebrew/bin:/usr/bin:/bin
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_BUNDLE_DUMP_NO_GO=1
export HOMEBREW_BUNDLE_DUMP_NO_NPM=1

BF="$1"
TMP="$(mktemp)"

brew bundle dump --force --file="$TMP"

mas list | awk '{ id=$1; $1=""; line=$0; sub(/^[ \t]+/, "", line); sub(/[ \t]+\([^)]*\)[ \t]*$/, "", line); printf "mas \"%s\", id: %s\n", line, id }' >>"$TMP"

if grep -q '^brew ' "$TMP" && grep -q '^cask ' "$TMP"; then
  mv "$TMP" "$BF"
else
  echo "dump-brewfile: brew bundle dump produced no brew/cask entries; keeping existing Brewfile" >&2
  rm -f "$TMP"
  exit 1
fi
