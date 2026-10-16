die() {
  echo "edge-op-sync: $*" >&2
  exit 1
}

dry_run=false
case "${1:-}" in
"") ;;
--dry-run) dry_run=true ;;
*) die "usage: edge-op-sync [--dry-run]" ;;
esac

secrets="${PROXY_SECRETS_FILE:-$PWD/secrets/lasthaze-edge/edge.yaml}"
vault="${EDGE_OP_VAULT:-Private}"
tag="${EDGE_OP_TAG:-lasthaze-edge}"
marker="edge-op-sync"
prefix="lasthaze-edge — "

[[ -f "$secrets" ]] || die "secrets file not found: $secrets (run from the dotfiles root)"
command -v op >/dev/null || die "1Password CLI (op) not found on PATH"

users="$(sops -d --extract '["USERS"]' "$secrets")"
jq -e 'type == "object" and all(.[]; .subPath | type == "string")' <<<"$users" >/dev/null 2>&1 ||
  die "USERS in $secrets is not a JSON object of {uuid, subPath}"
base="https://$(sops -d --extract '["DOMAIN"]' "$secrets")"
items="$(op item list --vault "$vault" --tags "$tag" --format json)"

run() {
  if $dry_run; then
    return 0
  fi
  "$@"
}

created=0 updated=0 adopted=0 archived=0 unchanged=0

while IFS=$'\t' read -r name url; do
  title="$prefix$name"
  IFS=$'\t' read -r id current managed tags < <(jq -r --arg t "$title" --arg m "$marker" '
    [.[] | select(.title == $t)][0] // empty
    | [
        .id,
        ((.urls // []) | (map(select(.primary)) + .)[0].href // ""),
        ((.tags // []) | any(. == $m)),
        ((.tags // []) + [$m] | unique | join(","))
      ]
    | @tsv
  ' <<<"$items") || true

  if [[ -z "${id:-}" ]]; then
    template="$(jq -n --arg title "$title" --arg name "$name" --arg url "$url" --arg tag "$tag" --arg m "$marker" '{
      title: $title,
      category: "LOGIN",
      tags: [$tag, $m],
      urls: [{label: "subscription", primary: true, href: $url}],
      fields: [{id: "username", type: "STRING", purpose: "USERNAME", label: "username", value: $name}]
    }')"
    run op item create --vault "$vault" --format json <<<"$template" >/dev/null
    echo "created:  $name"
    created=$((created + 1))
  elif [[ "$managed" != true ]]; then
    run op item edit "$id" --vault "$vault" --tags "$tags" --url "$url" </dev/null >/dev/null
    echo "adopted:  $name"
    adopted=$((adopted + 1))
  elif [[ "$current" != "$url" ]]; then
    run op item edit "$id" --vault "$vault" --url "$url" </dev/null >/dev/null
    echo "updated:  $name"
    updated=$((updated + 1))
  else
    unchanged=$((unchanged + 1))
  fi
  id="" current="" managed="" tags=""
done < <(jq -r --arg base "$base" 'to_entries[] | [.key, $base + "/" + .value.subPath] | @tsv' <<<"$users")

while IFS=$'\t' read -r id name; do
  run op item delete "$id" --vault "$vault" --archive </dev/null
  echo "archived: $name"
  archived=$((archived + 1))
done < <(jq -r --arg p "$prefix" --arg m "$marker" --argjson names "$(jq -c 'keys' <<<"$users")" '
  .[]
  | select((.tags // []) | any(. == $m))
  | select(.title | startswith($p))
  | (.title | ltrimstr($p)) as $name
  | select(any($names[]; . == $name) | not)
  | [.id, $name]
  | @tsv
' <<<"$items")

summary="created $created, updated $updated, adopted $adopted, archived $archived, unchanged $unchanged"
if $dry_run; then
  summary="dry run: $summary"
fi
echo "$summary"
