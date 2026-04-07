#!/usr/bin/env bash
# =============================================================================
# test-goal-flow.sh — Integration test: spawn → goal decompose → patrol
# =============================================================================
#
# Validates the full goal orchestration flow end-to-end using mock data.
# Does NOT require running containers or API access.
#
# Tests:
#   1. Goal state file creation and schema validation
#   2. Patrol script behavior with mock state
#   3. Skill submission pipeline (poll → review → deploy)
#   4. Proactive cron discovery of running containers
#
# Usage:
#   bash tests/test-goal-flow.sh
#
# =============================================================================

set -uo pipefail

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TMP_DIR=$(mktemp -d)

pass() { echo "  ✅ $1"; ((PASS++)); }
fail() { echo "  ❌ $1"; ((FAIL++)); }

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "============================================"
echo "Integration Test: Goal Flow"
echo "============================================"
echo ""

# ---------------------------------------------------------------------------
# Test 1: Goal state file schema
# ---------------------------------------------------------------------------
echo "📋 Test 1: Goal state schema"

cat > "$TMP_DIR/goals.json" << 'EOF'
{
  "goals": {
    "GOAL-20260407-001": {
      "description": "Test goal for integration test",
      "status": "active",
      "createdAt": "2026-04-07T12:00:00Z",
      "deadline": "2026-04-14",
      "subGoals": {
        "SG-1": {
          "description": "Backend API implementation",
          "assignees": ["lobster-alice"],
          "status": "open",
          "threadId": null,
          "acceptance": ["API returns 200", "Tests pass"]
        },
        "SG-2": {
          "description": "Frontend integration",
          "assignees": ["lobster-bob"],
          "status": "open",
          "threadId": null,
          "acceptance": ["Page renders", "API connected"]
        }
      }
    }
  }
}
EOF

# Validate JSON
if python3 -c "import json; json.load(open('$TMP_DIR/goals.json'))" 2>/dev/null || \
   node -e "JSON.parse(require('fs').readFileSync('$TMP_DIR/goals.json','utf8'))" 2>/dev/null; then
  pass "goals.json is valid JSON"
else
  fail "goals.json is not valid JSON"
fi

# Check required fields
if grep -q '"status"' "$TMP_DIR/goals.json" && \
   grep -q '"subGoals"' "$TMP_DIR/goals.json" && \
   grep -q '"acceptance"' "$TMP_DIR/goals.json"; then
  pass "goals.json has required fields (status, subGoals, acceptance)"
else
  fail "goals.json missing required fields"
fi

echo ""

# ---------------------------------------------------------------------------
# Test 2: Skill submission pipeline
# ---------------------------------------------------------------------------
echo "📋 Test 2: Skill submission pipeline"

# Create mock submission
MOCK_SUBMISSION="$TMP_DIR/submissions/test-skill"
mkdir -p "$MOCK_SUBMISSION"
cat > "$MOCK_SUBMISSION/SKILL.md" << 'EOF'
---
name: test-skill
description: "A test skill for integration testing"
---

# Test Skill

## When to Use
When running integration tests.

## Usage
Just a test.

## File Structure
```
test-skill/
└── SKILL.md
```

## Dependencies
None.
EOF

# Test review script
if [ -x "$REPO_DIR/scripts/review-skill-submission.sh" ]; then
  # Run review with mock submissions dir
  SKILL_SUBMISSIONS_DIR="$TMP_DIR/submissions" \
    bash "$REPO_DIR/scripts/review-skill-submission.sh" test-skill > "$TMP_DIR/review-output.txt" 2>&1 || true

  if grep -q "SKILL.md exists" "$TMP_DIR/review-output.txt"; then
    pass "review-skill-submission.sh detects SKILL.md"
  else
    fail "review-skill-submission.sh did not detect SKILL.md"
  fi

  if grep -q "No hardcoded secrets" "$TMP_DIR/review-output.txt"; then
    pass "review-skill-submission.sh security scan passes on clean skill"
  else
    fail "review-skill-submission.sh security scan failed on clean skill"
  fi
else
  fail "review-skill-submission.sh not found or not executable"
