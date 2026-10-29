#!/usr/bin/env bash
set -euo pipefail

# bootstrap.sh — single-command dotfiles installer for macOS.
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
AGE_KEY="${HOME}/.config/sops/age/keys.txt"

TEST_MODE=0
HOST=""

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }
err()  { printf '\033[1;31mERR\033[0m %s\n' "$*" >&2; }

usage() {
  cat >&2 <<EOF
Usage: bootstrap.sh [--test] <host>

Hosts:
  lasthaze-mbp   macOS (aarch64-darwin), nix-darwin + home-manager

Options:
  --test   unattended run for a VM: skips App Store and Full Disk Access
           checks, Brewfile entries other than formulae and TCC-protected defaults

Environment:
  BOOTSTRAP_NIX=upstream   install upstream Nix instead of Determinate Nix
  BOOTSTRAP_OPEN_PANELS=0  do not open System Settings panels at the end
EOF
  exit 2
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --test) TEST_MODE=1 ;;
      -h|--help) usage ;;
      -*) err "Unknown option: $1"; usage ;;
      *) HOST="$1" ;;
    esac
    shift
  done
  if [ -z "${HOST}" ]; then
    err "HOST argument is required"
    usage
  fi
  if [ "$(uname -s)" != "Darwin" ]; then
    err "bootstrap.sh supports macOS only"
    exit 1
  fi
  if [ "${TEST_MODE}" = "1" ]; then
    export DOT_SKIP_TCC_DEFAULTS=1
  fi
}

wait_for_enter() {
  printf '%s\n' "$1"
  if ! read -r _ </dev/tty; then
    err "This step needs an interactive terminal: run bootstrap.sh from Terminal.app"
    exit 1
  fi
}

keep_sudo_alive() {
  log "Caching sudo credentials"
  sudo -n true 2>/dev/null || sudo -v
  while true; do
    sudo -n true
    sleep 50
    kill -0 "$$" || exit
  done 2>/dev/null &
}

ensure_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    log "Xcode Command Line Tools already installed"
    return 0
  fi
  log "Installing Xcode Command Line Tools"
  local marker=/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress label
  touch "${marker}"
  label="$(softwareupdate -l 2>/dev/null | sed -n 's/^\* Label: \(Command Line Tools for Xcode.*\)$/\1/p' | sort -V | tail -1)"
  if [ -n "${label}" ]; then
    sudo softwareupdate -i "${label}"
  fi
  rm -f "${marker}"
  if ! xcode-select -p >/dev/null 2>&1; then
    xcode-select --install || true
  fi
  until xcode-select -p >/dev/null 2>&1; do
    sleep 5
    echo "  waiting for Xcode CLT install to finish…"
  done
  log "Xcode CLT ready"
}

ensure_rosetta() {
  if /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
    log "Rosetta already installed"
    return 0
  fi
  log "Installing Rosetta"
  softwareupdate --install-rosetta --agree-to-license
}

check_app_store() {
  open -a "App Store" || true
  wait_for_enter "Sign in to the App Store (needed by mas in the Brewfile), then press Enter…"
}

check_full_disk_access() {
  if defaults write com.apple.Safari BootstrapFullDiskAccessProbe -bool true 2>/dev/null; then
    defaults delete com.apple.Safari BootstrapFullDiskAccessProbe 2>/dev/null || true
    log "Terminal has Full Disk Access"
    return 0
  fi
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" || true
  err "The terminal has no Full Disk Access: switch would fail writing Safari, Mail and universalaccess defaults."
  err "Grant Full Disk Access to this terminal, reopen it and re-run bootstrap.sh ${HOST}."
  exit 1
}

ensure_homebrew() {
  if [ ! -x /opt/homebrew/bin/brew ]; then
    log "Installing Homebrew"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    log "Homebrew already installed"
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
}

ensure_repo_cloned() {
  if [ -d "${REPO_DIR}/.git" ]; then
    log "Repo already present at ${REPO_DIR}"
    if [ -z "$(git -C "${REPO_DIR}" status --porcelain)" ]; then
      git -C "${REPO_DIR}" pull --ff-only || warn "Could not fast-forward ${REPO_DIR}; continuing with the local checkout"
    else
      warn "${REPO_DIR} has local changes; running it without pulling"
    fi
    git -C "${REPO_DIR}" submodule update --init --recursive
    return 0
  fi
  log "Cloning ${REPO_URL} → ${REPO_DIR}"
  git clone --recurse-submodules "${REPO_URL}" "${REPO_DIR}"
}

ensure_nix_installed() {
  if command -v nix >/dev/null 2>&1 || [ -x /nix/var/nix/profiles/default/bin/nix ]; then
    log "Nix already installed"
    return 0
  fi
  if [ "${BOOTSTRAP_NIX:-determinate}" = "upstream" ]; then
    log "Installing upstream Nix"
    curl --proto '=https' --tlsv1.2 -sSf -L https://nixos.org/nix/install | sh -s -- --daemon --yes
  else
    log "Installing Determinate Nix"
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
      | sh -s -- install --no-confirm
  fi
}

source_nix_env() {
  if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
  export NIX_CONFIG="experimental-features = nix-command flakes"
}

use_system_path() {
  export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/${USER}/bin:${HOME}/.local/share/mise/shims:${PATH}"
  export DOTFILES="${REPO_DIR}"
}

