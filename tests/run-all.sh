#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0

run_suite() {
  local suite="$1"
  echo "━━━ Running: $suite ━━━"
  if bash "$SCRIPT_DIR/$suite"; then
    ((PASS++))
    echo "✅ $suite passed"
  else
    ((FAIL++))
    echo "❌ $suite failed"
  fi
  echo ""
}

run_suite test-scripts.sh
run_suite test-templates.sh
run_suite test-teamind.sh

echo "━━━━━━━━━━━━━━━━━━━━━"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