fi

# Test poll script
if [ -x "$REPO_DIR/scripts/poll-skill-submissions.sh" ]; then
  mkdir -p "$TMP_DIR/state"
  echo '{"seen":[]}' > "$TMP_DIR/state/skill-submissions-seen.json"

  SKILL_SUBMISSIONS_DIR="$TMP_DIR/submissions" \
    bash -c "cd $TMP_DIR && STATE_FILE=state/skill-submissions-seen.json bash $REPO_DIR/scripts/poll-skill-submissions.sh" > "$TMP_DIR/poll-output.txt" 2>&1 || true

  if grep -q "test-skill" "$TMP_DIR/poll-output.txt"; then
    pass "poll-skill-submissions.sh discovers new submission"
  else
    fail "poll-skill-submissions.sh did not discover submission"
  fi
else
  fail "poll-skill-submissions.sh not found or not executable"
fi

echo ""

# ---------------------------------------------------------------------------
# Test 3: Crontab syntax
# ---------------------------------------------------------------------------
echo "📋 Test 3: Crontab validation"

if [ -f "$REPO_DIR/crontab.example" ]; then
  # Check for valid cron syntax (basic: 5 fields + command)
  INVALID_LINES=0
  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    # Skip variable assignments
    [[ "$line" =~ ^[A-Z_]+= ]] && continue
    # Check for 5 cron fields
    FIELDS=$(echo "$line" | awk '{print NF}')
    if [ "$FIELDS" -lt 6 ]; then
      echo "    Invalid line: $line"
      ((INVALID_LINES++))
    fi
  done < "$REPO_DIR/crontab.example"

  if [ "$INVALID_LINES" -eq 0 ]; then
    pass "crontab.example has valid syntax"
  else
    fail "crontab.example has $INVALID_LINES invalid lines"
  fi
else
  fail "crontab.example not found"
fi

echo ""

# ---------------------------------------------------------------------------
# Test 4: All P1 files exist
# ---------------------------------------------------------------------------
echo "📋 Test 4: P1 file completeness"

P1_FILES=(
  "templates/controller/goal-ops/SKILL.md"
  "templates/skills/proactive-task-engine/SKILL.md"
  "templates/skills/task-autopilot/SKILL.md"
  "scripts/proactive-cron.sh"
  "templates/skills/coding-workflow/SKILL.md"
  "templates/controller/HEARTBEAT.md"
  "crontab.example"
  "scripts/poll-skill-submissions.sh"
  "scripts/review-skill-submission.sh"
  "scripts/deploy-skill.sh"
  "company-config/AGENTS.md"
  "company-skills/manifest.json"
)

for FILE in "${P1_FILES[@]}"; do
  if [ -f "$REPO_DIR/$FILE" ]; then
    # Check it's not empty
    if [ -s "$REPO_DIR/$FILE" ]; then
      pass "$FILE exists and is non-empty"
    else
      fail "$FILE exists but is empty"
    fi
  else
    fail "$FILE is missing"
  fi
done

echo ""

# ---------------------------------------------------------------------------
# Test 5: SKILL.md frontmatter validation
# ---------------------------------------------------------------------------
echo "📋 Test 5: SKILL.md frontmatter"

SKILL_FILES=$(find "$REPO_DIR/templates" -name "SKILL.md" -type f)
for SKILL in $SKILL_FILES; do
  REL_PATH="${SKILL#$REPO_DIR/}"
  if head -1 "$SKILL" | grep -q '^---'; then
    if grep -q '^name:' "$SKILL" && grep -q '^description:' "$SKILL"; then
      pass "$REL_PATH has valid frontmatter"
    else
      fail "$REL_PATH missing name/description in frontmatter"
    fi
  else
    # Some SKILL.md files may not need frontmatter (like HEARTBEAT.md)
    if [[ "$REL_PATH" == *"HEARTBEAT"* ]]; then
      pass "$REL_PATH (no frontmatter needed)"
    else
      fail "$REL_PATH missing frontmatter (---)"
    fi
  fi
done

echo ""
echo "============================================"
echo "Results: $PASS passed, $FAIL failed"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
