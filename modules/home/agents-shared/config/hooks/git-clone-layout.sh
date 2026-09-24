#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
tool_name="$(echo "$input" | jq -r '.tool_name // ""')"
[[ "$tool_name" != "Bash" ]] && exit 0

cmd="$(echo "$input" | jq -r '.tool_input.command // ""')"
[[ -z "$cmd" ]] && exit 0

echo "$cmd" | grep -qE '(^|[;&|`(]\s*)git\s+clone\s' || exit 0
echo "$cmd" | grep -qE '(^|[;&|`(]\s*)FORCE_CLONE_PATH=1\s' && exit 0

DEV="$HOME/Development"
CACHE="$HOME/.cache/repos"

cwd="$(echo "$input" | jq -r '.cwd // ""')"
[[ -z "$cwd" ]] && cwd="$(pwd)"

clone_segment="$(echo "$cmd" | sed -E 's/.*git[[:space:]]+clone[[:space:]]+//; s/[;&|].*//')"
read -ra tokens <<< "$clone_segment"

positionals=()
skip_next=false
for tok in "${tokens[@]}"; do
  if $skip_next; then skip_next=false; continue; fi
  case "$tok" in
    --branch|--depth|--jobs|--reference|--origin|--template|--config|--separate-git-dir|--filter|--bundle-uri|-b|-j|-o|-c|-u|--upload-pack)
      skip_next=true ;;
    -*) ;;
    *) positionals+=("$tok") ;;
  esac
done

[[ ${#positionals[@]} -eq 0 ]] && exit 0

url="${positionals[0]}"
url="${url%\"}"; url="${url#\"}"; url="${url%\'}"; url="${url#\'}"

owner=""
repo=""
if [[ "$url" =~ ^[a-zA-Z]+://[^/]+/(.+)/([^/]+)$ ]] || [[ "$url" =~ ^[^/@]+@[^:]+:(.+)/([^/]+)$ ]]; then
  owner="${BASH_REMATCH[1]##*/}"
  repo="${BASH_REMATCH[2]%.git}"
  repo="${repo%/}"
fi
owner="$(echo "$owner" | tr '[:upper:]' '[:lower:]')"

if [[ ${#positionals[@]} -ge 2 ]]; then
  target="${positionals[1]}"
  target="${target%\"}"; target="${target#\"}"; target="${target%\'}"; target="${target#\'}"
  target="${target/#\~/$HOME}"
  target="${target/#\$HOME/$HOME}"
  [[ "$target" != /* ]] && target="$cwd/$target"
else
  name="${repo:-$(basename "${url%.git}")}"
  target="$cwd/$name"
fi
target="${target%/}"

deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

rel_ok() {
  local base="$1" rel
  [[ "$target" == "$base/"* ]] || return 1
  rel="${target#"$base/"}"
  [[ "$rel" =~ ^[^/]+/[^/]+$ ]] || return 1
  if [[ -n "$owner" ]]; then
    [[ "${rel%%/*}" == "$owner" ]] || return 1
  fi
  return 0
}

rel_ok "$DEV" && exit 0
rel_ok "$CACHE" && exit 0
if [[ -z "$owner" && "$target" =~ ^"$DEV"/local/[^/]+$ ]]; then
  exit 0
fi

if [[ -n "$owner" && -n "$repo" ]]; then
  expected="Expected: ~/Development/$owner/$repo (work repo) or ~/.cache/repos/$owner/$repo (read-only reference clone)."
else
  expected="Expected: ~/Development/<owner>/<repo>, ~/Development/local/<repo> for a repo without remote, or ~/.cache/repos/<owner>/<repo> for a reference clone."
fi

deny "git clone target ${target/#"$HOME"/\~} breaks the disk layout (see /disk-layout skill). $expected Owner is the origin remote owner in lowercase; no host, category or language folders. Override: FORCE_CLONE_PATH=1 git clone ..."
