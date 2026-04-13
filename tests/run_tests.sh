#!/usr/bin/env bash
# Run the full test suite.
#
# Prerequisites
#   bats   ≥ 1.0  (https://github.com/bats-core/bats-core)
#   cram   ≥ 0.7  (pip install cram)
#   remake ≥ 4.3  (apt install remake)
#
# Usage
#   bash tests/run_tests.sh          # from repo root
#   ./tests/run_tests.sh             # or directly

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$REPO_ROOT/tests"
overall_failed=0

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
section() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "  ⚠️  '$1' not found – skipping those tests"
    echo "      Install: $2"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
echo "╔══════════════════════════════════════╗"
echo "║  LiaScript Course Builder Test Suite ║"
echo "╚══════════════════════════════════════╝"

# ---------------------------------------------------------------------------
# 1. bats – shell script unit tests
# ---------------------------------------------------------------------------
section "bats  (shell script unit tests)"
if require_tool bats "https://github.com/bats-core/bats-core"; then
  for bats_file in "$TESTS_DIR"/bats/*.bats; do
    echo ""
    echo "  ▶  $(basename "$bats_file")"
    if bats "$bats_file"; then
      : # success
    else
      overall_failed=$((overall_failed + 1))
    fi
  done
else
  overall_failed=$((overall_failed + 1))
fi

# ---------------------------------------------------------------------------
# 2. cram – CLI integration tests
# ---------------------------------------------------------------------------
section "cram  (CLI integration tests)"
if require_tool cram "pip install cram"; then
  export REPO_ROOT
  if cram --shell=bash "$TESTS_DIR"/cram/*.t; then
    echo "  cram: all tests passed"
  else
    overall_failed=$((overall_failed + 1))
  fi
else
  overall_failed=$((overall_failed + 1))
fi

# ---------------------------------------------------------------------------
# 3. remake – Makefile tests
# ---------------------------------------------------------------------------
section "remake  (Makefile tests)"
if require_tool remake "apt install remake"; then
  if remake -f "$TESTS_DIR/remake/Makefile.test" test; then
    : # success – remake already prints a summary
  else
    overall_failed=$((overall_failed + 1))
  fi
else
  overall_failed=$((overall_failed + 1))
fi

# ---------------------------------------------------------------------------
echo ""
echo "╔══════════════════════════════════════╗"
if [ "$overall_failed" -eq 0 ]; then
  echo "║  ✅  All test suites passed          ║"
else
  echo "║  ❌  $overall_failed suite(s) had failures          ║"
fi
echo "╚══════════════════════════════════════╝"
exit "$overall_failed"
