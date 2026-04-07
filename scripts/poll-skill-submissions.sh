#!/usr/bin/env bash
# =============================================================================
# poll-skill-submissions.sh — Scan skill-submissions/ for new submissions
# =============================================================================
#
# Checks the shared skill-submissions directory for new or pending submissions.
# Each submission is a directory containing at minimum a SKILL.md file.
#
# Usage:
#   bash scripts/poll-skill-submissions.sh
#
# Output:
#   Lists pending submissions with metadata. Returns exit code:
#     0 — new submissions found
#     1 — error
#     2 — no new submissions
#
# =============================================================================

set -euo pipefail

SUBMISSIONS_DIR="${SKILL_SUBMISSIONS_DIR:-/shared/skill-submissions}"
STATE_FILE="state/skill-submissions-seen.json"
LOG_PREFIX="[skill-poll]"

# Ensure state file exists
if [ ! -f "$STATE_FILE" ]; then
  echo '{"seen":[]}' > "$STATE_FILE"
fi

if [ ! -d "$SUBMISSIONS_DIR" ]; then
  echo "$LOG_PREFIX Submissions directory not found: $SUBMISSIONS_DIR"
  exit 1
fi

# Find all submission directories (must contain SKILL.md)
SUBMISSIONS=$(find "$SUBMISSIONS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

if [ -z "$SUBMISSIONS" ]; then
  echo "$LOG_PREFIX No submissions found."
  exit 2
fi

SEEN=$(cat "$STATE_FILE")
NEW_COUNT=0

echo "$LOG_PREFIX Scanning submissions..."
echo "---"

for DIR in $SUBMISSIONS; do
  NAME=$(basename "$DIR")

  # Check if already seen
  if echo "$SEEN" | grep -q "\"$NAME\""; then
    continue
  fi

  # Check for required SKILL.md
  if [ ! -f "$DIR/SKILL.md" ]; then
    echo "$LOG_PREFIX ⚠️  $NAME — missing SKILL.md, skipping"
    continue
  fi

  # Extract metadata from SKILL.md frontmatter
  DESCRIPTION=$(grep -m1 '^description:' "$DIR/SKILL.md" 2>/dev/null | sed 's/^description: *//' | tr -d '"' || echo "No description")
  AUTHOR=$(ls -ld "$DIR" | awk '{print $3}')
  SUBMITTED=$(stat -c '%y' "$DIR/SKILL.md" 2>/dev/null | cut -d. -f1 || echo "unknown")
  FILE_COUNT=$(find "$DIR" -type f | wc -l)

  echo "📦 NEW: $NAME"
  echo "   Description: $DESCRIPTION"
  echo "   Author: $AUTHOR"
  echo "   Submitted: $SUBMITTED"
  echo "   Files: $FILE_COUNT"
  echo ""

  ((NEW_COUNT++))
done

echo "---"

if [ "$NEW_COUNT" -eq 0 ]; then
  echo "$LOG_PREFIX No new submissions."
  exit 2
else
  echo "$LOG_PREFIX Found $NEW_COUNT new submission(s) pending review."
  echo "$LOG_PREFIX Run: bash scripts/review-skill-submission.sh <skill-name>"
  exit 0
fi
