# Monitoring & Alerting Templates

## Overview

Pre-built monitoring configurations for your Corellis fleet.
Copy and customize for your needs.

## Health Check Alert Template

### Slack Alert Format

```markdown
🔴 **Fleet Health Alert**

| Lobster | Issue | Since |
|---------|-------|-------|
| lobster-alice | Container stopped | 10:30 UTC |
| lobster-bob | Gateway unresponsive (HTTP 502) | 10:25 UTC |

**Auto-fix attempted**: ✅ lobster-alice restarted successfully
**Needs attention**: lobster-bob — gateway restart failed

Run `bash scripts/health-check.sh --verbose` for details.
```

### Alert Thresholds

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| Container status | Restarting | Stopped | Auto-restart → notify if fails |
| Memory usage | >80% | >90% | Notify → investigate leaks |
| CPU usage | >70% sustained | >90% sustained | Notify → check for loops |
| Disk usage | >80% | >90% | Clean logs → notify |
| Gateway response | >5s latency | No response | Auto-restart → notify |
| Restart frequency | >2 in 1h | >5 in 1h | Stop auto-restart → investigate |

## Resource Monitor Dashboard

### Quick Status Script

```bash
#!/usr/bin/env bash
# fleet-status.sh — One-line-per-lobster status
echo "LOBSTER           CPU%  MEM     STATUS"
echo "─────────────────────────────────────────"

for container in $(docker ps --filter "name=lobster-" --format '{{.Names}}' | sort); do
  stats=$(docker stats --no-stream --format '{{.CPUPerc}}\t{{.MemUsage}}' "$container" 2>/dev/null)
  status=$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null)
  printf "%-20s %s\t%s\n" "$container" "$stats" "$status"
done
```

### Log Pattern Alerts

```bash
#!/usr/bin/env bash
# log-alerts.sh — Scan all lobster logs for concerning patterns

PATTERNS=(
  "FATAL"
  "OOMKilled"
  "ECONNREFUSED"
  "rate.limit"
  "ENOMEM"
  "disk.full"
)

for container in $(docker ps --filter "name=lobster-" --format '{{.Names}}'); do
  for pattern in "${PATTERNS[@]}"; do
    count=$(docker logs "$container" --since 24h 2>&1 | grep -ci "$pattern" || true)
    if [ "$count" -gt 0 ]; then
      echo "⚠️ $container: $count occurrences of '$pattern' in last 24h"
    fi
  done
done
```

## Cron-Based Monitoring

### Recommended Schedule

```bash
# Quick health check — every 15 min
*/15 * * * * bash scripts/health-check.sh --auto-fix --notify 2>&1 | grep -v "OK"

# Resource monitoring — every hour
0 * * * * bash scripts/resource-monitor.sh --threshold 80

# Log patrol — twice daily
0 9,18 * * * bash scripts/log-patrol.sh --since 12h --notify-owner

# Weekly audit — Monday 08:00 UTC
0 8 * * 1 bash scripts/cron-audit.sh
```

## Integration Points

### Webhook Notifications

Send alerts to external systems:

```bash
# Generic webhook (Slack, Discord, PagerDuty, etc.)
notify_webhook() {
  local message="$1"
  local webhook_url="${ALERT_WEBHOOK_URL:-}"
  
  if [ -n "$webhook_url" ]; then
    curl -s -X POST "$webhook_url" \
      -H "Content-Type: application/json" \
      -d "{\"text\": \"$message\"}"
  fi
}

# Usage in health check
if [ "$STATUS" = "critical" ]; then
  notify_webhook "🔴 Critical: $LOBSTER is down"
fi
```

### Metrics Collection

For Prometheus/Grafana setups, expose metrics:

```bash
# Export as Prometheus text format
echo "# HELP corellis_lobster_status Lobster container status (1=running, 0=stopped)"
echo "# TYPE corellis_lobster_status gauge"
for container in $(docker ps -a --filter "name=lobster-" --format '{{.Names}}'); do
  status=$(docker inspect --format '{{.State.Running}}' "$container" 2>/dev/null)
  value=$( [ "$status" = "true" ] && echo 1 || echo 0 )
  echo "corellis_lobster_status{name=\"$container\"} $value"
done
```
