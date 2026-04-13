#!/usr/bin/env bash
# Shared helper library for courses.conf lookups.
#
# When sourced:
#   . scripts/courses_lib.sh
#   repo=$(lookup_repo "$course")   # prints repo suffix, or empty string
#
# When executed directly:
#   scripts/courses_lib.sh <course_name>  # prints repo suffix, or empty string

# Locate courses.conf relative to this script regardless of working directory.
_COURSES_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COURSES_CONF="${_COURSES_LIB_DIR}/courses.conf"

# lookup_repo <course_name>
# Prints the upstream repository suffix for the given course name, or an empty
# string when the course has no upstream mapping.
lookup_repo() {
  local course="$1"
  grep -v '^[[:space:]]*#' "${COURSES_CONF}" | grep "^${course}:" | cut -d: -f2 | tr -d '[:space:]' || true
}

# When this file is executed directly (not sourced) it acts as a thin
# command-line wrapper so Makefiles and other callers can use it without
# needing to source it.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [ -z "${1:-}" ]; then
    echo "Usage: $0 <course_name>" >&2
    exit 1
  fi
  lookup_repo "$1"
fi
