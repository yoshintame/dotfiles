#!/usr/bin/env bash
set -euo pipefail

mode=${1:?usage: gh-file-url.sh <open|copy|url> <file> [line]}
file=${2:?file path required}
line=${3:-}

dir=$(dirname "$file")
root=$(git -C "$dir" rev-parse --show-toplevel)

remote=$(git -C "$dir" remote get-url origin 2>/dev/null || true)
if [ -z "$remote" ]; then
  first=$(git -C "$dir" remote | head -n1)
  [ -n "$first" ] && remote=$(git -C "$dir" remote get-url "$first")
fi
[ -n "$remote" ] || { echo "no git remote for $file" >&2; exit 1; }

ref=$(git -C "$dir" symbolic-ref --quiet --short HEAD || git -C "$dir" rev-parse HEAD)

remote=${remote%.git}
case "$remote" in
  git@*:*)       host=${remote#git@}; host=${host%%:*}; path=${remote#*:} ;;
  ssh://*)       rest=${remote#ssh://}; rest=${rest#*@}; host=${rest%%/*}; path=${rest#*/} ;;
  https://*)     rest=${remote#https://}; rest=${rest#*@}; host=${rest%%/*}; path=${rest#*/} ;;
  http://*)      rest=${remote#http://};  rest=${rest#*@}; host=${rest%%/*}; path=${rest#*/} ;;
  *)             echo "unsupported remote: $remote" >&2; exit 1 ;;
esac

rel=${file#"$root"/}
url="https://$host/$path/blob/$ref/$rel"
[ -n "$line" ] && url="$url#L$line"

case "$mode" in
  open) open "$url" ;;
  copy) printf %s "$url" | pbcopy ;;
  url)  printf '%s\n' "$url" ;;
  *)    echo "unknown mode: $mode" >&2; exit 1 ;;
esac
