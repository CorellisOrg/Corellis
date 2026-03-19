#!/bin/bash
# 🔍 Daily Bottleneck Scanner — run once daily (e.g., 04:00 UTC)
# Cron: 0 4 * * * $(pwd)/scripts/scan-bottlenecks.sh

LOBSTER_FARM_DIR="${LOBSTER_FARM_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
YESTERDAY=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)
OUTPUT_DIR="$LOBSTER_FARM_DIR/bottleneck-inbox"
mkdir -p "$OUTPUT_DIR"

echo "🔍 Scanning date: $YESTERDAY"
FOUND=0

for container in $(docker ps --format '{{.Names}}' | grep '^lobster-'); do
    lobster_name="${container#lobster-}"
    files=$(docker exec "$container" find ${OPENCLAW_WORKSPACE:-~/.openclaw/workspace}/bottlenecks/ \
        -name "${YESTERDAY}*" -type f 2>/dev/null || true)
    if [ -n "$files" ]; then
        for f in $files; do
            fname=$(basename "$f")
            dest="${OUTPUT_DIR}/${lobster_name}-${fname}"
            docker cp "${container}:${f}" "$dest" 2>/dev/null \
                && echo "📄 ${lobster_name}: ${fname}" \
                && FOUND=$((FOUND+1))
        done
    fi
done

echo "=== Found $FOUND bottleneck file(s) ==="

if [ "$FOUND" -gt 0 ]; then
    openclaw agent -m "Daily scan: $FOUND bottleneck(s) from $YESTERDAY in $OUTPUT_DIR. Please review." \
        --deliver --timeout 120 2>/dev/null || true
fi
