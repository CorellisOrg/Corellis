#!/bin/bash
# spawn-lobster.sh - Create a new lobster instance
# Usage: ./spawn-lobster.sh <name> <slack_user_id> <slack_bot_token> <slack_app_token>
#
# Example: ./spawn-lobster.sh alice U0XXXXXXXXX xoxb-xxx xapp-xxx

set -euo pipefail

NAME="${1:?Usage: $0 <name> <slack_user_id> <slack_bot_token> <slack_app_token>}"
SLACK_USER_ID="${2:?Missing slack_user_id}"
SLACK_BOT_TOKEN="${3:?Missing slack_bot_token}"
SLACK_APP_TOKEN="${4:?Missing slack_app_token}"

FARM_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Load shared env (API keys)
source "$FARM_DIR/.env" 2>/dev/null || true
COMPOSE_FILE="$FARM_DIR/docker-compose.yml"
CONFIG_DIR="$FARM_DIR/configs/$NAME"
SERVICE_NAME="lobster-$NAME"

# Check if already exists
if [ -d "$CONFIG_DIR" ]; then
    echo "❌ Lobster '$NAME' already exists at $CONFIG_DIR"
    exit 1
fi

# Find next available port
# Find next available noVNC port (start from 18860)
NOVNC_PORT=18860
while grep -q "published: \"${NOVNC_PORT}\"" "$COMPOSE_FILE" 2>/dev/null; do
    NOVNC_PORT=$((NOVNC_PORT + 1))
done
LAST_PORT=$(grep -oP 'published: "\K\d+' "$COMPOSE_FILE" 2>/dev/null | sort -n | tail -1 || echo "18800")
NEXT_PORT=$((LAST_PORT + 1))

# Find next available noVNC port (start from 18860)
LAST_VNC=$(grep -oP 'published: "\K188[6-9]\d' "$COMPOSE_FILE" 2>/dev/null | sort -n | tail -1 || echo "18859")
NOVNC_PORT=$((LAST_VNC + 1))

# Generate random gateway token
GW_TOKEN=$(openssl rand -hex 24)

echo "🦞 Spawning lobster '$NAME'..."
echo "   Slack User: $SLACK_USER_ID"
echo "   Gateway Port: $NEXT_PORT"
echo "   noVNC Port: $NOVNC_PORT"

# Create config directory
mkdir -p "$CONFIG_DIR/workspace"

# Generate openclaw.json — all lessons learned baked in:
# - dmPolicy: "pairing" (not "open" — conflicts with allowFrom)
# - controlUi.dangerouslyAllowHostHeaderOriginFallback: true (needed for non-loopback bind)
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
            "cost": {
              "input": 0.015,
              "output": 0.075,
              "cacheRead": 0.0015,
              "cacheWrite": 0.01875
            },
            "contextWindow": 200000,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "amazon-bedrock/global.anthropic.claude-opus-4-6-v1"
      },
      "compaction": {
        "mode": "safeguard"
      },
      "maxConcurrent": 2,
      "subagents": {
        "maxConcurrent": 4
      }
    }
  },
  "session": {
    "dmScope": "per-peer",
    "identityLinks": {
      "owner": [
        "slack:${SLACK_USER_ID}"
      ]
    }
  },
  "channels": {
    "slack": {
      "mode": "socket",
      "enabled": true,
      "botToken": "${SLACK_BOT_TOKEN}",
      "appToken": "${SLACK_APP_TOKEN}",
      "dmPolicy": "pairing",
      "allowFrom": ["${SLACK_USER_ID}"],
      "dm": {
        "enabled": true
      },
      "channels": {
        "*": {
          "allow": true,
          "requireMention": true
        }
      },
      "nativeStreaming": true,
      "streaming": "partial"
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "lan",
    "auth": {
      "mode": "token",
      "token": "${GW_TOKEN}"
    },
    "controlUi": {
      "dangerouslyAllowHostHeaderOriginFallback": true
    }
  },
  "talk": {
    "provider": "elevenlabs",
    "providers": {
      "elevenlabs": {
        "apiKey": "${ELEVENLABS_API_KEY:-}"
      }
    }
  },
  "acp": {
    "\$include": "./acp.json"
  },
  "tools": {
    "profile": "full",
    "sessions": {
      "visibility": "all"
    },
    "agentToAgent": {
      "enabled": true
    }
  },
  "plugins": {
    "entries": {
      "acpx": {
        "enabled": true,
        "config": {
          "permissionMode": "approve-all"
        }
      }
    }
  }
}
JSONEOF

# Copy ACP config from template
cp "$FARM_DIR/templates/acp.json" "$CONFIG_DIR/acp.json"

