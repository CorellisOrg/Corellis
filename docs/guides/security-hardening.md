# Security Hardening Guide

Best practices for securing your Corellis deployment.

## Secrets Management

### Never hardcode secrets
- Use `secrets.json` as the single source of truth for all API keys and tokens
- Reference secrets via `SecretRef` in `openclaw.json` — never put keys in `env` directly
- Keep `secrets.json` with `chmod 600` (owner read/write only)

### Secret rotation
```bash
# Update a key across controller + all lobsters in one command
bash scripts/update-key.sh API_KEY_NAME "new-value"

# Audit current secret distribution
bash scripts/update-key.sh --audit
```

### What goes where
| Type | Location | Example |
|------|----------|---------|
| API keys | `secrets.json` → SecretRef | `BRAVE_API_KEY`, `SLACK_BOT_TOKEN` |
| SDK env vars | `openclaw.json` env | `AWS_REGION`, `AZURE_ENDPOINT` |
| Multi-value configs | `.env.*` files (bind mount) | `.env.mysql`, `.env.appsflyer` |
| OAuth tokens | Dedicated config files | `~/.config/notion/api_key` |

## Container Isolation

### Read-only mounts
Company config and knowledge base should be mounted read-only:
```yaml
volumes:
  - ./company-config:/shared/company-config:ro
  - ./company-memory:/shared/company:ro
  - ./company-skills:/home/lobster/.openclaw/workspace/company-skills:ro
```

### Resource limits
Always set CPU and memory limits per container:
```yaml
deploy:
  resources:
    limits:
      cpus: "1.5"
      memory: 2G
```

### No privileged mode
- Never run lobster containers with `--privileged`
- Only mount the Docker socket if the container genuinely needs it (controller only)
- Use specific capabilities instead: `--cap-add=SYS_PTRACE` only if needed for debugging

## Network Security

### Firewall rules
- Expose only necessary ports (gateway, canvas)
- Use security groups / iptables to restrict access by source IP
- Keep management ports (SSH, admin) restricted to VPN or specific IPs

### Internal communication
- Lobsters communicate via Slack API (external) — no direct container-to-container networking needed
- If using internal APIs, bind to `127.0.0.1` or container network only

## Access Control

### Owner-only operations
These must be restricted to the fleet owner:
- Container lifecycle (start/stop/restart/delete)
- Spawning new lobsters
- Gateway configuration changes
- Broadcast messages to all lobsters
- System-level operations (package install, firewall, SSH)
- Cron job management

### Lobster self-service
Lobsters may be allowed to:
- Restart their own container (verify sender identity matches container owner)
- Read shared knowledge base
- Submit skills for review (not deploy directly)

## Audit & Monitoring

### Log what matters
- Credential access and rotation events
- Container lifecycle events (start/stop/restart)
- Failed authentication attempts
- Outbound message sends (who sent what where)

### Periodic checks
Add to your `HEARTBEAT.md` or cron:
- Verify `secrets.json` permissions are still `600`
- Check for containers running without resource limits
- Scan for hardcoded secrets in workspace files
- Review outbound message logs for anomalies

## Privacy

### Privacy lists
- Maintain a privacy configuration for lobsters whose activity should be invisible
- Private lobsters must not appear in any output — not listed, not counted, not explained

### DM isolation
- Owner DM content must never be mentioned in channels or to other users
- Each team member's memory file is isolated — no cross-reading

## Backup

### What to back up
| Data | Priority | Frequency |
|------|----------|-----------|
| `secrets.json` | Critical | After every change |
| `state/goals.json` | High | Daily |
| `company-config/` | High | Weekly |
| `company-skills/` | Medium | Weekly |
| Lobster workspace files | Medium | Weekly |
| Container images | Low | After rebuilds |

### Backup script
```bash
# Daily backup of critical state
tar czf /data/backups/corellis-$(date +%Y%m%d).tar.gz \
  secrets.json \
  state/ \
  company-config/ \
  company-skills/

# Keep last 30 days
find /data/backups -name "corellis-*.tar.gz" -mtime +30 -delete
```
