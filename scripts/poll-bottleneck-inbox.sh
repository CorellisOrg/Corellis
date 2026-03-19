#!/bin/bash
# 🔍 Bottleneck Queue Poller — run every 5 minutes via cron
# Cron: */5 * * * * $(pwd)/scripts/poll-bottleneck-inbox.sh

LOBSTER_FARM_DIR="${LOBSTER_FARM_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
INBOX="$LOBSTER_FARM_DIR/bottleneck-inbox"
ARCHIVE="$INBOX/archived"
LOCKFILE="/tmp/bottleneck-poll.lock"

mkdir -p "$ARCHIVE"

exec 200>"$LOCKFILE"
flock -n 200 || exit 0

FILES=$(find "$INBOX" -maxdepth 1 -name "*.md" -type f 2>/dev/null)
COUNT=$(echo "$FILES" | grep -c '.' 2>/dev/null || echo 0)

if [ "$COUNT" -eq 0 ] || [ -z "$FILES" ]; then
    exit 0
fi

FILE_LIST=""
for f in $FILES; do
    fname=$(basename "$f")
    FILE_LIST="$FILE_LIST\n- $fname"
    mv "$f" "$ARCHIVE/"
done

openclaw agent -m "Bottleneck queue: $COUNT new report(s):$FILE_LIST\nFiles archived to $ARCHIVE/ — please review." --deliver --timeout 120 2>/dev/null || true
