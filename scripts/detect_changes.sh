#!/bin/bash
# Detect changed YAML files and courses that need regeneration.
# Writes 'courses_to_generate' and 'missing_html' to $GITHUB_OUTPUT.

set -euo pipefail

echo "=== Detecting Changes ==="

# Get changed YAML files from last commit
changed_yamls=$(git diff --name-only HEAD~1 HEAD | grep '\.yml$' | grep -v '^\.github/' || true)
echo "Changed YAML files: $changed_yamls"

# Initialize lists for processing
courses_to_generate=""
missing_html=""

# Check each course YAML file
for yaml_file in *.yml; do
  course_name=$(basename "$yaml_file" .yml)
  html_file="${course_name}.html"

  # Check if YAML was changed or HTML is missing
  if echo "$changed_yamls" | grep -q "$yaml_file" || [ ! -f "$html_file" ]; then
    echo "Course '$course_name' needs regeneration:"
    if echo "$changed_yamls" | grep -q "$yaml_file"; then
      echo "  - YAML file was changed"
    fi
    if [ ! -f "$html_file" ]; then
      echo "  - HTML file is missing"
      missing_html="$missing_html $course_name"
    fi
    courses_to_generate="$courses_to_generate $course_name"
  else
    echo "Course '$course_name' is up to date"
  fi
done

echo "courses_to_generate=$courses_to_generate" >> "$GITHUB_OUTPUT"
echo "missing_html=$missing_html" >> "$GITHUB_OUTPUT"
