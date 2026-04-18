#!/usr/bin/env bash
set -euo pipefail

# bootstrap.sh — single-command dotfiles installer for macOS / Linux.
#
# Usage (fresh machine, via curl):
#   curl -fsSL https://raw.githubusercontent.com/yoshintame/dotfiles/master/bootstrap.sh | bash -s -- lasthaze-mbp
#
# Usage (local, repo already cloned):
#   bash ~/.dotfiles/bootstrap.sh lasthaze-mbp
#
# Idempotent: safe to re-run. Each step checks state before acting.

REPO_URL="${DOTFILES_REPO_URL:-https://github.com/yoshintame/dotfiles.git}"
REPO_DIR="${DOTFILES_DIR:-${HOME}/.dotfiles}"

HOST="${1:-}"


log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }
err()  { printf '\033[1;31mERR\033[0m %s\n' "$*" >&2; }

usage() {
  cat >&2 <<EOF
Usage: bootstrap.sh <host>

Hosts defined in flake.nix:
  lasthaze-mbp       macOS (aarch64-darwin)
  lasthaze-server    Linux (x86_64-linux)

Example:
  bash bootstrap.sh lasthaze-mbp
EOF
  exit 2
}

require_host() {
  if [ -z "${HOST}" ]; then
    err "HOST argument is required"
    usage
  fi
}

ensure_xcode_clt() {
  if [ "$(uname -s)" != "Darwin" ]; then
    return 0
  fi
  if xcode-select -p >/dev/null 2>&1; then
    log "Xcode Command Line Tools already installed"
    return 0
  fi
  log "Installing Xcode Command Line Tools (interactive prompt)…"
  xcode-select --install || true
  until xcode-select -p >/dev/null 2>&1; do
    sleep 5
    echo "  waiting for Xcode CLT install to finish…"
  done
  log "Xcode CLT ready"
}

ensure_repo_cloned() {
  if [ -d "${REPO_DIR}/.git" ]; then
    log "Repo already present at ${REPO_DIR}"
    return 0
  fi
  log "Cloning ${REPO_URL} → ${REPO_DIR}"
  git clone "${REPO_URL}" "${REPO_DIR}"
}

ensure_nix_installed() {
  if command -v nix >/dev/null 2>&1; then
    log "Nix already installed"
    return 0
  fi
  log "Installing Nix via Determinate Systems installer…"
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
}

source_nix_env() {
  if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  elif [ -e "${HOME}/.nix-profile/etc/profile.d/nix.sh" ]; then
    # shellcheck disable=SC1091
    . "${HOME}/.nix-profile/etc/profile.d/nix.sh"
  fi
  export NIX_CONFIG="experimental-features = nix-command flakes"
  export FLAKE_ROOT="${REPO_DIR}"
}

backup_conflicting_etc_files() {
  [ "$(uname -s)" = "Darwin" ] || return 0
  local f
  for f in /etc/zshenv /etc/zshrc /etc/bashrc /etc/shells; do
    if [ -f "$f" ] && [ ! -L "$f" ] && [ ! -f "${f}.before-nix-darwin" ]; then
      log "Backing up $f → ${f}.before-nix-darwin (nix-darwin activation prep)"
      sudo mv "$f" "${f}.before-nix-darwin"
    fi
  done
}

run_system_switch() {
  local host="$1"
  log "Building system for host: ${host}"
  case "$(uname -s)" in
    Darwin)
      sudo --preserve-env=NIX_CONFIG \
        /nix/var/nix/profiles/default/bin/nix \
        --extra-experimental-features "nix-command flakes" \
        run github:lnl7/nix-darwin/nix-darwin-25.05#darwin-rebuild -- \
        --impure switch --flake "${REPO_DIR}#${host}"
      ;;
    Linux)
      nix --extra-experimental-features "nix-command flakes" \
        run github:nix-community/home-manager/release-25.05 -- \
        switch --impure --flake "${REPO_DIR}#${host}"
      ;;
    *)
      err "Unsupported OS: $(uname -s)"
      exit 1
      ;;
  esac
}