# Create empty secrets.json (lobsters store personal secrets here)
echo '{}' > "$CONFIG_DIR/secrets.json"
chmod 644 "$CONFIG_DIR/secrets.json"

# Generate workspace files — use full template
# Generate AGENTS.md inline
cat > "$CONFIG_DIR/workspace/AGENTS.md" << 'AGENTSEOF'
# AGENTS.md

You are a lobster in a team. Follow your SOUL.md personality and company policies.
AGENTSEOF

cat > "$CONFIG_DIR/workspace/SOUL.md" << 'MDEOF'
# SOUL.md - Lobster Personality

You are a friendly, efficient personal AI assistant lobster 🦞

## Core Principles
- Be directly useful, skip the fluff
- Have your own opinions and personality
- Try to solve problems first, ask only if stuck
- Remember what matters

## Style
- Concise, professional, occasionally humorous
- Communicate in the user's preferred language
MDEOF

cat > "$CONFIG_DIR/workspace/USER.md" << MDEOF
# USER.md - About Your Owner

- **Slack ID**: ${SLACK_USER_ID}
- **Note**: Get to know your owner during the first conversation
MDEOF

cat > "$CONFIG_DIR/workspace/MEMORY.md" << 'MDEOF'
# MEMORY.md - Long-term Memory

> Record important things here. Read at the start of each session.

---

_Waiting for first conversation..._
MDEOF

# Create mcporter config with company MCP servers
mkdir -p "$CONFIG_DIR/workspace/config"
cat > "$CONFIG_DIR/workspace/config/mcporter.json" << 'MCPEOF'
{
  "mcpServers": {
    "your-mcp-server": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "https://your-mcp-server.example.com/mcp",
        "--header",
        "Authorization: Bearer YOUR_MCP_API_KEY_HERE"
      ],
      "env": {}
    }
  }
}
MCPEOF

# Append service to docker-compose.yml (before the final volumes: section if it exists)
# We need to insert into the services: block properly
# Strategy: append the service definition, then the volume declaration

# Remove trailing empty lines from compose file
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
      - ${SERVICE_NAME}-data:/home/lobster/.openclaw
      - ./configs/${NAME}/openclaw.json:/home/lobster/.openclaw/openclaw.json:ro
      - ./configs/${NAME}/secrets.json:/home/lobster/.openclaw/secrets.json:ro
      - ./configs/${NAME}/acp.json:/home/lobster/.openclaw/acp.json:ro
      - ./configs/${NAME}/workspace:/home/lobster/.openclaw/workspace
      - ./company-memory:/shared/company:ro
      - ./company-skills:/home/lobster/.openclaw/workspace/company-skills:ro
      - ./bottleneck-inbox:/shared/bottleneck-inbox
      - ./skill-submissions:/shared/skill-submissions
      - ./company-config:/shared/company-config:ro
      - ./shared-knowledge.md:/shared/shared-knowledge.md
      - /data/go-mod-cache:/usr/local/go-tools/pkg/mod
      - /data/go-build-cache:/home/lobster/.cache/go-build
    env_file:
      - .env
    environment:
      - HOME=/home/lobster
    tty: true
    mem_limit: 2g
    shm_size: 512m
    cpus: 0.5
YAMLEOF

# Add the volume declaration to the top-level volumes: section
# Check if volumes: section exists at the top level
if grep -q "^volumes:" "$COMPOSE_FILE"; then
    # Append under existing volumes: section
    sed -i "/^volumes:/a\\  ${SERVICE_NAME}-data:" "$COMPOSE_FILE"
else
    # Create volumes: section
    cat >> "$COMPOSE_FILE" << YAMLEOF

volumes:
  ${SERVICE_NAME}-data:
YAMLEOF
fi

# Fix config file permissions (must be readable by lobster user UID 1001)
chmod 644 "$CONFIG_DIR/openclaw.json"

echo ""
echo "✅ Lobster '$NAME' created!"
echo "   Config: $CONFIG_DIR/"
echo "   Gateway Port: $NEXT_PORT"
echo "   noVNC Port: $NOVNC_PORT"
echo "   Service: $SERVICE_NAME"
echo ""
echo "🚀 Starting..."

# Auto-start
cd "$FARM_DIR"
docker compose up -d $SERVICE_NAME 2>&1

echo ""
echo "⏳ Gateway takes ~90 seconds to fully start."
echo "   Check status: docker logs $SERVICE_NAME"

# Sync company skills as symlinks into workspace/skills/
echo ""
echo "🔗 Syncing company skills..."
sleep 5  # wait for container to be ready
bash "$(dirname "$0")/sync-company-skills.sh" "$NAME" 2>&1
