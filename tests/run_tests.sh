#!/usr/bin/env bash
# Run all test scripts in this directory.
# Usage:  bash tests/run_tests.sh
#         ./tests/run_tests.sh

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "╔══════════════════════════════════════╗"
echo "║  Change-Detection Test Suite         ║"
echo "╚══════════════════════════════════════╝"

overall_failed=0

for test_file in "$TESTS_DIR"/test_*.sh; do
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Running: $(basename "$test_file")"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if bash "$test_file"; then
    : # success
  else
    overall_failed=$((overall_failed + 1))
  fi
done

echo ""
echo "╔══════════════════════════════════════╗"
if [ "$overall_failed" -eq 0 ]; then
  echo "║  ✅  All test files passed           ║"
else
  echo "║  ❌  $overall_failed test file(s) had failures  ║"
fi
echo "╚══════════════════════════════════════╝"

exit "$overall_failed"
