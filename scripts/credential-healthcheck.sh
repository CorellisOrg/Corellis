#!/bin/bash
# credential-healthcheck.sh - Credential health check + auto fallback
# Runs via system crontab every 5 minutes, no AI dependency

set -uo pipefail

CRED_FILE="$LOBSTER_FARM_DIR/credentials.json"
STATE_FILE="/tmp/credential-healthcheck-state"
SWITCH_SCRIPT="$LOBSTER_FARM_DIR/scripts/credential-healthcheck.sh"
LOG_FILE="/var/log/credential-healthcheck.log"

# Log rotation: truncate to last 500 lines when over 1MB
if [[ -f "$LOG_FILE" ]] && [[ $(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt 1048576 ]]; then
  tail -500 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi

log() { echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $*" >> "$LOG_FILE"; }

CURRENT=$(jq -r .current "$CRED_FILE")
FALLBACK=$(jq -r .fallback "$CRED_FILE")

# If already on fallback, no need to check
if [[ "$CURRENT" == "$FALLBACK" ]]; then
  exit 0
fi

# Read current credentials
AK=$(jq -r ".profiles.${CURRENT}.AWS_ACCESS_KEY_ID" "$CRED_FILE")
SK=$(jq -r ".profiles.${CURRENT}.AWS_SECRET_ACCESS_KEY" "$CRED_FILE")
REGION=$(jq -r ".profiles.${CURRENT}.AWS_REGION" "$CRED_FILE")

MODEL="global.anthropic.claude-opus-4-6-v1"
ERR_FILE="/tmp/healthcheck-err.txt"
RESP_FILE="/tmp/healthcheck-response.json"
START_TS=$(date +%s%3N 2>/dev/null || date +%s)

# Use converse API (more stable than invoke-model, no anthropic_version dependency)
HTTP_CODE=$(AWS_ACCESS_KEY_ID="$AK" AWS_SECRET_ACCESS_KEY="$SK" AWS_DEFAULT_REGION="$REGION" \
  aws bedrock-runtime converse \
    --model-id "$MODEL" \
    --messages '[{"role":"user","content":[{"text":"ping"}]}]' \
    --inference-config '{"maxTokens":1}' \
    --output json \
    2>"$ERR_FILE" > "$RESP_FILE" && echo "200" || echo "FAIL")

END_TS=$(date +%s%3N 2>/dev/null || date +%s)
DURATION=$((END_TS - START_TS))

if [[ "$HTTP_CODE" == "200" ]]; then
  # Success - check if recovering from failure
  if [[ -f "$STATE_FILE" ]]; then
    PREV_COUNT=$(cat "$STATE_FILE")
    rm -f "$STATE_FILE"
    log "✅ RECOVERED after $PREV_COUNT failure(s). profile=$CURRENT region=$REGION latency=${DURATION}ms"
  fi
  exit 0
fi

# === FAILURE — log details ===
FAIL_COUNT=0
if [[ -f "$STATE_FILE" ]]; then
  FAIL_COUNT=$(cat "$STATE_FILE")
fi
FAIL_COUNT=$((FAIL_COUNT + 1))
echo "$FAIL_COUNT" > "$STATE_FILE"

ERR_FULL=$(cat "$ERR_FILE" 2>/dev/null | head -20)
RESP_BODY=$(cat "$RESP_FILE" 2>/dev/null | head -5)

log "❌ FAILED profile=$CURRENT attempt=$FAIL_COUNT region=$REGION model=$MODEL latency=${DURATION}ms"
log "   stderr: $ERR_FULL"
if [[ -n "$RESP_BODY" ]]; then
  log "   response: $RESP_BODY"
fi

if [[ "$FAIL_COUNT" -ge 2 ]]; then
  log "🔄 FALLBACK TRIGGERED: $CURRENT → $FALLBACK (after $FAIL_COUNT consecutive failures)"
  
  "$SWITCH_SCRIPT" "$FALLBACK" >> "$LOG_FILE" 2>&1
  rm -f "$STATE_FILE"
  
  LABEL=$(jq -r ".profiles.${CURRENT}.label" "$CRED_FILE")
  BOT_TOKEN=$(jq -r '.channels.slack.botToken // empty' $HOME/.openclaw/openclaw.json)
  OWNER_CHANNEL="DXXXXXXXXXX"
  ERR_SUMMARY=$(echo "$ERR_FULL" | head -2 | tr '\n' ' ' | cut -c1-200 | sed 's/"/\\"/g')
  
  if [[ -n "$BOT_TOKEN" ]]; then
    curl -s -X POST https://slack.com/api/chat.postMessage \
      -H "Authorization: Bearer $BOT_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"channel\":\"$OWNER_CHANNEL\",\"text\":\"⚠️ Credential auto-fallback notification\\n\\n'${LABEL}' credential failed health check ${FAIL_COUNT} consecutive times, automatically switched back to stable credentials.\\n\\nError: ${ERR_SUMMARY}\\nLatency: ${DURATION}ms\\n\\nDetailed log: /var/log/credential-healthcheck.log\\nTo switch again, just let me know.\"}" \
      >> "$LOG_FILE" 2>&1
  fi
  
  log "Fallback complete."
fi
