#!/usr/bin/env bash
set -euo pipefail

export DESVIO_CONFIG="$HOME/.config/desvio/plannotator/desvio.conf"
export DESVIO_INTERACTIVE=0
config_dir=$(dirname "$DESVIO_CONFIG")
repo="$HOME/Development/backnotprop/plannotator"

git -C "$repo" fetch --quiet --tags origin
. "$DESVIO_CONFIG"

key=$(
  {
    echo "$DESVIO_BASE"
    sed 's/#.*//' "$config_dir/manifest.txt" | xargs -n1 git -C "$DESVIO_REPO" rev-parse
    cat "$config_dir"/*
    bun "$config_dir/vscode-theme.ts"
  } | git hash-object --stdin
)
stamp="$DESVIO_STATE/installed-key"

if [ "${1:-}" != "--force" ] && [ "$key" = "$(cat "$stamp" 2>/dev/null)" ]; then
  exit 0
fi

desvio build --no-bisect-gate
desvio run install
mkdir -p "$DESVIO_STATE"
printf '%s\n' "$key" > "$stamp"
