#!/usr/bin/env bash
set -euo pipefail

# tests/tart/preflight.sh — bring a fresh tart clone of cirruslabs
# macos-sonoma-base into a state where bootstrap.sh can run unattended.
#
# Closes the gap between the cirruslabs base image (admin user, brew
# preinstalled under admin) and what bootstrap.sh expects (primary user
# `yoshintame` matching hosts/lasthaze-mbp/default.nix#username,
# passwordless sudo for --test mode, /opt/homebrew writable by that user).
#
# See projects/dotfiles-architecture/tart-base-image-choice.md (vault) for the design rationale.
#
# Usage:
#   tests/tart/preflight.sh <vm-name>
#
# Example:
#   tart clone bootstrap-base test-run
#   tart run test-run --no-graphics &
#   tests/tart/preflight.sh test-run
#   ssh yoshintame@$(tart ip test-run) \
#       bash ~/.dotfiles/bootstrap.sh --test lasthaze-mbp

VM_NAME="${1:-}"
TART="${TART:-tart}"
KEY_PATH="${TART_TEST_KEY:-${HOME}/.ssh/tart-test}"
KNOWN_HOSTS="${TART_TEST_KNOWN_HOSTS:-${HOME}/.ssh/tart-known-hosts}"
ADMIN_USER="${TART_ADMIN_USER:-admin}"
ADMIN_PASS="${TART_ADMIN_PASS:-admin}"
TARGET_USER="${TARGET_USER:-yoshintame}"
TARGET_PASS="${TARGET_PASS:-yoshintame}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }
err()  { printf '\033[1;31mERR\033[0m %s\n' "$*" >&2; }

if [ -z "${VM_NAME}" ]; then
  err "Usage: $0 <vm-name>"
  exit 2
fi

if ! command -v "${TART}" >/dev/null 2>&1; then
  err "tart not found on PATH (set TART=path to override)"
  exit 2
fi

if ! command -v expect >/dev/null 2>&1; then
  err "expect(1) is required for the one-time password auth handshake"
  exit 2
fi

ensure_keypair() {
  if [ -f "${KEY_PATH}" ] && [ -f "${KEY_PATH}.pub" ]; then
    return 0
  fi
  log "Generating throwaway SSH keypair at ${KEY_PATH}"
  ssh-keygen -t ed25519 -f "${KEY_PATH}" -N '' -C 'tart-test' -q
}

resolve_ip() {
  log "Waiting for ${VM_NAME} to acquire an IP (up to 120s)"
  IP="$("${TART}" ip "${VM_NAME}" --wait 120)"
  if [ -z "${IP}" ]; then
    err "could not get IP for VM ${VM_NAME}"
    exit 1
  fi
  log "VM ${VM_NAME} reachable at ${IP}"
}

inject_admin_pubkey() {
  if ssh -i "${KEY_PATH}" \
      -o UserKnownHostsFile="${KNOWN_HOSTS}" \
      -o IdentitiesOnly=yes \
      -o IdentityAgent=none \
      -o ConnectTimeout=5 \
      -o BatchMode=yes \
      "${ADMIN_USER}@${IP}" true 2>/dev/null; then
    log "${ADMIN_USER}@${IP}: pubkey already authorized, skipping injection"
    return 0
  fi
  log "Injecting host pubkey into ${ADMIN_USER}@${IP} via password auth"
  rm -f "${KNOWN_HOSTS}"
  local pubkey
  pubkey="$(cat "${KEY_PATH}.pub")"
  expect <<EOF
set timeout 60
spawn env SSH_AUTH_SOCK="" ssh \\
    -o StrictHostKeyChecking=no \\
    -o UserKnownHostsFile=${KNOWN_HOSTS} \\
    -o PreferredAuthentications=password \\
    -o PubkeyAuthentication=no \\
    -o IdentitiesOnly=yes \\
    -o IdentityAgent=none \\
    ${ADMIN_USER}@${IP} \\
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '${pubkey}' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo INJECTED"
expect {
    "password:" { send "${ADMIN_PASS}\r"; exp_continue }
    "INJECTED" { }
    timeout { puts "TIMEOUT"; exit 1 }
    eof { }
}
expect eof
EOF
}

