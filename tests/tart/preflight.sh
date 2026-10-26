#!/usr/bin/env bash
set -euo pipefail

USER_NAME="yoshintame"
PASSWORD="${1:?usage: preflight.sh <password> <ssh-public-key>}"
PUBLIC_KEY="${2:?usage: preflight.sh <password> <ssh-public-key>}"
HOME_DIR="/Users/${USER_NAME}"

if ! id "${USER_NAME}" >/dev/null 2>&1; then
  sudo sysadminctl -addUser "${USER_NAME}" -fullName "${USER_NAME}" -password "${PASSWORD}" -admin
  sudo createhomedir -c -u "${USER_NAME}" >/dev/null
fi

echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" | sudo tee "/etc/sudoers.d/${USER_NAME}" >/dev/null
sudo chmod 440 "/etc/sudoers.d/${USER_NAME}"

if dscl . -read /Groups/com.apple.access_ssh >/dev/null 2>&1; then
  sudo dseditgroup -o edit -a "${USER_NAME}" -t user com.apple.access_ssh
fi

sudo mkdir -p "${HOME_DIR}/.ssh"
echo "${PUBLIC_KEY}" | sudo tee "${HOME_DIR}/.ssh/authorized_keys" >/dev/null
sudo chown -R "${USER_NAME}:staff" "${HOME_DIR}/.ssh"
sudo chmod 700 "${HOME_DIR}/.ssh"
sudo chmod 600 "${HOME_DIR}/.ssh/authorized_keys"

networksetup -listallnetworkservices | tail -n +2 | while read -r service; do
  sudo networksetup -setv6off "${service}"
done

perl -e '
  my @key = (125, 137, 82, 35, 210, 188, 221, 234, 163, 185, 31);
  my @bytes = unpack("C*", $ARGV[0]);
  push @bytes, (0) x (12 - @bytes % 12);
  print pack("C*", map { $bytes[$_] ^ $key[$_ % 11] } 0 .. $#bytes);
' "${PASSWORD}" | sudo tee /etc/kcpassword >/dev/null
sudo chmod 600 /etc/kcpassword
sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser "${USER_NAME}"
test "$(sudo defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser)" = "${USER_NAME}"
sync
