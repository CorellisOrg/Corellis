# Cost Optimization Guide

## Understanding Your Costs

### Cost Breakdown by Component

| Component | Driver | Typical Cost | Optimization |
|-----------|--------|-------------|--------------|
| LLM API calls | Token usage per lobster | 60-80% of total | Model routing, caching |
| Server compute | RAM + CPU per lobster | 15-25% of total | Right-sizing, scheduling |
| Slack API | Message volume | Usually free tier | Batch operations |
| External APIs | Brave Search, Apify, etc. | 5-10% of total | Caching, rate limiting |

### Per-Lobster Cost Estimate

| Usage Level | Monthly LLM Cost | Description |
|-------------|-----------------|-------------|
| Light | $5-15 | Occasional questions, simple tasks |
| Moderate | $15-50 | Daily use, research, code review |
| Heavy | $50-150 | ACP coding, deep research, goal-ops |

## LLM Cost Optimization

### Model Routing

Use cheaper models for routine tasks, expensive models for complex ones:

| Task Type | Recommended Model | Why |
|-----------|------------------|-----|
| Heartbeat checks | Haiku / small model | Routine, low complexity |
| Patrol scripts | Haiku (only on anomaly) | $0 cost when normal |
| Code review | Sonnet / mid-tier | Balance of quality and cost |
| Complex reasoning | Opus / large model | Worth the cost for accuracy |
| Embeddings | text-embedding-3-small | Cheapest option, good enough |

### Reduce Unnecessary Token Usage

1. **Heartbeat efficiency**: Return `HEARTBEAT_OK` immediately when nothing to do (no AI call)
2. **Patrol scripts**: Use bash to detect anomalies first, only call AI when needed
3. **Context management**: Keep MEMORY.md under 4KB; prune old daily logs
4. **Batch operations**: Combine multiple checks into one heartbeat cycle

### Caching Strategy

```
First request: web_search("latest React version") → cache result
Same day repeat: read cache → skip API call
```

Cache candidates:
- Web search results (TTL: 24h)
- Task board queries (TTL: 5 min)
- Team capability lookups (TTL: 1h)

## Compute Optimization

### Right-Size Containers

| Lobster Type | CPU | RAM | Notes |
|-------------|-----|-----|-------|
| Chat-only | 0.5 | 1 GB | No ACP, no browser |
| Standard | 1.0 | 2 GB | Most lobsters |
| ACP-enabled | 1.5 | 3 GB | Claude Code / Codex |
| Heavy compute | 2.0 | 4 GB | Data analysis, rendering |

### Schedule Non-Critical Lobsters

If some lobsters are only needed during work hours:

```bash
# Stop non-essential lobsters at night (save RAM)
0 22 * * * docker stop lobster-intern lobster-qa-helper

# Start them in the morning
0 8 * * 1-5 docker start lobster-intern lobster-qa-helper
```

### Shared Caches

Mount shared caches to avoid duplicate downloads:

```yaml
volumes:
  - /data/go-mod-cache:/usr/local/go-tools/pkg/mod:ro
  - /data/go-build-cache:/home/lobster/.cache/go-build
  - /data/npm-cache:/home/lobster/.npm
```

## External API Optimization

### Brave Search

- Free tier: 2,000 queries/month
- Paid: $5/month for 20,000 queries
- **Tip**: With 20+ lobsters sharing one key, you'll hit limits fast. Consider per-lobster rate limiting.

### Apify

- Pay-per-use for Reddit/Twitter scraping
- **Tip**: Cache results aggressively. Same query within 1h → use cache.

## Monitoring Costs

### Track Token Usage

Add to your daily report:
```
📊 Daily Cost Summary
- Total tokens: 1.2M input, 300K output
- Estimated cost: $8.50
- Top consumer: lobster-alice (goal-ops heavy)
- Cheapest: lobster-intern (chat only, $0.30)
```

### Cost Alerts

Set up alerts when daily spend exceeds threshold:
```bash
# In health check or daily cron
DAILY_LIMIT=50  # dollars
if [ "$TODAY_COST" -gt "$DAILY_LIMIT" ]; then
  notify_owner "⚠️ Daily LLM spend: \$$TODAY_COST (limit: \$$DAILY_LIMIT)"
fi
```

## Quick Wins

1. **Switch patrol to bash** — $0 when everything is normal
2. **Use Haiku for heartbeats** — 10x cheaper than Opus
3. **Prune context** — smaller MEMORY.md = fewer tokens per call
4. **Cache web searches** — most results are valid for hours
5. **Stop idle lobsters** — if they're not being used, stop the container