run_remote_as_admin() {
  ssh -i "${KEY_PATH}" \
      -o UserKnownHostsFile="${KNOWN_HOSTS}" \
      -o IdentitiesOnly=yes \
      -o IdentityAgent=none \
      "${ADMIN_USER}@${IP}" \
      "bash -s -- $1 $2 $3" \
      <<'REMOTE_EOF'
set -euo pipefail
TARGET_USER="$1"
TARGET_PASS="$2"
ADMIN_PASS="$3"

log() { printf '   \033[1;34m::\033[0m %s\n' "$*"; }

if id "${TARGET_USER}" >/dev/null 2>&1; then
  log "user ${TARGET_USER} already exists, skipping creation"
else
  log "creating user ${TARGET_USER}"
  sudo sysadminctl \
    -addUser "${TARGET_USER}" \
    -fullName "${TARGET_USER}" \
    -password "${TARGET_PASS}" \
    -home "/Users/${TARGET_USER}" \
    -shell /bin/zsh \
    -admin \
    -adminUser "$(whoami)" \
    -adminPassword "${ADMIN_PASS}" 2>&1 | tail -3
fi

if [ ! -d "/Users/${TARGET_USER}" ]; then
  log "creating home directory for ${TARGET_USER}"
  sudo createhomedir -c -u "${TARGET_USER}" 2>&1 | tail -1
fi

PUBKEY="$(cat "${HOME}/.ssh/authorized_keys")"
if sudo grep -qF "${PUBKEY}" "/Users/${TARGET_USER}/.ssh/authorized_keys" 2>/dev/null; then
  log "${TARGET_USER}: pubkey already authorized"
else
  log "injecting pubkey into ${TARGET_USER}"
  sudo mkdir -p "/Users/${TARGET_USER}/.ssh"
  echo "${PUBKEY}" | sudo tee "/Users/${TARGET_USER}/.ssh/authorized_keys" >/dev/null
  sudo chown -R "${TARGET_USER}:staff" "/Users/${TARGET_USER}/.ssh"
  sudo chmod 700 "/Users/${TARGET_USER}/.ssh"
  sudo chmod 600 "/Users/${TARGET_USER}/.ssh/authorized_keys"
fi

if [ -f "/etc/sudoers.d/${TARGET_USER}-test" ]; then
  log "sudoers.d/${TARGET_USER}-test already in place"
else
  log "granting passwordless sudo to ${TARGET_USER} (test-only)"
  echo "${TARGET_USER} ALL=(ALL) NOPASSWD: ALL" \
    | sudo tee "/etc/sudoers.d/${TARGET_USER}-test" >/dev/null
  sudo chmod 440 "/etc/sudoers.d/${TARGET_USER}-test"
fi

if [ -d /opt/homebrew ]; then
  CURRENT_OWNER="$(stat -f '%Su' /opt/homebrew)"
  if [ "${CURRENT_OWNER}" = "${TARGET_USER}" ]; then
    log "/opt/homebrew already owned by ${TARGET_USER}"
  else
    log "reowning /opt/homebrew (${CURRENT_OWNER} -> ${TARGET_USER})"
    sudo chown -R "${TARGET_USER}:staff" /opt/homebrew
  fi
fi

log "preflight complete inside VM"
REMOTE_EOF
}

verify_target_user() {
  if ssh -i "${KEY_PATH}" \
      -o UserKnownHostsFile="${KNOWN_HOSTS}" \
      -o IdentitiesOnly=yes \
      -o IdentityAgent=none \
      -o BatchMode=yes \
      "${TARGET_USER}@${IP}" \
      'sudo -n whoami | grep -q root && stat -f "%Su" /opt/homebrew'; then
    log "verified: ${TARGET_USER}@${IP} has NOPASSWD sudo and owns /opt/homebrew"
  else
    err "verification failed — ${TARGET_USER} cannot sudo or does not own /opt/homebrew"
    exit 1
  fi
}

print_next_step() {
  cat <<EOF

Preflight done. To run bootstrap:

  ssh -i ${KEY_PATH} \\
      -o UserKnownHostsFile=${KNOWN_HOSTS} \\
      -o IdentitiesOnly=yes -o IdentityAgent=none \\
      ${TARGET_USER}@${IP} \\
      'bash ~/.dotfiles/bootstrap.sh --test lasthaze-mbp'

(or clone the repo first if not yet present)

EOF
}

main() {
  ensure_keypair
  resolve_ip
  inject_admin_pubkey
  run_remote_as_admin "${TARGET_USER}" "${TARGET_PASS}" "${ADMIN_PASS}"
  verify_target_user
  print_next_step
}

main "$@"
