---
name: corellis
description: "AI team intelligence and fleet management for OpenClaw. Spawn, monitor, and orchestrate a fleet of AI lobster assistants in Docker — with proactive bottleneck detection, peer-to-peer knowledge sharing, health checks, rolling upgrades, and owner notifications."
---

# 🦞 Lobster Farm — Enterprise AI Fleet Manager

Manage a fleet of OpenClaw AI assistants ("lobsters") running as independent Docker containers. Each team member gets their own dedicated AI assistant that shares company knowledge but maintains private personal memory.

## Quick Start (Already have OpenClaw?)

If you already have OpenClaw running, just say:

```
"initialize lobster farm" or "setup lobster farm"
```

Your AI will automatically set up everything **and detect your existing LLM API keys** — no manual config editing needed. Then provide a Slack Bot Token and spawn your first lobster. Total time: ~5 minutes.

## Prerequisites (Manual Setup)

If you prefer manual control, or don't have OpenClaw yet:

1. A server with Docker installed
2. Run: `curl -sSL https://raw.githubusercontent.com/CorellisOrg/corellis/main/install.sh | bash`
3. Fill in your API keys in `.env`
4. `clawhub install corellis`

👉 **Full deployment guide**: https://github.com/CorellisOrg/corellis

## What This Skill Does

This skill gives your **master OpenClaw instance** (the "controller") the ability to manage all lobster containers via natural language:

| Command | What it does |
|---------|-------------|
| "spawn lobster alice" | Create a new lobster container |
| "lobster status" | Show all lobsters' health & resources |
| "restart lobster bob" | Restart a specific lobster |
| "lobster logs carol" | View recent logs |
| "broadcast: hello" | Send message to all lobsters |
| "rescue lobster dave" | Diagnose & fix a broken lobster |
| "health check" | Check all lobsters' health |
| "log patrol" | Scan logs for errors across fleet |
| "resource monitor" | Show CPU/memory usage |
| "rolling upgrade" | Upgrade fleet with canary + auto-rollback |

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│                 Host Machine                 │
│                                              │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐       │
│  │ 🦞 Alice│ │ 🦞 Bob  │ │ 🦞 Carol│  ...  │
│  │ (Docker)│ │ (Docker)│ │ (Docker)│       │
│  └────┬────┘ └────┬────┘ └────┬────┘       │
│       │            │            │            │
│  ┌────┴────────────┴────────────┴────┐      │
│  │     Shared Read-Only Mounts       │      │
│  │  📚 company-memory/              │      │
│  │  🔧 company-skills/              │      │
│  └───────────────────────────────────┘      │
│                                              │
│  ┌──────────────────┐                        │
│  │ 🎛️ Controller     │ ← this skill runs here│
│  │ (Host OpenClaw)  │                        │
│  └──────────────────┘                        │
└──────────────────────────────────────────────┘
```

## Configuration

Before using, set these paths in your environment or adjust the commands below:

| Variable | Default | Description |
|----------|---------|-------------|
| `LOBSTER_FARM_DIR` | `$LOBSTER_FARM_DIR` | Root directory of Lobster Farm deployment |
| `BACKUP_DIR` | `$LOBSTER_FARM_DIR/backups` | Backup storage location |

## Operations

### 0. First-Time Setup (Run Once)

When the user says "initialize lobster farm" / "setup lobster farm" / "initialize lobster farm":

```bash
# 1. Check Docker
docker --version && docker compose version

# 2. Clone repo
LOBSTER_FARM_DIR=${LOBSTER_FARM_DIR:-~/corellis}
git clone https://github.com/CorellisOrg/corellis.git $LOBSTER_FARM_DIR

# 3. Build image (takes 3-5 minutes)
cd $LOBSTER_FARM_DIR
docker build -f docker/Dockerfile.lite -t lobster-openclaw:latest .

