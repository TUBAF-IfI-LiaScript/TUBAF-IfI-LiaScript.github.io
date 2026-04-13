#!/usr/bin/env bash
# Tests for scripts/check_changes.sh
#
# Strategy
# --------
# Each test runs check_changes.sh in an isolated temporary directory that
# contains only the files the test wants to be present (YAML, HTML, cache).
# External HTTP calls are intercepted by placing a mock `curl` script first
# on PATH so that tests run offline and deterministically.
#
# check_changes.sh sources courses_lib.sh from its own directory (the
# production scripts/ tree) and uses the production courses.conf.  Tests
# therefore use real course names:
#   - "digitalesysteme"  – has an upstream repo mapping in courses.conf
#   - "index"            – present in COURSES but has NO mapping in courses.conf
#
# Exit-code contract of check_changes.sh
#   0  → rebuild needed
#   1  → no rebuild needed
#   1  → YAML file not found (exits with non-zero)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/check_changes.sh"
. "$REPO_ROOT/tests/lib/test_lib.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# make_mock_bin <tmpdir> <remote_sha>
# Creates a mock `curl` that returns a minimal GitHub API JSON payload.
# Pass "ERROR" as <remote_sha> to simulate a network failure (empty response).
make_mock_bin() {
  local tmpdir="$1"
  local remote_sha="$2"
  local mock_bin="$tmpdir/mock_bin"
  mkdir -p "$mock_bin"

  if [ "$remote_sha" = "ERROR" ]; then
    cat > "$mock_bin/curl" << 'EOF'
#!/usr/bin/env bash
# Mock curl – simulates network failure by returning empty output
echo ""
exit 0
EOF
  else
    cat > "$mock_bin/curl" << EOF
#!/usr/bin/env bash
# Mock curl – returns a fake GitHub API commits response
echo '{"sha":"${remote_sha}","commit":{}}'
EOF
  fi
  chmod +x "$mock_bin/curl"
  echo "$mock_bin"
}

