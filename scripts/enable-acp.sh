#!/bin/bash
set -e

NAME="$1"
if [ -z "$NAME" ]; then
    echo "Usage: $0 <lobster-name>"
    exit 1
fi

CONFIG="$LOBSTER_FARM_DIR/configs/$NAME/openclaw.json"
COMPOSE="$LOBSTER_FARM_DIR/docker-compose.yml"
CONTAINER="lobster-$NAME"

if [ ! -f "$CONFIG" ]; then echo "❌ Config not found: $CONFIG"; exit 1; fi

# Step 1: Add $include to openclaw.json
echo "🔧 Adding ACP \$include to openclaw.json..."
python3 -c "
import json
with open('$CONFIG') as f: cfg = json.load(f)
cfg['acp'] = {'\$include': './acp.json'}
with open('$CONFIG', 'w') as f: json.dump(cfg, f, indent=2)
print('  ✅ acp.\$include -> ./acp.json')
"

# Step 2: Create acp.json in volume
echo "🔧 Creating acp.json in volume..."
ACP_JSON='{"enabled":true,"dispatch":{"enabled":true},"backend":"acpx","defaultAgent":"claude","allowedAgents":["claude"],"maxConcurrentSessions":2}'
docker exec $CONTAINER sh -c \"echo '$ACP_JSON' > /home/lobster/.openclaw/acp.json && chown lobster:lobster /home/lobster/.openclaw/acp.json\" 2>/dev/null && echo "  ✅ acp.json created" || {
    echo "  ⚠️  Container not running, writing to volume directly..."
    VOLUME_PATH=$(docker volume inspect ${CONTAINER}-data --format '{{.Mountpoint}}' 2>/dev/null)
    if [ -n "$VOLUME_PATH" ]; then
        echo "$ACP_JSON" | sudo tee "$VOLUME_PATH/acp.json" > /dev/null
        sudo chown 1000:1000 "$VOLUME_PATH/acp.json"
        echo "  ✅ Written to volume"
    else
        echo "  ❌ Cannot find volume"; exit 1
    fi
}

# Step 3: Bump memory to 3G
echo "🔧 Bumping memory to 3G..."
sed -i "/lobster-$NAME:/,/lobster-/{s/mem_limit: 2g/mem_limit: 3g/}" "$COMPOSE"
echo "  ✅ Memory: 3G"

# Step 4: Add CLAUDE_CODE_USE_BEDROCK=1
echo "🔧 Adding CLAUDE_CODE_USE_BEDROCK=1..."
if grep -A 30 "lobster-$NAME:" "$COMPOSE" | grep -q "CLAUDE_CODE_USE_BEDROCK"; then
    echo "  ⚠️  Already has it"
else
    sed -i "/lobster-$NAME:/,/lobster-/{/env_file:/a\\      - CLAUDE_CODE_USE_BEDROCK=1" "$COMPOSE"
    echo "  ✅ Added"
fi

# Step 5: Ensure openclaw.json is :ro
if grep -A 30 "lobster-$NAME:" "$COMPOSE" | grep "openclaw.json" | grep -q ":ro"; then
    echo "  ✅ openclaw.json already :ro"
else
    sed -i "/lobster-$NAME:/,/lobster-/{s|openclaw.json:/home/lobster/.openclaw/openclaw.json$|openclaw.json:/home/lobster/.openclaw/openclaw.json:ro|}" "$COMPOSE"
    echo "  ✅ Added :ro"
fi

# Step 6: Restart
echo "🔧 Restarting..."
cd $LOBSTER_FARM_DIR
docker compose up -d $CONTAINER 2>&1

echo ""
echo "🦞 Claude Code enabled for $NAME!"
echo "   Gateway needs ~5-8 min to fully start with ACP."
