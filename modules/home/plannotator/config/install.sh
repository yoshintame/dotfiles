#!/usr/bin/env bash
set -euo pipefail
: "${DESVIO_WORKTREE:?run this with: desvio run install}"

mkdir -p "$HOME/.local/bin"
install -m 755 "$DESVIO_WORKTREE/plannotator" "$HOME/.local/bin/plannotator"
"$HOME/.local/bin/plannotator" --version
