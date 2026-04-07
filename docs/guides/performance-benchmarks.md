# Performance Benchmarks

## Fleet Sizing Reference

Tested on a single server: 64 GB RAM, 16 vCPU (AWS m5.4xlarge equivalent).

### Container Overhead

| Metric | Per Lobster (idle) | Per Lobster (active) | Per Lobster (ACP) |
|--------|--------------------|---------------------|-------------------|
| RAM | 400 MB | 800 MB | 1.5-2.5 GB |
| CPU | <1% | 5-15% | 20-40% (burst) |
| Disk | 200 MB | 500 MB | 1-2 GB |
| Startup time | 8-12s | — | — |

### Fleet Capacity

| Server Size | Lobsters (no ACP) | Lobsters (with ACP) | Recommended Max |
|-------------|-------------------|---------------------|-----------------|
| 8 GB / 4 vCPU | 5-8 | 2-3 | 5 |
| 16 GB / 8 vCPU | 10-15 | 5-7 | 10 |
| 32 GB / 16 vCPU | 20-25 | 10-12 | 20 |
| 64 GB / 16 vCPU | 30-40 | 15-20 | 28 |

> "Recommended Max" leaves headroom for spikes and controller overhead.

### Response Latency

Average time from Slack message received to reply sent:

| Scenario | P50 | P95 | Notes |
|----------|-----|-----|-------|
| Simple chat reply | 3s | 8s | Single LLM call |
| Tool use (1 tool) | 5s | 12s | LLM + tool + LLM |
| Web search + synthesis | 8s | 20s | Search + fetch + LLM |
| ACP code task | 30s | 120s | Spawn + execute + verify |
| Goal decomposition | 15s | 45s | Complex reasoning |

### Teamind Performance

| Operation | Dataset: 10K msgs | Dataset: 50K msgs |
|-----------|-------------------|-------------------|
| Incremental index (100 new msgs) | 15s | 15s |
| Full reindex | 8 min | 40 min |
| Semantic search | 200ms | 500ms |
| Daily digest (1 lobster) | 5s | 8s |

### GoalOps Timing

| Phase | Typical Duration |
|-------|-----------------|
| Decomposition (5 SGs) | 30-60s |
| Distribution (5 threads) | 10-15s |
| Patrol check (no anomaly) | 2s (bash only) |
| Patrol check (with AI) | 8-15s |
| Acceptance verification | 15-30s per SG |

## Bottleneck Analysis

### Common Bottlenecks

| Bottleneck | Symptom | Fix |
|-----------|---------|-----|
| RAM pressure | OOM kills, swap thrashing | Reduce lobster count or upgrade RAM |
| LLM rate limits | 429 errors, queue buildup | Spread requests, use multiple keys |
| Slack API limits | Message send failures | Batch messages, add delays |
| Disk I/O | Slow container starts | Move Docker data to SSD |
| Network | High search latency | Cache results, reduce external calls |

### Scaling Inflection Points

| Lobsters | What Changes |
|----------|-------------|
| 1-5 | Everything works out of the box |
| 5-15 | Need resource limits, monitoring, shared caches |
| 15-25 | Need Brave Search key management, RAM optimization |
| 25-50 | Consider multi-machine, dedicated controller |
| 50+ | Kubernetes or equivalent orchestration recommended |

## How to Run Your Own Benchmarks

```bash
# Container startup time
time docker run --rm lobster-openclaw:latest echo "ready"

# Memory baseline
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}' \
  $(docker ps --filter "name=lobster-" -q)

# Response latency (requires a test message)
START=$(date +%s%N)
# Send test message via Slack API and measure response
END=$(date +%s%N)
echo "Latency: $(( (END - START) / 1000000 )) ms"
```
