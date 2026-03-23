# 🦞 Corellis

[![Stars](https://img.shields.io/github/stars/CorellisOrg/corellis?style=social)](https://github.com/CorellisOrg/corellis)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![OpenClaw](https://img.shields.io/badge/Built%20on-OpenClaw-blue)](https://openclaw.ai)
[![CI](https://github.com/CorellisOrg/corellis/actions/workflows/ci.yml/badge.svg)](https://github.com/CorellisOrg/corellis/actions/workflows/ci.yml)

> **We run a 28-lobster AI team that handles ops, marketing, releases, and weekly reports. This is the system behind it.**

Turn one [OpenClaw](https://openclaw.ai) assistant into a self-managing AI workforce — lobsters that coordinate tasks, learn from their mistakes, and get better every week.

**Production-tested since February 2026** · 28 lobsters · 50,000+ Slack messages indexed · 500+ self-corrections · single server

---

## A Real Example

Last month we tested fleet-wide goal coordination for the first time. The founder typed one message:

> *"Launch a user acquisition campaign for the new product line."*

Here's what happened over the next 2 hours — with zero human intervention after that single message:

1. **The controller** decomposed the goal into 6 sub-goals and created a milestone + 7 tracking cards on the task board
2. **6 lobsters were assigned** — marketing, engineering, payments, ops, partnerships, frontend — each in a dedicated thread
3. **All 6 confirmed** within minutes, following the goal-participant protocol: analyze scope → break into subtasks → define acceptance criteria
4. **Spontaneous cross-team coordination emerged** — the payments lobster and the partnerships lobster started aligning on API design in their thread (4 rounds of back-and-forth). The marketing lobster and the ops lobster resolved scope boundaries on their own
5. **One lobster independently created 5 subtask cards** with goal IDs, owners, dependencies, and deadlines — without being asked

**Result:** 36 task cards on the board — 1 milestone, 7 sub-goals, 28 self-created subtasks. Two cross-team interfaces aligned. All from one sentence.

![Demo: Lobsters coordinate on a goal](docs/demo.gif)

---

## How It Works

Each team member gets their own AI assistant (a "lobster") running in a Docker container — with private memory and conversations. Behind the scenes, they share company knowledge and a searchable team memory.

```
┌─────────────────────────────────────────────┐
│  Your Server                                │
│                                             │
│  🎛️ Controller (your OpenClaw)              │
│  "Spawn a lobster for alice"                │
│                                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│  │ 🦞 alice │ │ 🦞 bob   │ │ 🦞 carol │   │
│  │ Marketing│ │ Ops      │ │ Finance  │   │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘   │
│       └─────────────┴─────────────┘         │
│         Shared knowledge & team memory      │
└─────────────────────────────────────────────┘
```

| Just OpenClaw | OpenClaw + Corellis |
|---|---|
| 1 AI assistant for you | 1 AI assistant **per team member** |
| Your personal memory | **4-layer memory**: personal → member → channel → company |
| You know what you discussed | **Teamind**: search all team discussions semantically |
| You learn from your mistakes | **Fleet learning**: one lobster's lesson promotes to all |
| Manual setup per person | **One command** to spawn a new lobster |

---

## Key Capabilities

### 🧠 Teamind — Collective Team Memory
Every Slack conversation is indexed with embeddings. Any lobster can search *"what did we decide about the pricing model?"* and get accurate, sourced answers — across all channels, all history.

### 🧬 Self-Improving Lobsters
Lobsters detect when they're corrected, record the lesson, and permanently improve. Validated patterns promote fleet-wide — one lobster's mistake becomes every lobster's knowledge.

### 🎯 GoalOps — Goals, Not Instructions
Give your controller a high-level goal. It decomposes into sub-goals, assigns to lobsters, and they self-coordinate — with P2P handoffs, dependency tracking, and human-in-the-loop approval for sensitive actions.

### 📋 Task Management
Unified task board with sprint planning, breakdown, and tracking. Backend-agnostic: works with Notion, Linear, GitHub Projects, or plain markdown.

### 🐣 30-Second Spawning
Tell your controller *"spawn a lobster for alice"* — it creates the Slack app, handles OAuth, and launches the container. You click Allow and paste one token.

### 📦 17 Built-in Skills
Deep research, SEO monitoring, landing page optimization, weekly reports, structured decision alignment, approval workflows, Excalidraw diagrams, data dashboards, and more. See [`templates/skills/`](templates/skills/).

### 🔄 Fleet Operations
Rolling upgrades with canary + auto-rollback. Config broadcasting. Health checks. Credential management. Gateway watchdogs. 24 operational scripts — all battle-tested.

---

## Get Started

**Prerequisites:** [OpenClaw](https://openclaw.ai) on your host machine + Docker

```bash
git clone https://github.com/CorellisOrg/corellis.git
cd corellis
cp .env.example .env           # add your LLM API key
docker compose up -d           # launch your first lobster
```

> **Note:** Each lobster needs a Slack bot app. Run `./scripts/create-slack-app.sh <name>` to create one automatically, or see [Slack Bot Setup](docs/slack-bot-setup.md) for manual setup.

**→ Full walkthrough: [Tutorial: Set Up a 3-Person Team in 30 Minutes](docs/tutorial-3-person-team.md)**

---

## Production Evidence

This isn't a weekend project. Corellis has been running continuously since February 2026:

| Metric | Value |
|--------|-------|
| Fleet size | 28 lobsters on a single server (64GB RAM, 16 vCPU) |
| Teamind indexed | 50,000+ Slack messages across 30+ channels |
| Self-improving cycles | 500+ corrections detected and persisted |
| Goals executed | 200+ goals decomposed and coordinated |
| Skills deployed | 17 fleet-wide + custom per-lobster skills |

The 24 operational scripts and Teamind modules were built iteratively from real production needs — not designed in a vacuum.

---

## Architecture

<details>
<summary>Controller on host + lobsters in Docker containers</summary>

The **controller** runs on the host (not in Docker) — it manages containers and writes to shared directories. Each **lobster** runs in an isolated Docker container with read-only access to shared knowledge.

```
┌──────────────────────────────────────────────────┐
│  Host Machine                                     │
│                                                   │
│  🎛️ Controller (OpenClaw on host)                 │
│  ├── Manages Docker containers                    │
│  ├── Writes company-skills/, company-memory/      │
│  └── Runs spawn, broadcast, sync, health-check    │
│                                                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐         │
│  │ 🦞 alice │ │ 🦞 bob   │ │ 🦞 carol │         │
│  │ (Docker) │ │ (Docker) │ │ (Docker) │         │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘         │
│       │             │             │               │
│  ┌────┴─────────────┴─────────────┴────┐         │
│  │  Shared Volumes (bind mount, ro)    │         │
│  │  company-memory/ company-skills/    │         │
│  │  company-config/ shared-knowledge   │         │
│  └─────────────────────────────────────┘         │
│                                                   │
│  Each lobster also has private rw storage:        │
│  configs/<name>/workspace/ → ~/.openclaw/         │
└──────────────────────────────────────────────────┘
```

**Why the controller isn't in Docker:** It needs to run `docker compose`, manage host files, and execute fleet scripts. Docker-in-Docker adds complexity with no benefit.

</details>

## Developer Reference

Looking for the full technical details? Everything from the README is documented in depth:

| | |
|---|---|
| 📖 [Complete Capabilities](docs/capabilities.md) | All 24 scripts, memory architecture, security model, cron schedules |
| 🏗️ [Architecture Deep Dive](ARCHITECTURE.md) | Design philosophy, system layers, GoalOps sequence diagrams |
| 🔧 [Slack Bot Setup](docs/slack-bot-setup.md) | Create Slack apps (automated or manual) |
| 📋 [Operational Guides](docs/guides/) | 2nd Me setup, ACP sessions, GitHub tokens, credentials, audits |
| 🚀 [Tutorial: 3-Person Team](docs/tutorial-3-person-team.md) | End-to-end walkthrough, zero to running |

<details>
<summary>All 24 operational scripts</summary>

### Core Operations
| Script | Description |
|--------|-------------|
| `create-slack-app.sh` | Auto-create Slack App via Manifest API |
| `spawn-lobster.sh` | Create a new lobster container |
| `health-check.sh` | Check gateway, Slack, disk, memory for all lobsters |
| `rolling-upgrade.sh` | Upgrade image with canary testing and auto-rollback |

### Fleet Management
| Script | Description |
|--------|-------------|
| `apply-fleet-config.sh` | Deep-merge JSON patches into all lobster configs |
| `sync-fleet.sh` | Push skills, memory, and API keys to all lobsters |
| `broadcast.sh` | Send message via AI session (lobster reformulates) |
| `broadcast-direct.sh` | Send message via Slack API (100% reliable) |

### Maintenance
| Script | Description |
|--------|-------------|
| `config-watchdog.sh` | Dead-man switch: auto-rollback if not cancelled |
| `gateway-watchdog.sh` | Cron job: restart gateway if unhealthy |
| `enable-acp.sh` | Enable Claude Code/ACP on a specific lobster |
| `patch-all.sh` | Apply all OpenClaw patches (idempotent) |

</details>

<details>
<summary>Governance framework</summary>

Corellis includes a governance framework so your fleet operates as a coherent organization:

| Template | Purpose |
|----------|---------|
| `AGENTS.md` | Company-wide rules: session startup, memory management, correction detection, security |
| `REGISTRY.md` | Master index of all shared resources |
| `DIRECTORY.md` | Path/permission mapping for all shared directories |
| `PLAYBOOK-SPEC.md` | Standard format for operational playbooks |

Place them in `company-config/` on the host → bind-mounted read-only into every lobster → consistent behavior fleet-wide.

</details>

<details>
<summary>Secrets management</summary>

Each lobster gets two secret files:

- **`secrets.json`** (read-only) — Shared API keys injected at spawn time
- **`personal-secrets.json`** (read-write) — Per-lobster private credentials

OpenClaw's SecretRef system (`{"$ref": "secrets://KEY"}`) keeps secrets out of config files.

</details>

---

## Alternatives

| Approach | Corellis Difference |
|----------|-------------------|
| **CrewAI / AutoGen** | They orchestrate tasks. Corellis orchestrates an **organization** — persistent lobsters with memory, identity, and relationships |
| **ChatDev / MetaGPT** | Code-generation focused. Corellis is **general-purpose**: ops, marketing, research, finance, anything |
| **Multiple separate assistants** | No coordination. Corellis adds **shared knowledge, Teamind, fleet learning, and GoalOps** |
| **Enterprise AI platforms** (Glean, Moveworks) | SaaS, closed-source. Corellis is **self-hosted, MIT licensed, fully customizable** |

## Requirements

- [OpenClaw](https://openclaw.ai) on the host machine
- Docker + Docker Compose
- Slack workspace with bot apps (one per lobster)
- 2GB RAM per lobster (3GB with Claude Code)

## Links

- 🌐 [corellis.ai](https://corellis.ai)
- 📖 [OpenClaw Documentation](https://docs.openclaw.ai)
- 💬 [OpenClaw Community](https://discord.com/invite/clawd)
- 🐛 [Issues & Feature Requests](https://github.com/CorellisOrg/corellis/issues)

## License

MIT
