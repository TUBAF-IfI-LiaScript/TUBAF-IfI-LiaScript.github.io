#!/usr/bin/env bash
# Tests for scripts/detect_changes.sh
#
# Strategy
# --------
# detect_changes.sh calls `git diff --name-only HEAD~1 HEAD` to find recently
# changed YAML files and also inspects the filesystem for missing HTML files.
# Each test sets up a minimal temporary git repository so that the script runs
# in a realistic, fully isolated environment without touching the actual repo.
#
# Exit-code contract of detect_changes.sh
#   The script itself does not use a meaningful exit code – it writes its
#   results to $GITHUB_OUTPUT.  Tests therefore inspect that file instead.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/detect_changes.sh"
. "$REPO_ROOT/tests/lib/test_lib.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# init_git_repo <dir>
# Initialises a bare git repository with a first empty commit so that
# HEAD~1 always exists (required by detect_changes.sh's git diff call).
init_git_repo() {
  local dir="$1"
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  # First commit (empty baseline so HEAD~1 exists after the second commit)
  git -C "$dir" commit -q --allow-empty -m "initial"
}

# stage_and_commit <dir> [message]
# Stages all changes in <dir> and creates a new commit.
stage_and_commit() {
  local dir="$1"
  local msg="${2:-update}"
  git -C "$dir" add -A
  git -C "$dir" commit -q -m "$msg"
}

# run_detect <dir>
# Runs detect_changes.sh from within <dir> with a temporary GITHUB_OUTPUT file.
# Echoes the path to the output file (caller must capture with a subshell).
# Also echoes script stdout/stderr to the caller's stdout.
run_detect() {
  local dir="$1"
  local gh_output="$dir/.github_output"
  touch "$gh_output"

  (
    cd "$dir"
    GITHUB_OUTPUT="$gh_output" bash "$SCRIPT" 2>&1
  ) || true

  echo "$gh_output"
}