# run_check <tmpdir> <mock_bin> <course>
# Runs check_changes.sh from within tmpdir, with mock_bin prepended to PATH.
# Echoes the combined stdout/stderr output and exits with the script's exit code.
run_check() {
  local tmpdir="$1"
  local mock_bin="$2"
  local course="$3"
  (
    cd "$tmpdir"
    PATH="$mock_bin:$PATH" bash "$SCRIPT" "$course" 2>&1
  )
  return $?
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

suite "check_changes.sh – argument handling"

test_missing_argument() {
  local out
  out=$(bash "$SCRIPT" 2>&1) || true
  assert_output_contains "Usage:" "$out" "no argument: prints usage"
}
test_missing_argument

test_missing_yaml() {
  setup_tmpdir
  local mock_bin exit_code=0 out
  mock_bin=$(make_mock_bin "$TMPDIR_TEST" "abc123")
  # "digitalesysteme" has a remote mapping; YAML intentionally absent
  out=$(cd "$TMPDIR_TEST" && PATH="$mock_bin:$PATH" bash "$SCRIPT" "digitalesysteme" 2>&1) || exit_code=$?
  assert_exit_code 1 "${exit_code:-0}" "missing YAML: exits with non-zero"
  assert_output_contains "not found" "$out" "missing YAML: error message shown"
  teardown_tmpdir
}
test_missing_yaml

# ---------------------------------------------------------------------------

suite "check_changes.sh – no cache (first run)"

test_no_cache_no_html() {
  setup_tmpdir
  echo "title: Test" > "$TMPDIR_TEST/digitalesysteme.yml"
  local mock_bin exit_code=0 out
  mock_bin=$(make_mock_bin "$TMPDIR_TEST" "deadbeef1234")

  out=$(run_check "$TMPDIR_TEST" "$mock_bin" "digitalesysteme") || exit_code=$?
  assert_exit_code 0 "$exit_code" "no cache + no HTML: rebuild needed (exit 0)"
  assert_output_contains "rebuild needed" "$out" "no cache + no HTML: output says rebuild needed"
  teardown_tmpdir
}
test_no_cache_no_html

test_no_cache_html_exists() {
  setup_tmpdir
  echo "title: Test" > "$TMPDIR_TEST/digitalesysteme.yml"
  touch "$TMPDIR_TEST/digitalesysteme.html"
  local mock_bin exit_code=0 out
  mock_bin=$(make_mock_bin "$TMPDIR_TEST" "deadbeef1234")

  out=$(run_check "$TMPDIR_TEST" "$mock_bin" "digitalesysteme") || exit_code=$?
  # No cache → cached YAML = "missing" ≠ real hash → rebuild needed
  assert_exit_code 0 "$exit_code" "no cache + HTML exists: rebuild needed (no cached hash)"
  teardown_tmpdir
}
test_no_cache_html_exists

# ---------------------------------------------------------------------------

suite "check_changes.sh – cache matches (up-to-date)"

test_all_up_to_date() {
  setup_tmpdir
  echo "title: Test" > "$TMPDIR_TEST/digitalesysteme.yml"
  touch "$TMPDIR_TEST/digitalesysteme.html"

  local remote_sha="aabbccddeeff0011"
  local mock_bin
  mock_bin=$(make_mock_bin "$TMPDIR_TEST" "$remote_sha")

  mkdir -p "$TMPDIR_TEST/.cache"
  local yaml_hash
  yaml_hash=$(sha256sum "$TMPDIR_TEST/digitalesysteme.yml" | cut -d' ' -f1)
  printf "%s\n%s\n" "$yaml_hash" "$remote_sha" > "$TMPDIR_TEST/.cache/digitalesysteme"

  local exit_code=0 out
  out=$(run_check "$TMPDIR_TEST" "$mock_bin" "digitalesysteme") || exit_code=$?
  assert_exit_code 1 "$exit_code" "all up-to-date: no rebuild needed (exit 1)"
  assert_output_contains "No changes detected" "$out" "all up-to-date: output says no changes"
  teardown_tmpdir
}
test_all_up_to_date

# ---------------------------------------------------------------------------

suite "check_changes.sh – individual change triggers"

test_yaml_changed() {
  setup_tmpdir
  echo "title: Test" > "$TMPDIR_TEST/digitalesysteme.yml"
  touch "$TMPDIR_TEST/digitalesysteme.html"

  local remote_sha="aabbccddeeff0011"
  local mock_bin
  mock_bin=$(make_mock_bin "$TMPDIR_TEST" "$remote_sha")

  # Cache has a stale YAML hash
  mkdir -p "$TMPDIR_TEST/.cache"
  printf "%s\n%s\n" "stale_yaml_hash_value_0000" "$remote_sha" > "$TMPDIR_TEST/.cache/digitalesysteme"

  local exit_code=0 out
  out=$(run_check "$TMPDIR_TEST" "$mock_bin" "digitalesysteme") || exit_code=$?
  assert_exit_code 0 "$exit_code" "YAML changed: rebuild needed (exit 0)"
  assert_output_contains "YAML file changed" "$out" "YAML changed: reason in output"
  teardown_tmpdir
}
test_yaml_changed

test_remote_changed() {
  setup_tmpdir
  echo "title: Test" > "$TMPDIR_TEST/digitalesysteme.yml"
  touch "$TMPDIR_TEST/digitalesysteme.html"

  local new_remote_sha="newsha9999"
  local mock_bin
  mock_bin=$(make_mock_bin "$TMPDIR_TEST" "$new_remote_sha")

  # Cache has the correct YAML hash but an old remote SHA
  mkdir -p "$TMPDIR_TEST/.cache"
  local yaml_hash
  yaml_hash=$(sha256sum "$TMPDIR_TEST/digitalesysteme.yml" | cut -d' ' -f1)
  printf "%s\n%s\n" "$yaml_hash" "oldsha1111" > "$TMPDIR_TEST/.cache/digitalesysteme"

  local exit_code=0 out
  out=$(run_check "$TMPDIR_TEST" "$mock_bin" "digitalesysteme") || exit_code=$?
  assert_exit_code 0 "$exit_code" "remote changed: rebuild needed (exit 0)"
  assert_output_contains "Remote repository changed" "$out" "remote changed: reason in output"
  teardown_tmpdir
}
test_remote_changed

test_html_missing() {
  setup_tmpdir
  echo "title: Test" > "$TMPDIR_TEST/digitalesysteme.yml"
  # Intentionally no HTML file

  local remote_sha="aabbccddeeff0011"
  local mock_bin
  mock_bin=$(make_mock_bin "$TMPDIR_TEST" "$remote_sha")

  # Cache has correct YAML and remote hashes, but HTML is absent
  mkdir -p "$TMPDIR_TEST/.cache"
  local yaml_hash
  yaml_hash=$(sha256sum "$TMPDIR_TEST/digitalesysteme.yml" | cut -d' ' -f1)
  printf "%s\n%s\n" "$yaml_hash" "$remote_sha" > "$TMPDIR_TEST/.cache/digitalesysteme"

  local exit_code=0 out
  out=$(run_check "$TMPDIR_TEST" "$mock_bin" "digitalesysteme") || exit_code=$?
  assert_exit_code 0 "$exit_code" "HTML missing: rebuild needed (exit 0)"
  assert_output_contains "HTML file missing" "$out" "HTML missing: reason in output"
  teardown_tmpdir
}
test_html_missing

# ---------------------------------------------------------------------------

suite "check_changes.sh – remote unreachable"

test_remote_unreachable_no_other_changes() {
  setup_tmpdir
  echo "title: Test" > "$TMPDIR_TEST/digitalesysteme.yml"
  touch "$TMPDIR_TEST/digitalesysteme.html"

  # Mock curl returns empty – simulates network failure
  local mock_bin
  mock_bin=$(make_mock_bin "$TMPDIR_TEST" "ERROR")

  # Cache has current YAML hash and "unreachable" as the last known remote state
  mkdir -p "$TMPDIR_TEST/.cache"
  local yaml_hash
  yaml_hash=$(sha256sum "$TMPDIR_TEST/digitalesysteme.yml" | cut -d' ' -f1)
  printf "%s\n%s\n" "$yaml_hash" "unreachable" > "$TMPDIR_TEST/.cache/digitalesysteme"

  local exit_code=0 out
  out=$(run_check "$TMPDIR_TEST" "$mock_bin" "digitalesysteme") || exit_code=$?
  assert_exit_code 1 "$exit_code" "remote unreachable + no other changes: no rebuild (exit 1)"
  teardown_tmpdir
}
test_remote_unreachable_no_other_changes

test_remote_unreachable_yaml_changed() {
  setup_tmpdir
  echo "title: Test" > "$TMPDIR_TEST/digitalesysteme.yml"
  touch "$TMPDIR_TEST/digitalesysteme.html"

  local mock_bin
  mock_bin=$(make_mock_bin "$TMPDIR_TEST" "ERROR")

  # Stale YAML hash: rebuild triggered even when remote is unreachable
  mkdir -p "$TMPDIR_TEST/.cache"
  printf "%s\n%s\n" "stale_yaml_hash" "unreachable" > "$TMPDIR_TEST/.cache/digitalesysteme"

  local exit_code=0 out
  out=$(run_check "$TMPDIR_TEST" "$mock_bin" "digitalesysteme") || exit_code=$?
  assert_exit_code 0 "$exit_code" "remote unreachable + YAML changed: rebuild still triggered (exit 0)"
  teardown_tmpdir
}
test_remote_unreachable_yaml_changed

# ---------------------------------------------------------------------------

suite "check_changes.sh – course without remote mapping"
# "index" is in the COURSES list but has no entry in courses.conf.
# check_changes.sh should set REMOTE_HASH="no-remote" and skip the API call.

test_no_remote_mapping_up_to_date() {
  setup_tmpdir
  echo "title: Index" > "$TMPDIR_TEST/index.yml"
  touch "$TMPDIR_TEST/index.html"

  local mock_bin
  mock_bin=$(make_mock_bin "$TMPDIR_TEST" "SHOULD_NOT_BE_CALLED")

  mkdir -p "$TMPDIR_TEST/.cache"
  local yaml_hash
  yaml_hash=$(sha256sum "$TMPDIR_TEST/index.yml" | cut -d' ' -f1)
  printf "%s\n%s\n" "$yaml_hash" "no-remote" > "$TMPDIR_TEST/.cache/index"

  local exit_code=0 out
  out=$(run_check "$TMPDIR_TEST" "$mock_bin" "index") || exit_code=$?
  assert_exit_code 1 "$exit_code" "no remote mapping + up-to-date: no rebuild (exit 1)"
  teardown_tmpdir
}
test_no_remote_mapping_up_to_date

test_no_remote_mapping_yaml_changed() {
  setup_tmpdir
  echo "title: Index" > "$TMPDIR_TEST/index.yml"
  touch "$TMPDIR_TEST/index.html"

  local mock_bin
  mock_bin=$(make_mock_bin "$TMPDIR_TEST" "SHOULD_NOT_BE_CALLED")

  mkdir -p "$TMPDIR_TEST/.cache"
  printf "%s\n%s\n" "stale_hash" "no-remote" > "$TMPDIR_TEST/.cache/index"

  local exit_code=0 out
  out=$(run_check "$TMPDIR_TEST" "$mock_bin" "index") || exit_code=$?
  assert_exit_code 0 "$exit_code" "no remote mapping + YAML changed: rebuild needed (exit 0)"
  teardown_tmpdir
}
test_no_remote_mapping_yaml_changed

# ---------------------------------------------------------------------------
summary
