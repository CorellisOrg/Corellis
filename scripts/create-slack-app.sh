#!/usr/bin/env bash
# Create a Slack App for a new lobster using Manifest API + guide admin through install
# Usage: ./create-slack-app.sh <name>
#
# Flow:
#   1. Auto-creates Slack app via manifest API (scopes, events, socket mode all pre-configured)
#   2. Outputs install link → admin clicks "Allow" 
#   3. Admin goes to app settings to get bot token (xoxb-) and create app token (xapp-)
#   4. Admin provides tokens → spawn-lobster.sh completes the setup
#
# Requires: .slack-config-tokens.json in project root (config token + refresh token)
set -euo pipefail

NAME="${1:?Usage: $0 <name>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FARM_DIR="$(dirname "$SCRIPT_DIR")"
TOKEN_FILE="${SLACK_CONFIG_TOKENS:-$FARM_DIR/.slack-config-tokens.json}"

if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "❌ Config token file not found: $TOKEN_FILE"
  echo "Generate one at: https://api.slack.com/apps → Your App Configuration Tokens"
  exit 1
fi

CONFIG_TOKEN=$(python3 -c "import json; print(json.load(open('$TOKEN_FILE'))['config_token'])")
REFRESH_TOKEN=$(python3 -c "import json; print(json.load(open('$TOKEN_FILE'))['refresh_token'])")

# --- Helper: refresh config token ---
refresh_token() {
  echo "🔄 Refreshing config token..." >&2
  RESP=$(curl -s -X POST https://slack.com/api/tooling.tokens.rotate \
    -d "refresh_token=$REFRESH_TOKEN")
  
  OK=$(echo "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ok', False))")
  if [[ "$OK" != "True" ]]; then
    echo "❌ Token refresh failed. Please regenerate at https://api.slack.com/apps" >&2
    exit 1
  fi
  
  CONFIG_TOKEN=$(echo "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")
  REFRESH_TOKEN=$(echo "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['refresh_token'])")
  
  python3 -c "
import json, os
data = {
    'config_token': '$CONFIG_TOKEN',
    'refresh_token': '$REFRESH_TOKEN',
    'updated_at': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
}
with open('$TOKEN_FILE', 'w') as f:
    json.dump(data, f, indent=2)
os.chmod('$TOKEN_FILE', 0o600)
"
  echo "✅ Token refreshed" >&2
}

# --- Helper: call Slack API with auto-refresh ---
slack_api() {
  local METHOD="$1"
  local DATA="$2"
  
  RESP=$(curl -s -X POST "https://slack.com/api/$METHOD" \
    -H "Authorization: Bearer $CONFIG_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$DATA")
  
  ERROR=$(echo "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('error', ''))" 2>/dev/null || echo "")
  
  if [[ "$ERROR" == "token_expired" || "$ERROR" == "not_authed" || "$ERROR" == "invalid_auth" ]]; then
    refresh_token
    RESP=$(curl -s -X POST "https://slack.com/api/$METHOD" \
      -H "Authorization: Bearer $CONFIG_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$DATA")
  fi
  
  echo "$RESP"
}

# --- Step 1: Create the app from manifest ---
echo "📦 Creating Slack app: lobster-${NAME}..." >&2

MANIFEST=$(python3 -c "
import json
m = {
    'display_information': {
        'name': 'lobster-${NAME}'
    },
    'features': {
        'bot_user': {
            'display_name': 'lobster-${NAME}',
            'always_online': True
        }
    },
    'oauth_config': {
        'scopes': {
            'bot': [
                'app_mentions:read',
                'assistant:write',
                'bookmarks:read',
                'canvases:read',
                'canvases:write',
                'channels:history',
                'channels:read',
                'chat:write',
                'files:read',
                'files:write',
                'groups:history',
                'groups:read',
                'im:history',
                'im:read',
                'im:write',
                'mpim:history',
                'mpim:read',
                'reactions:read',
                'reactions:write',
                'users:read'
            ]
        }
    },
    'settings': {
        'event_subscriptions': {
            'bot_events': [
                'app_mention',
                'assistant_thread_context_changed',
                'assistant_thread_started',
                'message.channels',
                'message.groups',
                'message.im'
            ]
        },
        'interactivity': {
            'is_enabled': True
        },
        'org_deploy_enabled': False,
        'socket_mode_enabled': True,
        'token_rotation_enabled': False
    }
}
print(json.dumps(m))
")

CREATE_RESP=$(slack_api "apps.manifest.create" "{\"manifest\": $MANIFEST}")
CREATE_OK=$(echo "$CREATE_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ok', False))")

if [[ "$CREATE_OK" != "True" ]]; then
  echo "❌ Failed to create app:" >&2
  echo "$CREATE_RESP" | python3 -m json.tool >&2
  exit 1
fi

APP_ID=$(echo "$CREATE_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['app_id'])")
echo "✅ App created: $APP_ID" >&2

# Extract credentials
CREDS=$(echo "$CREATE_RESP" | python3 -c "
import json, sys
d = json.load(sys.stdin)
c = d.get('credentials', {})
print(json.dumps(c))
")

# --- Save app info ---
APP_INFO_FILE="$FARM_DIR/configs/.app-registry/${NAME}.json"
mkdir -p "$(dirname "$APP_INFO_FILE")"

python3 -c "
import json
creds = json.loads('$CREDS')
info = {
    'name': '${NAME}',
    'app_id': '$APP_ID',
    'client_id': creds.get('client_id', ''),
    'client_secret': creds.get('client_secret', ''),
    'signing_secret': creds.get('signing_secret', ''),
    'verification_token': creds.get('verification_token', ''),
    'status': 'created_pending_install',
    'created_at': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
}
with open('$APP_INFO_FILE', 'w') as f:
    json.dump(info, f, indent=2)
import os
os.chmod('$APP_INFO_FILE', 0o600)
"

# --- Output instructions ---
echo "" >&2
echo "========================================" >&2
echo "🦞 Slack App Ready: lobster-${NAME}" >&2
echo "========================================" >&2
echo "" >&2
echo "App ID: $APP_ID" >&2
echo "" >&2
echo "📌 Admin needs to do 2 things:" >&2
echo "" >&2
echo "Step 1: Install the app (click Allow):" >&2
echo "  👉 https://api.slack.com/apps/$APP_ID/install-on-team" >&2
echo "" >&2
echo "Step 2: After install, copy these 2 tokens:" >&2
echo "  Bot Token (xoxb-): https://api.slack.com/apps/$APP_ID/oauth" >&2
echo "  App Token (xapp-): https://api.slack.com/apps/$APP_ID/general → App-Level Tokens → Generate (name: socket, scope: connections:write)" >&2
echo "" >&2
echo "Then run:" >&2
echo "  ./spawn-lobster.sh ${NAME} <SLACK_USER_ID> <xoxb-TOKEN> <xapp-TOKEN>" >&2
echo "========================================" >&2

# JSON output to stdout
echo "$CREATE_RESP" | python3 -c "
import json, sys
d = json.load(sys.stdin)
c = d.get('credentials', {})
out = {
    'app_id': d['app_id'],
    'client_id': c.get('client_id', ''),
    'install_url': 'https://api.slack.com/apps/' + d['app_id'] + '/install-on-team',
    'oauth_url': 'https://api.slack.com/apps/' + d['app_id'] + '/oauth',
    'app_token_url': 'https://api.slack.com/apps/' + d['app_id'] + '/general',
    'name': '${NAME}',
    'status': 'created_pending_install'
}
print(json.dumps(out, indent=2))
"
