#!/usr/bin/env bash
# =============================================================================
# cron-audit.sh — Weekly self-check of cron job health
# =============================================================================
#
# Scans cron log files for errors, missed runs, and anomalies.
# Designed to run weekly (Monday 08:00 UTC) via crontab.
#
# Usage:
#   bash scripts/cron-audit.sh
#
# =============================================================================

set -uo pipefail

LOG_PREFIX="[cron-audit]"
LOG_DIR="/tmp"
LOG_PATTERN="corellis-cron-*.log"
REPORT=""
ISSUES=0

echo "$LOG_PREFIX Weekly cron audit — $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "============================================"

# Check each cron log for errors
for logfile in "$LOG_DIR"/$LOG_PATTERN; do
    [ -f "$logfile" ] || continue
    
    basename=$(basename "$logfile")
    size=$(stat -c%s "$logfile" 2>/dev/null || echo "0")
    last_mod=$(stat -c%Y "$logfile" 2>/dev/null || echo "0")
    now=$(date +%s)
    age_hours=$(( (now - last_mod) / 3600 ))
    
    # Check for error patterns
    errors=$(grep -ciE '(error|fatal|fail|panic|exception|denied)' "$logfile" 2>/dev/null || echo "0")
    
    if [ "$errors" -gt "0" ]; then
        echo "⚠️  $basename: $errors error line(s) in last 7 days"
        grep -iE '(error|fatal|fail|panic|exception|denied)' "$logfile" 2>/dev/null | tail -3 | sed 's/^/   /'
        ((ISSUES++))
    fi
    
    # Check for stale logs (no updates in >48h for frequent jobs)
    if [[ "$basename" == *"watchdog"* || "$basename" == *"bottleneck"* ]] && [ "$age_hours" -gt 48 ]; then
        echo "⚠️  $basename: no updates for ${age_hours}h (expected every 5 min)"
        ((ISSUES++))
    fi
done

# Check crontab is installed
if crontab -l &>/dev/null; then
    CRON_JOBS=$(crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$' | wc -l)
    echo "📋 Active cron jobs: $CRON_JOBS"
else
    echo "⚠️  No crontab installed!"
    ((ISSUES++))
fi

# Summary
echo ""
echo "============================================"
if [ "$ISSUES" -eq 0 ]; then
    echo "✅ All cron jobs healthy — no issues found"
else
    echo "🚨 $ISSUES issue(s) found — review above for details"
fi
echo "$LOG_PREFIX Audit complete."
