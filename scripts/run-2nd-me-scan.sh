#!/bin/bash
# run-2nd-me-scan.sh — Trigger daily self-improvement scan on a lobster.
#
# Runs inside a lobster container via `docker exec`. The lobster will:
# 1. Review recent .learnings/ entries
# 2. Promote patterns to MEMORY.md / AGENTS.md
# 3. Archive old entries
# 4. Update daily log
#
# Usage:
#   # Single lobster
#   docker exec lobster-alice bash /shared/scripts/run-2nd-me-scan.sh
#
#   # All lobsters (from host)
#   for c in $(docker ps --filter "name=lobster-" --format '{{.Names}}'); do
#     echo "🧬 Scanning $c..."
#     docker exec "$c" bash /shared/scripts/run-2nd-me-scan.sh &
#   done
#   wait
#
# Recommended cron (on host):
#   0 4 * * * $(pwd)/scripts/trigger-2nd-me-all.sh >> /tmp/2nd-me-scan.log 2>&1

set -euo pipefail

exec openclaw agent \
  --session-id isolated \
  --timeout 600 \
  --message "[2nd-me-daily-scan] This is a scheduled daily self-improvement scan (cron). Review your .learnings/ directory: promote validated lessons to MEMORY.md, archive old entries, check for repeated patterns. Do NOT message your owner (silent mode)."
