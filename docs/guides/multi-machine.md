# Multi-Machine Deployment Guide

## When to Scale Beyond One Server

| Signal | Threshold |
|--------|-----------|
| RAM usage | >85% sustained |
| Lobster count | >15 per machine (with ACP) |
| Response latency | Noticeable slowdown during peak |
| Reliability needs | Can't tolerate single point of failure |

## Architecture Options

### Option 1: Horizontal Split (Recommended)

Split lobsters across machines by team/function:

```
┌─────────────────────┐     ┌─────────────────────┐
│  Server A            │     │  Server B            │
│  🎛️ Controller       │     │                      │
│  🦞 alice (ops)      │     │  🦞 dave (marketing)  │
│  🦞 bob (eng)        │     │  🦞 eve (finance)     │
│  🦞 carol (design)   │     │  🦞 frank (support)   │
└─────────┬───────────┘     └──────────┬──────────┘
          │                            │
          └──────── Slack API ─────────┘
          (coordination via messages)
```

**Pros**: Simple, each server is independent, lobsters communicate via Slack (already works)
**Cons**: Controller only on one machine, manual sync needed

### Setup Steps

1. **Server A (primary)**: Full Corellis install with controller
2. **Server B**: Corellis install, lobsters only (no controller)
3. **Shared config**: Sync `company-*` directories via rsync/S3
4. **Shared secrets**: Distribute `secrets.json` securely to each server

```bash
# On Server B — sync shared resources from Server A
rsync -avz serverA:/path/to/company-config/ ./company-config/
rsync -avz serverA:/path/to/company-skills/ ./company-skills/
rsync -avz serverA:/path/to/company-memory/ ./company-memory/
```

### Option 2: Controller + Workers

Dedicated controller server with worker servers for lobsters:

```
┌──────────────┐
│  Controller   │ ◄── SSH/API ──► ┌──────────┐
│  (management) │                  │ Worker 1  │
│  No lobsters  │                  │ 10 lobsters│
└──────────────┘                  └──────────┘
                                  ┌──────────┐
                 ◄── SSH/API ──► │ Worker 2  │
                                  │ 10 lobsters│
                                  └──────────┘
```

**Implementation**: Controller uses SSH or Docker remote API to manage workers.

### Option 3: Kubernetes (Advanced)

For large-scale deployments (50+ lobsters):

- Each lobster = a Pod with persistent volume
- Company resources = ConfigMaps/Secrets
- Controller = Deployment with RBAC
- Horizontal Pod Autoscaler for demand-based scaling

> ⚠️ K8s adds significant complexity. Only recommended if you already have K8s infrastructure.

## Shared State Sync

### Company resources (config, skills, memory)

| Method | Latency | Complexity |
|--------|---------|------------|
| rsync cron (5 min) | ~5 min | Low |
| S3 + sync script | ~2 min | Medium |
| NFS mount | Real-time | Medium (network dependency) |
| Git pull | On-demand | Low |

### Secrets

- **Never sync secrets over unencrypted channels**
- Use: `scp` with SSH key, encrypted S3, or secrets manager (Vault, AWS SM)
- Each server has its own `secrets.json` with the same content

## Monitoring Across Machines

```bash
# Health check all servers (run from controller)
for server in serverA serverB; do
  echo "=== $server ==="
  ssh $server "cd /path/to/corellis && bash scripts/health-check.sh"
done
```

## Capacity Planning

| Resource | Per Lobster | Per Lobster + ACP |
|----------|------------|-------------------|
| RAM | ~1.5 GB | ~3 GB |
| CPU | 0.5 cores | 1.5 cores |
| Disk | ~500 MB | ~2 GB |
| Network | Minimal | Minimal |

**Example**: 64 GB RAM server → ~20 lobsters with ACP, ~40 without.
