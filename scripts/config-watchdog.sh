#!/bin/bash
# config-watchdog.sh - Configuration change watchdog (dead-man switch)
# Usage: ./config-watchdog.sh [timeout_seconds] [backup_file] [target]
# After starting, if no cancel signal is received within N seconds, auto-rollback config and restart
set -uo pipefail

TIMEOUT="${1:-120}"
BACKUP="${2:-}"
TARGET="${3:-master}"  # master or lobster name
CANCEL_FILE="/tmp/watchdog-cancel-$$"

if [[ -z "$BACKUP" ]]; then
  echo "Usage: $0 <timeout_seconds> <backup_file> [master|lobster-name]"
  exit 1
fi

if [[ ! -f "$BACKUP" ]]; then
  echo "ERROR: Backup file not found: $BACKUP"
  exit 1
fi

echo "🐕 Watchdog started"
echo "   Target: $TARGET"
echo "   Timeout: ${TIMEOUT}s"
echo "   Backup: $BACKUP"
echo "   Cancel: touch $CANCEL_FILE"
echo "   PID: $$"
echo ""

# Countdown
for ((i=TIMEOUT; i>0; i--)); do
  if [[ -f "$CANCEL_FILE" ]]; then
    echo "✅ Watchdog cancelled (received cancel signal)"
    rm -f "$CANCEL_FILE"
    exit 0
  fi
  
  # Report every 10 seconds
  if (( i % 10 == 0 )); then
    echo "⏳ ${i}s remaining..."
  fi
  sleep 1
done

echo ""
echo "⚠️ Timeout! No cancel signal received, starting rollback..."

if [[ "$TARGET" == "master" ]]; then
  CONFIG="$HOME/.openclaw/openclaw.json"
  echo "📋 Rolling back controller config..."
  sudo cp "$BACKUP" "$CONFIG"
  sudo chown ubuntu:ubuntu "$CONFIG"
  sudo chmod 600 "$CONFIG"
  
  # Try to restart gateway
  echo "🔄 Restarting Gateway..."
  openclaw gateway restart 2>/dev/null || true
  
  # Wait 10 seconds and check health
  sleep 10
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18789/health 2>/dev/null || echo "000")
  if [[ "$HTTP_CODE" == "200" ]]; then
    echo "✅ Rollback succeeded, Gateway healthy (HTTP 200)"
  else
    echo "❌ Gateway still unhealthy (HTTP $HTTP_CODE), attempting force restart..."
    pkill -f "openclaw" 2>/dev/null || true
    sleep 3
    cd $HOME/.openclaw && nohup openclaw gateway start > /dev/null 2>&1 &
    sleep 10
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18789/health 2>/dev/null || echo "000")
    echo "After force restart: HTTP $HTTP_CODE"
  fi
else
  CONFIG="$LOBSTER_FARM_DIR/configs/$TARGET/openclaw.json"
  echo "📋 Rolling back lobster $TARGET config..."
  cp "$BACKUP" "$CONFIG"
  
  echo "🔄 Restarting lobster gateway..."
  sudo docker exec "lobster-$TARGET" openclaw gateway restart 2>/dev/null || true
  
  sleep 10
  HTTP_CODE=$(sudo docker exec "lobster-$TARGET" curl -s -o /dev/null -w "%{http_code}" http://localhost:18789/health 2>/dev/null || echo "000")
  if [[ "$HTTP_CODE" == "200" ]]; then
    echo "✅ Rollback succeeded, lobster-$TARGET healthy (HTTP 200)"
  else
    echo "❌ Still unhealthy, attempting docker restart..."
    sudo docker restart "lobster-$TARGET"
    sleep 15
    HTTP_CODE=$(sudo docker exec "lobster-$TARGET" curl -s -o /dev/null -w "%{http_code}" http://localhost:18789/health 2>/dev/null || echo "000")
    echo "After docker restart: HTTP $HTTP_CODE"
  fi
fi

echo ""
echo "🐕 Watchdog complete."