bootstrap_age_key() {
  local key_file="${HOME}/.config/sops/age/keys.txt"
  if [ -f "${key_file}" ]; then
    log "SOPS age key already present at ${key_file}"
    return 0
  fi
  if ! command -v op >/dev/null 2>&1; then
    warn "1Password CLI (op) not found — skipping age-key bootstrap."
    warn "Ensure brew bundle installed 1password-cli, authorize 1Password GUI, then run: mise run dot:bootstrap-age-key"
    return 0
  fi
  if ! op account list >/dev/null 2>&1; then
    warn "1Password CLI not authorized yet."
    warn "Open 1Password.app → sign in → Settings → Developer → enable CLI integration, then run: mise run dot:bootstrap-age-key"
    return 0
  fi
  log "Restoring SOPS age key from 1Password"
  mkdir -p "$(dirname "${key_file}")"
  op read 'op://Private/sops-age-key/private key' > "${key_file}"
  chmod 600 "${key_file}"
}

bootstrap_ssh() {
  if [ "$(uname -s)" != "Darwin" ]; then
    return 0
  fi
  if ! command -v mise >/dev/null 2>&1; then
    warn "mise not found — skipping SSH Agent bootstrap. Run: mise run dot:bootstrap-ssh after rebuild."
    return 0
  fi
  log "Configuring 1Password SSH Agent via mise"
  if ! (cd "${REPO_DIR}" && mise run dot:bootstrap-ssh); then
    warn "dot:bootstrap-ssh failed — see docs/post-install-checklist.md"
  fi
}

print_post_install_checklist() {
  if [ "$(uname -s)" != "Darwin" ]; then
    return 0
  fi
  cat <<EOF

\033[1;32m================================================================\033[0m
\033[1;32m  System build complete. Manual post-install steps remaining:\033[0m
\033[1;32m================================================================\033[0m

Full checklist: ${REPO_DIR}/docs/post-install-checklist.md

Summary of what you still need to click through System Settings:

  1. Apple ID / App Store signin (for mas)
  2. 1Password signin + SSH Agent + CLI integration
  3. Accessibility permissions: Karabiner / Hammerspoon / AeroSpace
  4. Input Monitoring: karabiner_grabber, karabiner_observer
  5. Full Disk Access: your terminal + restic
  6. Login Items: Karabiner / Hammerspoon / AeroSpace
  7. (optional) tailscale up

These cannot be automated without MDM. See docs/post-install-checklist.md for deeplinks.

After finishing the checklist run:
  mise run dot:bootstrap-age-key   # if 1Password CLI was not ready during bootstrap
  mise run dot:bootstrap-ssh       # finalize 1Password SSH Agent wiring
  mise run dot:rebuild             # second switch — applies sops-templates secrets

EOF
}

open_permission_panels() {
  if [ "$(uname -s)" != "Darwin" ]; then
    return 0
  fi
  if [ "${BOOTSTRAP_OPEN_PANELS:-1}" = "0" ]; then
    return 0
  fi
  log "Opening System Settings panels (set BOOTSTRAP_OPEN_PANELS=0 to skip)"
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent" || true
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" || true
}

main() {
  require_host

  ensure_xcode_clt
  ensure_repo_cloned

  # If we were curl'd from the internet, bash is executing a tempfile.
  # Re-exec from the cloned repo so $0 / relative paths behave.
  if [ -z "${BOOTSTRAP_REEXEC:-}" ] && [ "${BASH_SOURCE[0]:-}" != "${REPO_DIR}/bootstrap.sh" ]; then
    log "Re-executing from ${REPO_DIR}/bootstrap.sh"
    BOOTSTRAP_REEXEC=1 exec bash "${REPO_DIR}/bootstrap.sh" "${HOST}"
  fi

  ensure_nix_installed
  source_nix_env
  backup_conflicting_etc_files

  # First switch: installs Nix packages + Brewfile (1password-cli, etc.).
  # The sops-templates module has a bootstrap guard: it skips rendering with
  # a warning when ~/.config/sops/age/keys.txt is absent, so this first switch
  # succeeds cleanly on a fresh machine even before the age key is restored.
  run_system_switch "${HOST}"

  bootstrap_age_key
  bootstrap_ssh

  # Second switch: now sops-templates can decrypt secrets into place.
  if [ -f "${HOME}/.config/sops/age/keys.txt" ]; then
    log "Re-running switch to apply sops-templates with age key present"
    run_system_switch "${HOST}"
  else
    warn "Age key still missing — skipping second switch. Run 'mise run dot:rebuild' after bootstrap-age-key succeeds."
  fi

  print_post_install_checklist
  open_permission_panels
}

main "$@"
