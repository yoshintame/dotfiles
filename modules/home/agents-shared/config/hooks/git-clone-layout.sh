#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
tool_name="$(echo "$input" | jq -r '.tool_name // ""')"

[[ "$tool_name" != "Bash" ]] && exit 0

cmd="$(echo "$input" | jq -r '.tool_input.command // ""')"
[[ -z "$cmd" ]] && exit 0

if ! echo "$cmd" | grep -qE '(^|[;&|`(]\s*)git\s+clone\s'; then
  exit 0
fi

if echo "$cmd" | grep -qE '(^|[;&|`(]\s*)FORCE_CLONE_PATH=1\s'; then
  exit 0
fi

HOME_DIR="$HOME"
DEV="$HOME_DIR/Development"
CACHE="$HOME_DIR/.cache/repos"

deny() {
  local reason="$1"
  jq -n --arg r "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

cwd="$(echo "$input" | jq -r '.cwd // ""')"
[[ -z "$cwd" ]] && cwd="$(pwd)"

resolve_path() {
  local p="$1"
  p="${p/#\~/$HOME_DIR}"
  p="${p/#\$HOME/$HOME_DIR}"
  if [[ "$p" != /* ]]; then
    p="$cwd/$p"
  fi
  echo "$p"
}

extract_clone_target() {
  local tokens url_seen=false
  read -ra tokens <<< "$cmd"
  local skip_next=false
  local last_positional=""
  local positional_count=0

  for tok in "${tokens[@]}"; do
    if $skip_next; then
      skip_next=false
      continue
    fi
    [[ "$tok" == "git" || "$tok" == "clone" ]] && continue
    [[ "$tok" == FORCE_CLONE_PATH=* ]] && continue

    if [[ "$tok" == --* ]]; then
      case "$tok" in
        --branch|--depth|--jobs|-j|--reference|--origin|-o|--template|--config|-c|--separate-git-dir|--filter|--bundle-uri)
          skip_next=true ;;
        --branch=*|--depth=*|--jobs=*|--reference=*|--origin=*|--template=*|--config=*|--separate-git-dir=*|--filter=*|--bundle-uri=*)
          ;; # value is part of the flag
      esac
      continue
    fi
    if [[ "$tok" == -* ]]; then
      case "$tok" in
        -b|-j|-o|-c) skip_next=true ;;
      esac
      continue
    fi

    positional_count=$((positional_count + 1))
    last_positional="$tok"
  done

  if [[ $positional_count -ge 2 ]]; then
    echo "$last_positional"
  elif [[ $positional_count -eq 1 ]]; then
    local repo_name
    repo_name="$(basename "$last_positional" .git)"
    echo "$cwd/$repo_name"
  fi
}

clone_target="$(extract_clone_target)"
[[ -z "$clone_target" ]] && exit 0

clone_target="$(resolve_path "$clone_target")"

allowed_prefixes=(
  "$DEV/work/"
  "$DEV/personal/"
  "$DEV/forks/"
  "$DEV/sandbox/"
  "$DEV/archive/"
  "$CACHE/"
)

for prefix in "${allowed_prefixes[@]}"; do
  if [[ "$clone_target" == "$prefix"* ]]; then
    exit 0
  fi
done

deny "git clone target does not match disk layout conventions (see /disk-layout skill). Allowed:
  ~/Development/work/<company>/<repo>
  ~/Development/personal/<repo>
  ~/Development/forks/<repo>
  ~/Development/sandbox/<repo>
  ~/.cache/repos/<repo>
Override: FORCE_CLONE_PATH=1 git clone ..."