# 4. Create directory structure with starter templates
mkdir -p $LOBSTER_FARM_DIR/{company-memory,company-skills,configs,backups}

# 4a. Create company-memory README if empty
if [ ! -f "$LOBSTER_FARM_DIR/company-memory/README.md" ]; then
cat > $LOBSTER_FARM_DIR/company-memory/README.md << 'CMEOF'
# Company Memory

Shared knowledge base for all lobsters (read-only bind mount).

Put files here that every lobster should know about:
- `tech-stack.md` — languages, frameworks, infrastructure
- `team-guidelines.md` — code review process, naming conventions
- `product-overview.md` — what your company builds
- `faq.md` — common questions and answers

Lobsters access these via semantic search (memory_search tool).
Keep files focused and well-structured for best retrieval.
CMEOF
fi

# 4b. Create company-skills README if empty
if [ ! -f "$LOBSTER_FARM_DIR/company-skills/README.md" ]; then
cat > $LOBSTER_FARM_DIR/company-skills/README.md << 'CSEOF'
# Company Skills

Shared skills for all lobsters (read-only bind mount).

Each skill is a folder with a `SKILL.md` that defines:
- Trigger words (when to activate)
- Instructions (what to do)
- Scripts (optional automation)

Example structure:
```
company-skills/
├── weekly-report/
│   └── SKILL.md      # "generate weekly report" → query DB + format report
├── mysql-query/
│   └── SKILL.md      # "query database" → safe read-only SQL
└── onboarding/
    └── SKILL.md      # "onboarding" → checklist + resources
```

Changes here take effect immediately (bind mount, no restart needed).
CSEOF
fi

# 5. Generate .env — auto-detect LLM keys from host OpenClaw
cp $LOBSTER_FARM_DIR/.env.example $LOBSTER_FARM_DIR/.env

# 6. Auto-populate LLM keys from host environment (if available)
# Check common env vars and openclaw.json for existing API keys
for key in ANTHROPIC_API_KEY AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION OPENAI_API_KEY BRAVE_API_KEY; do
  val=$(printenv $key 2>/dev/null)
  if [ -n "$val" ]; then
    sed -i "s|^#\?${key}=.*|${key}=${val}|" $LOBSTER_FARM_DIR/.env
  fi
