# DIRECTORY.md — Lobster Farm Directory Index

> Purpose, permissions, and container paths for each file/directory. This file must be updated synchronously when modifying directory structure.

---

## 📂 Shared Directories (bind mount to all lobsters)

| Host Path | Container Path | Permissions | Purpose |
|-----------|----------------|-------------|---------|
| `company-config/` | `/shared/company-config/` | **ro** | Company policy files (AGENTS.md etc.), read-only immutable |
| `company-memory/` | `/shared/company/` | **ro** | Company knowledge base (INDEX.md, business knowledge docs), read-only |
| `company-skills/` | `~/workspace/company-skills/` | **ro** | Company shared skills (mysql, observability etc.), read-only |
| `shared-knowledge.md` | `/shared/shared-knowledge.md` | **rw** | Company-wide shared knowledge (lobsters can append), **independent of company-config** |
| `bottleneck-inbox/` | `/shared/bottleneck-inbox/` | **rw** | Bottleneck report inbox, lobsters write, control center polls |
| `skill-submissions/` | `/shared/skill-submissions/` | **rw** | Lobsters submit personal skills to company library |

## 📂 Individual Lobster Configuration

| Host Path | Container Path | Permissions | Purpose |
|-----------|----------------|-------------|---------|
| `configs/<name>/openclaw.json` | `~/.openclaw/openclaw.json` | **ro** | Lobster Gateway configuration (Slack token, models etc.) |
| `configs/<name>/workspace/` | `~/.openclaw/workspace/` | **rw** | Lobster personal workspace (AGENTS.md, MEMORY.md etc.) |
| Docker volume `lobster-<name>-data` | `~/.openclaw/` | **rw** | Lobster persistent data (sessions, logs etc.) |

## 📂 Infrastructure Files (host-only, not mounted into containers)

| Path | Purpose |
|------|---------|
| `Dockerfile.lite` | Docker image definition (OpenClaw + Chrome + VNC + ACP) |
| `docker-compose.yml` | Container orchestration (auto-maintained by spawn-lobster.sh) |
| `entrypoint.sh` | Container entry script (starts OpenClaw + Chrome + VNC + noVNC) |
| `fleet-config.json` | Lobster fleet metadata (names, ports, owners etc.) |
| `scripts/` | Management scripts (spawn, backup, broadcast, upgrade etc.) |
| `secrets/` | Sensitive credential storage |
| `credentials.json` | Credential configuration |
| `logs/` | Lobster log collection |
| `friction-reports/` | User friction point reports |

## 🔑 Permission Design Principles

1. **Policy files (company-config) = read-only**: Maintained by control center, lobsters cannot modify
2. **Knowledge base (company-memory) = read-only**: Maintained by control center, lobsters access via semantic search
3. **Shared knowledge (shared-knowledge.md) = writable**: Independent file, not placed in any :ro directory
4. **Bottleneck reports (bottleneck-inbox) = writable**: Lobsters write, control center polls and processes
5. **Personal workspace = writable**: Autonomously managed by lobsters
6. **Gateway configuration = read-only**: Prevents lobsters from tampering with their own configuration

---

_Last updated: 2026-03-03_
_Must synchronously update this file and spawn-lobster.sh when modifying directory structure_