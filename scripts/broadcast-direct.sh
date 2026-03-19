#!/bin/bash
# 🦞 Lobster Direct Broadcast (bypasses AI decision layer)
# Uses each lobster's Slack Bot Token to DM their owner directly
# Usage: direct-broadcast.sh "message"

FARM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGS_DIR="$FARM_DIR/configs"
MESSAGE="${1:-}"
NO_FOOTER="${2:-}"

if [ -z "$MESSAGE" ]; then
    echo "Usage: direct-broadcast.sh <message> [no-footer]"
    echo "  Pass a second arg to skip the default footer"
    exit 1
fi

echo "🦞 Lobster Direct Broadcast (Slack API)"
echo "━━━━━━━━━━━━━━━━━━━━"

SUCCESS=0
FAIL=0

for config_file in "$CONFIGS_DIR"/*/openclaw.json; do
    lobster_name=$(basename "$(dirname "$config_file")")

    eval $(python3 -c "
import json, os
with open('$config_file') as f:
    cfg = json.load(f)
token_val = cfg.get('channels',{}).get('slack',{}).get('botToken','')

# Resolve SecretRef: if botToken is a dict with 'id', read from secrets.json
if isinstance(token_val, dict) and 'id' in token_val:
    secret_key = token_val['id'].lstrip('/')
    secrets_file = os.path.join(os.path.dirname('$config_file'), 'secrets.json')
    try:
        with open(secrets_file) as sf:
            secrets = json.load(sf)
        token = secrets.get(secret_key, '')
    except:
        token = ''
elif isinstance(token_val, str):
    token = token_val
else:
    token = ''

owners = cfg.get('session',{}).get('identityLinks',{}).get('owner',[])
owner_id = ''
for o in owners:
    if o.startswith('slack:'):
        owner_id = o.replace('slack:','')
        break
if not owner_id:
    af = cfg.get('channels',{}).get('slack',{}).get('allowFrom',[])
    if af:
        owner_id = af[0]
print(f'BOT_TOKEN=\"{token}\"')
print(f'OWNER_ID=\"{owner_id}\"')
" 2>/dev/null)

    [ -z "$BOT_TOKEN" ] || [ -z "$OWNER_ID" ] && echo "⚠️ $lobster_name: missing config" && FAIL=$((FAIL+1)) && continue

    # Escape message for JSON
    JSON_MSG=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$MESSAGE")

    result=$(curl -s -X POST https://slack.com/api/chat.postMessage \
        -H "Authorization: Bearer $BOT_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"channel\":\"$OWNER_ID\",\"text\":$JSON_MSG,\"mrkdwn\":true}" 2>&1)

    ok=$(echo "$result" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('ok',''))" 2>/dev/null)

    if [ "$ok" = "True" ]; then
        echo "✅ $lobster_name → $OWNER_ID"
        SUCCESS=$((SUCCESS+1))
    else
        error=$(echo "$result" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('error','unknown'))" 2>/dev/null)
        echo "❌ $lobster_name: $error"
        FAIL=$((FAIL+1))
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━"
echo "Result: ✅ $SUCCESS ok | ❌ $FAIL failed"