done
```

The setup script automatically detects LLM API keys from the host OpenClaw's environment. If keys are found, `.env` is pre-filled — **no manual editing needed**.

If no keys are detected (e.g., host uses a config file instead of env vars), prompt the user to fill in `.env` with their LLM provider key.

Verify setup:
```bash
docker images | grep lobster-openclaw
ls $LOBSTER_FARM_DIR/{company-memory,company-skills,configs}
```

If all checks pass, print: "✅ Lobster Farm initialized! Say 'spawn lobster <name>' to create your first lobster, or run create-slack-app.sh <name> manually."

### 1. Spawn a New Lobster

**Recommended flow** (conversational — user tells you what to do):
1. User says: "Spawn a new lobster called alice for @username"
2. You run `./scripts/create-slack-app.sh alice` to auto-create the Slack app
3. Give user the install link → they click Allow (~5s)
4. Ask user to create an app-level token and paste it back (~15s)
5. Run `./scripts/spawn-lobster.sh alice <slack_user_id> <xoxb-token> <xapp-token>`
6. Wait for gateway to start, then verify

**Manual CLI flow** (if user provides all tokens upfront):
```bash
cd $LOBSTER_FARM_DIR
./scripts/create-slack-app.sh <name>              # Step 1: create Slack app
./scripts/spawn-lobster.sh <name> <slack_user_id> <xoxb-token> <xapp-token>  # Step 2: spawn
docker compose up -d lobster-<name>
```

Verify after gateway starts (~90 seconds):
```bash
docker logs lobster-<name> --tail 20
```

### 2. Check Fleet Status

```bash
cd $LOBSTER_FARM_DIR && docker compose ps"
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.Status}}'"
```

### 3. Restart a Lobster

```bash
cd $LOBSTER_FARM_DIR && docker compose restart lobster-<name>"
```

### 4. View Logs

```bash
docker logs lobster-<name> --tail 50"
```

### 5. Stop / Remove a Lobster

```bash
cd $LOBSTER_FARM_DIR
docker compose stop lobster-<name>"
docker compose rm -f lobster-<name>"
# To permanently delete data (careful!):
# docker volume rm corellis_lobster-<name>-data"
```

### 6. Broadcast Messages

**System event broadcast** (AI decides whether to forward to user):
```bash
$LOBSTER_FARM_DIR/scripts/broadcast.sh "Your message"
# To specific lobsters:
$LOBSTER_FARM_DIR/scripts/broadcast.sh "Your message" alice bob
```

**Direct API broadcast** (100% reliable, bypasses AI):
```bash
$LOBSTER_FARM_DIR/scripts/broadcast-direct.sh "📢 Your announcement"
```

### 7. Sync Skills & Memory

```bash
$LOBSTER_FARM_DIR/scripts/sync-fleet.sh
# With new API key (triggers container rebuild):
$LOBSTER_FARM_DIR/scripts/sync-fleet.sh --key NEW_API_KEY=xxx
# Dry run:
$LOBSTER_FARM_DIR/scripts/sync-fleet.sh --dry-run
```

### 8. Backup

```bash
# Manual backup
$LOBSTER_FARM_DIR/scripts/backup-lobsters.sh
# Backups stored at: $BACKUP_DIR/<name>/YYYY-MM-DD.tar.gz
```

### 9. Rescue a Lobster

When a lobster is unhealthy:
1. Check logs: `docker logs lobster-<name> --tail 100"`
2. Check resources: `docker stats --no-stream lobster-<name>"`
3. Try restart: `cd $LOBSTER_FARM_DIR && docker compose restart lobster-<name>"`
4. If OOM: check memory limit (minimum 2G recommended)
5. If persistent: recreate `docker compose up -d --force-recreate lobster-<name>"`

## Memory Architecture

Lobster Farm uses a 4-layer memory system:

| Layer | Scope | Example |
|-------|-------|---------|
| Layer 1: Owner private | Only owner sees | MEMORY.md, personal notes |
| Layer 2: Member personal | Individual + owner | team/members/<ID>.md |
| Layer 3: Channel memory | Channel members | team/channels/<ID>.md |
| Layer 4: Shared knowledge | Everyone (read-only) | company-memory/, TEAM_MEMORY.md |

### 10. Health Check

```bash
# Quick check (all lobsters)
$LOBSTER_FARM_DIR/scripts/health-check.sh

# Detailed with auto-fix
$LOBSTER_FARM_DIR/scripts/health-check.sh --verbose --auto-fix

# JSON output (for scripting)
$LOBSTER_FARM_DIR/scripts/health-check.sh --json

# With Slack notification on issues
$LOBSTER_FARM_DIR/scripts/health-check.sh --auto-fix --notify
```

Checks: container status → HTTP response → memory usage (>90%) → abnormal restarts (<5min).
Recommended: cron every 30 minutes with `--auto-fix --notify`.

### 11. Log Patrol

```bash
# Scan last 30 minutes
$LOBSTER_FARM_DIR/scripts/log-patrol.sh

# Scan last 4 hours, show details
$LOBSTER_FARM_DIR/scripts/log-patrol.sh --verbose --since 4h

# Notify individual lobster owners about their issues
$LOBSTER_FARM_DIR/scripts/log-patrol.sh --since 24h --notify-owner
```

Scans for: FATAL/OOM (critical), Error/rate-limit/ECONNREFUSED (error), WARN/timeout/retry (warning).
Recommended: daily cron with `--since 24h --notify-owner`.

### 12. Resource Monitor

