#!/usr/bin/env bash
# =============================================================================
# review-skill-submission.sh — Review a skill submission for quality & safety
# =============================================================================
#
# Performs automated checks on a submitted skill before approval:
#   1. Structure validation (SKILL.md exists, frontmatter present)
#   2. Security scan (no hardcoded secrets, API keys, internal URLs)
#   3. Content quality (description, trigger conditions, file references)
#
# Usage:
#   bash scripts/review-skill-submission.sh <skill-name>
#
# Example:
#   bash scripts/review-skill-submission.sh my-cool-skill
#
# =============================================================================

set -euo pipefail

SUBMISSIONS_DIR="${SKILL_SUBMISSIONS_DIR:-/shared/skill-submissions}"
LOG_PREFIX="[skill-review]"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <skill-name>"
  echo "Example: $0 my-cool-skill"
  exit 1
fi

SKILL_NAME="$1"
SKILL_DIR="$SUBMISSIONS_DIR/$SKILL_NAME"

if [ ! -d "$SKILL_DIR" ]; then
  echo "$LOG_PREFIX ❌ Submission not found: $SKILL_DIR"
  exit 1
fi

ISSUES=0
WARNINGS=0

pass()  { echo "  ✅ $1"; }
warn()  { echo "  ⚠️  $1"; ((WARNINGS++)); }
fail()  { echo "  ❌ $1"; ((ISSUES++)); }

echo "============================================"
echo "Reviewing skill: $SKILL_NAME"
echo "Path: $SKILL_DIR"
echo "============================================"
echo ""

# ---------------------------------------------------------------------------
# 1. Structure validation
# ---------------------------------------------------------------------------
echo "📋 Structure Check"

# SKILL.md exists
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  pass "SKILL.md exists"
else
  fail "SKILL.md is missing (required)"
fi

# Frontmatter present
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  if head -1 "$SKILL_DIR/SKILL.md" | grep -q '^---'; then
    pass "SKILL.md has frontmatter"

    # Check required frontmatter fields
    for FIELD in name description; do
      if grep -q "^${FIELD}:" "$SKILL_DIR/SKILL.md"; then
        pass "Frontmatter has '$FIELD'"
      else
        fail "Frontmatter missing '$FIELD' (required)"
      fi
    done
  else
    fail "SKILL.md missing frontmatter (must start with ---)"
  fi
fi

# Check for references/ or scripts/ directories
for SUBDIR in references scripts templates; do
  if [ -d "$SKILL_DIR/$SUBDIR" ]; then
    FILE_COUNT=$(find "$SKILL_DIR/$SUBDIR" -type f | wc -l)
    pass "$SUBDIR/ directory ($FILE_COUNT files)"
  fi
done

echo ""

# ---------------------------------------------------------------------------
# 2. Security scan
# ---------------------------------------------------------------------------
echo "🔒 Security Check"

# Scan for potential secrets/keys
SECRET_PATTERNS=(
  'sk-[a-zA-Z0-9]{20,}'          # OpenAI-style keys
  'xoxb-[0-9]+'                   # Slack bot tokens
  'xoxp-[0-9]+'                   # Slack user tokens
  'ghp_[a-zA-Z0-9]{36}'           # GitHub PATs
  'ntn_[a-zA-Z0-9]+'              # Notion tokens
  'AKIA[0-9A-Z]{16}'              # AWS access keys
  'Bearer [a-zA-Z0-9._-]{20,}'   # Bearer tokens
)

FOUND_SECRETS=0
for PATTERN in "${SECRET_PATTERNS[@]}"; do
  MATCHES=$(grep -rn -E "$PATTERN" "$SKILL_DIR" 2>/dev/null | grep -v '.git/' || true)
  if [ -n "$MATCHES" ]; then
    fail "Potential secret found matching pattern: $PATTERN"
    echo "      $MATCHES" | head -3
    ((FOUND_SECRETS++))
  fi
done

if [ "$FOUND_SECRETS" -eq 0 ]; then
  pass "No hardcoded secrets detected"
fi

# Check for hardcoded internal URLs/IPs
INTERNAL_PATTERNS=(
  '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+'   # IP:port
  'internal\.'                                  # internal domains
  'localhost:[0-9]+'                            # localhost with port
)

for PATTERN in "${INTERNAL_PATTERNS[@]}"; do
  MATCHES=$(grep -rn -E "$PATTERN" "$SKILL_DIR" --include="*.md" --include="*.sh" --include="*.json" 2>/dev/null | grep -v '.git/' | grep -v 'example' | grep -v 'template' || true)
  if [ -n "$MATCHES" ]; then
    warn "Possible internal URL/IP (verify these are examples, not real endpoints):"
    echo "      $(echo "$MATCHES" | head -2)"
  fi
done

# Check for .env files that shouldn't be submitted
if find "$SKILL_DIR" -name ".env" -o -name ".env.*" 2>/dev/null | grep -q .; then
  fail "Contains .env file(s) — these should not be in submissions"
fi

echo ""

# ---------------------------------------------------------------------------
# 3. Content quality
# ---------------------------------------------------------------------------
echo "📝 Content Quality"

if [ -f "$SKILL_DIR/SKILL.md" ]; then
  LINE_COUNT=$(wc -l < "$SKILL_DIR/SKILL.md")

  if [ "$LINE_COUNT" -lt 10 ]; then
    fail "SKILL.md is too short ($LINE_COUNT lines) — likely incomplete"
  elif [ "$LINE_COUNT" -lt 30 ]; then
    warn "SKILL.md is short ($LINE_COUNT lines) — consider adding more detail"
  else
    pass "SKILL.md has $LINE_COUNT lines"
  fi

  # Check for common sections
  for SECTION in "When" "Usage" "File" "Depend"; do
    if grep -qi "$SECTION" "$SKILL_DIR/SKILL.md"; then
      pass "Contains '$SECTION' section"
    else
      warn "Missing '$SECTION' section (recommended)"
    fi
  done
fi

# Check total file count
TOTAL_FILES=$(find "$SKILL_DIR" -type f -not -path '*/.git/*' | wc -l)
echo ""
echo "  📁 Total files: $TOTAL_FILES"

echo ""
echo "============================================"
echo "Review Summary: $SKILL_NAME"
echo "  ❌ Issues:   $ISSUES"
echo "  ⚠️  Warnings: $WARNINGS"
echo "============================================"

if [ "$ISSUES" -gt 0 ]; then
  echo ""
  echo "❌ FAILED — Fix $ISSUES issue(s) before approval."
  exit 1
else
  if [ "$WARNINGS" -gt 0 ]; then
    echo ""
    echo "⚠️  PASSED with $WARNINGS warning(s). Review warnings before approving."
  else
    echo ""
    echo "✅ PASSED — Ready for approval."
  fi
  echo ""
  echo "To deploy: bash scripts/deploy-skill.sh $SKILL_NAME"
  exit 0
fi
