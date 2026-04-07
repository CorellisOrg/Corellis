---
name: goal-ops
slug: goal-ops
description: "Distributed goal orchestration system. Decomposes big goals into sub-goals, distributes to lobsters, monitors progress via event-driven + patrol fallback, and verifies completion. Integrates with task boards (Notion/Linear/GitHub) and messaging (Slack/Discord)."
---

# GoalOps — Distributed Goal Orchestration

> Decompose → Distribute → Monitor → Complete
>
> Event-driven coordination with patrol fallback.
> Controller decomposes goals and verifies completion.
> Lobsters execute autonomously and collaborate peer-to-peer.

## When to Use

- Multi-lobster goals requiring coordination across domains
- Tasks that need decomposition, assignment, tracking, and verification
- User says: "goal: XXX" / "execute goal: XXX" / "complete XXX"

**Not for**: Single-lobster simple tasks (use direct conversation or task-autopilot)

## Architecture

```
                    ┌──────────────┐
                    │  Controller  │
                    │  (you)       │
                    └──────┬───────┘
              Decompose    │    Verify
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │ Lobster A│◄──►│ Lobster B│◄──►│ Lobster C│
    │  (SG-1)  │    │  (SG-2)  │    │  (SG-3)  │
    └──────────┘    └──────────┘    └──────────┘
         P2P collaboration (direct @mentions)
```

**Controller responsibilities**: Decompose goals, create task board entries, distribute to lobsters, patrol for stuck tasks, verify acceptance criteria, generate completion reports.

**Lobster responsibilities**: Receive sub-goals, decompose into subtasks, execute, update task board, report progress, collaborate with other lobsters directly.

## Configuration

```json
{
  "channel": "YOUR_CHANNEL_ID",
  "taskBoard": {
    "provider": "notion",
    "databaseId": "YOUR_DATABASE_ID",
    "dataSourceId": "YOUR_DATASOURCE_ID"
  },
  "moduleMapping": "path/to/module-owners.md",
  "stateFile": "skills/goal-ops/state/goals.json",
  "botIdMapping": "path/to/bot-id-mapping.md"
}
```

## Phase 1: Decompose

### Input
User provides: goal description, optional deadline, key results, constraints.

### Steps

1. **Parse goal** — Extract objective, deadline, KRs, constraints
2. **Read team capabilities** — Load module-owners mapping to know who can do what
3. **Break into sub-goals (SGs)** — By functional domain, not by workflow phase
   - Each SG: clear description, assignee(s), acceptance criteria, effort estimate, dependencies
4. **Coverage self-check** — All SGs complete → does the big goal succeed? Any gaps? Overlap?
5. **Present goal tree** to user for confirmation:

```
🎯 Goal: [GOAL-ID] Description (deadline: YYYY-MM-DD)

├── SG-1: [Description] → @lobster-a
│   Acceptance: [criteria]
│   Depends: none
│
├── SG-2: [Description] → @lobster-b
│   Acceptance: [criteria]
│   Depends: SG-1
│
└── SG-3: [Description] → @lobster-c @lobster-d
    Acceptance: [criteria]
    Depends: none

✅ Coverage check: passed
```

6. **Wait for user confirmation** before proceeding

### Goal ID Format
`GOAL-YYYYMMDD-NNN` (e.g., `GOAL-20260314-001`)

## Phase 2: Distribute

After user confirms:

### 2.1 Create State Record

Write to `state/goals.json`:
```json
{
  "goals": {
    "GOAL-20260314-001": {
      "description": "...",
      "status": "active",
      "createdAt": "2026-03-14T08:00:00Z",
      "deadline": "2026-03-20",
      "subGoals": {
        "SG-1": {
          "description": "...",
          "assignees": ["lobster-a"],
          "status": "open",
          "threadId": null,
          "acceptance": ["criteria1", "criteria2"]
        }
      }
    }
  }
}
```

### 2.2 Create Task Board Entries

Create a milestone entry for the goal, plus one entry per SG:
- Milestone: goal title, deadline, KRs
- SG entries: description, assignee, acceptance criteria, Goal ID tag

### 2.3 Distribute via Messaging

Post one message per SG in the coordination channel thread:

```markdown
🎯 *[GOAL-ID / SG-N] Sub-goal description*

*Goal*: GOAL-ID — Goal description
*Assigned*: @lobster-a (lead) @lobster-b (support)
*Deadline*: YYYY-MM-DD
*Acceptance Criteria*:
- Criterion 1
- Criterion 2

*Dependencies*:
- Requires SG-M completion (@lobster-c)
- OR: No dependencies, start immediately

*Task Board*: [link to board entry]

<!-- goal-meta
{"goalId":"GOAL-ID","sgId":"SG-N","assignee":"name","deadline":"YYYY-MM-DD","dependencies":[],"downstream":["SG-X"],"acceptance":["criterion1","criterion2"]}
-->

Please reply with:
1. ✅ Confirmation + your task breakdown
2. Update task board status as you progress
3. @controller when complete for acceptance
```

