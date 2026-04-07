# Heartbeat Checklist — Controller Auto-Pilot

Run through this checklist every 2-3 hours during active periods.
Skip during quiet hours (23:00-08:00 UTC) unless urgent.

## 1. Goal Patrol (highest priority when goals are active)

- Read `skills/goal-ops/state/goals.json`
- For each `status: "active"` goal:

### 1a. Unanswered @mentions (top priority)
- Read each SG thread's latest messages
- Check if any lobster @mentioned you without a reply
- Acceptance requests → verify and respond immediately
- Help requests → diagnose and resolve (decide what you can; escalate only what you can't)

### 1b. Stuck detection
- Read each active SG thread's **last message** (not first)
- Stuck criteria (based on thread's last message timestamp):
  - Thread silent >2h AND status not complete → nudge in thread
  - <4h before SG deadline AND status still Open → urgent nudge
  - Lobster waiting on external dependency → push the dependency, not the lobster
- Before nudging: read last 10 messages to confirm it's truly stalled

### 1c. Progress check
- Run `scripts/patrol.sh` or check task board
- Flag: overdue? stalled? blocked?
- Anomalies → @ the relevant lobster in thread

## 2. Skill Submissions

- Run `bash scripts/poll-skill-submissions.sh`
- New submissions → run review, notify owner for approval

## 3. Bottleneck Inbox

- Check `bottleneck-inbox/` for new escalations
- Unresolved items → triage and route to the right lobster or owner

## 4. Memory Maintenance (at least once per day)

- Read recent `memory/YYYY-MM-DD.md` daily logs
- Check for unsynchronized items:
  - New API keys/credentials → update MEMORY.md + TOOLS.md
  - New tools/integrations → update TOOLS.md
  - Important decisions → distill into MEMORY.md
- Create today's daily log if it doesn't exist

## 5. Health Checks

- Run `memory_search("health check test")` — verify embedding search works
  - If `disabled` or `error` → alert owner immediately
- Spot-check 1-2 lobster containers: `docker inspect lobster-<name>`
  - Not running → attempt restart, log the event

## 6. Cron Audit (weekly, Mondays)

- Check `reports/cron-audit-*.json` for this week's report
- Error rate >50% for any lobster → notify owner with summary

## Notes

- If nothing needs attention → reply HEARTBEAT_OK
- Batch related checks together to minimize API calls
- Log significant findings to today's daily log
