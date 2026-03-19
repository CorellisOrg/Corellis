# Bottleneck Reporting Skill

> When you detect a work blocker during conversation, automatically log it to the shared queue for the controller to analyze.

## What Counts as a Bottleneck?

A blocker in the workflow that significantly reduces productivity:

- **Repeated failures**: Same operation attempted ≥3 times without success
- **Process blocked**: Can't proceed to the next step
- **Waiting on dependencies**: Need another person, system, or approval
- **Missing information**: Can't make a decision without key info
- **Tool/system failures**: API errors, environment issues, outages
- **Knowledge gaps**: Don't know how to proceed, no docs available

## When to Trigger

**Proactive detection**: Don't wait for the user to say "I'm stuck." If you sense a blocker during conversation, log it.

Signals:
- Visible frustration or repeated attempts in conversation
- You yourself can't resolve the issue for the user
- Progress stalled beyond expected timeframe
- Needs escalation to someone else

## Logging Process

### Step 1: Write to Shared Queue

Write directly to `/shared/bottleneck-inbox/` (shared writable mount). Filename format:

```
<your-lobster-name>-YYYY-MM-DD-brief-description.md
```

Example: `alice-2026-03-02-payment-api-timeout.md`

Template:

```markdown
# [Brief description]

> Summary: [One-line description]
> Keywords: bottleneck, [relevant business keywords]
> Logged: YYYY-MM-DD HH:MM UTC
> User: [user name]
> Lobster: [your name]

---

## Description
[Detailed description of the blocker]

## Context
[What were they trying to do? Business context?]

## Attempted Solutions
- [Attempt 1: what was tried, what happened]
- [Attempt 2: what was tried, what happened]

## Current Status
[Where are things stuck? Any workaround in place?]

## Suggested Category
- [ ] Common issue (others likely to encounter)
- [ ] Isolated issue (specific to this scenario)
- [ ] Tool/system issue
- [ ] Knowledge/documentation gap
- [ ] Process inefficiency
```

### Step 2: Inform the User

After logging, tell the user:
> "I've logged this blocker to the shared queue. The controller will analyze it — common issues get added to the company knowledge base, individual issues get escalated."

## Notes

- **Don't wait for the user to ask** — detect proactively
- **One file per blocker** — don't combine multiple issues
- If the blocker gets resolved during conversation, still log it (mark "resolved") for pattern analysis
- Write path: `/shared/bottleneck-inbox/`, not your local workspace
- The controller polls the queue every 5 minutes automatically
