#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOTFILES_DIR="$(cd "$MODULE_DIR/../.." && pwd)"

CONFIG_SRC="$MODULE_DIR/config/config.toml"
WORKTREE_HOOK="$DOTFILES_DIR/modules/agents-shared/config/hooks/worktree-create.sh"

if [ ! -x "$WORKTREE_HOOK" ]; then
  echo "FATAL: WorktreeCreate hook not found at $WORKTREE_HOOK" >&2
  exit 2
fi
if ! command -v wt >/dev/null 2>&1; then
  echo "FATAL: 'wt' (worktrunk) not in PATH" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "FATAL: 'jq' not in PATH" >&2
  exit 2
fi

TMP_ROOT="$(mktemp -d -t wt-e2e.XXXXXX)"
REPO_DIR="$TMP_ROOT/myproject"
WT_ROOT="$TMP_ROOT/worktrees"
TEST_CONFIG="$TMP_ROOT/wt-config.toml"

PASS=0
FAIL=0
declare -a FAILURES

cleanup() {
  local status=$?
  if [ -n "${TMP_ROOT:-}" ] && [ -d "$TMP_ROOT" ]; then
    find "$TMP_ROOT" -type d -name ".git" 2>/dev/null | while read -r d; do
      chmod -R u+w "$d" 2>/dev/null || true
    done
    rm -rf "$TMP_ROOT" 2>/dev/null || true
  fi
  exit $status
}
trap cleanup EXIT INT TERM

log() { printf '%s\n' "$*"; }
section() { printf '\n=== %s ===\n' "$*"; }
pass() { PASS=$((PASS + 1)); printf '[PASS] %s\n' "$*"; }
fail() {
  FAIL=$((FAIL + 1))
  FAILURES+=("$*")
  printf '[FAIL] %s\n' "$*"
}

assert_dir_exists() {
  local path="$1" msg="$2"
  if [ -d "$path" ]; then pass "$msg"; else fail "$msg (missing: $path)"; fi
}
assert_dir_absent() {
  local path="$1" msg="$2"
  if [ ! -e "$path" ]; then pass "$msg"; else fail "$msg (still present: $path)"; fi
}
wait_dir_absent() {
  local path="$1" tries="${2:-20}" delay="${3:-0.25}"
  while [ "$tries" -gt 0 ] && [ -e "$path" ]; do
    sleep "$delay"
    tries=$((tries - 1))
  done
}
assert_file_exists() {
  local path="$1" msg="$2"
  if [ -f "$path" ]; then pass "$msg"; else fail "$msg (missing: $path)"; fi
}
assert_eq() {
  local expected="$1" actual="$2" msg="$3"
  if [ "$expected" = "$actual" ]; then pass "$msg"; else fail "$msg (expected=$expected actual=$actual)"; fi
}
assert_neq() {
  local a="$1" b="$2" msg="$3"
  if [ "$a" != "$b" ]; then pass "$msg"; else fail "$msg (both=$a)"; fi
}

init_config() {
  # Rewrite user config.toml pointing worktree-path to our test tmpdir
  # (so we don't pollute ~/.local/share/worktrees/ during the tests)
  cat > "$TEST_CONFIG" <<EOF
worktree-path = "$WT_ROOT/{{ repo }}/{{ branch | sanitize }}"

[merge]
commit = false
squash = false
rebase = true
ff = true
remove = true

[[pre-start]]
setup = "$MODULE_DIR/config/hooks/pre-start.sh {{ primary_worktree_path }} {{ worktree_path }}"
EOF
}

init_repo() {
  rm -rf "$REPO_DIR" "$WT_ROOT"
  mkdir -p "$REPO_DIR"
  git -C "$REPO_DIR" init -b main -q
  git -C "$REPO_DIR" config user.email "test@example.com"
  git -C "$REPO_DIR" config user.name "Test"
  printf 'init\n' > "$REPO_DIR/README.md"
  printf '.env\n' > "$REPO_DIR/.gitignore"
  printf 'SECRET=1\n' > "$REPO_DIR/.env"
  git -C "$REPO_DIR" add README.md .gitignore
  git -C "$REPO_DIR" commit -qm "init"
}

