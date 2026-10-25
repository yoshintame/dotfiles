#!/usr/bin/env bash
set -euo pipefail

BASE_IMAGE="ghcr.io/cirruslabs/macos-sequoia-vanilla:latest"
BASE_VM="bootstrap-base-sequoia-vanilla"
RUN_VM="bootstrap-run"
HOST="lasthaze-mbp"
REPO_DIR="${DOTFILES_DIR:-${HOME}/.dotfiles}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGE_KEY="${HOME}/.config/sops/age/keys.txt"

WITH_AGE_KEY=0
FROM_GITHUB=0
KEEP=0

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
err() { printf '\033[1;31mERR\033[0m %s\n' "$*" >&2; }

usage() {
  cat >&2 <<EOF
Usage: tests/tart/run.sh [--with-age-key] [--from-github] [--keep]

Runs bootstrap.sh --test ${HOST} end-to-end in a fresh Tart clone of ${BASE_IMAGE}.

  --with-age-key  copy the local SOPS age key into the guest so the second switch renders secrets
  --from-github   run bootstrap.sh from GitHub master instead of the local working tree
  --keep          leave the VM running for inspection
EOF
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --with-age-key) WITH_AGE_KEY=1 ;;
    --from-github) FROM_GITHUB=1 ;;
    --keep) KEEP=1 ;;
    *) usage ;;
  esac
  shift
done

WORK="$(mktemp -d)"
SSH_OPTS=(-F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5)
IP=""
TART_PID=""

cleanup() {
  if [ "${KEEP}" = "1" ]; then
    log "VM ${RUN_VM} left running at ${IP}: ssh -i ${WORK}/id yoshintame@${IP}"
    return
  fi
  tart stop "${RUN_VM}" >/dev/null 2>&1 || true
  tart delete "${RUN_VM}" >/dev/null 2>&1 || true
  rm -rf "${WORK}"
}
trap cleanup EXIT

admin_ssh() { nix run nixpkgs#sshpass -- -p admin ssh "${SSH_OPTS[@]}" -o PubkeyAuthentication=no "admin@${IP}" "$@"; }
user_ssh() { ssh "${SSH_OPTS[@]}" -i "${WORK}/id" "yoshintame@${IP}" "$@"; }

start_vm() {
  tart run --no-graphics "${RUN_VM}" >"${WORK}/tart.log" 2>&1 &
  TART_PID=$!
  IP="$(tart ip --wait 300 "${RUN_VM}")"
  until nc -z "${IP}" 22 2>/dev/null; do sleep 2; done
  log "VM ${RUN_VM} is up at ${IP}"
}

if ! tart list --quiet | grep -qx "${BASE_VM}"; then
  log "Cloning ${BASE_IMAGE} → ${BASE_VM}"
  tart clone "${BASE_IMAGE}" "${BASE_VM}"
fi
tart delete "${RUN_VM}" >/dev/null 2>&1 || true
tart clone "${BASE_VM}" "${RUN_VM}"

ssh-keygen -q -t ed25519 -N '' -f "${WORK}/id"
start_vm

log "Preflight: user yoshintame with passwordless sudo and autologin"
admin_ssh "cat > /tmp/preflight.sh" <"${HERE}/preflight.sh"
admin_ssh "bash /tmp/preflight.sh '$(openssl rand -hex 12)' '$(cat "${WORK}/id.pub")'"

log "Rebooting into the yoshintame GUI session"
admin_ssh "sudo shutdown -h now" || true
wait "${TART_PID}" || true
start_vm
for attempt in $(seq 1 100); do
  user_ssh 'launchctl print gui/$(id -u) >/dev/null 2>&1' && break
  if [ "${attempt}" = "100" ]; then
    err "yoshintame has no GUI session after reboot: autologin did not take effect"
    exit 1
  fi
  sleep 3
done

if [ "${WITH_AGE_KEY}" = "1" ]; then
  log "Copying the SOPS age key"
  user_ssh 'mkdir -p ~/.config/sops/age && umask 077 && cat > ~/.config/sops/age/keys.txt' <"${AGE_KEY}"
fi

status=0
if [ "${FROM_GITHUB}" = "1" ]; then
  log "Running bootstrap.sh from GitHub master"
  user_ssh "curl -fsSL https://raw.githubusercontent.com/yoshintame/dotfiles/master/bootstrap.sh | bash -s -- --test ${HOST}" || status=$?
else
  log "Copying the local working tree of ${REPO_DIR}"
  rsync -a --exclude node_modules --exclude apm_modules --exclude result --exclude .direnv \
    -e "ssh ${SSH_OPTS[*]} -i ${WORK}/id" "${REPO_DIR}/" "yoshintame@${IP}:.dotfiles/"
  log "Running bootstrap.sh --test ${HOST}"
  user_ssh "bash ~/.dotfiles/bootstrap.sh --test ${HOST}" || status=$?
fi

if [ "${status}" != "0" ]; then
  err "bootstrap.sh exited with ${status}"
  exit "${status}"
fi

log "Checking the result"
user_ssh 'bash -s' <<'CHECKS'
set -euo pipefail
nix=/nix/var/nix/profiles/default/bin/nix
"$nix" --version
"$nix" config show builders
grep -q lasthaze-homelab /etc/nix/machines
test -x /run/current-system/sw/bin/darwin-rebuild
if [ -f ~/.config/sops/age/keys.txt ]; then
  test -n "$(ls -A ~/.config/sops-nix/secrets/)"
  echo "secrets rendered"
fi
CHECKS
log "bootstrap.sh --test ${HOST} passed"
