#!/usr/bin/env bash
# =============================================================================
# update-key.sh — Rotate a secret across controller + all lobsters
# =============================================================================
#
# Updates a key in secrets.json for the controller and all lobster configs,
# then restarts affected containers to pick up the change.
#
# Usage:
#   bash scripts/update-key.sh <KEY_NAME> <new-value>
#   bash scripts/update-key.sh --audit
#
# Examples:
#   bash scripts/update-key.sh BRAVE_API_KEY "sk-new-key-value"
#   bash scripts/update-key.sh --audit    # Show which keys exist where
#
# =============================================================================

set -euo pipefail

LOG_PREFIX="[update-key]"
FARM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGS_DIR="$FARM_DIR/configs"

# ---------------------------------------------------------------------------
# Audit mode: show key distribution across all lobsters
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--audit" ]; then
    echo "$LOG_PREFIX Secret distribution audit — $(date -u '+%Y-%m-%d %H:%M UTC')"
    echo "============================================"
    
    for config_dir in "$CONFIGS_DIR"/*/; do
        [ -d "$config_dir" ] || continue
        lobster=$(basename "$config_dir")
        secrets_file="$config_dir/secrets.json"
        
        if [ ! -f "$secrets_file" ]; then
            echo "⚠️  $lobster: no secrets.json"
            continue
        fi
        
        keys=$(jq -r 'keys[]' "$secrets_file" 2>/dev/null | sort | tr '\n' ', ' | sed 's/,$//')
        count=$(jq -r 'keys | length' "$secrets_file" 2>/dev/null || echo "?")
        perms=$(stat -c%a "$secrets_file" 2>/dev/null || echo "???")
        
        echo "📦 $lobster ($count keys, perms $perms): $keys"
    done
    
    echo ""
    echo "============================================"
    echo "$LOG_PREFIX Audit complete."
    exit 0
fi

# ---------------------------------------------------------------------------
# Update mode
# ---------------------------------------------------------------------------
KEY_NAME="${1:?Usage: $0 <KEY_NAME> <new-value> OR $0 --audit}"
NEW_VALUE="${2:?Missing new value. Usage: $0 <KEY_NAME> <new-value>}"

echo "$LOG_PREFIX Rotating '$KEY_NAME' across all lobsters..."

UPDATED=0
FAILED=0

for config_dir in "$CONFIGS_DIR"/*/; do
    [ -d "$config_dir" ] || continue
    lobster=$(basename "$config_dir")
    secrets_file="$config_dir/secrets.json"
    
    if [ ! -f "$secrets_file" ]; then
        echo "⚠️  $lobster: no secrets.json, skipping"
        continue
    fi
    
    # Update the key
    TMP=$(mktemp)
    if jq --arg key "$KEY_NAME" --arg val "$NEW_VALUE" '.[$key] = $val' \
       "$secrets_file" > "$TMP" 2>/dev/null; then
        mv "$TMP" "$secrets_file"
        chmod 600 "$secrets_file"
        echo "✅ $lobster: updated"
        ((UPDATED++))
    else
        rm -f "$TMP"
        echo "❌ $lobster: failed to update"
        ((FAILED++))
    fi
done

echo ""
echo "$LOG_PREFIX Updated $UPDATED lobster(s), $FAILED failed."

# Restart containers to pick up new secrets
if [ "$UPDATED" -gt 0 ]; then
    echo "$LOG_PREFIX Restarting affected containers..."
    COMPOSE_FILE="$FARM_DIR/docker-compose.yml"
    if [ -f "$COMPOSE_FILE" ]; then
        cd "$FARM_DIR"
        docker compose restart 2>&1 | tail -5
        echo "$LOG_PREFIX ✅ Containers restarted."
    else
        echo "$LOG_PREFIX ⚠️  No docker-compose.yml found. Restart containers manually."
    fi
fi