wt_() {
  WORKTRUNK_CONFIG_PATH="$TEST_CONFIG" command wt "$@"
}

branch_exists() {
  local repo="$1" branch="$2"
  git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"
}

# --- Scenarios -------------------------------------------------------------

s1_create_worktree() {
  section "S1: Create worktree via worktrunk"
  init_repo

  wt_ -C "$REPO_DIR" switch --create feature-x --no-cd --yes --format json >/dev/null 2>&1 \
    || { fail "S1.wt_switch_create exited non-zero"; return; }

  local expected="$WT_ROOT/myproject/feature-x"
  assert_dir_exists "$expected" "S1.worktree_dir_exists"

  if [ -d "$expected" ]; then
    local head_ref
    head_ref="$(git -C "$expected" symbolic-ref --short HEAD 2>/dev/null || echo '')"
    assert_eq "feature-x" "$head_ref" "S1.head_is_feature-x"
    local marker
    marker="$(git -C "$expected" rev-parse --git-path wt-hook-ran 2>/dev/null || true)"
    assert_file_exists "$marker" "S1.pre_start_hook_marker"
    assert_file_exists "$expected/.env" "S1.env_copied_from_primary"
  fi
}

s2_ship_clean_tree() {
  section "S2: Ship on clean tree"
  init_repo

  wt_ -C "$REPO_DIR" switch --create feature-x --no-cd --yes --format json >/dev/null 2>&1 \
    || { fail "S2.wt_switch_create failed"; return; }

  local wt_path="$WT_ROOT/myproject/feature-x"

  # 2 commits in feature-x
  printf 'a\n' > "$wt_path/a.txt"
  git -C "$wt_path" add a.txt
  git -C "$wt_path" commit -qm "feat: add a"
  printf 'b\n' > "$wt_path/b.txt"
  git -C "$wt_path" add b.txt
  git -C "$wt_path" commit -qm "feat: add b"

  # 1 diverging commit in main
  printf 'main-tip\n' > "$REPO_DIR/m.txt"
  git -C "$REPO_DIR" add m.txt
  git -C "$REPO_DIR" commit -qm "main: add m"

  local merge_log="$TMP_ROOT/s2-merge.log"
  wt_ -C "$wt_path" merge main --yes --no-hooks >"$merge_log" 2>&1
  local ec=$?
  if [ "$ec" != "0" ]; then
    log "     merge output (see $merge_log):"
    log "$(tail -n 20 "$merge_log" 2>/dev/null | sed 's/^/       /')"
  fi
  assert_eq "0" "$ec" "S2.wt_merge_exit_0"

  # After merge: 3 commits on main (init, add a, add b after rebase-onto, merged via ff;
  # plus main: add m) = 4. Let me think again.
  # init -> main: add m (on main)
  # feature-x off main, then 2 commits (feat a, feat b). After rebase onto main tip
  # (which has "main: add m"), feature is: init -> main: add m -> feat a -> feat b.
  # ff merge -> main ends up: init -> main: add m -> feat a -> feat b. 4 commits total.
  local count
  count="$(git -C "$REPO_DIR" rev-list --count main 2>/dev/null || echo 0)"
  assert_eq "4" "$count" "S2.main_has_4_linear_commits"

  wait_dir_absent "$wt_path"
  assert_dir_absent "$wt_path" "S2.worktree_removed_after_merge"

  if branch_exists "$REPO_DIR" "feature-x"; then
    fail "S2.feature_branch_deleted (still exists)"
  else
    pass "S2.feature_branch_deleted"
  fi
}

