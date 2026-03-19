#!/bin/bash
# 🦞 Lobster broadcast script
# Sends a message to all (or specified) running lobsters, which then DM their respective owners
#
# Usage:
#   broadcast.sh "message content"                  # Broadcast to all lobsters
#   broadcast.sh "message content" alice bob         # Send to specific lobsters only

FARM_DIR="$LOBSTER_FARM_DIR"
CONFIGS_DIR="$FARM_DIR/configs"

MESSAGE="${1:-}"
shift 2>/dev/null || true
TARGETS=("$@")

if [ -z "$MESSAGE" ]; then
    echo "Usage: broadcast.sh <message> [lobster1 lobster2 ...]"
    exit 1
fi

echo "🦞 Lobster Broadcast"
echo "━━━━━━━━━━━━━━━━━━━━"
echo "Message: $MESSAGE"
echo ""

SUCCESS=0
FAIL=0
TOTAL=0

# Get all running lobster container names
CONTAINERS=$(cd "$FARM_DIR" && docker compose ps --status running --format '{{.Name}}' 2>/dev/null | grep "^lobster-" || true)

if [ -z "$CONTAINERS" ]; then
    echo "No running lobster containers found"
    exit 0
fi

for container in $CONTAINERS; do
    lobster_name="${container#lobster-}"
    
    # Filter by targets if specified
    if [ ${#TARGETS[@]} -gt 0 ]; then
        MATCH=false
        for t in "${TARGETS[@]}"; do
            [ "$t" == "$lobster_name" ] && MATCH=true && break
        done
        [ "$MATCH" != "true" ] && continue
    fi
    
    TOTAL=$((TOTAL + 1))
    
    # Read owner's Slack User ID from openclaw.json
    config_file="$CONFIGS_DIR/$lobster_name/openclaw.json"
    if [ ! -f "$config_file" ]; then
        echo "  ⚠️  $lobster_name: config file not found, skipping"
        FAIL=$((FAIL + 1))
        continue
    fi
    
    owner_id=$(python3 -c "
import json
with open('$config_file') as f:
    cfg = json.load(f)
owners = cfg.get('session',{}).get('identityLinks',{}).get('owner',[])
for o in owners:
    if o.startswith('slack:'):
        print(o)
        break
" 2>/dev/null)
    
    if [ -z "$owner_id" ]; then
        echo "  ⚠️  $lobster_name: could not get owner Slack ID, skipping"
        FAIL=$((FAIL + 1))
        continue
    fi
    
    echo "  📡 $lobster_name → $owner_id ..."
    
    # Write message to temp file to avoid quote escaping issues
    TMPFILE=$(mktemp)
    echo "$MESSAGE" > "$TMPFILE"
    MSG_ESCAPED=$(python3 -c "import sys; print(open(sys.argv[1]).read().strip())" "$TMPFILE")
    rm -f "$TMPFILE"
    
    # Send via docker exec calling openclaw agent
    result=$(docker exec $container openclaw agent --to '$owner_id' --message \"$MSG_ESCAPED\" --deliver --timeout 120 --json 2>&1) || true
    
    # Check result
    status=$(echo "$result" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('status',''))" 2>/dev/null || echo "")
    
    if [ "$status" = "ok" ]; then
        reply=$(echo "$result" | python3 -c "
import sys,json
d=json.loads(sys.stdin.read())
payloads = d.get('result',{}).get('payloads',[])
if payloads:
    t = payloads[0].get('text','(no reply)')
    print(t[:80])
else:
    print('(no reply)')
" 2>/dev/null || echo "(parse failed)")
        echo "  ✅ $lobster_name: $reply"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "  ❌ $lobster_name: send failed"
        echo "     $(echo "$result" | head -2)"
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━"
echo "Result: scanned $TOTAL lobsters | ✅ $SUCCESS succeeded | ❌ $FAIL failed"
