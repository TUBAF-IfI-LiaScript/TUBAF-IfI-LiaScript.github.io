#!/bin/bash
# Print a deployment summary.
# Usage: ./scripts/deployment_summary.sh "<space-separated course names that were regenerated>"

set -euo pipefail

IFS=' ' read -ra course_list <<< "${1:-}"

echo "=== Deployment Summary ==="
echo "HTML files to deploy:"
ls -la ./*.html 2>/dev/null || echo "No HTML files"
echo ""
echo "Asset directories:"
find assets/ -type d 2>/dev/null || echo "No asset directories"
echo ""
echo "PDF counts per course:"
for dir in assets/*/pdf; do
  if [ -d "$dir" ]; then
    course=$(basename "$(dirname "$dir")")
    count=$(ls -1 "$dir"/*.pdf 2>/dev/null | wc -l)
    echo "  $course: $count PDFs"
  fi
done
echo ""
echo "Generated in this run:"
if [ ${#course_list[@]} -gt 0 ] && [ -n "${course_list[0]}" ]; then
  for course in "${course_list[@]}"; do
    echo "  - $course"
  done
else
  echo "  - No courses needed regeneration"
fi
echo "=== End Summary ==="
