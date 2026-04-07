---
name: proactive-task-engine
slug: proactive-task-engine
description: "Proactive task discovery engine. Periodically scans task boards (OKR, GitHub Issues, Notion, Linear) for items the lobster can pick up, generates structured approval requests with confidence scoring. Turns lobsters from reactive responders into self-driving agents."
---

# Proactive Task Engine — Self-Driving Lobster

> Scan → Discover → Score → Propose → Execute (on approval)
>
> Instead of waiting for assignments, lobsters proactively find work they can do.

## When to Trigger

- **Cron nudge**: Controller sends a daily `[proactive-scan]` message via `proactive-cron.sh`
- **Heartbeat idle**: During heartbeat, if no active tasks and idle for >2 hours
- **Manual**: Owner says "scan for tasks" / "find something to do"

## Core Loop

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Scan Boards │ ──▶ │ Filter/Score │ ──▶ │   Propose    │
└──────────────┘     └──────────────┘     └──────────────┘
                                                 │
                                          Owner approves?
                                           │          │
                                          yes         no
                                           │          │
                                     ┌─────▼──┐  ┌───▼───┐
                                     │Execute  │  │ Skip  │
                                     └────────┘  └───────┘
```

## Phase 1: Scan

Connect to configured task boards and pull open/unassigned items.

### Supported Backends

| Backend | How to Query | Configuration |
|---------|-------------|---------------|
| Notion | Notion API — filter by Status = "Open", Assignee = empty | `config.notion.databaseId` |
| GitHub Issues | GitHub API — filter by `is:open no:assignee` | `config.github.repo` |
| Linear | Linear API — filter by unassigned, open state | `config.linear.teamId` |
| Local file | Read `tasks.json` or `TODO.md` in workspace | `config.local.path` |

### Scan Query

```
Fetch all items where:
  - Status: Open / Backlog / To Do
  - Assignee: unassigned OR assigned to me
  - Priority: any (scoring handles prioritization)
  - Updated: within last 30 days (skip stale items)
```

## Phase 2: Filter & Score

For each discovered item, compute a **fit score** (0-10):

### Scoring Criteria

| Factor | Weight | Description |
|--------|--------|-------------|
| Capability match | 40% | Does the task fall within my skill domain? |
| Priority | 25% | P0/P1 score higher than P3 |
| Effort estimate | 20% | Can I complete this within 1 work session? |
| Dependencies | 15% | Are all prerequisites met? |

### Capability Matching

Read your own `MEMORY.md` or capability profile to determine your domains:
- Code: languages, frameworks, modules you've worked on
- Research: topics you've investigated before
- Ops: infrastructure, deployment, monitoring
- Design: UI/UX, product specs

### Score Thresholds

| Score | Action |
|-------|--------|
| 8-10 | High confidence — include in proposal |
| 5-7 | Medium — include with caveats |
| 0-4 | Low — skip unless nothing else available |

## Phase 3: Propose

Generate a structured approval request for your owner (via DM or thread):

```markdown
🔍 **Proactive Task Proposal**

I scanned [Board Name] and found items I can help with:

**High Confidence (8+):**
1. 🟢 [Task Title] (Score: 9/10)
   - Why: Matches my [domain] expertise, no dependencies, ~2h effort
   - Plan: [1-2 sentence approach]

2. 🟢 [Task Title] (Score: 8/10)
   - Why: [reasoning]
   - Plan: [approach]

**Medium Confidence (5-7):**
3. 🟡 [Task Title] (Score: 6/10)
   - Why: Related to my domain but involves [unfamiliar area]
   - Plan: [approach with caveats]

Shall I proceed with any of these? Reply with numbers (e.g., "do 1 and 2")
or "skip" to pass.
```

### Proposal Rules

- Maximum 5 items per proposal (don't overwhelm)
- Always include your reasoning (why you think you can do it)
- Always include effort estimate
- If nothing scores above 5: report "scanned, nothing actionable" — don't force it

## Phase 4: Execute

On owner approval:

1. Update task board: assign to self, set status to "In Progress"
2. Execute the task using your skills and tools
3. Report progress in the relevant thread/channel
4. On completion: update board status to "Done", notify owner

## Configuration

Store in your workspace as `proactive-config.json`:

```json
{
  "enabled": true,
  "scanInterval": "daily",
  "backends": [
    {
      "type": "notion",
      "databaseId": "YOUR_DATABASE_ID",
      "filter": {
        "status": ["Open", "Backlog"],
        "assignee": ["unassigned", "self"]
      }
    }
  ],
  "capabilities": ["backend", "api-design", "data-analysis"],
  "maxProposals": 5,
  "autoExecuteThreshold": null
}
```

### Auto-Execute Mode (optional)

If owner sets `autoExecuteThreshold` (e.g., 9), tasks scoring at or above that
threshold are executed without waiting for approval. Use with caution.

## File Structure

```
skills/proactive-task-engine/
├── SKILL.md              # This file
└── references/
    └── scoring-guide.md  # Detailed scoring rubric and examples
```

## Dependencies

- Task board API access (Notion token, GitHub token, etc.)
- Read access to own capability profile / MEMORY.md
- Message tool for sending proposals to owner
