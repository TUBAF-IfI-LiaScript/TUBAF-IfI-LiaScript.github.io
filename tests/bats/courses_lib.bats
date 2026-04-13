#!/usr/bin/env bats
# Unit tests for scripts/courses_lib.sh
#
# courses_lib.sh can be both sourced (as a library) and executed directly
# (as a command-line wrapper).  Both usage modes are tested here.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
LIB="$REPO_ROOT/scripts/courses_lib.sh"
CONF="$REPO_ROOT/scripts/courses.conf"

# ---------------------------------------------------------------------------
# Executed directly (CLI wrapper)
# ---------------------------------------------------------------------------

@test "run without argument: exits non-zero with usage on stderr" {
  run bash "$LIB"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "digitalesysteme maps to EingebetteteSysteme" {
  run bash "$LIB" "digitalesysteme"
  [ "$status" -eq 0 ]
  [ "$output" = "EingebetteteSysteme" ]
}

@test "prozprog maps to ProzeduraleProgrammierung" {
  run bash "$LIB" "prozprog"
  [ "$status" -eq 0 ]
  [ "$output" = "ProzeduraleProgrammierung" ]
}

@test "softwareentwicklung maps to Softwareentwicklung" {
  run bash "$LIB" "softwareentwicklung"
  [ "$status" -eq 0 ]
  [ "$output" = "Softwareentwicklung" ]
}

@test "robotikprojekt maps to SoftwareprojektRobotik" {
  run bash "$LIB" "robotikprojekt"
  [ "$status" -eq 0 ]
  [ "$output" = "SoftwareprojektRobotik" ]
}

@test "index has no upstream mapping (empty output)" {
  run bash "$LIB" "index"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "unknown course has no upstream mapping (empty output)" {
  run bash "$LIB" "nonexistent_course_xyz"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# Sourced as a library
# ---------------------------------------------------------------------------

@test "lookup_repo() returns correct mapping when sourced" {
  # shellcheck disable=SC1090
  source "$LIB"
  result=$(lookup_repo "digitalesysteme")
  [ "$result" = "EingebetteteSysteme" ]
}

@test "lookup_repo() returns empty string for unknown course when sourced" {
  # shellcheck disable=SC1090
  source "$LIB"
  result=$(lookup_repo "does_not_exist")
  [ -z "$result" ]
}

# ---------------------------------------------------------------------------
# courses.conf content
# ---------------------------------------------------------------------------

@test "courses.conf exists and is readable" {
  [ -f "$CONF" ]
  [ -r "$CONF" ]
}

@test "courses.conf contains all expected course entries" {
  grep -q "^digitalesysteme:" "$CONF"
  grep -q "^prozprog:" "$CONF"
  grep -q "^softwareentwicklung:" "$CONF"
  grep -q "^robotikprojekt:" "$CONF"
}