run_first_switch() {
  local darwin_rebuild log_file
  log "Building darwin-rebuild pinned by flake.lock"
  darwin_rebuild="$(nix build --no-link --print-out-paths --inputs-from "${REPO_DIR}" nix-darwin#darwin-rebuild)"
  log_file="$(mktemp)"

  for attempt in 1 2; do
    log "First switch for ${HOST} (attempt ${attempt})"
    if sudo env PATH="${PATH}" NIX_CONFIG="${NIX_CONFIG}" NIX_PATH="nixpkgs=flake:nixpkgs" \
      DOT_SKIP_TCC_DEFAULTS="${DOT_SKIP_TCC_DEFAULTS:-}" \
      "${darwin_rebuild}/bin/darwin-rebuild" switch --impure --flake "${REPO_DIR}#${HOST}" 2>&1 | tee "${log_file}"; then
      rm -f "${log_file}"
      return 0
    fi
    if [ "${attempt}" = "1" ] && grep -q 'Unexpected files in /etc' "${log_file}"; then
      awk '/Unexpected files in \/etc/ { block = 1 } block && /^Please/ { exit } block && /^[[:space:]]+\/etc\// { print $1 }' "${log_file}" | while read -r file; do
        log "Moving ${file} → ${file}.before-nix-darwin"
        sudo mv "${file}" "${file}.before-nix-darwin"
      done
      continue
    fi
    err "First switch failed, see output above"
    exit 1
  done
}

install_brewfile() {
  log "Installing the Brewfile"
  if [ "${TEST_MODE}" = "1" ]; then
    (cd "${REPO_DIR}" && mise run dot:brew --formulae-only)
  elif ! (cd "${REPO_DIR}" && mise run dot:brew); then
    warn "Some Brewfile entries did not install (listed above); continuing"
  fi
}

setup_toolchains() {
  log "Installing mise toolchains"
  mise install uv
  mise install
  log "Installing bun dependencies of the repo"
  for dir in "${REPO_DIR}" "${REPO_DIR}"/packages/*; do
    if [ -f "${dir}/package.json" ]; then
      (cd "${dir}" && mise exec -- bun install)
    fi
  done
}

bootstrap_age_key() {
  if [ -f "${AGE_KEY}" ]; then
    log "SOPS age key already present at ${AGE_KEY}"
    return 0
  fi
  if [ ! -x /opt/homebrew/bin/op ]; then
    warn "1Password CLI is not installed (see the Brewfile report); run 'dot bootstrap-age-key' once it is"
    return 0
  fi
  open -a 1Password || true
  for attempt in 1 2 3 4 5; do
    if (cd "${REPO_DIR}" && mise run dot:bootstrap-age-key); then
      return 0
    fi
    [ "${attempt}" = "5" ] && break
    wait_for_enter "Sign in to 1Password and enable Settings → Developer → Integrate with 1Password CLI, then press Enter to retry…"
  done
  warn "Could not read the age key from 1Password; run 'dot bootstrap-age-key' later"
}

bootstrap_ssh() {
  log "Configuring 1Password SSH Agent"
  if ! (cd "${REPO_DIR}" && mise run dot:bootstrap-ssh); then
    warn "dot:bootstrap-ssh failed — enable Settings → Developer → Use the SSH agent in 1Password, then run: dot bootstrap-ssh"
  fi
}

run_second_switch() {
  if [ ! -f "${AGE_KEY}" ]; then
    warn "Age key missing — skipping second switch. Run 'dot rebuild' after 'dot bootstrap-age-key'."
    return 0
  fi
  log "Second switch: render secrets with the age key present"
  (cd "${REPO_DIR}" && mise run dot:rebuild)
}

print_next_steps() {
  cat <<EOF

System build complete. The remaining manual steps are in the reinstall runbook
of the Obsidian vault (projects/mbp-clean-reinstall/knowledge/mbp-reinstall-runbook.md):

  1. Accessibility and Input Monitoring: Karabiner, Hammerspoon, AeroSpace
  2. Full Disk Access for restic
  3. Login Items: Karabiner, Hammerspoon, AeroSpace
  4. tailscale up, restic restore and identities

These cannot be automated without MDM.
EOF
}

open_permission_panels() {
  if [ "${BOOTSTRAP_OPEN_PANELS:-1}" = "0" ]; then
    return 0
  fi
  log "Opening System Settings panels (set BOOTSTRAP_OPEN_PANELS=0 to skip)"
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent" || true
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" || true
}

main() {
  parse_args "$@"

  ensure_xcode_clt
  ensure_repo_cloned

  # If we were curl'd from the internet, bash is executing a tempfile.
  # Re-exec from the cloned repo so $0 / relative paths behave.
  if [ -z "${BOOTSTRAP_REEXEC:-}" ] && [ "${BASH_SOURCE[0]:-}" != "${REPO_DIR}/bootstrap.sh" ]; then
    log "Re-executing from ${REPO_DIR}/bootstrap.sh"
    BOOTSTRAP_REEXEC=1 exec bash "${REPO_DIR}/bootstrap.sh" "$@"
  fi

  if [ "${TEST_MODE}" != "1" ]; then
    check_full_disk_access
    if [ ! -e /run/current-system ]; then
      check_app_store
    fi
  fi
  keep_sudo_alive
  ensure_rosetta
  ensure_homebrew
  ensure_nix_installed
  source_nix_env

  # The sops-templates wrapper around sops-nix declares its config inside a
  # mkIf gated on the age-key file existing on disk, so this first switch on
  # a fresh machine succeeds without secrets — sops-install-secrets is not
  # wired up yet.
  run_first_switch
  use_system_path
  setup_toolchains
  install_brewfile

  if [ "${TEST_MODE}" = "1" ]; then
    if [ ! -f "${AGE_KEY}" ]; then
      warn "Test mode: no age key at ${AGE_KEY}, secrets stay unrendered"
    fi
  else
    bootstrap_age_key
    bootstrap_ssh
  fi
  run_second_switch

  print_next_steps
  if [ "${TEST_MODE}" != "1" ]; then
    open_permission_panels
  fi
}

main "$@"
