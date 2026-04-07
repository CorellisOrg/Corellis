# Tutorial: Set Up AI Assistants for Your 3-Person Team

> **Prerequisite**: You already have [OpenClaw](https://openclaw.ai) running as your personal AI assistant. Lobster Farm helps you extend it to your whole team.
>
> **Time**: ~30 minutes | **Result**: 3 team members each get their own AI assistant — private memory, shared company knowledge, collective team memory.

---

## What You'll Build

```
┌─────────────────────────────────────────┐
│  Your Server                            │
│                                         │
│  🎛️ Controller (your OpenClaw)           │
│     ├── 🦞 lobster-alice  (Alice's AI)  │
│     ├── 🦞 lobster-bob    (Bob's AI)    │
│     └── 🦞 lobster-carol  (Carol's AI)  │
│                                         │
│  📚 Shared: company knowledge + skills  │
│  🔒 Private: each person's memory       │
│  🧠 Teamind: searchable team history  │
└─────────────────────────────────────────┘
```

Each lobster:
- Has private conversations and memory (only the owner sees)
- Shares company knowledge, skills, and policies (read-only)
- Can search all team Slack discussions via Teamind
- Learns from its mistakes via Self-Improving (2nd Me)
- Has Claude Code / ACP built in for coding tasks

---

## Prerequisites

- A Linux server (Ubuntu 22.04+ recommended, minimum 8GB RAM for 3 lobsters)
- Docker + Docker Compose installed
- A Slack workspace where you can create apps
- An LLM API key (Anthropic, OpenAI, or AWS Bedrock)

---

## Step 1: Install Lobster Farm (5 min)

```bash
# Clone the repo
git clone https://github.com/CorellisOrg/corellis.git
cd corellis

# Copy environment template
cp .env.example .env
```

Edit `.env` and fill in your LLM API key. At minimum you need ONE of:

```bash
# Option A: Anthropic (simplest)
ANTHROPIC_API_KEY=sk-ant-...

# Option B: OpenAI
OPENAI_API_KEY=sk-...

# Option C: AWS Bedrock (if you have it)
AWS_ACCESS_KEY_ID=your-access-key-id
AWS_SECRET_ACCESS_KEY=...
AWS_DEFAULT_REGION=us-west-2
```

Build the Docker image:

```bash
docker build -f docker/Dockerfile.lite -t lobster-openclaw:latest .
# Takes 3-5 minutes on first run
```

Initialize the directory structure:

```bash
cp docker-compose.base.yml docker-compose.yml
mkdir -p company-memory company-skills company-config configs
```

---

## Step 2: Create Slack Bots (10 min)

Each team member needs their own Slack Bot. You'll create 3 apps.

> 📖 Detailed guide: [docs/slack-bot-setup.md](slack-bot-setup.md)

**Quick version** (repeat for each person):

1. Go to [api.slack.com/apps](https://api.slack.com/apps) → **Create New App** → **From scratch**
2. Name it (e.g., "Alice's Lobster") → Select your workspace
3. **Socket Mode** → Enable → Create app-level token → Save the `xapp-...` token
4. **OAuth & Permissions** → Add scopes:
   - `chat:write`, `files:read`, `files:write`, `users:read`
   - `channels:history`, `groups:history`, `im:history`, `mpim:history`
   - `channels:read`, `groups:read`, `im:read`
5. **Install to Workspace** → Save the `xoxb-...` token
6. **Event Subscriptions** → Enable → Subscribe to:
   - `message.im`, `message.groups`, `app_mention`
7. Note the user's **Slack User ID** (click their profile → ⋮ → Copy member ID)

After creating all 3, you should have:

| Person | Slack User ID | Bot Token | App Token |
|--------|--------------|-----------|-----------|
| Alice | U0AAAAAAA | xoxb-alice-... | xapp-alice-... |
| Bob | U0BBBBBBB | xoxb-bob-... | xapp-bob-... |
| Carol | U0CCCCCCC | xoxb-carol-... | xapp-carol-... |

---

## Step 3: Spawn Your Lobsters (5 min)

**Option A: Tell your controller** (recommended)
```
You:        "Spawn lobsters for alice, bob, and carol"
Controller:  Creates Slack apps → gives you install links → you click Allow for each
             → asks for app tokens → you paste them → containers launch automatically
```

**Option B: CLI**
```bash
# Create Slack apps (1 param each — auto-creates via Manifest API)
./scripts/create-slack-app.sh alice
./scripts/create-slack-app.sh bob
./scripts/create-slack-app.sh carol
# Follow the install links, get tokens, then:
./scripts/spawn-lobster.sh alice U0AAAAAAA xoxb-alice-token xapp-alice-token
./scripts/spawn-lobster.sh bob   U0BBBBBBB xoxb-bob-token   xapp-bob-token
./scripts/spawn-lobster.sh carol U0CCCCCCC xoxb-carol-token  xapp-carol-token
```

Each spawn:
1. Creates config files in `configs/<name>/`
2. Adds a service to `docker-compose.yml`
3. Starts the container

Wait for each lobster's gateway to start, then verify:

```bash
# Check all are running
docker compose ps

# Should show:
# lobster-alice   running
# lobster-bob     running
# lobster-carol   running
```

**Test it**: Open Slack, DM Alice's bot. Say "hi". You should get a response within a few seconds.

---

## Step 4: Add Company Knowledge (5 min)

Create shared knowledge that all lobsters can access:

```bash
# Company overview
cat > company-memory/about.md << 'EOF'
# About Our Company

We build [your product]. Our tech stack:
- Frontend: React + TypeScript
- Backend: Python + FastAPI
- Infrastructure: AWS, Docker, GitHub Actions

Team: Alice (frontend), Bob (backend), Carol (devops)
EOF

# Team guidelines
cat > company-memory/guidelines.md << 'EOF'
# Team Guidelines

- Code reviews required for all PRs
- Use conventional commits (feat:, fix:, chore:)
- Deploy to staging first, production after QA sign-off
- On-call rotation: weekly, see #ops channel
EOF
```

Sync to all lobsters:

```bash
./scripts/sync-fleet.sh
```

Now any lobster can answer "what's our tech stack?" or "what's the deploy process?" using shared knowledge.

---

## Step 5: Enable Self-Improving (2 min)

Copy the self-improving skill so lobsters learn from their mistakes:

```bash
cp -r templates/self-improving/ company-skills/self-improving/
./scripts/sync-company-skills.sh
```

Now when you correct a lobster ("no, we use Python 3.12, not 3.11"), it will:
1. Record the correction in `.learnings/corrections.md`
2. Periodically promote validated lessons to permanent memory
3. Never make the same mistake again

Optional: Set up the daily self-improvement scan:

```bash
# Add to crontab (runs at 04:00 UTC daily)
echo "0 4 * * * $(pwd)/scripts/trigger-2nd-me-all.sh >> /tmp/2nd-me.log 2>&1" | crontab -
```

---

## Step 6: Enable Teamind (5 min)

Give your team a collective memory — any lobster can search what was discussed in Slack channels.

```bash
cd scripts/teamind
npm install

# Initialize the database
node setup.js

# Register your main Slack channel(s)
node indexer.js --add-channel C0XXXXXXX general
node indexer.js --add-channel C0YYYYYYY engineering

# Run first index (may take a few minutes depending on channel history)
node indexer.js
```

Set up automatic indexing:

```bash
# Add to crontab
cat << 'CRON' | crontab -
# Teamind: incremental index every hour
0 * * * * cd $(pwd)/scripts/teamind && node indexer.js >> /tmp/teamind-index.log 2>&1
# Teamind: daily digest at 04:00 UTC
0 4 * * * cd $(pwd)/scripts/teamind && node digest.js >> /tmp/teamind-digest.log 2>&1
CRON
```

Now any lobster can search team history:
> "What did we decide about the API redesign last week?"

Teamind searches across all indexed channels and returns relevant thread summaries with key decisions.

---

## Step 7: Verify Everything Works (5 min)

### Health check

```bash
./scripts/health-check.sh
# Should show: ✅ alice ✅ bob ✅ carol
```

### Test each lobster

DM each bot in Slack:

1. **Basic**: "What's our tech stack?" → Should answer from company knowledge
2. **Memory**: "Remember that I prefer dark mode" → Then later: "What are my preferences?"
3. **Teamind** (if indexed): "What was discussed in #general today?"
4. **Coding**: "Use Claude Code to create a hello world Python script"

### Test isolation

- Alice's lobster should NOT know Bob's private conversations
- All lobsters SHOULD know company guidelines

---

## What's Next?

### Recommended cron jobs

```bash
# Health check every 30 min
*/30 * * * * $(pwd)/scripts/health-check.sh --auto-fix --notify

# Daily log patrol at 09:00 UTC
0 9 * * * $(pwd)/scripts/log-patrol.sh --since 24h

# Weekly backup on Sunday 03:00 UTC
0 3 * * 0 $(pwd)/scripts/backup-lobsters.sh
```

### Add more skills

Create custom skills in `company-skills/`:

```
company-skills/
├── weekly-report/
│   └── SKILL.md      # "Generate weekly report" → query your systems
├── deploy/
│   └── SKILL.md      # "Deploy to staging" → run your deploy script
└── onboarding/
│   └── SKILL.md      # "New hire checklist" → step-by-step guide
```

Run `./scripts/sync-company-skills.sh` after adding new skills.

The built-in skill templates in `templates/skills/` include goal-participant, proactive-task-engine, task-autopilot, coding-workflow, and more. Copy any you want to `company-skills/` and register in `manifest.json`.

### Try GoalOps

Give your controller a multi-person goal:

```
You: "goal: Build a customer feedback dashboard by Friday"
```

The controller will:
1. Decompose into sub-goals (backend API, frontend UI, data pipeline)
2. Assign to alice, bob, carol based on their capabilities
3. Create task board entries and Slack threads
4. Monitor progress and nudge stuck lobsters

See `templates/controller/goal-ops/SKILL.md` for the full protocol.

### Enable proactive task discovery

Add the daily cron so lobsters proactively find work:

```bash
# Add to crontab (or see crontab.example for all recommended jobs)
0 9 * * * cd $(pwd) && bash scripts/proactive-cron.sh
```

Lobsters will scan their task boards each morning and propose items they can pick up.

### Scale up

Adding more team members? Just tell your controller:

```
You: "Spawn a new lobster called dave for @dave"
```

Or use the CLI:
```bash
./scripts/create-slack-app.sh dave
./scripts/spawn-lobster.sh dave U0DDDDDDD xoxb-dave-token xapp-dave-token
```

Each lobster needs ~2-3GB RAM. A 32GB server comfortably runs 10 lobsters.

---

## Troubleshooting

### Lobster won't start

```bash
docker logs lobster-alice --tail 50
# Common: missing API key → check .env
# Common: port conflict → check docker compose ports
```

### Lobster doesn't respond in Slack

1. Check Socket Mode is enabled in Slack App settings
2. Verify the `xapp-...` token (App Token, not Bot Token)
3. Check Event Subscriptions are enabled with correct events
4. Try: `docker restart lobster-alice`

### High memory usage

```bash
./scripts/resource-monitor.sh --threshold 80
# If consistently >90%, increase container memory limit in docker-compose.yml
```

### Teamind not finding results

```bash
cd scripts/teamind
node search.js "test query" --json
# If 0 results: check that channels are registered and indexed
node indexer.js --dry-run  # preview what would be indexed
```

---

## Architecture Deep Dive

For the complete feature reference (all 24 scripts, security model, skill tiers, etc.), see:

📖 **[docs/capabilities.md](capabilities.md)**
