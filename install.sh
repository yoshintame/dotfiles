#!/usr/bin/env bash
# install.sh — thin wrapper over bootstrap.sh for the case when the repo is
# already cloned locally and you want to (re)build the system.
#
# For a true from-scratch install on a fresh macOS, use:
#   curl -fsSL https://raw.githubusercontent.com/yoshintame/dotfiles/master/bootstrap.sh | bash -s -- <host>
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${ROOT}/bootstrap.sh" "$@"
