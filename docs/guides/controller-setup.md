# Controller Setup Guide

## Overview

A **controller lobster** is a special lobster that can manage the entire fleet from inside Docker. It has the same capabilities as a regular lobster, plus:

- 🔌 **Docker socket access** — can spawn, stop, restart, and upgrade other lobsters
- 📁 **Farm directory mounted** at `/farm/` — full access to configs, scripts, and compose files
- 📝 **Read-write company-config** — can update fleet policies without host access

## When to Use

| Scenario | Recommendation |
|----------|---------------|
| Personal use, 2-3 lobsters | Controller in Docker (this guide) |
| Team use, 5+ lobsters | Controller on host (more secure) |
| Enterprise / strict security | Controller on host with RBAC |

## Quick Start

```bash
# 1. Make sure you have docker-compose.yml ready
cp docker-compose.base.yml docker-compose.yml  # if not already done

# 2. Spawn the controller
./scripts/spawn-controller.sh lilshell U0XXXXXXXXX xoxb-your-bot-token xapp-your-app-token

# 3. Spawn regular lobsters (can be done from host OR from the controller)
./scripts/spawn-lobster.sh alice U0YYYYYYYYY xoxb-alice-bot-token xapp-alice-app-token
```

## Architecture

```
┌──────────────────────────────────────────────┐
│  Host Machine                                │
│                                              │
│  docker-compose.yml                          │
│  ┌────────────────┐  ┌────────────────┐      │
│  │  Controller 🎛️  │  │  Lobster A 🦞  │     │
│  │  /farm/ (rw)   │  │  /shared/ (ro) │      │
│  │  docker.sock   │  │  workspace     │      │
│  │  company-config│  └────────────────┘      │
│  │  (rw)          │  ┌────────────────┐      │
│  │                │  │  Lobster B 🦞  │      │
│  │  Can manage ──────▶  /shared/ (ro) │      │
│  │  all containers│  │  workspace     │      │
│  └────────────────┘  └────────────────┘      │
└──────────────────────────────────────────────┘
```

## What the Controller Can Do

Once running, tell the controller lobster in Slack:

- *"Show me fleet status"* → runs `docker ps` and reports
- *"Spawn a new lobster named bob"* → runs `spawn-lobster.sh`
- *"Restart alice"* → runs `docker compose restart lobster-alice`
- *"Check fleet health"* → runs `health-check.sh`
- *"Upgrade all lobsters"* → runs `rolling-upgrade.sh`
- *"Broadcast: meeting at 3pm"* → runs `broadcast.sh`

## Security Considerations

⚠️ **Docker socket = root access.** The controller container can:
- Start/stop any container on the host
- Mount any host directory
- Execute commands as root via Docker

**Mitigations:**
1. The controller runs as the `lobster` user (non-root) inside the container
2. Only the fleet owner (configured `SLACK_USER_ID`) can send commands
3. The AGENTS.md rules require confirmation before destructive operations

**For higher security:**
- Run the controller on the host instead of in Docker
- Use Docker socket proxies (e.g., [Tecnativa/docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy)) to limit API access
- Enable OpenClaw exec approvals for sensitive commands

## Differences from Regular Lobsters

| Feature | Regular Lobster | Controller |
|---------|----------------|------------|
| Docker management | ❌ | ✅ via socket |
| Farm directory | ❌ | ✅ at `/farm/` |
| company-config | Read-only | Read-write |
| Fleet scripts | ❌ | ✅ at `/farm/scripts/` |
| `LOBSTER_ROLE` env | *(unset)* | `controller` |
| Default AGENTS.md | Basic | Fleet management rules |

## Promoting an Existing Lobster

If you already have lobsters running and want to promote one to controller,
you'll need to update its service definition in `docker-compose.yml` to add
the controller-specific volumes. See `spawn-controller.sh` for the exact
volume mounts needed.

## Notes

- **Bind mount changes are live.** When the controller edits `company-config/` files,
  all other lobsters see the changes immediately (they mount the same host directory).
  No restart needed for file content changes.
- **Docker Compose changes require restart.** If the controller edits `docker-compose.yml`
  (e.g., adding a new lobster), it needs to run `docker compose up -d` to apply.
