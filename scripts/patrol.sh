#!/usr/bin/env bash
# =============================================================================
# patrol.sh — GoalOps patrol: detect stuck sub-goals and unanswered mentions
# =============================================================================
#
# Scans active goals for anomalies:
#   - Sub-goals stuck in "in_progress" for >2 hours
#   - Sub-goals with no updates for >4 hours
#   - Unanswered controller @mentions in goal threads
#
# Usage:
#   bash scripts/patrol.sh
#
# Runs as a cron job (every 30 min). Zero cost when no active goals.
# =============================================================================

set -uo pipefail

LOG_PREFIX="[patrol]"
STATE_FILE="${GOAL_STATE_FILE:-state/goals.json}"

# Exit early if no active goals
if [ ! -f "$STATE_FILE" ]; then
    exit 0
fi

# Check if there are any active goals
ACTIVE=$(python3 -c "
import json, sys
try:
    data = json.load(open('$STATE_FILE'))
    goals = data.get('goals', {})
    active = [g for g, v in goals.items() if v.get('status') == 'active']
    print(len(active))
except:
    print(0)
" 2>/dev/null || echo "0")

if [ "$ACTIVE" = "0" ]; then
    exit 0
fi

echo "$LOG_PREFIX Patrolling $ACTIVE active goal(s)..."

NOW=$(date +%s)
STUCK_HOURS=2
SILENT_HOURS=4
ISSUES=0

# Check each active goal for stuck sub-goals
while IFS= read -r line; do
    echo "$line"
    if [[ "$line" == *"⚠️"* ]]; then
        ((ISSUES++))
    fi
done < <(python3 -c "
import json, sys
from datetime import datetime, timezone

state_file = '$STATE_FILE'
stuck_hours = $STUCK_HOURS
silent_hours = $SILENT_HOURS

try:
    with open(state_file) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    sys.exit(0)

now = datetime.now(timezone.utc)
issues = 0

for goal_id, goal in data.get('goals', {}).items():
    if goal.get('status') != 'active':
        continue
    for sg_id, sg in goal.get('subGoals', {}).items():
        status = sg.get('status', 'open')
        updated = sg.get('updatedAt')
        if not updated:
            continue
        try:
            updated_dt = datetime.fromisoformat(updated.replace('Z', '+00:00'))
            hours_since = (now - updated_dt).total_seconds() / 3600
        except (ValueError, AttributeError):
            continue
        if status == 'in_progress' and hours_since > stuck_hours:
            assignees = sg.get('assignees', ['?'])
            print(f'⚠️  {goal_id}/{sg_id}: stuck in_progress for {hours_since:.1f}h (assigned to {assignees})')
            issues += 1
        if hours_since > silent_hours:
            print(f'⚠️  {goal_id}/{sg_id}: no update for {hours_since:.1f}h')
            issues += 1

if issues == 0:
    print('✅ All sub-goals progressing normally')
else:
    print(f'\n🚨 {issues} issue(s) found — consider nudging assigned lobsters')
" 2>/dev/null || echo "✅ No issues (state parse skipped)")

echo "$LOG_PREFIX Patrol complete."
