#!/usr/bin/env bash
# Run the full test suite.
#
# Prerequisites (all must be installed – any missing tool aborts immediately)
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

# Per-framework pass/fail tracking (0 = passed, 1 = failed)
bats_failed=0
cram_failed=0
remake_failed=0

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
section() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# require_tool <name> <install-hint>
# Exits the entire script immediately if <name> is not on PATH.
require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo ""
    echo "❌  Required tool '$1' not found."
    echo "    Install with: $2"
    echo "    All three tools (bats, cram, remake) must be installed before running the suite."
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Dependency check – fails fast if any tool is missing
# ---------------------------------------------------------------------------
echo "╔══════════════════════════════════════╗"
echo "║  LiaScript Course Builder Test Suite ║"
echo "╚══════════════════════════════════════╝"

section "Checking prerequisites"
require_tool bats   "https://github.com/bats-core/bats-core  (or: npm install -g bats)"
require_tool cram   "pip install cram"
require_tool remake "apt install remake"
echo "  ✅  bats, cram, remake all found"

# ---------------------------------------------------------------------------
# 1. bats – shell script unit tests
# ---------------------------------------------------------------------------
section "bats  (shell script unit tests)"
bats_files=("$TESTS_DIR"/bats/*.bats)
if [ ! -e "${bats_files[0]}" ]; then
  echo "  ⚠️  No .bats files found in tests/bats/ – nothing to run"
else
  for bats_file in "${bats_files[@]}"; do
    echo ""
    echo "  ▶  $(basename "$bats_file")"
    if ! bats "$bats_file"; then
      bats_failed=1
    fi
  done
fi

# ---------------------------------------------------------------------------
# 2. cram – CLI integration tests
# ---------------------------------------------------------------------------
section "cram  (CLI integration tests)"
cram_files=("$TESTS_DIR"/cram/*.t)
if [ ! -e "${cram_files[0]}" ]; then
  echo "  ⚠️  No .t files found in tests/cram/ – nothing to run"
else
  export REPO_ROOT
  if cram --shell=bash "${cram_files[@]}"; then
    echo "  cram: all tests passed"
  else
    cram_failed=1
  fi
fi

# ---------------------------------------------------------------------------
# 3. remake – Makefile tests
# ---------------------------------------------------------------------------
section "remake  (Makefile tests)"
if remake -f "$TESTS_DIR/remake/Makefile.test" test; then
  : # success – remake already prints a summary
else
  remake_failed=1
fi

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
overall_failed=$(( bats_failed + cram_failed + remake_failed ))

echo ""
echo "╔══════════════════════════════════════╗"
if [ "$overall_failed" -eq 0 ]; then
  echo "║  ✅  All test suites passed          ║"
else
  [ "$bats_failed"   -eq 1 ] && echo "║  ❌  bats   suite FAILED             ║"
  [ "$cram_failed"   -eq 1 ] && echo "║  ❌  cram   suite FAILED             ║"
  [ "$remake_failed" -eq 1 ] && echo "║  ❌  remake suite FAILED             ║"
fi
echo "╚══════════════════════════════════════╝"
exit "$overall_failed"
