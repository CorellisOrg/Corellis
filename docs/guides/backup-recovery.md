# Backup & Recovery Guide

## What to Back Up

| Data | Priority | Frequency | Why |
|------|----------|-----------|-----|
| `secrets.json` | 🔴 Critical | After every change | All API keys — unrecoverable if lost |
| `state/goals.json` | 🔴 Critical | Daily | Active goal tracking state |
| `company-config/` | 🟡 High | Weekly | Fleet governance rules |
| `company-skills/` | 🟡 High | Weekly | Shared skill definitions |
| `company-memory/` | 🟡 High | Weekly | Knowledge base |
| Lobster workspaces | 🟡 High | Weekly | Personal memory, daily logs |
| Container images | 🟢 Low | After rebuilds | Can rebuild from Dockerfile |
| `docker-compose.yml` | 🟢 Low | After changes | Can regenerate from configs |

## Automated Backup Script

```bash
#!/usr/bin/env bash
# backup.sh — Daily backup of critical fleet data
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/data/backups}"
DATE=$(date +%Y%m%d-%H%M)
ARCHIVE="$BACKUP_DIR/corellis-$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"

# Critical + high priority data
tar czf "$ARCHIVE" \
  --exclude='*.log' \
  --exclude='node_modules' \
  --exclude='.git' \
  secrets.json \
  state/ \
  company-config/ \
  company-skills/ \
  company-memory/ \
  configs/

echo "✅ Backup created: $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"

# Retention: keep last 30 days
find "$BACKUP_DIR" -name "corellis-*.tar.gz" -mtime +30 -delete
echo "🧹 Old backups cleaned (>30 days)"
```

Add to crontab:
```bash
0 4 * * * cd /path/to/corellis && bash scripts/backup.sh >> /tmp/corellis-backup.log 2>&1
```

## Recovery Procedures

### Scenario 1: Single Lobster Lost

If a lobster's workspace is corrupted or deleted:

```bash
# 1. Find latest backup
ls -la /data/backups/corellis-*.tar.gz | tail -5

# 2. Extract just that lobster's config
tar xzf /data/backups/corellis-YYYYMMDD-HHMM.tar.gz configs/<name>/

# 3. Restart the lobster
docker restart lobster-<name>
```

### Scenario 2: Secrets Lost

```bash
# 1. Extract secrets from backup
tar xzf /data/backups/corellis-YYYYMMDD-HHMM.tar.gz secrets.json

# 2. Fix permissions
chmod 600 secrets.json

# 3. Redistribute to lobsters
bash scripts/update-key.sh --audit  # verify all keys present
```

### Scenario 3: Full Server Recovery

```bash
# 1. Install prerequisites
# - Docker + Docker Compose
# - OpenClaw (npm install -g openclaw)
# - Mount data volume

# 2. Restore from backup
tar xzf /data/backups/corellis-YYYYMMDD-HHMM.tar.gz

# 3. Rebuild containers
docker compose up -d

# 4. Verify health
bash scripts/health-check.sh --verbose

# 5. Apply patches (if OpenClaw was reinstalled)
bash scripts/patch-all.sh
```

### Scenario 4: Corrupted State

If `goals.json` or other state files are corrupted:

```bash
# 1. Check for recent valid state
git log --oneline state/  # if state is in git

# 2. Or restore from backup
tar xzf /data/backups/corellis-YYYYMMDD-HHMM.tar.gz state/

# 3. Verify JSON validity
python3 -c "import json; json.load(open('state/goals.json'))"
```

## Best Practices

1. **Test restores periodically** — a backup you've never tested is not a backup
2. **Keep offsite copies** — S3, another server, or encrypted cloud storage
3. **Never backup secrets to public repos** — use `.gitignore` for `secrets.json`
4. **Log backup results** — so you know immediately when backups fail
5. **Version your docker-compose.yml** — keep it in git so you can recreate the fleet
