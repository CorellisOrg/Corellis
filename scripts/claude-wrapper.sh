#!/bin/bash
# claude-wrapper: wraps real claude to capture usage data
# Logs result events with total_cost_usd to /shared/cc-usage-logs/<lobster>.jsonl

REAL_CLAUDE="/usr/local/bin/claude-real"
LOBSTER_NAME="${LOBSTER_NAME:-unknown}"
LOG_FILE="/shared/cc-usage-logs/${LOBSTER_NAME}.jsonl"

mkdir -p /shared/cc-usage-logs 2>/dev/null

# Use a temp file to capture output, then process after exit
TMPOUT=$(mktemp)
trap "rm -f $TMPOUT" EXIT

# Run real claude, tee output to both stdout and temp file
"$REAL_CLAUDE" "$@" | tee "$TMPOUT"
EXIT_CODE=${PIPESTATUS[0]}

# Extract result events with cost data and log them
grep '"total_cost_usd"' "$TMPOUT" | while IFS= read -r line; do
    echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"lobster\":\"${LOBSTER_NAME}\",\"event\":${line}}" >> "$LOG_FILE"
done

exit $EXIT_CODE
