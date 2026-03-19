#!/bin/bash
# trigger-2nd-me-all.sh — Trigger 2nd Me self-improvement scan on ALL lobsters.
#
# Usage:
#   ./trigger-2nd-me-all.sh
#
# Recommended cron:
#   0 4 * * * $(pwd)/scripts/trigger-2nd-me-all.sh >> /tmp/2nd-me-scan.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🧬 2nd Me Daily Scan — $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "============================================="

COUNT=0
FAIL=0

for container in $(docker ps --filter "name=lobster-" --format '{{.Names}}' | sort); do
    echo -n "  $container ... "
    if docker exec "$container" openclaw agent \
        --session-id isolated \
        --timeout 600 \
        --message "[2nd-me-daily-scan] Scheduled daily self-improvement scan. Review .learnings/, promote validated lessons, archive old entries. Silent mode." \
        >/dev/null 2>&1; then
        echo "✅"
        COUNT=$((COUNT + 1))
    else
        echo "❌"
        FAIL=$((FAIL + 1))
    fi
done

echo "============================================="
echo "✅ Scanned: $COUNT | ❌ Failed: $FAIL"
