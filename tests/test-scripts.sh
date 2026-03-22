#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0

echo "=== Shell Script Validation ==="

# 1. All .sh files should have valid bash syntax
echo "--- Syntax check ---"
for f in "$ROOT"/scripts/*.sh; do
  if bash -n "$f" 2>/dev/null; then
    echo "  ✓ $(basename "$f")"
  else
    echo "  ✗ $(basename "$f") — syntax error"
    ((ERRORS++))
  fi
done

# 2. All .sh files should be executable
echo "--- Permission check ---"
for f in "$ROOT"/scripts/*.sh; do
  if [ -x "$f" ]; then
    echo "  ✓ $(basename "$f")"
  else
    echo "  ✗ $(basename "$f") — not executable"
    ((ERRORS++))
  fi
done

# 3. All scripts should use set -e or set -euo pipefail
echo "--- Safety flags check ---"
for f in "$ROOT"/scripts/*.sh; do
  if head -5 "$f" | grep -q 'set -e'; then
    echo "  ✓ $(basename "$f")"
  else
    echo "  ⚠ $(basename "$f") — missing set -e (warning)"
  fi
done

# 4. install.sh should be valid
echo "--- Install script check ---"
if [ -f "$ROOT/install.sh" ] && bash -n "$ROOT/install.sh"; then
  echo "  ✓ install.sh syntax OK"
else
  echo "  ✗ install.sh — syntax error"
  ((ERRORS++))
fi

echo ""
echo "Script tests complete: $ERRORS errors"
[ "$ERRORS" -eq 0 ]
