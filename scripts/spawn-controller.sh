#!/bin/bash
# spawn-controller.sh - Create a controller lobster with Docker management capabilities
#
# The controller lobster runs inside Docker but can manage other containers via
# the Docker socket. It has read-write access to fleet configuration and can
# spawn, upgrade, and monitor other lobsters.
#
# Usage: ./spawn-controller.sh <name> <slack_user_id> <slack_bot_token> <slack_app_token>
# Example: ./spawn-controller.sh lilshell U0XXXXXXXXX xoxb-xxx xapp-xxx
#
# ⚠️  SECURITY NOTE:
#   The controller container gets access to the Docker socket (/var/run/docker.sock).
#   This is effectively root access to the host. Only use this in trusted environments.
#   For production setups with strict security requirements, run the controller on the
#   host instead (see docs/guides/host-controller-setup.md).

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${CYAN}[controller]${NC} $*"; }
ok()   { echo -e "${GREEN}✅ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
fail() { echo -e "${RED}❌ $*${NC}"; exit 1; }

NAME="${1:?Usage: $0 <name> <slack_user_id> <slack_bot_token> <slack_app_token>}"
SLACK_USER_ID="${2:?Missing slack_user_id}"
SLACK_BOT_TOKEN="${3:?Missing slack_bot_token}"
SLACK_APP_TOKEN="${4:?Missing slack_app_token}"

FARM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$FARM_DIR/.env" 2>/dev/null || true

COMPOSE_FILE="$FARM_DIR/docker-compose.yml"
CONFIG_DIR="$FARM_DIR/configs/$NAME"
SERVICE_NAME="lobster-$NAME"

# ── Safety checks ──

if [ -d "$CONFIG_DIR" ]; then
    fail "Lobster '$NAME' already exists at $CONFIG_DIR. Remove it first or choose a different name."
fi

if [ ! -S /var/run/docker.sock ]; then
    fail "Docker socket not found at /var/run/docker.sock. Is Docker running?"
fi

# ── Security warning ──
echo ""
warn "SECURITY: The controller container will have Docker socket access."
warn "This grants it effective root access to the host system."
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo ""
[[ $REPLY =~ ^[Yy]$ ]] || { log "Aborted."; exit 0; }

# ── Port allocation ──
LAST_PORT=$(grep -oP 'published: "\K\d+' "$COMPOSE_FILE" 2>/dev/null | sort -n | tail -1 || echo "18800")
NEXT_PORT=$((LAST_PORT + 1))
LAST_VNC=$(grep -oP 'published: "\K188[6-9]\d' "$COMPOSE_FILE" 2>/dev/null | sort -n | tail -1 || echo "18859")
NOVNC_PORT=$((LAST_VNC + 1))

GW_TOKEN=$(openssl rand -hex 24)

log "Spawning controller lobster '$NAME'..."
log "  Slack User: $SLACK_USER_ID"
log "  Gateway Port: $NEXT_PORT"
log "  noVNC Port: $NOVNC_PORT"

# ── Create config ──
mkdir -p "$CONFIG_DIR/workspace"

# Generate openclaw.json
cat > "$CONFIG_DIR/openclaw.json" << JSONEOF
{
  "env": {},
  "models": {
    "providers": {
      "amazon-bedrock": {
        "baseUrl": "https://bedrock-runtime.us-west-2.amazonaws.com",
        "auth": "aws-sdk",
        "api": "bedrock-converse-stream",
        "models": [
          {
            "id": "global.anthropic.claude-opus-4-6-v1",
            "name": "Claude Opus 4.6 (Bedrock)",
            "reasoning": true,
            "input": ["text", "image"],
            "cost": { "input": 0.015, "output": 0.075, "cacheRead": 0.0015, "cacheWrite": 0.01875 },
            "contextWindow": 200000,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": { "primary": "amazon-bedrock/global.anthropic.claude-opus-4-6-v1" },
      "compaction": { "mode": "safeguard" },
      "maxConcurrent": 2,
      "subagents": { "maxConcurrent": 4 }
    }
  },
  "session": {
    "dmScope": "per-peer",
    "identityLinks": { "owner": ["slack:${SLACK_USER_ID}"] }
  },
  "channels": {
    "slack": {
      "mode": "socket",
      "enabled": true,
      "botToken": "${SLACK_BOT_TOKEN}",
      "appToken": "${SLACK_APP_TOKEN}",
      "dmPolicy": "pairing",
      "allowFrom": ["${SLACK_USER_ID}"],
      "dm": { "enabled": true },
      "channels": { "*": { "allow": true, "requireMention": true } },
      "nativeStreaming": true,
      "streaming": "partial"
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "lan",
    "auth": { "mode": "token", "token": "${GW_TOKEN}" },
    "controlUi": { "dangerouslyAllowHostHeaderOriginFallback": true }
  },
  "acp": { "\$include": "./acp.json" },
  "tools": {
    "profile": "full",
    "sessions": { "visibility": "all" },
    "agentToAgent": { "enabled": true }
  },
  "plugins": {
    "entries": {
      "acpx": { "enabled": true, "config": { "permissionMode": "approve-all" } }
    }
  }
}
JSONEOF

# Copy ACP config from template
cp "$FARM_DIR/templates/acp.json" "$CONFIG_DIR/acp.json" 2>/dev/null || true

# Create empty secrets.json (lobsters store personal secrets here)
echo '{}' > "$CONFIG_DIR/secrets.json"
chmod 644 "$CONFIG_DIR/secrets.json"

# ── Controller-specific workspace files ──
cat > "$CONFIG_DIR/workspace/AGENTS.md" << 'AGENTSEOF'
# AGENTS.md — Controller Lobster

## Role
You are the **controller** of the Lobster Farm. You manage the fleet of lobster agents.

## Capabilities
You have Docker socket access and can:
- Spawn new lobsters (`/farm/scripts/spawn-lobster.sh`)
- View container status (`docker ps`, `docker logs`)
- Restart/stop lobsters (`docker compose -f /farm/docker-compose.yml restart/stop`)
- Run fleet management scripts in `/farm/scripts/`
- Edit shared configuration in `/farm/company-config/` (rw)
- Edit shared knowledge in `/shared/shared-knowledge.md`
- Monitor fleet health

## Farm Directory
The farm root is mounted at `/farm/`:
```
/farm/
├── configs/           ← Per-lobster configs (rw)
├── company-config/    ← Company policies (rw for you)
├── company-memory/    ← Company knowledge base
├── company-skills/    ← Shared skills
├── scripts/           ← Fleet management scripts
├── docker-compose.yml ← Container definitions
└── .env               ← Shared secrets
```

## Key Scripts
- `/farm/scripts/spawn-lobster.sh <name> <slack_id> <bot_token> <app_token>`
- `/farm/scripts/rolling-upgrade.sh` — Upgrade all lobsters
- `/farm/scripts/backup-lobsters.sh` — Backup all data
- `/farm/scripts/health-check.sh` — Check fleet health
- `/farm/scripts/broadcast.sh <message>` — Broadcast to all lobsters
- `/farm/scripts/sync-company-skills.sh` — Sync skills to all lobsters

## Rules
- Always confirm with the owner before destructive operations (stop, remove)
- Log important fleet changes to your MEMORY.md
- Keep company-config/ and company-skills/ organized
AGENTSEOF

cat > "$CONFIG_DIR/workspace/SOUL.md" << 'MDEOF'
# SOUL.md - Controller Personality

You are the controller lobster 🦞🎛️ — the fleet manager.

## Core Principles
- Keep the fleet running smoothly
- Be proactive about health monitoring
- Escalate issues early, fix them fast
- Document everything important

## Style
- Concise, operational, reliable
- Communicate in the user's preferred language
MDEOF

cat > "$CONFIG_DIR/workspace/USER.md" << MDEOF
# USER.md - About the Fleet Owner

- **Slack ID**: ${SLACK_USER_ID}
- **Role**: Fleet owner / administrator
MDEOF

cat > "$CONFIG_DIR/workspace/MEMORY.md" << 'MDEOF'
# MEMORY.md - Controller Memory

> Fleet state and operational history.

---

_Controller initialized. Waiting for first fleet operation..._
MDEOF

# ── Append controller service to docker-compose.yml ──
sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$COMPOSE_FILE"

cat >> "$COMPOSE_FILE" << YAMLEOF

  ${SERVICE_NAME}:
    image: lobster-openclaw:latest
    container_name: ${SERVICE_NAME}
    restart: unless-stopped
    ports:
      - published: "${NEXT_PORT}"
        target: "18789"
      - published: "${NOVNC_PORT}"
        target: "6080"
    volumes:
      # --- Standard lobster mounts ---
      - ${SERVICE_NAME}-data:/home/lobster/.openclaw
      - ./configs/${NAME}/openclaw.json:/home/lobster/.openclaw/openclaw.json:ro
      - ./configs/${NAME}/secrets.json:/home/lobster/.openclaw/secrets.json:ro
      - ./configs/${NAME}/acp.json:/home/lobster/.openclaw/acp.json:ro
      - ./configs/${NAME}/workspace:/home/lobster/.openclaw/workspace
      - ./company-memory:/shared/company:ro
      - ./company-skills:/home/lobster/.openclaw/workspace/company-skills:ro
      - ./bottleneck-inbox:/shared/bottleneck-inbox
      - ./skill-submissions:/shared/skill-submissions
      # --- Controller-specific mounts ---
      - /var/run/docker.sock:/var/run/docker.sock
      - .:/farm
      - ./company-config:/shared/company-config
    env_file:
      - .env
    environment:
      - HOME=/home/lobster
      - LOBSTER_ROLE=controller
    tty: true
    mem_limit: 3g
    shm_size: 512m
    cpus: 1.5
YAMLEOF

# Add volume declaration
if grep -q "^volumes:" "$COMPOSE_FILE"; then
    sed -i "/^volumes:/a\\  ${SERVICE_NAME}-data:" "$COMPOSE_FILE"
else
    cat >> "$COMPOSE_FILE" << YAMLEOF

volumes:
  ${SERVICE_NAME}-data:
YAMLEOF
fi

chmod 644 "$CONFIG_DIR/openclaw.json"

# ── Done ──
echo ""
ok "Controller lobster '$NAME' created!"
echo ""
echo "   Config:       $CONFIG_DIR/"
echo "   Gateway Port: $NEXT_PORT"
echo "   noVNC Port:   $NOVNC_PORT"
echo "   Service:      $SERVICE_NAME"
echo ""
echo -e "${YELLOW}Key differences from regular lobsters:${NC}"
echo "   🔌 Docker socket mounted → can manage containers"
echo "   📁 Farm directory at /farm/ → full access to repo & configs"
echo "   📝 company-config/ is rw → can update fleet policies"
echo "   🏷️  LOBSTER_ROLE=controller env var set"
echo ""
log "Starting..."

cd "$FARM_DIR"
docker compose up -d "$SERVICE_NAME" 2>&1

echo ""
echo "⏳ Gateway takes ~90 seconds to fully start."
echo "   Check status: docker logs $SERVICE_NAME"

# Sync company skills
echo ""
log "Syncing company skills..."
sleep 5
bash "$(dirname "$0")/sync-company-skills.sh" "$NAME" 2>&1 || true

echo ""
ok "Controller is ready! The lobster at $SERVICE_NAME can now manage the fleet."
