#!/usr/bin/env bash
set -euo pipefail

export DESVIO_CONFIG="$HOME/.config/desvio/plannotator/desvio.conf"
export DESVIO_INTERACTIVE=0
config_dir=$(dirname "$DESVIO_CONFIG")
# shellcheck source=desvio.conf
. "$DESVIO_CONFIG"

git -C "$DESVIO_REPO" fetch --quiet --tags origin
latest=$(git -C "$DESVIO_REPO" tag --list 'v*' --sort=-v:refname | head -1)
key=$(
  {
    echo "$latest"
    sed 's/#.*//' "$config_dir/manifest.txt" | xargs -n1 git -C "$DESVIO_REPO" rev-parse
    cat "$config_dir/desvio.conf" "$config_dir/vscode-theme.ts"
    bun "$config_dir/vscode-theme.ts"
  } | git hash-object --stdin
)
stamp="$DESVIO_STATE/installed-key"

if [ "${1:-}" != "--force" ] && [ "$key" = "$(cat "$stamp" 2>/dev/null)" ]; then
  exit 0
fi

desvio build --no-bisect-gate "$latest"
desvio run install
mkdir -p "$DESVIO_STATE"
printf '%s\n' "$key" > "$stamp"
