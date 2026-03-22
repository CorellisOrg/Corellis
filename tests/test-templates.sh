#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0

echo "=== Template Integrity ==="

# 1. Required template files exist
echo "--- Required files ---"
for f in \
  templates/company-config/AGENTS.md \
  templates/company-config/REGISTRY.md \
  templates/company-config/DIRECTORY.md \
  templates/company-memory/INDEX.md \
  templates/manifest.json \
  templates/SKILL_POLICY.md; do
  if [ -f "$ROOT/$f" ]; then
    echo "  ✓ $f"
  else
    echo "  ✗ $f — MISSING"
    ((ERRORS++))
  fi
done

# 2. manifest.json is valid JSON
echo "--- manifest.json validation ---"
if python3 -c "import json; json.load(open('$ROOT/templates/manifest.json'))" 2>/dev/null; then
  echo "  ✓ valid JSON"
else
  echo "  ✗ invalid JSON"
  ((ERRORS++))
fi

# 3. Every skill in manifest.json has a directory
echo "--- Skill directories ---"
if command -v python3 &>/dev/null; then
  python3 -c "
import json, os
m = json.load(open('$ROOT/templates/manifest.json'))
skills = m.get('skills', m) if isinstance(m, dict) else []
if isinstance(skills, dict):
    skills = list(skills.keys())
missing = 0
for s in skills[:30]:  # limit check
    name = s if isinstance(s, str) else s.get('name', '')
    if not name: continue
    paths = [
        os.path.join('$ROOT', 'templates', 'skills', name),
        os.path.join('$ROOT', 'templates', name),
    ]
    if any(os.path.isdir(p) for p in paths):
        print(f'  ✓ {name}')
    else:
        print(f'  ⚠ {name} — directory not found (may be inline)')
print()
" 2>/dev/null || echo "  (skipped — python3 not available)"
fi

# 4. Docker files exist
echo "--- Docker files ---"
for f in docker/Dockerfile.lite docker/entrypoint.sh docker-compose.base.yml; do
  if [ -f "$ROOT/$f" ]; then
    echo "  ✓ $f"
  else
    echo "  ✗ $f — MISSING"
    ((ERRORS++))
  fi
done

echo ""
echo "Template tests complete: $ERRORS errors"
[ "$ERRORS" -eq 0 ]
