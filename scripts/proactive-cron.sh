#!/usr/bin/env bash
# =============================================================================
# proactive-cron.sh — Daily trigger for lobster proactive task scanning
# =============================================================================
#
# Sends a nudge to each running lobster, prompting them to scan their task
# boards (OKR, GitHub Issues, Notion, etc.) for items they can pick up.
#
# Designed to work with the proactive-task-engine skill on each lobster.
#
# Usage:
#   bash scripts/proactive-cron.sh
#
# Recommended cron (daily 09:00 UTC):
#   0 9 * * * cd ~/workspace && bash scripts/proactive-cron.sh
#
# =============================================================================

set -euo pipefail

LOG_PREFIX="[proactive-cron]"

# Discover running lobster containers
LOBSTERS=$(docker ps --filter "name=lobster-" --format '{{.Names}}' 2>/dev/null || true)

if [ -z "$LOBSTERS" ]; then
  echo "$LOG_PREFIX No running lobster containers found. Exiting."
  exit 0
fi

COUNT=$(echo "$LOBSTERS" | wc -l)
echo "$LOG_PREFIX Found $COUNT running lobster(s). Sending proactive scan nudge..."

NUDGE_MESSAGE="[proactive-scan] Please run your proactive-task-engine skill: scan your task boards for items you can pick up, and report any proposals back to your owner."

SUCCESS=0
FAIL=0

for LOBSTER in $LOBSTERS; do
  echo "$LOG_PREFIX Nudging $LOBSTER..."

  # Send the nudge via docker exec into the lobster's OpenClaw CLI
  if docker exec "$LOBSTER" openclaw send --message "$NUDGE_MESSAGE" 2>/dev/null; then
    echo "$LOG_PREFIX   ✅ $LOBSTER nudged"
    ((SUCCESS++))
  else
    # Fallback: write a trigger file the lobster can pick up on next heartbeat
    docker exec "$LOBSTER" bash -c "mkdir -p /tmp/proactive && echo '$NUDGE_MESSAGE' > /tmp/proactive/trigger-$(date +%Y%m%d).txt" 2>/dev/null || true
    echo "$LOG_PREFIX   ⚠️ $LOBSTER — openclaw send failed, wrote trigger file"
    ((FAIL++))
  fi
done

echo "$LOG_PREFIX Done. Success: $SUCCESS, Failed: $FAIL"
