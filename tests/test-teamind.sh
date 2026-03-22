#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEAMIND="$ROOT/scripts/teamind"
ERRORS=0

echo "=== Teamind Module Validation ==="

# 1. package.json exists and is valid
echo "--- package.json ---"
if [ -f "$TEAMIND/package.json" ] && python3 -c "import json; json.load(open('$TEAMIND/package.json'))" 2>/dev/null; then
  echo "  ✓ valid"
else
  echo "  ✗ missing or invalid"
  ((ERRORS++))
fi

# 2. All JS files have valid syntax
echo "--- Syntax check ---"
for f in "$TEAMIND"/*.js; do
  if node --check "$f" 2>/dev/null; then
    echo "  ✓ $(basename "$f")"
  else
    echo "  ✗ $(basename "$f") — syntax error"
    ((ERRORS++))
  fi
done

# 3. Required modules exist
echo "--- Required modules ---"
for mod in setup.js indexer.js search.js digest.js; do
  if [ -f "$TEAMIND/$mod" ]; then
    echo "  ✓ $mod"
  else
    echo "  ✗ $mod — MISSING"
    ((ERRORS++))
  fi
done

echo ""
echo "Teamind tests complete: $ERRORS errors"
[ "$ERRORS" -eq 0 ]
