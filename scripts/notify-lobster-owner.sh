#!/bin/bash
# 🦞 Notify a lobster's owner via their lobster's bot
# Usage: ./notify-lobster-owner.sh <lobster-name> <message>
# Reads botToken + allowFrom from the lobster's openclaw.json

set -euo pipefail

NAME="${1:?Usage: $0 <lobster-name> <message>}"
MESSAGE="${2:?Missing message}"
CONTAINER="lobster-${NAME}"

# Extract botToken and owner Slack ID from container config
CONFIG=$(docker exec $CONTAINER node -e "
const cfg = JSON.parse(require('fs').readFileSync('/home/lobster/.openclaw/openclaw.json','utf8'));
const slack = cfg.channels?.slack || {};
const owner = (slack.allowFrom || [])[0] || '';
console.log(JSON.stringify({token: slack.botToken, owner: owner}));
" 2>/dev/null)

TOKEN=$(echo "$CONFIG" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));process.stdout.write(d.token||'')")
OWNER=$(echo "$CONFIG" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));process.stdout.write(d.owner||'')")

if [ -z "$TOKEN" ] || [ -z "$OWNER" ]; then
    echo "❌ Cannot find botToken or owner for $NAME"
    exit 1
fi

# Send DM via Slack API
RESPONSE=$(curl -s -X POST https://slack.com/api/chat.postMessage \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"channel\":\"$OWNER\",\"text\":\"$MESSAGE\"}")

OK=$(echo "$RESPONSE" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));process.stdout.write(String(d.ok))")

if [ "$OK" = "true" ]; then
    echo "✅ Notified $NAME's owner ($OWNER)"
else
    ERROR=$(echo "$RESPONSE" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));process.stdout.write(d.error||'unknown')")
    echo "❌ Failed to notify $NAME's owner: $ERROR"
    exit 1
fi
