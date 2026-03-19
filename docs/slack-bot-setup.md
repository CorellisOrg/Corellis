# 🤖 Slack Bot Setup Guide

Each lobster needs its own Slack App. Two ways to set it up:

| Method | Time | Best for |
|--------|------|----------|
| **Automated** (recommended) | ~2 min | Teams spawning multiple lobsters |
| **Manual** | ~5 min | First-time setup or no config token |

---

## Method 1: Automated Setup (Recommended)

The `create-slack-app.sh` script creates a fully configured Slack App via the Manifest API — all scopes, events, and socket mode pre-configured. No manual clicking.

### One-time prerequisite: Get a Configuration Token

1. Go to **https://api.slack.com/apps**
2. Scroll down to **"Your App Configuration Tokens"**
3. Click **"Generate Token"** for your workspace
4. Save both tokens:

```bash
cat > .slack-config-tokens.json << 'TOKEOF'
{
  "config_token": "xoxe.xoxp-...",
  "refresh_token": "xoxe-..."
}
TOKEOF
chmod 600 .slack-config-tokens.json
```

### Create & spawn

```bash
# 1. Create the Slack app (auto-configures everything)
./scripts/create-slack-app.sh alice

# 2. The script outputs an install link — click "Allow" in your browser

# 3. Copy the two tokens from the links the script prints:
#    - Bot Token (xoxb-...): from OAuth page
#    - App Token (xapp-...): create one at General → App-Level Tokens
#      (name: "socket", scope: connections:write)

# 4. Spawn the lobster
./scripts/spawn-lobster.sh alice U0XXXXXXXXX xoxb-... xapp-...
```

That's it. The gateway starts in about 90 seconds, then DM the bot in Slack.

> **Even easier:** Tell your controller "spawn lobster alice for @username" and it runs these steps for you. You just click Allow and paste the app token.

---

## Method 2: Manual Setup

If you don't have a Configuration Token, or prefer manual control.

### Step 1: Create a Slack App

1. Go to **https://api.slack.com/apps** → **"Create New App"** → **"From scratch"**
2. **App Name**: `lobster-<name>` (e.g., `lobster-alice`)
3. **Workspace**: Select yours → **"Create App"**

### Step 2: Enable Socket Mode

1. Left sidebar → **"Socket Mode"** → Toggle ON
2. Create App-Level Token: name `socket`, scope `connections:write`
3. **📋 Save the `xapp-...` token**

### Step 3: Bot Permissions

Left sidebar → **"OAuth & Permissions"** → **"Bot Token Scopes"** → Add:

```
app_mentions:read    channels:history    channels:read
chat:write           files:read          files:write
groups:history       groups:read         im:history
im:read              im:write            mpim:history
mpim:read            reactions:read      reactions:write
users:read
```

### Step 4: Events

Left sidebar → **"Event Subscriptions"** → Toggle ON → Subscribe to bot events:

```
app_mention    message.channels    message.groups
message.im     message.mpim
```

Save Changes.

### Step 5: Install & Get Tokens

1. Left sidebar → **"Install App"** → **"Install to Workspace"** → Allow
2. **📋 Save the `xoxb-...` token**

### Step 6: Get Owner's Slack ID

In Slack: click person's name → View full profile → ⋮ → Copy member ID → `U0XXXXXXXXX`

### Step 7: Spawn

```bash
./scripts/spawn-lobster.sh alice U0XXXXXXXXX xoxb-... xapp-...
```

---

## 🔧 Troubleshooting

| Problem | Fix |
|---------|-----|
| Bot doesn't respond to DMs | Check Socket Mode is ON, `im:history` + `message.im` events added |
| "not_authed" error | Double-check `xoxb-...` token; try reinstalling the app |
| Bot works in channels but not DMs | Owner needs to DM the bot first (pairing mode) |
| Permission errors | Add missing scopes → reinstall the app |

Check logs: `docker logs lobster-alice --tail 50`