s3_ship_fails_on_dirty() {
  section "S3: Ship fails on dirty tree"
  init_repo

  wt_ -C "$REPO_DIR" switch --create feature-x --no-cd --yes --format json >/dev/null 2>&1 \
    || { fail "S3.wt_switch_create failed"; return; }

  local wt_path="$WT_ROOT/myproject/feature-x"

  # one committed change so the branch has something
  printf 'a\n' > "$wt_path/a.txt"
  git -C "$wt_path" add a.txt
  git -C "$wt_path" commit -qm "feat: add a"

  # dirty: modify tracked file, don't commit
  printf 'dirty-readme\n' >> "$wt_path/README.md"

  local main_sha_before
  main_sha_before="$(git -C "$REPO_DIR" rev-parse main)"

  WORKTRUNK_CONFIG_PATH="$TEST_CONFIG" command wt -C "$wt_path" merge main --yes --no-hooks --format json >/dev/null 2>&1
  local ec=$?
  assert_neq "0" "$ec" "S3.wt_merge_exit_nonzero_on_dirty"

  assert_dir_exists "$wt_path" "S3.worktree_still_alive"

  if [ -d "$wt_path" ]; then
    local diff
    diff="$(git -C "$wt_path" status --porcelain 2>/dev/null || echo '')"
    if [ -n "$diff" ]; then pass "S3.dirty_changes_preserved"; else fail "S3.dirty_changes_preserved (status clean)"; fi
  fi

  local main_sha_after
  main_sha_after="$(git -C "$REPO_DIR" rev-parse main)"
  assert_eq "$main_sha_before" "$main_sha_after" "S3.main_untouched"
}

s4_nuke_via_remove_force() {
  section "S4: Nuke via wt remove --force"
  init_repo

  wt_ -C "$REPO_DIR" switch --create feature-x --no-cd --yes --format json >/dev/null 2>&1 \
    || { fail "S4.wt_switch_create failed"; return; }

  local wt_path="$WT_ROOT/myproject/feature-x"

  # untracked file so --force is required
  printf 'junk\n' > "$wt_path/untracked.txt"

  local main_sha_before
  main_sha_before="$(git -C "$REPO_DIR" rev-parse main)"

  # --foreground so we can observe the final state deterministically
  wt_ -C "$REPO_DIR" remove --force --foreground --yes feature-x --no-hooks --format json >/dev/null 2>&1
  local ec=$?
  assert_eq "0" "$ec" "S4.wt_remove_force_exit_0"

  assert_dir_absent "$wt_path" "S4.worktree_dir_removed"

  if branch_exists "$REPO_DIR" "feature-x"; then
    log "     note: branch feature-x still exists (wt remove --force without -D keeps unmerged branch)"
    pass "S4.branch_state_recorded: KEPT (unmerged)"
  else
    log "     note: branch feature-x deleted by wt remove --force"
    pass "S4.branch_state_recorded: DELETED"
  fi

  local main_sha_after
  main_sha_after="$(git -C "$REPO_DIR" rev-parse main)"
  assert_eq "$main_sha_before" "$main_sha_after" "S4.main_untouched"
}