# read_output_var <output_file> <var_name>
# Extracts a variable value from a $GITHUB_OUTPUT formatted file
# (format: "varname=value").
read_output_var() {
  local file="$1"
  local var="$2"
  grep "^${var}=" "$file" 2>/dev/null | sed "s/^${var}=//" || true
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

suite "detect_changes.sh – no changes needed"

test_no_changed_yamls_all_html_present() {
  setup_tmpdir
  init_git_repo "$TMPDIR_TEST"

  # Create YAML and HTML files and commit them
  echo "title: Course A" > "$TMPDIR_TEST/coursea.yml"
  touch "$TMPDIR_TEST/coursea.html"
  stage_and_commit "$TMPDIR_TEST" "add course A"

  # Second commit with no YAML changes (touch an unrelated file)
  echo "readme" > "$TMPDIR_TEST/README.md"
  stage_and_commit "$TMPDIR_TEST" "add readme only"

  local gh_output
  gh_output=$(run_detect "$TMPDIR_TEST")

  local courses
  courses=$(read_output_var "$gh_output" "courses_to_generate")
  assert_output_not_contains "coursea" "$courses" \
    "no YAML change + HTML present: coursea not in courses_to_generate"

  teardown_tmpdir
}
test_no_changed_yamls_all_html_present

# ---------------------------------------------------------------------------

suite "detect_changes.sh – YAML changed"

test_changed_yaml_triggers_regeneration() {
  setup_tmpdir
  init_git_repo "$TMPDIR_TEST"

  # First commit: YAML + HTML both present
  echo "title: Course A v1" > "$TMPDIR_TEST/coursea.yml"
  touch "$TMPDIR_TEST/coursea.html"
  stage_and_commit "$TMPDIR_TEST" "initial course A"

  # Second commit: modify the YAML only
  echo "title: Course A v2" > "$TMPDIR_TEST/coursea.yml"
  stage_and_commit "$TMPDIR_TEST" "update coursea.yml"

  local output_file="$TMPDIR_TEST/.github_output"
  touch "$output_file"
  (cd "$TMPDIR_TEST"; GITHUB_OUTPUT="$output_file" bash "$SCRIPT" 2>&1) || true

  local courses
  courses=$(read_output_var "$output_file" "courses_to_generate")
  assert_output_contains "coursea" "$courses" \
    "YAML changed: coursea appears in courses_to_generate"

  teardown_tmpdir
}
test_changed_yaml_triggers_regeneration

# ---------------------------------------------------------------------------

suite "detect_changes.sh – HTML missing"

test_missing_html_triggers_regeneration() {
  setup_tmpdir
  init_git_repo "$TMPDIR_TEST"

  # Commit a YAML without a corresponding HTML file
  echo "title: Course B" > "$TMPDIR_TEST/courseb.yml"
  stage_and_commit "$TMPDIR_TEST" "add courseb yaml, no html"

  # Second commit: unrelated change (ensures HEAD~1 is the previous commit)
  echo "note" > "$TMPDIR_TEST/note.txt"
  stage_and_commit "$TMPDIR_TEST" "unrelated change"

  local output_file="$TMPDIR_TEST/.github_output"
  touch "$output_file"
  (cd "$TMPDIR_TEST"; GITHUB_OUTPUT="$output_file" bash "$SCRIPT" 2>&1) || true

  local courses missing
  courses=$(read_output_var "$output_file" "courses_to_generate")
  missing=$(read_output_var "$output_file" "missing_html")

  assert_output_contains "courseb" "$courses" \
    "HTML missing: courseb in courses_to_generate"
  assert_output_contains "courseb" "$missing" \
    "HTML missing: courseb in missing_html"

  teardown_tmpdir
}
test_missing_html_triggers_regeneration

# ---------------------------------------------------------------------------

suite "detect_changes.sh – YAML changed AND HTML missing"

test_yaml_changed_and_html_missing() {
  setup_tmpdir
  init_git_repo "$TMPDIR_TEST"

  # Baseline: no files
  echo "placeholder" > "$TMPDIR_TEST/.keep"
  stage_and_commit "$TMPDIR_TEST" "init"

  # Second commit: add a YAML, still no HTML
  echo "title: Course C" > "$TMPDIR_TEST/coursec.yml"
  stage_and_commit "$TMPDIR_TEST" "add coursec.yml"

  local output_file="$TMPDIR_TEST/.github_output"
  touch "$output_file"
  (cd "$TMPDIR_TEST"; GITHUB_OUTPUT="$output_file" bash "$SCRIPT" 2>&1) || true

  local courses missing
  courses=$(read_output_var "$output_file" "courses_to_generate")
  missing=$(read_output_var "$output_file" "missing_html")

  assert_output_contains "coursec" "$courses" \
    "YAML changed + HTML missing: coursec in courses_to_generate"
  assert_output_contains "coursec" "$missing" \
    "YAML changed + HTML missing: coursec in missing_html"

  teardown_tmpdir
}
test_yaml_changed_and_html_missing

# ---------------------------------------------------------------------------

suite "detect_changes.sh – .github/ YAML files excluded"

test_github_yml_not_treated_as_course() {
  setup_tmpdir
  init_git_repo "$TMPDIR_TEST"

  # First: baseline commit
  echo "placeholder" > "$TMPDIR_TEST/.keep"
  stage_and_commit "$TMPDIR_TEST" "init"

  # Second commit: modify a workflow YAML only
  mkdir -p "$TMPDIR_TEST/.github/workflows"
  echo "on: push" > "$TMPDIR_TEST/.github/workflows/ci.yml"
  stage_and_commit "$TMPDIR_TEST" "add workflow"

  local output_file="$TMPDIR_TEST/.github_output"
  touch "$output_file"
  (cd "$TMPDIR_TEST"; GITHUB_OUTPUT="$output_file" bash "$SCRIPT" 2>&1) || true

  local courses
  courses=$(read_output_var "$output_file" "courses_to_generate")
  assert_output_not_contains "ci" "$courses" \
    ".github/*.yml excluded: workflow YAML not treated as course"
  assert_output_not_contains ".github" "$courses" \
    ".github/*.yml excluded: .github path not in courses_to_generate"

  teardown_tmpdir
}
test_github_yml_not_treated_as_course

# ---------------------------------------------------------------------------

suite "detect_changes.sh – multiple courses, partial update"

test_only_changed_course_regenerated() {
  setup_tmpdir
  init_git_repo "$TMPDIR_TEST"

  # First commit: two courses, both with HTML
  echo "title: Course D" > "$TMPDIR_TEST/coursed.yml"
  echo "title: Course E" > "$TMPDIR_TEST/coursee.yml"
  touch "$TMPDIR_TEST/coursed.html"
  touch "$TMPDIR_TEST/coursee.html"
  stage_and_commit "$TMPDIR_TEST" "add courses D and E"

  # Second commit: only coursed.yml changes
  echo "title: Course D v2" > "$TMPDIR_TEST/coursed.yml"
  stage_and_commit "$TMPDIR_TEST" "update coursed"

  local output_file="$TMPDIR_TEST/.github_output"
  touch "$output_file"
  (cd "$TMPDIR_TEST"; GITHUB_OUTPUT="$output_file" bash "$SCRIPT" 2>&1) || true

  local courses
  courses=$(read_output_var "$output_file" "courses_to_generate")
  assert_output_contains "coursed" "$courses" \
    "partial update: changed course coursed in courses_to_generate"
  assert_output_not_contains "coursee" "$courses" \
    "partial update: unchanged course coursee not in courses_to_generate"

  teardown_tmpdir
}
test_only_changed_course_regenerated

# ---------------------------------------------------------------------------
summary
