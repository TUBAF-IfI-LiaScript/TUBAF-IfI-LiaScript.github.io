#!/usr/bin/env bats
# Unit tests for scripts/detect_changes.sh
#
# Approach
# --------
# detect_changes.sh uses `git diff --name-only HEAD~1 HEAD` to find recently
# changed YAML files and also checks for missing HTML files.  Each test spins
# up an isolated git repository in a temp directory, creates the required
# commits, and then runs detect_changes.sh from that directory.
#
# Results are written to a $GITHUB_OUTPUT file; tests read that file instead
# of relying on the script's exit code.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/detect_changes.sh"

# ---------------------------------------------------------------------------
# Per-test lifecycle
# ---------------------------------------------------------------------------
setup() {
  TEST_DIR="$(mktemp -d)"
  OUTPUT_FILE="$TEST_DIR/.github_output"
  touch "$OUTPUT_FILE"

  # Initialise a minimal git repo: first empty commit so HEAD~1 exists.
  git -C "$TEST_DIR" init -q
  git -C "$TEST_DIR" config user.email "test@example.com"
  git -C "$TEST_DIR" config user.name "Test"
  git -C "$TEST_DIR" commit -q --allow-empty -m "initial"

  cd "$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# commit_all [message]  – stage everything and create a commit
commit_all() {
  git -C "$TEST_DIR" add -A
  git -C "$TEST_DIR" commit -q -m "${1:-update}"
}

# run_detect  – run detect_changes.sh from $TEST_DIR
run_detect() {
  run env GITHUB_OUTPUT="$OUTPUT_FILE" bash "$SCRIPT"
}

# output_var <name>  – read a variable from the GITHUB_OUTPUT file
output_var() {
  grep "^${1}=" "$OUTPUT_FILE" 2>/dev/null | sed "s/^${1}=//" || true
}

# ---------------------------------------------------------------------------
# No changes needed
# ---------------------------------------------------------------------------

@test "no YAML change and all HTML present: courses_to_generate is empty" {
  echo "title: Course A" > coursea.yml
  touch coursea.html
  commit_all "add course A"

  # Second commit: only an unrelated file changes
  echo "readme" > README.md
  commit_all "add readme"

  run_detect
  [ "$status" -eq 0 ]
  result=$(output_var "courses_to_generate")
  [[ "$result" != *"coursea"* ]]
}

# ---------------------------------------------------------------------------
# YAML changed
# ---------------------------------------------------------------------------

@test "YAML changed in last commit: course appears in courses_to_generate" {
  echo "title: Course A v1" > coursea.yml
  touch coursea.html
  commit_all "initial course A"

  echo "title: Course A v2" > coursea.yml
  commit_all "update coursea.yml"

  run_detect
  result=$(output_var "courses_to_generate")
  [[ "$result" == *"coursea"* ]]
}

# ---------------------------------------------------------------------------
# HTML missing
# ---------------------------------------------------------------------------

@test "HTML missing: course appears in both outputs" {
  echo "title: Course B" > courseb.yml
  commit_all "add courseb yaml"

  echo "note" > note.txt
  commit_all "unrelated change"

  run_detect
  courses=$(output_var "courses_to_generate")
  missing=$(output_var "missing_html")
  [[ "$courses" == *"courseb"* ]]
  [[ "$missing" == *"courseb"* ]]
}

# ---------------------------------------------------------------------------
# YAML changed AND HTML missing
# ---------------------------------------------------------------------------

@test "YAML changed and HTML missing: course appears in both outputs" {
  echo "placeholder" > .keep
  commit_all "init"

  echo "title: Course C" > coursec.yml
  commit_all "add coursec.yml"

  run_detect
  courses=$(output_var "courses_to_generate")
  missing=$(output_var "missing_html")
  [[ "$courses" == *"coursec"* ]]
  [[ "$missing" == *"coursec"* ]]
}

# ---------------------------------------------------------------------------
# .github/ YAML files excluded
# ---------------------------------------------------------------------------

@test ".github/ YAML excluded: workflow file not treated as a course" {
  echo "placeholder" > .keep
  commit_all "init"

  mkdir -p .github/workflows
  echo "on: push" > .github/workflows/ci.yml
  commit_all "add workflow"

  run_detect
  courses=$(output_var "courses_to_generate")
  [[ "$courses" != *"ci"* ]]
  [[ "$courses" != *".github"* ]]
}

# ---------------------------------------------------------------------------
# Multiple courses – partial update
# ---------------------------------------------------------------------------

@test "only changed course appears in courses_to_generate" {
  echo "title: Course D" > coursed.yml
  echo "title: Course E" > coursee.yml
  touch coursed.html coursee.html
  commit_all "add courses D and E"

  echo "title: Course D v2" > coursed.yml
  commit_all "update coursed"

  run_detect
  courses=$(output_var "courses_to_generate")
  [[ "$courses" == *"coursed"* ]]
  [[ "$courses" != *"coursee"* ]]
}