Record each message's thread ID in `state/goals.json`.

### 2.4 Notify User

```
✅ Goal GOAL-ID launched!
- N sub-goals distributed
- Task board entries created
- Lobsters notified

Monitor: "GOAL-ID progress?" or check task board
```

## Phase 3: Monitor

### 3.1 Event-Driven (Primary)

Lobsters collaborate peer-to-peer — they @ each other directly for coordination.

**Lobsters @ controller only for:**
1. **Acceptance**: SG complete, requesting verification
2. **Blocking**: Can't resolve without controller help
3. **Decisions**: Confidence ≤ 5 on an important choice

**On receiving @mention from lobster:**
- Acceptance request → verify criteria → approve/reject → notify downstream
- Help request → diagnose → resolve or escalate
- Decision request → evaluate → confirm or redirect

### 3.2 Patrol Fallback (Secondary)

Bash script runs periodically (cron every 30-60 min). $0 cost when everything is normal.

**`scripts/patrol.sh` logic:**
1. Read `state/goals.json` — skip if no active goals
2. For each active SG: query task board for current status
3. Compare with last snapshot (`state/last-snapshot.json`)
4. Detect anomalies:

| Anomaly | Action |
|---------|--------|
| Status changed | Log it, notify downstream if dependency unlocked |
| Silent >2h, status incomplete | @ lobster in thread asking for update |
| Deadline <4h away, status still Open | Urgent nudge |
| Lobster waiting on dependency | Push the dependency provider, not the waiter |

5. If anomalies found → output `ANOMALY_DETECTED` → trigger AI to handle
6. If all normal → output `NORMAL` → exit (no AI cost)

### 3.3 Adjustments

Trigger replanning when:
- Task exceeds estimate by >50%
- Acceptance criteria can't be met as written
- External requirements changed
- A lobster reports infeasibility

Adjustment steps:
1. Explain the change in the relevant thread
2. Update task board entries
3. Update `state/goals.json`
4. Notify affected lobsters
5. Notify user if scope/deadline changes

## Phase 4: Complete

### 4.1 Completion Check

When all SGs report done:
1. Verify each SG's acceptance criteria are met
2. Check: do all completed SGs together satisfy the original goal?
3. If gaps remain → create additional SGs or adjust

### 4.2 Completion Report

Send to user:
```markdown
✅ Goal Complete — GOAL-ID

🎯 Goal: [description]
📅 Timeline: [start] → [end] (planned X days, actual Y days)

📊 Sub-goals:
├── ✅ SG-1: [description] (@lobster-a) — [key outcome]
├── ✅ SG-2: [description] (@lobster-b) — [key outcome]
└── ✅ SG-3: [description] (@lobster-c) — [key outcome]

📈 Key Results:
- KR1: [target] → [actual] ✅/❌
- KR2: [target] → [actual] ✅/❌

📝 Lessons:
- [What went well]
- [What to improve]

🔗 Task Board: [filtered link]
```

### 4.3 Archive

- Update `state/goals.json`: status → `completed`
- Archive execution log to `state/archive/GOAL-ID.md`
- Write lessons to daily log

## User Commands

| Command | Action |
|---------|--------|
| "goal: XXX" | Start Phase 1 (decompose) |
| "GOAL-ID progress?" | Show current status of all SGs |
| "pause GOAL-ID" | Pause monitoring, notify lobsters |
| "adjust GOAL-ID: ..." | Replan |
| "cancel GOAL-ID" | Cancel goal, notify lobsters, archive |

## Thread Rules

- **All SG communication happens in the goal's main thread** (or one thread per SG, configurable)
- Do not create new channel-level messages for SG updates
- Only humans can initiate new threads in the channel

## File Structure

```
skills/goal-ops/
├── SKILL.md                    # This file
├── scripts/
│   ├── patrol.sh               # Bash patrol script (cron, $0 when idle)
│   └── check-progress.sh       # Quick progress summary
├── state/
│   ├── goals.json              # Active goal state
│   ├── last-snapshot.json      # Last task board snapshot (for diff)
│   └── archive/                # Completed goal logs
├── templates/
│   ├── goal-tree.md            # Goal tree display template
│   ├── sg-message.md           # SG distribution message template
│   └── completion-report.md    # Completion report template
└── references/
    ├── state-schema.md         # Full state file JSON schema
    └── lobster-protocol.md     # What lobsters must do (→ goal-participant skill)
```

## Dependencies

- Messaging channel with bot access (Slack, Discord, etc.)
- Task board API (Notion, Linear, GitHub Issues)
- Module-owners mapping file
- Bot ID mapping file (for correct @mentions)
- goal-participant skill installed on lobsters
- Patrol cron job configured (see `crontab.example`)
