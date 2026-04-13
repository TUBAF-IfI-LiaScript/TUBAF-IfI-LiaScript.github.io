#!/usr/bin/env bash
# Minimal test helper library.
# Source this file from individual test scripts:
#   . "$(dirname "$0")/lib/test_lib.sh"

_PASS=0
_FAIL=0
_SKIP=0
_CURRENT_SUITE=""

# ---------------------------------------------------------------------------
# suite <name> – set the current test suite label
# ---------------------------------------------------------------------------
suite() { _CURRENT_SUITE="$1"; echo ""; echo "▶  $_CURRENT_SUITE"; }

# ---------------------------------------------------------------------------
# pass <description> – record a passing test
# ---------------------------------------------------------------------------
pass() {
  _PASS=$((_PASS + 1))
  printf "  ✅ %s\n" "$1"
}

# ---------------------------------------------------------------------------
# fail <description> [details] – record a failing test
# ---------------------------------------------------------------------------
fail() {
  _FAIL=$((_FAIL + 1))
  printf "  ❌ %s\n" "$1"
  [ -n "${2:-}" ] && printf "     %s\n" "$2"
}

# ---------------------------------------------------------------------------
# skip <description> [reason] – record a skipped test
# ---------------------------------------------------------------------------
skip() {
  _SKIP=$((_SKIP + 1))
  printf "  ⏭️  SKIP: %s" "$1"
  [ -n "${2:-}" ] && printf " (%s)" "$2"
  printf "\n"
}

# ---------------------------------------------------------------------------
# assert_exit_code <expected> <actual> <description>
# ---------------------------------------------------------------------------
assert_exit_code() {
  local expected="$1" actual="$2" desc="$3"
  if [ "$actual" -eq "$expected" ]; then
    pass "$desc"
  else
    fail "$desc" "expected exit $expected, got $actual"
  fi
}

# ---------------------------------------------------------------------------
# assert_output_contains <substring> <output> <description>
# ---------------------------------------------------------------------------
assert_output_contains() {
  local substring="$1" output="$2" desc="$3"
  if echo "$output" | grep -qF "$substring"; then
    pass "$desc"
  else
    fail "$desc" "expected output to contain: $substring"
  fi
}

# ---------------------------------------------------------------------------
# assert_output_not_contains <substring> <output> <description>
# ---------------------------------------------------------------------------
assert_output_not_contains() {
  local substring="$1" output="$2" desc="$3"
  if ! echo "$output" | grep -qF "$substring"; then
    pass "$desc"
  else
    fail "$desc" "expected output NOT to contain: $substring"
  fi
}

# ---------------------------------------------------------------------------
# assert_file_exists <path> <description>
# ---------------------------------------------------------------------------
assert_file_exists() {
  if [ -f "$1" ]; then
    pass "$2"
  else
    fail "$2" "file not found: $1"
  fi
}

# ---------------------------------------------------------------------------
# assert_file_not_exists <path> <description>
# ---------------------------------------------------------------------------
assert_file_not_exists() {
  if [ ! -f "$1" ]; then
    pass "$2"
  else
    fail "$2" "file unexpectedly exists: $1"
  fi
}

# ---------------------------------------------------------------------------
# setup_tmpdir – create an isolated temp directory and set $TMPDIR_TEST
# ---------------------------------------------------------------------------
setup_tmpdir() {
  TMPDIR_TEST=$(mktemp -d)
}

# ---------------------------------------------------------------------------
# teardown_tmpdir – remove the temp directory created by setup_tmpdir
# ---------------------------------------------------------------------------
teardown_tmpdir() {
  [ -n "${TMPDIR_TEST:-}" ] && rm -rf "$TMPDIR_TEST"
}

# ---------------------------------------------------------------------------
# summary – print test totals; exit 1 if any failures
# ---------------------------------------------------------------------------
summary() {
  echo ""
  echo "──────────────────────────────────────"
  printf "  Results: %d passed, %d failed, %d skipped\n" "$_PASS" "$_FAIL" "$_SKIP"
  echo "──────────────────────────────────────"
  [ "$_FAIL" -eq 0 ]
}
