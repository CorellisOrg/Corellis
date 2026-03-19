---
name: non-blocking-wait
description: "Avoid long waits that block the session. Any operation requiring wait times exceeding 10 seconds (monitoring PRs, waiting for CI, waiting for approval, waiting for issue generation, etc.) must use subagent or cron for asynchronous processing, immediately returning control to the user. Use when: any scenario requiring polling/waiting/monitoring."
---

# Non-Blocking Wait

## ⛔ Absolutely Forbidden

- `sleep N` (N > 10) then check results
- `exec` with extremely long `timeout` for polling
- `process poll` with extremely long `timeout` waiting for background tasks
- Any blocking operations that prevent the session from responding to user messages

## Key Principles

> **Never let a session block while waiting for a result.**
> **Users may send new messages at any time, and the session must always be able to respond.**

---

## ✅ Solution 1: Subagent (Recommended)

Spawn a child agent responsible for waiting + polling + subsequent operations, while the main session returns immediately.

### Advantages
- Child agent has complete tool capabilities (exec, message, cron, etc.)
- Can execute complex multi-step follow-up logic (not just notifications)
- Automatically notifies main session upon completion
- Main session can check progress via `subagents list`, adjust direction with `subagents steer`

### Pattern

```
1. Execute trigger operation (e.g., create release branch)
2. sessions_spawn a subagent with task description:
   - What to poll (e.g., check issues)
   - Polling interval (e.g., every 60s)
   - Success condition (e.g., find 2 Release Approval issues)
   - What to do on success (e.g., send message to channel @alice)
   - Timeout condition (e.g., notify user if not found within 30 minutes)
3. Immediately reply to user: "Background monitoring started, will notify you when complete"
```

### Example: Waiting for Release Approval Issues

```
sessions_spawn:
  task: |
    Monitor your-org/your-backend Release Approval Issues generation.
    Execute every 60s:
    gh api "repos/your-org/your-backend/issues?state=all&sort=created&direction=desc&per_page=5" \
      --jq '.[] | select(.title | startswith("Release Approval")) | ...'
    
    After finding 2 issues matching PR #8406:
    1. Use message tool to send to CXXXXXXXXXX channel, @UXXXXXXXXXX for review
    2. Task complete
    
    If not found after 30 minutes → DM U08738HSXEY to remind manual check
  mode: run
```

### Example: Monitoring PR Review Status

```
sessions_spawn:
  task: |
    Monitor PR #8406 review status. Check every 60s:
    gh pr view 8406 --repo your-org/your-backend --json state,reviewDecision,mergeable
    
    - reviewDecision=APPROVED + mergeable=MERGEABLE → DM U08738HSXEY to confirm merge
    - state=CLOSED/MERGED → end
    - After 3 hours → DM reminder
  mode: run
```

---

## ✅ Solution 2: Cron

Suitable for simple periodic check scenarios (only needs notifications, no complex follow-up logic).

### Pattern

```
1. Execute trigger operation
2. Create cron job (systemEvent) for periodic trigger checks
3. Immediately reply to user
4. When cron triggers:
   - Condition met → execute operation + delete cron
   - Not met → NO_REPLY
   - Timeout → notify user + delete cron
```

### Cron Design Principles
- Interval ≥ 60s
- Write termination conditions and timeout in cron text
- Each trigger is idempotent

---

## Selection Guide

| Scenario | Recommended Solution | Reason |
|----------|---------------------|---------|
| Multi-step operations after wait | Subagent | Child agent can chain multiple steps |
| Simple status notifications | Cron | Lightweight, doesn't occupy session |
| Background coding tasks | Subagent/Background exec + auto-notify | CC has built-in system event notifications |
| Very long waits (>1h) | Cron | Subagent may timeout |

## Applicable Scenarios

- PR review / CI monitoring
- Release Approval Issue waiting
- Deployment status checks
- Background coding agent execution
- Any "do A, wait for result, then do B" workflows