---
name: approval-flow
slug: approval-flow
description: "Universal approval flow framework — receives structured proposals, sends to Slack channel/DM/thread, parses human approval commands (execute/partial execute/skip/reject), callbacks to execution chain. All scenario SKILLs requiring human approval should call this atomic capability, don't implement approval logic yourself."
metadata:
  openclaw:
    emoji: "✅"
    tier: base
    requires:
      bins: ["curl"]
---

# Approval Flow — Universal Approval Flow Framework

> **Atomic Capability**: Any scenario requiring "proposal→human approval→execution" should reuse this SKILL, don't write your own approval parsing logic.

---

## Responsibility Boundaries

| This SKILL is Responsible for | This SKILL is NOT Responsible for |
|-------------------------------|-----------------------------------|
| Format proposal messages | Generate proposal content (provided by scenario SKILL) |
| Send to specified Slack target | Decide which channel to send to (specified by scenario SKILL) |
| Parse approval replies | Specific execution logic (callback to scenario SKILL) |
| Manage approval status | Business priority decisions |

---

## Input Specification

When scenario SKILLs call approval-flow, provide the following structured input:

```json
{
  "proposal_id": "unique-id",
  "target": {
    "type": "channel | dm | thread",
    "channel_id": "CXXXXXXXXXX",
    "thread_ts": "optional-thread-ts",
    "user_id": "optional-for-dm"
  },
  "content": {
    "title": "🚨 SEO Alert — 2026-03-18",
    "body": "Formatted proposal body (Slack mrkdwn)",
    "items": [
      {"id": "①", "label": "Optimize ai-voice-generator page", "priority": "high"},
      {"id": "②", "label": "Competitor analysis report", "priority": "medium"}
    ],
    "footer": "Confirm execution? (or adjust priority)"
  },
  "config": {
    "timeout_hours": 24,
    "reminder_hours": 4,
    "auto_reject_on_timeout": true,
    "allow_partial": true
  }
}
```

**Minimum Required**: `target` + `content.body` + `content.footer`. Other fields have defaults.

---

## Approval Command Parsing Rules

Parsing rules for human replies (matched by priority):

| Human Says | Parsed As | Execution Scope |
|------------|-----------|-----------------|
| "do" / "execute" / "start" / "confirm" / "go" / "approved" | `APPROVE_ALL` | Execute all items |
| "execute ①②" / "do 1 and 3" / "only do ①" | `APPROVE_PARTIAL` | Execute only specified items |
| "skip ③" / "don't do ③" | `APPROVE_EXCEPT` | Execute all except specified |
| "don't do" / "skip" / "cancel" / "reject" / "never mind" | `REJECT` | Don't execute |
| "do ③ first" / "③ priority" | `APPROVE_REORDER` | Execute all, adjust order |
| Additional info (non-command) | `INFO_UPDATE` | Don't execute, update proposal context |
| Timeout with no reply | `TIMEOUT` | Handle per config |

### Parsing Logic

```
1. Remove @mentions, emoji, whitespace
2. Check if contains explicit rejection words → REJECT
3. Check if contains item references (①②③ or 1/2/3 or #1/#2) → PARTIAL/EXCEPT/REORDER
4. Check if contains affirmative words → APPROVE_ALL
5. No matches → INFO_UPDATE (treat as additional info, don't execute)
```

**Key Principle**: Better to mistakenly judge as INFO_UPDATE (don't execute) than APPROVE (incorrect execution).

---

## Output Specification

After parsing approval, output structured result for scenario SKILL use:

```json
{
  "proposal_id": "unique-id",
  "decision": "APPROVE_ALL | APPROVE_PARTIAL | APPROVE_EXCEPT | APPROVE_REORDER | REJECT | TIMEOUT | INFO_UPDATE",
  "approved_items": ["①", "②"],
  "rejected_items": ["③"],
  "reorder": ["③", "①", "②"],
  "raw_reply": "do ③ first, then ①②",
  "additional_info": "Additional info provided by human (if any)"
}
```

---

## Usage (Scenario SKILL Perspective)

### Send Proposal

After scenario SKILL prepares proposal content, send using this template:

```
# In your scenario SKILL:

1. Prepare proposal content (your business logic)
2. Organize data per this SKILL's input specification
3. Use message tool to send to target (channel/DM/thread)
4. Add standard footer at end of message:
   "Confirm execution? (reply 'do' to execute all / 'execute ①②' for partial / 'don't do' to skip)"
5. Record proposal status as pending
```

### Parse Reply

After receiving human reply, process per this SKILL's parsing rules:

```
1. Read reply text
2. Match per "Approval Command Parsing Rules" table
3. Output structured decision
4. Based on decision type:
   - APPROVE_* → Call scenario SKILL's execution logic
   - REJECT → Record skip, notify scenario SKILL
   - INFO_UPDATE → Update context, wait for next reply
   - TIMEOUT → Handle per config
```

### State Management

```json
// Approval state file: <scenario-skill>/state/approval-state.json
{
  "pending": false,
  "last_proposal_id": "seo-alert-20260318",
  "last_proposal_time": "2026-03-18T08:00:00Z",
  "last_decision": "APPROVE_PARTIAL",
  "today_proposals": 1,
  "max_daily_proposals": 3
}
```

**Anti-spam Rules**:
- `pending == true` → Don't send new proposals (wait for previous approval)
- `today_proposals >= max_daily_proposals` → No more sends today
- Same content won't repeat within 24h (idempotent)

---

## Standard Footer Templates

Scenario SKILLs should uniformly use at proposal end:

**Simple Version** (when no numbered items):
```
Confirm execution? (reply 'do' to execute / 'don't do' to skip)
```

**Full Version** (when numbered items exist):
```
Confirm execution? (reply 'do' to execute all / 'execute ①②' for partial / 'don't do' to skip)
```

---

## Relationship with Scenario SKILLs

```
Scenario SKILL (proactive / seo-agent / prod-release / ...)
  ├→ Business logic (perception/decision/priority)
  ├→ approval-flow (proposal sending + approval parsing + state management)
  └→ Execution layer (their respective downstream SOPs)
```

This SKILL is a pure **process framework**, containing no business logic.

---

_Atomic Capability · 2026-03-18_