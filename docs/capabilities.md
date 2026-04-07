# 🦞 Lobster Farm — Product Capabilities

> Complete reference for all features and systems. For quick start, see [README.md](../README.md).

---

## Table of Contents

- [Core Concept](#core-concept)
- [Fleet Operations](#fleet-operations)
- [Memory Architecture](#memory-architecture)
- [Teamind — Collective Team Memory](#teamind--collective-team-memory)
- [Self-Improving (2nd Me)](#self-improving-2nd-me)
- [Skill Tier System](#skill-tier-system)
- [Bottleneck Detection & Team Intelligence](#bottleneck-detection--team-intelligence)
- [Shared Knowledge (Peer Learning)](#shared-knowledge-peer-learning)
- [Security Model](#security-model)
- [Goal Orchestration (GoalOps)](#goal-orchestration-goalops)
- [Proactive Task Discovery](#proactive-task-discovery)
- [Coding Agent Workflow](#coding-agent-workflow)
- [Monitoring & Observability](#monitoring--observability)
- [Upgrade & Rollout](#upgrade--rollout)
- [All Scripts Reference](#all-scripts-reference)

---

## Core Concept

Every team member gets their own **dedicated AI assistant** ("lobster") running in an isolated Docker container. Lobsters:

- **Share** company knowledge, skills, and policies (read-only mounts)
- **Keep private** personal conversations, memory, and credentials
- **Learn** from each other through shared knowledge and Teamind
- **Self-improve** by recording and promoting lessons from mistakes
- **Detect** blockers proactively and report to the controller

The **controller** (host OpenClaw) manages the fleet: spawning, monitoring, broadcasting, upgrading.

---

## Fleet Operations

### Spawning

Two steps to create a new lobster:

```bash
# Recommended: Tell your controller
# "Spawn a new lobster called alice for @username"
# The controller runs create-slack-app.sh + spawn-lobster.sh automatically.

# Manual CLI:
./scripts/create-slack-app.sh alice           # Auto-creates Slack app
# → Follow install link, click Allow, get tokens
./scripts/spawn-lobster.sh alice U0XXXXXXXXX xoxb-... xapp-...
```

What happens under the hood:
1. `create-slack-app.sh` creates a Slack app via Manifest API (scopes, events, socket mode all pre-configured)
2. Admin clicks Allow on the install link (~5s), then creates an app-level token (~15s)
3. `spawn-lobster.sh` creates config directory with `openclaw.json`, `acp.json`, `secrets.json`
4. Appends service to `docker-compose.yml` with all volume mounts
5. Starts container with Chrome, VNC, noVNC, and OpenClaw gateway

> 📖 Full guide: [docs/slack-bot-setup.md](../docs/slack-bot-setup.md) — includes manual setup option if you don't have a Slack Configuration Token.

### Broadcast

Two modes for fleet-wide communication:

| Mode | Script | How it works | Use case |
|------|--------|-------------|----------|
| **AI-mediated** | `broadcast.sh` | Sends as system event; lobster decides how/whether to relay to user | Non-urgent updates, context sharing |
| **Direct API** | `broadcast-direct.sh` | Calls Slack API directly; guaranteed delivery | Urgent announcements, downtime notices |

### Fleet Sync

Push configuration changes, new skills, API keys, or memory updates to all lobsters simultaneously:

```bash
./scripts/sync-fleet.sh                     # sync all
./scripts/sync-fleet.sh --key NEW_KEY=xxx   # add API key
./scripts/sync-fleet.sh --dry-run           # preview changes
```

### Backup & Rescue

- **Auto-backup**: `backup-lobsters.sh` archives all configs + workspaces to timestamped tarballs
- **Rescue mode**: Check logs → inspect resources → restart → force-recreate (escalating recovery)

---

## Memory Architecture

Four-layer memory with strict isolation:

```
┌──────────────────────────────────────────────────┐
│ Layer 4: Company Knowledge (read-only)           │
│   company-memory/, company-skills/, company-config│
│   → All lobsters can read, none can write        │
├──────────────────────────────────────────────────┤
│ Layer 3: Channel Memory                          │
│   team/channels/<ChannelID>.md                   │
│   → Shared within a Slack channel context        │
├──────────────────────────────────────────────────┤
│ Layer 2: Member Personal                         │
│   team/members/<UserID>.md                       │
│   → Individual + their lobster + controller      │
├──────────────────────────────────────────────────┤
│ Layer 1: Owner Private                           │
│   MEMORY.md, daily logs                          │
│   → Only the lobster's owner sees this           │
└──────────────────────────────────────────────────┘
```

**Key principle**: Information flows down (company → everyone), never up (private → shared) without explicit action.

### Memory Files Per Lobster

| File | Scope | Description |
|------|-------|-------------|
| `MEMORY.md` | Owner only | Long-term curated memory (decisions, preferences) |
| `memory/YYYY-MM-DD.md` | Owner only | Daily raw conversation logs |
| `team/members/<ID>.md` | Owner + controller | Personal work style, preferences, tasks |
| `team/channels/<ID>.md` | Channel members | Channel-specific decisions and context |
| `TEAM_MEMORY.md` | All authorized users | Team-wide shared knowledge |

---

## Teamind — Collective Team Memory

**The problem**: Lobsters only know what happens in their own conversations. When teammates discuss decisions in a shared Slack channel, other lobsters don't know — leading to blind spots and repeated questions.

**The solution**: Teamind indexes all Slack channel messages with vector embeddings, generates thread summaries, and lets any lobster search the team's collective memory.

### How It Works

```
Slack channels ──→ indexer.js ──→ SQLite database
                      │              ├── messages (with embeddings)
                      │              ├── thread_summaries (LLM-generated)
                      │              └── index_state (cursor tracking)
                      │
                  search.js ←── Lobster: "what was decided about X?"
                      │
                  digest.js ──→ Per-lobster daily digest markdown
```

### Components

| Component | What it does |
|-----------|-------------|
| `setup.js` | Initialize SQLite database with proper schema |
| `indexer.js` | Fetch Slack history, embed messages, summarize threads |
| `search.js` | Semantic search across threads and messages |
| `digest.js` | Generate personalized daily digest per lobster |

### Thread Summaries

Every thread with ≥3 messages gets an LLM-generated summary containing:

- **Title** — concise description
- **Summary** — 2-3 sentence overview
- **Thread type** — `decision` / `bug_fix` / `brainstorm` / `status_update` / `qa` / `casual` / `announcement`
- **Key points** — specific conclusions and decisions
- **Participants** — who contributed what
- **Open items** — unresolved tasks with assignees

### Search Capabilities

```bash
# Basic semantic search
node search.js "API design decision" --json

# Composable filters
node search.js "recommendation algorithm" \
  --channel CXXXXXXXXXX \
  --type decision \
  --after 2026-03-01 \
  --participant alice \
  --limit 10 \
  --json
```

Returns ranked thread summaries + individual message matches with cosine similarity scores.

### Daily Digest

Each lobster receives a personalized digest of threads they participated in (or high-activity threads everyone should know about). Written as markdown, easy to integrate into daily logs or MEMORY.md.

### Embedding Providers

| Provider | Model | Dimensions | Cost |
|----------|-------|-----------|------|
| OpenAI | text-embedding-3-small | 1536 | ~$0.02/1M tokens |
| Gemini | text-embedding-004 | varies | Free tier available |

### Recommended Cron

```bash
# Incremental index every hour
0 * * * * cd scripts/teamind && node indexer.js

# Full digest daily at 04:00 UTC
0 4 * * * cd scripts/teamind && node digest.js
```

---

## Self-Improving (2nd Me)

**The problem**: AI assistants repeat the same mistakes because they don't have structured learning from corrections.

**The solution**: Lobsters detect when they're corrected (using semantic understanding, not keywords), record the lesson, and periodically promote validated patterns to permanent memory.

### How It Works

```
User corrects lobster ──→ Detect correction (semantic)
                              │
                              ▼
                     Record in .learnings/corrections.md
                              │
                              ▼ (daily cron)
                     Review & validate lessons
                              │
                              ▼
                     Promote to MEMORY.md / AGENTS.md
```

### Trigger Conditions

| Scenario | Detection | Action |
|----------|-----------|--------|
| **Corrected by user** | Semantic detection (any phrasing) | Record correction + root cause |
| **Command failed** | Error/exception | Record error + fix |
| **Outdated knowledge** | API behavior differs from expectation | Record knowledge gap |
| **Better approach found** | Discovered more efficient method | Record best practice |
| **Complex task completed** | ≥5 steps | Self-reflection |

**Not triggered by**: one-time instructions, hypothetical discussions, silence.

### Storage Structure

```
.learnings/
├── corrections.md      # Core: what I got wrong and why
├── errors.md           # Command/tool failures and fixes
├── reflections.md      # Post-task self-assessment
└── best-practices.md   # Discovered better approaches
```

### Promotion Rules

Lessons don't stay in `.learnings/` forever — important ones get promoted:

| Condition | Promoted to | Example |
|-----------|------------|---------|
| Affects daily workflow | `MEMORY.md` | "Always use CC for code analysis" |
| Tool usage pattern | `TOOLS.md` | "MySQL queries need LIMIT" |
| Behavioral pattern | `AGENTS.md` | "Confirm understanding before acting" |
| Same lesson ≥3 times | Immediate promotion | — |

### Fleet-wide Scan

```bash
# Trigger scan on all lobsters
./scripts/trigger-2nd-me-all.sh

# Single lobster
docker exec lobster-alice bash /shared/scripts/run-2nd-me-scan.sh
```

Recommended: daily cron at 04:00 UTC.

---

## Skill Tier System

Skills have three access levels, controlled by `manifest.json`:

| Tier | Access | Examples |
|------|--------|---------|
| `base` | All lobsters | teamind, self-improving, bottleneck-reporting |
| `restricted` | Allowlisted only | finance dashboard, HR data, admin tools |
| `admin` | Controller only | fleet management, credential rotation |

### Adding a Skill

1. Create `company-skills/<name>/SKILL.md` with YAML frontmatter
2. Register in `manifest.json`
3. Run `sync-company-skills.sh` or restart lobsters (entrypoint auto-syncs)

### Skill Discovery

The entrypoint automatically symlinks `company-skills/` into each lobster's `workspace/skills/`, so OpenClaw discovers them on boot. No manual configuration needed per lobster.

See [SKILL_POLICY.md](../templates/SKILL_POLICY.md) for full spec.

---

## Bottleneck Detection & Team Intelligence

Lobsters don't wait for users to say "I'm stuck." They detect it from conversation patterns.

### How It Works

1. **Detection**: Lobster notices repeated failures, missing info, or blocked processes
2. **Report**: Writes structured report to `/shared/bottleneck-inbox/`
3. **Triage**: Controller polls every 5 minutes + daily full scan
4. **Promote**: Common issues → `company-memory/` (all lobsters learn)
5. **Escalate**: Individual issues → team lead notification

### Bottleneck Report Format

```markdown
## Bottleneck: [Title]
- **Reporter**: lobster-alice
- **User**: U0XXXXXXXXX
- **Category**: missing_access | missing_info | bug | process_blocker
- **Severity**: low | medium | high
- **Description**: What's blocking progress
- **Attempted**: What was already tried
```

### Scripts

| Script | Frequency | What it does |
|--------|-----------|-------------|
| `poll-bottleneck-inbox.sh` | Every 5 min | Check for new reports |
| `scan-bottlenecks.sh` | Daily 04:00 | Pattern analysis across all reports |

---

## Shared Knowledge (Peer Learning)

A living document (`shared-knowledge.md`) that any lobster can write to:

```
Lobster discovers useful pattern ──→ Writes to shared-knowledge.md
                                          │
                                     Other lobsters read it
                                          │
                                     Controller curates weekly
                                          │
                                     Best entries → company-memory/
```

**This creates a learning loop**: lobsters discover → share → controller curates → all lobsters benefit.

---

## Security Model

### Credential Isolation

| File | Access | Description |
|------|--------|-------------|
| `secrets.json` | Read-only | Shared API keys (injected at spawn) |
| `personal-secrets.json` | Read-write | Per-lobster private credentials |
| `.env` | Host only | Master API keys (never mounted directly) |

OpenClaw's **SecretRef** system (`{"$ref": "secrets://KEY"}`) keeps secrets out of `openclaw.json`.

### Volume Isolation

- Company resources: **read-only** mount (lobsters can't modify shared knowledge)
- Personal workspace: **read-write** (isolated per lobster)
- Bottleneck inbox: **read-write** (controlled shared space)

### Watchdogs

| Watchdog | What it does |
|----------|-------------|
| `config-watchdog.sh` | Dead-man switch: auto-rollback config changes if not confirmed within N seconds |
| `gateway-watchdog.sh` | Cron: auto-restart gateway if health check fails |

### Credential Health Check

```bash
./scripts/credential-healthcheck.sh
```

Verifies all lobster credentials are valid and API keys haven't expired.

---

## Goal Orchestration (GoalOps)

Coordinate multi-lobster goals with automatic decomposition, distribution, and monitoring.

### How It Works

```
Owner: "goal: Launch new feature by Friday"
    │
    ▼
Controller decomposes → SG-1 (backend), SG-2 (frontend), SG-3 (QA)
    │
    ▼
Distribute to lobsters via Slack threads + task board entries
    │
    ▼
Lobsters execute autonomously, collaborate P2P
    │
    ▼
Patrol script detects stuck tasks → nudge → escalate
    │
    ▼
Controller verifies acceptance criteria → completion report
```

### Key Features

| Feature | Description |
|---------|-------------|
| 4-phase flow | Decompose → Distribute → Monitor → Complete |
| Event-driven | Lobsters report progress; controller reacts |
| Patrol fallback | Bash script runs every 30 min, $0 cost when idle |
| P2P collaboration | Lobsters @mention each other directly |
| Task board sync | Auto-creates entries in Notion/Linear/GitHub Issues |
| Coverage check | Verifies sub-goals fully cover the big goal |

See `templates/controller/goal-ops/SKILL.md` for full protocol.

---

## Proactive Task Discovery

Lobsters don't just wait for assignments — they actively scan for work.

### How It Works

1. Daily cron (`proactive-cron.sh`) nudges all lobsters
2. Each lobster scans configured task boards for unassigned/open items
3. Items are scored by capability match, priority, effort, and dependencies
4. High-scoring items are proposed to the owner for approval
5. On approval, lobster assigns itself and executes

### Confidence Scoring

| Score | Action |
|-------|--------|
| 8-10 | Recommend with high confidence |
| 5-7 | Present with caveats |
| 0-4 | Skip unless nothing else available |

See `templates/skills/proactive-task-engine/SKILL.md` and `templates/skills/task-autopilot/SKILL.md`.

---

## Coding Agent Workflow

Structured collaboration with ACP coding agents (Claude Code, Codex, Cursor).

### Confidence-Based Routing

| Confidence | Action |
|------------|--------|
| High (8-10) | Auto-execute with verification |
| Medium (5-7) | Structured prompt, careful review |
| Low (1-4) | Ask human before proceeding |

### Verification Pipeline

Every code change goes through:
1. Automated: tests pass, lint clean, build succeeds
2. Manual: changes match requirements, no hardcoded values, consistent style
3. Decision: ship, iterate, or abandon

See `templates/skills/coding-workflow/SKILL.md`.

---

## Monitoring & Observability

### Health Check (4-point inspection)

```bash
./scripts/health-check.sh --verbose --auto-fix --notify
```

Checks:
1. **Container status** — running? healthy?
2. **HTTP response** — gateway responding?
3. **Memory usage** — over 90% triggers alert
4. **Restart frequency** — abnormal restarts (<5 min interval)

Recommended: cron every 30 minutes with `--auto-fix --notify`.

### Log Patrol (3-tier alerting)

```bash
./scripts/log-patrol.sh --since 24h --notify-owner
```

Scans for:
- 🔴 **Critical**: FATAL, OOM
- 🟡 **Error**: Error, rate-limit, ECONNREFUSED
- 🟢 **Warning**: WARN, timeout, retry

Recommended: daily cron at 09:00 UTC.

### Resource Monitor

```bash
./scripts/resource-monitor.sh --all --threshold 80
```

Shows: CPU%, memory usage/limit, PID count, host load average.

### Owner Notification

```bash
./scripts/notify-lobster-owner.sh <name> "Your message"
```

Reads bot token + owner from the lobster's config automatically. Used by health-check and log-patrol for targeted alerts.

---

## Upgrade & Rollout

### Rolling Upgrade

Zero-downtime fleet upgrades with automatic canary testing:

```bash
./scripts/rolling-upgrade.sh --canary alice --batch-size 5
```

Process:
1. **Canary**: Upgrade one lobster first
2. **Health check**: Wait 90s, verify health
3. **Batch upgrade**: Upgrade remaining in batches
4. **Auto-rollback**: If any health check fails, revert canary + stop

### Canary Rollout Tracking

Use `CANARY.md` (template in `templates/`) to track gradual feature rollouts:

```markdown
### #1 — New Feature (Status: 🟡 canary)
- Canary group: alice, bob (2/20)
- Started: 2026-03-15
- Metrics: error rate, memory usage
```

### Patch System

After every OpenClaw upgrade, run:

```bash
./scripts/patch-all.sh
```

Current patches:
| Patch | Issue |
|-------|-------|
| `patch-implicit-mention.sh` | Thread messages trigger AI without @mention |
| `patch-cc-session.sh` | ACP session requires thread binding on Slack |

---

## All Scripts Reference

### Core Operations (5)
| Script | Description |
|--------|-------------|
| `create-slack-app.sh` | Auto-create Slack App via Manifest API |
| `spawn-lobster.sh` | Create new lobster container (after create-slack-app or with tokens) |
| `health-check.sh` | 4-point health inspection + auto-fix |
| `backup-lobsters.sh` | Archive all configs and workspaces |
| `rolling-upgrade.sh` | Canary → batch → auto-rollback upgrade |
| `enable-acp.sh` | Enable Claude Code/ACP on a lobster |

### Fleet Management (5)
| Script | Description |
|--------|-------------|
| `apply-fleet-config.sh` | Deep-merge JSON patch into all configs |
| `sync-fleet.sh` | Push skills, memory, and API keys |
| `sync-company-skills.sh` | Symlink shared skills into workspaces |
| `broadcast.sh` | AI-mediated broadcast (lobster reformulates) |
| `broadcast-direct.sh` | Direct Slack API broadcast (guaranteed) |

### Monitoring (4)
| Script | Description |
|--------|-------------|
| `log-patrol.sh` | Log scanning with 3-tier alerting |
| `resource-monitor.sh` | CPU/memory/PID monitoring |
| `notify-lobster-owner.sh` | DM a lobster's owner via their bot |
| `credential-healthcheck.sh` | Verify all credentials are valid |

### Intelligence (4)
| Script | Description |
|--------|-------------|
| `poll-bottleneck-inbox.sh` | Check for new bottleneck reports |
| `scan-bottlenecks.sh` | Pattern analysis across all reports |
| `run-2nd-me-scan.sh` | Self-improvement scan (single lobster) |
| `trigger-2nd-me-all.sh` | Self-improvement scan (all lobsters) |

### Watchdogs & Patches (4)
| Script | Description |
|--------|-------------|
| `config-watchdog.sh` | Dead-man switch for config changes |
| `gateway-watchdog.sh` | Auto-restart unhealthy gateways |
| `patch-implicit-mention.sh` | Fix thread implicit mention behavior |
| `patch-cc-session.sh` | Fix ACP session binding requirement |

### Utilities (2)
| Script | Description |
|--------|-------------|
| `claude-wrapper.sh` | Claude Code CLI wrapper |
| `teamind/` | Group chat memory system (4 JS modules) |

**Total: 24 shell scripts + 4 Node.js modules**

---

## Recommended Cron Schedule

```bash
# Health check every 30 min
*/30 * * * * $(pwd)/scripts/health-check.sh --auto-fix --notify

# Log patrol daily 09:00 UTC
0 9 * * * $(pwd)/scripts/log-patrol.sh --since 24h --notify-owner

# Teamind incremental index every hour
0 * * * * cd $(pwd)/scripts/teamind && node indexer.js

# Teamind digest + 2nd Me scan daily 04:00 UTC
0 4 * * * cd $(pwd)/scripts/teamind && node digest.js
5 4 * * * $(pwd)/scripts/trigger-2nd-me-all.sh

# Bottleneck polling every 5 min
*/5 * * * * $(pwd)/scripts/poll-bottleneck-inbox.sh

# Bottleneck analysis daily 04:00 UTC
0 4 * * * $(pwd)/scripts/scan-bottlenecks.sh

# Backup weekly Sunday 03:00 UTC
0 3 * * 0 $(pwd)/scripts/backup-lobsters.sh
```