s5_cc_integration() {
  section "S5: CC integration — WorktreeCreate hook"
  init_repo

  local session_id="test-session-abc123"
  local worktree_name="feature-y"

  local hook_stdout="$TMP_ROOT/s5-hook.stdout"
  local hook_stderr="$TMP_ROOT/s5-hook.stderr"
  printf '{"session_id":"%s","transcript_path":"/tmp/fake","cwd":"%s","hook_event_name":"WorktreeCreate","worktree_name":"%s","isolation":"worktree"}' \
    "$session_id" "$REPO_DIR" "$worktree_name" \
    | WORKTRUNK_CONFIG_PATH="$TEST_CONFIG" "$WORKTREE_HOOK" >"$hook_stdout" 2>"$hook_stderr"
  local ec=$?
  if [ "$ec" != "0" ]; then
    log "     hook stderr:"
    log "$(sed 's/^/       /' "$hook_stderr")"
  fi
  assert_eq "0" "$ec" "S5.hook_exit_0"

  local created_path
  created_path="$(tail -n 1 "$hook_stdout")"
  local expected_path="$WT_ROOT/myproject/$worktree_name"
  assert_eq "$expected_path" "$created_path" "S5.hook_returned_expected_path"
  assert_dir_exists "$created_path" "S5.hook_created_worktree"

  if [ -d "$created_path" ]; then
    local head_ref
    head_ref="$(git -C "$created_path" symbolic-ref --short HEAD 2>/dev/null || echo '')"
    # key check: NOT 'worktree-feature-y' (CC default), just 'feature-y'
    assert_eq "$worktree_name" "$head_ref" "S5.branch_is_plain_name_not_worktree_prefixed"

    # verify NOT under <repo>/.claude/worktrees/
    case "$created_path" in
      "$REPO_DIR/.claude/worktrees/"*)
        fail "S5.layout_not_default_cc_location (got $created_path)" ;;
      *)
        pass "S5.layout_is_central_storage_not_cc_default" ;;
    esac

    # session id should be written via git config --worktree
    local stored_session
    stored_session="$(git -C "$created_path" config --worktree claude.sessionId 2>/dev/null || echo '')"
    assert_eq "$session_id" "$stored_session" "S5.session_id_stored_in_worktree_config"
  fi
}

s6_squash_not_applied() {
  section "S6: Squash is NOT applied"
  init_repo

  wt_ -C "$REPO_DIR" switch --create feature-x --no-cd --yes --format json >/dev/null 2>&1 \
    || { fail "S6.wt_switch_create failed"; return; }

  local wt_path="$WT_ROOT/myproject/feature-x"

  printf '1\n' > "$wt_path/c1.txt"; git -C "$wt_path" add c1.txt; git -C "$wt_path" commit -qm "feat: c1"
  printf '2\n' > "$wt_path/c2.txt"; git -C "$wt_path" add c2.txt; git -C "$wt_path" commit -qm "feat: c2"
  printf '3\n' > "$wt_path/c3.txt"; git -C "$wt_path" add c3.txt; git -C "$wt_path" commit -qm "feat: c3"

  local merge_log="$TMP_ROOT/s6-merge.log"
  wt_ -C "$wt_path" merge main --yes --no-hooks >"$merge_log" 2>&1
  local ec=$?
  if [ "$ec" != "0" ]; then
    log "     merge output (see $merge_log):"
    log "$(tail -n 20 "$merge_log" 2>/dev/null | sed 's/^/       /')"
  fi
  assert_eq "0" "$ec" "S6.wt_merge_exit_0"

  # main log should contain 3 separate commit subjects
  local log_subjects
  log_subjects="$(git -C "$REPO_DIR" log --format='%s' main 2>/dev/null | tr '\n' '|')"
  local c1_present c2_present c3_present
  c1_present=0; c2_present=0; c3_present=0
  case "$log_subjects" in *"feat: c1"*) c1_present=1;; esac
  case "$log_subjects" in *"feat: c2"*) c2_present=1;; esac
  case "$log_subjects" in *"feat: c3"*) c3_present=1;; esac

  if [ "$c1_present" = 1 ] && [ "$c2_present" = 1 ] && [ "$c3_present" = 1 ]; then
    pass "S6.all_3_commits_preserved_on_main"
  else
    fail "S6.all_3_commits_preserved_on_main (subjects: $log_subjects)"
  fi
}

# --- Run -------------------------------------------------------------------

init_config

s1_create_worktree
s2_ship_clean_tree
s3_ship_fails_on_dirty
s4_nuke_via_remove_force
s5_cc_integration
s6_squash_not_applied

section "Summary"
log "PASS: $PASS"
log "FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  log ""
  log "Failed assertions:"
  for msg in "${FAILURES[@]}"; do
    log "  - $msg"
  done
  exit 1
fi
exit 0
