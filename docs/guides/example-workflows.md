# Example Workflows Gallery

Real-world workflow patterns you can implement with Corellis.

## 1. Weekly Status Report

**Trigger**: Cron every Friday at 16:00 UTC

```
Controller → each lobster: "Summarize your week"
  ↓
Each lobster reads their daily logs → generates summary
  ↓
Controller collects all summaries → formats combined report
  ↓
Posts to #weekly-updates channel
```

**Skills used**: `weekly-report` template skill

---

## 2. Incident Response

**Trigger**: Alert detected (monitoring webhook or manual "@controller incident: X")

```
Controller decomposes:
  SG-1: @ops-lobster → investigate root cause
  SG-2: @frontend-lobster → check user-facing impact
  SG-3: @comms-lobster → draft status page update
  ↓
Lobsters execute in parallel, report in thread
  ↓
Controller verifies fix + comms → posts all-clear
```

**Skills used**: `goal-ops`, `goal-participant`

---

## 3. New Feature Development

**Trigger**: "goal: Build user invite system"

```
Phase 1 — Controller decomposes:
  SG-1: @design-lobster → product spec + UI mockup
  SG-2: @backend-lobster → API design + implementation
  SG-3: @frontend-lobster → UI implementation
  SG-4: @qa-lobster → test plan + execution
  ↓
Phase 2 — Sequential with P2P coordination:
  SG-1 completes → notifies SG-2 and SG-3
  SG-2 and SG-3 align on API contract directly
  SG-2 + SG-3 complete → SG-4 starts testing
  ↓
Phase 3 — QA verifies on preview environment
  ↓
Phase 4 — Controller accepts → merge + deploy
```

**Skills used**: `goal-ops`, `coding-workflow`, `task-autopilot`

---

## 4. Onboarding New Team Member

**Trigger**: "Spawn a lobster for dave"

```
Controller:
  1. Creates Slack app (create-slack-app.sh)
  2. Spawns container (spawn-lobster.sh)
  3. Syncs company skills + config
  ↓
Dave's lobster first session:
  - Reads BOOTSTRAP.md → sets up identity
  - Loads company-config/AGENTS.md → knows the rules
  - Loads company-memory → has team context
  ↓
Dave's lobster is immediately useful:
  - Knows team conventions and tech stack
  - Can search team history via Teamind
  - Follows governance rules from day one
```

---

## 5. Daily Standup Automation

**Trigger**: Cron daily at 09:00 UTC

```
Controller → proactive-cron.sh → nudge all lobsters
  ↓
Each lobster:
  1. Scans task board for assigned items
  2. Checks yesterday's daily log for carryover
  3. Posts status update in team channel:
     "Done: X, Y. Today: Z. Blocked: none"
```

**Skills used**: `proactive-task-engine`, `task-management`

---

## 6. Knowledge Base Maintenance

**Trigger**: Weekly heartbeat check

```
Controller scans:
  - Bottleneck inbox → common patterns?
  - Self-improvement logs → fleet-wide lessons?
  - Shared knowledge → outdated entries?
  ↓
Actions:
  - Promote common bottleneck solutions to company-memory
  - Promote validated self-improvement lessons fleet-wide
  - Archive stale entries
  - Generate "This Week I Learned" digest
```

---

## 7. Competitive Intelligence

**Trigger**: "Monitor competitor X" (sets up news-beacon scene)

```
Daily cron:
  news-beacon scans 8 sources (HN, Reddit, Twitter, news, web...)
  ↓
  AI scores relevance and novelty
  ↓
  Generates structured briefing
  ↓
  Posts to designated channel
```

**Skills used**: `news-beacon` (if installed), `deep-research`

---

## Building Your Own Workflows

1. **Identify the pattern**: Is it a one-shot task, recurring job, or multi-step goal?
2. **Choose the mechanism**:
   - One-shot → direct conversation or `task-autopilot`
   - Recurring → cron + heartbeat
   - Multi-step → `goal-ops`
3. **Create a skill** if you'll reuse it: `company-skills/<name>/SKILL.md`
4. **Register** in `manifest.json` and sync to fleet
