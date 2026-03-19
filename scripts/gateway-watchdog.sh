#!/bin/bash
# Gateway Watchdog - runs via system cron every 5 minutes
# Checks if openclaw gateway is healthy, attempts fix + restart if not
#
# Setup (host crontab):
#   */5 * * * * $(pwd)/scripts/gateway-watchdog.sh
#
# For lobsters (container crontab):
#   */5 * * * * docker exec lobster-<name> $(pwd)/scripts/gateway-watchdog.sh

LOG="/tmp/gateway-watchdog.log"
CONFIG="$HOME/.openclaw/openclaw.json"
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

SECRETS="$HOME/.openclaw/secrets.json"

fix_config() {
    local changed=0

    # Fix cron array -> delete it (known bad pattern)
    if jq -e '(.cron | type) == "array"' "$CONFIG" &>/dev/null; then
        echo "[$TIMESTAMP] Removing invalid cron array from config" >> "$LOG"
        jq 'del(.cron)' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
        changed=1
    fi

    # Fix env secret references (objects that should be strings)
    if [ -f "$SECRETS" ] && jq -e '.env | to_entries[] | select(.value | type == "object")' "$CONFIG" &>/dev/null; then
        echo "[$TIMESTAMP] Restoring env string values from secrets.json" >> "$LOG"
        jq --slurpfile s "$SECRETS" '
          .env = (.env | to_entries | map(
            if (.value | type) == "object" then .value = ($s[0][.key] // .value) else . end
          ) | from_entries) |
          if (.gateway.auth.token | type) == "object" then .gateway.auth.token = $s[0]["GATEWAY_AUTH_TOKEN"] else . end |
          if (.channels.telegram.botToken | type) == "object" then .channels.telegram.botToken = $s[0]["TELEGRAM_BOT_TOKEN"] else . end |
          if (.channels.slack.botToken | type) == "object" then .channels.slack.botToken = $s[0]["SLACK_BOT_TOKEN"] else . end |
          if (.channels.slack.appToken | type) == "object" then .channels.slack.appToken = $s[0]["SLACK_APP_TOKEN"] else . end
        ' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
        changed=1
    fi

    return $changed
}

# Detect restart method (systemctl vs openclaw cli vs docker)
restart_gateway() {
    if systemctl --user is-active openclaw-gateway.service &>/dev/null 2>&1; then
        systemctl --user restart openclaw-gateway.service >> "$LOG" 2>&1
    elif command -v openclaw &>/dev/null; then
        openclaw gateway restart >> "$LOG" 2>&1
    else
        echo "[$TIMESTAMP] Cannot find restart method" >> "$LOG"
        return 1
    fi
}

# Check if gateway process is running
GATEWAY_PID=$(pgrep -f "openclaw.*gateway" 2>/dev/null || true)
SYSTEMD_ACTIVE=$(systemctl --user is-active openclaw-gateway.service 2>/dev/null || echo "unknown")

if [ -z "$GATEWAY_PID" ] && [ "$SYSTEMD_ACTIVE" != "active" ]; then
    echo "[$TIMESTAMP] Gateway DOWN - attempting restart" >> "$LOG"
    fix_config
    openclaw doctor --fix >> "$LOG" 2>&1 || true
    fix_config
    restart_gateway
    echo "[$TIMESTAMP] Restart triggered" >> "$LOG"
    exit 0
fi

# Process is running - check if it responds (HTTP health check)
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://127.0.0.1:18789/__openclaw__/health 2>/dev/null)
if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "401" ] && [ "$HTTP_CODE" != "403" ]; then
    echo "[$TIMESTAMP] Gateway UNRESPONSIVE (HTTP $HTTP_CODE) - attempting fix + restart" >> "$LOG"
    fix_config
    openclaw doctor --fix >> "$LOG" 2>&1 || true
    fix_config
    restart_gateway
    echo "[$TIMESTAMP] Restart triggered after unresponsive" >> "$LOG"
    exit 0
fi

# Even when healthy, proactively clean known bad patterns
fix_config