```bash
# Show all lobsters
$LOBSTER_FARM_DIR/scripts/resource-monitor.sh --all

# Only show lobsters above threshold
$LOBSTER_FARM_DIR/scripts/resource-monitor.sh --threshold 80

# JSON output
$LOBSTER_FARM_DIR/scripts/resource-monitor.sh --json
```

Shows: CPU%, memory usage/limit, PID count, host load average.

### 13. Rolling Upgrade

When you have a new Docker image:

```bash
# Preview (no actual changes)
$LOBSTER_FARM_DIR/scripts/rolling-upgrade.sh --dry-run

# Full upgrade: canary first, then batches of 3
$LOBSTER_FARM_DIR/scripts/rolling-upgrade.sh

# Custom canary + batch size
$LOBSTER_FARM_DIR/scripts/rolling-upgrade.sh --canary alice --batch-size 5
```

Process: canary upgrade → 90s health check → batch upgrade → auto-rollback on failure.

### 14. Notify Lobster Owner

Send a DM to a specific lobster's owner via their lobster's bot:

```bash
$LOBSTER_FARM_DIR/scripts/notify-lobster-owner.sh <name> "Your message"
```

Reads botToken + owner from the lobster's config automatically.

### 15. Bottleneck Reporting (AI Team Intelligence)

Lobsters proactively detect when their user is stuck and report blockers to a shared queue. The controller analyzes patterns — common issues become company knowledge, individual issues get escalated.

**Setup:**
```bash
# Create shared inbox
mkdir -p $LOBSTER_FARM_DIR/bottleneck-inbox

# Add to each lobster's docker-compose volumes:
#   - ./bottleneck-inbox:/shared/bottleneck-inbox:rw

# Copy skill template for lobsters
cp -r $LOBSTER_FARM_DIR/templates/bottleneck-reporting/ $LOBSTER_FARM_DIR/company-skills/

# Set up cron (controller host)
# */5 * * * * $LOBSTER_FARM_DIR/scripts/poll-bottleneck-inbox.sh
# 0 4 * * * $LOBSTER_FARM_DIR/scripts/scan-bottlenecks.sh
```

**How it works:**
1. Lobster detects user is stuck (repeated failures, missing info, blocked process)
2. Lobster writes a structured report to `/shared/bottleneck-inbox/`
3. Controller polls every 5 minutes + daily full scan at 04:00 UTC
4. Common issues → promoted to `company-memory/` (all lobsters learn)
5. Individual issues → escalated to team lead

This is **not** a bug tracker — it's AI-powered team intelligence. Lobsters don't wait for users to say "I'm stuck." They detect it from conversation context.

### 16. Shared Knowledge System (Peer Learning)

Lobsters share discoveries with each other through a writable knowledge file:

**Setup:**
```bash
# Create shared knowledge file from template
cp $LOBSTER_FARM_DIR/templates/shared-knowledge/shared-knowledge.md $LOBSTER_FARM_DIR/shared-knowledge.md

# Add to each lobster's docker-compose volumes:
#   - ./shared-knowledge.md:/shared/shared-knowledge.md:rw

# Optional: weekly review cron
# 0 4 * * 1 openclaw agent -m "Review shared-knowledge.md for promotion to company-memory." --deliver
```

**Architecture:**
- `shared-knowledge.md` (read/write) — living document, any lobster can contribute
- `company-memory/` (read-only) — stable curated knowledge, controller promotes verified entries

This creates a **learning loop**: lobsters discover → share → controller curates → all lobsters benefit.


## Notes

- If docker requires group permissions, you may need to add your user to the `docker` group: `sudo usermod -aG docker $USER`
- The controller (master) runs on the host, not in Docker
- API keys are injected via `.env` environment variables
- Each lobster needs minimum 2GB memory (1GB will OOM)
- Gateway startup takes ~90 seconds — wait before health checks
- Container requires `tty: true` for proper output
