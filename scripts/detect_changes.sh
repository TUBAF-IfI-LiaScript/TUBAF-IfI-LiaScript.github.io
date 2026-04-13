#!/bin/bash
# Detect changed YAML files and courses that need regeneration.
# Writes 'courses_to_generate' and 'missing_html' to $GITHUB_OUTPUT.

set -euo pipefail

# ---------------------------------------------------------------------------
# get_changed_yamls – list YAML files modified in the last commit.
# Sets CHANGED_YAMLS.
# ---------------------------------------------------------------------------
get_changed_yamls() {
  CHANGED_YAMLS=$(git diff --name-only HEAD~1 HEAD | grep '\.yml$' | grep -v '^\.github/' || true)
  echo "Changed YAML files: $CHANGED_YAMLS"
}

# ---------------------------------------------------------------------------
# check_courses – iterate all course YAMLs, collect which need regeneration.
# Sets COURSES_TO_GENERATE and MISSING_HTML.
# ---------------------------------------------------------------------------
check_courses() {
  COURSES_TO_GENERATE=""
  MISSING_HTML=""

  for yaml_file in *.yml; do
    local course_name html_file
    course_name=$(basename "$yaml_file" .yml)
    html_file="${course_name}.html"

    if echo "$CHANGED_YAMLS" | grep -q "$yaml_file" || [ ! -f "$html_file" ]; then
      echo "Course '$course_name' needs regeneration:"
      if echo "$CHANGED_YAMLS" | grep -q "$yaml_file"; then
        echo "  - YAML file was changed"
      fi
      if [ ! -f "$html_file" ]; then
        echo "  - HTML file is missing"
        MISSING_HTML="$MISSING_HTML $course_name"
      fi
      COURSES_TO_GENERATE="$COURSES_TO_GENERATE $course_name"
    else
      echo "Course '$course_name' is up to date"
    fi
  done
}

# ---------------------------------------------------------------------------
# write_outputs – write results to $GITHUB_OUTPUT
# ---------------------------------------------------------------------------
write_outputs() {
  echo "courses_to_generate=$COURSES_TO_GENERATE" >> "$GITHUB_OUTPUT"
  echo "missing_html=$MISSING_HTML" >> "$GITHUB_OUTPUT"
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  echo "=== Detecting Changes ==="
  get_changed_yamls
  check_courses
  write_outputs
}

main
