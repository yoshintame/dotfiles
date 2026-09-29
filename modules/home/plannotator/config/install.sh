#!/usr/bin/env bash
set -euo pipefail
: "${DESVIO_STATE:?run this with: desvio run install}"

mkdir -p "$HOME/.local/bin"
install -m 755 "$DESVIO_STATE/plannotator" "$HOME/.local/bin/plannotator"
"$HOME/.local/bin/plannotator" --version
