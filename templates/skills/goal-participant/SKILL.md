---
name: goal-participant
slug: goal-participant
description: "Goal collaboration participant protocol. Automatically triggered when you are @mentioned in Slack channels/threads with messages containing [SG-X], Goal ID, or goal-meta tags. Defines standard processes for task reception, execution reporting, cross-lobster coordination, and task board synchronization."
---

# Goal Participant Skill — Goal Collaboration Participant

## When to Trigger

When a message that @mentions you meets **any** of the following conditions, act according to this protocol:

1. Message contains sub-goal number starting with `[SG-` (e.g., `[SG-2]`)
2. Message contains goal identifier with `Goal ID:` or `GOAL-` prefix
3. Message contains structured metadata block with `<!-- goal-meta`
4. The parent message of the thread you're in meets the above conditions
5. Master control (Master Control / U0CONTROLLER) @mentions you in goal-related threads

## Core Principles

- **You are the executor**, master control is the coordinator. Master control breaks down goals, assigns tasks, tracks progress; you're responsible for receiving, executing, and reporting.
- **All communication within threads**. The message where you receive the task is your thread, don't go to the main channel message area.
- **Proactive reporting, don't wait to be asked**. Report progress, call out blockers, announce completion.
- **Cross-lobster collaboration uses @mention**. Need alignment? Directly @ the other lobster with Goal ID context.

---

## Phase 1: Task Reception

When you are @mentioned and receive a sub-goal task, follow these steps:

> ⏰ **Response Time**: Add ✅ reaction to confirm you've seen the message at the next heartbeat, reply with complete task breakdown in the thread within 30 minutes.

### 1.1 Parse Task Information

Extract from message:

| Field | Source | Example |
|-------|--------|---------|
| Goal ID | Message text or goal-meta | `GOAL-20260314-001` |
| SG Number | Message title | `SG-2` |
| Deadline | Message text | `3/15` |
| Acceptance Criteria | Message body | Specific deliverable list |
| Dependencies | Message body | `Start after SG-1 completion` |
| Downstream | Message body | `SG-3 needs your API docs` |
| Collaborators | Other lobsters @mentioned in message | `@alice-clawd align interface` |

If the message contains `<!-- goal-meta ... -->` block, prioritize parsing JSON for structured data.

### 1.2 Confirm Receipt

Reply in thread with format:

```
✅ Received!

**Task**: [SG-X] Task Name
**Deadline**: YYYY-MM-DD
**Understood Acceptance Criteria**:
1. ...
2. ...

**My Task Breakdown**:
1. [ ] Sub-step 1 (estimated time)
2. [ ] Sub-step 2 (estimated time)
3. [ ] Sub-step 3 (estimated time)

**Dependencies Confirmed**: [Ready / Waiting for SG-X]
**Expected Completion**: YYYY-MM-DD HH:MM
```

Also add ✅ reaction to parent message.

### 1.3 Update Task Board

If task board information is provided in the message:

> **📋 Operation Method**: Execute according to operation templates in `company-skills/task-management/SKILL.md (read the active backend)`.
> - Find your tasks: Query by "by assignee + this week"
> - Update status: Use "update task status" template, `Open` → `In Progress`
> - Write notes: Use "update notes" template, input task breakdown

---

## Phase 2: Task Execution

### 2.1 Normal Execution

Complete tasks according to your professional capabilities. This part has no fixed format, based on actual needs:
- Write code/design documents/test cases/tracking schemes etc.
- Use all tools you have permission for (search, browser, exec, ACP etc.)

### 2.2 Progress Reporting

**Upon completing each sub-step** or **having important output**, report in thread:

```
📊 Progress Update [SG-X]

**Completed**:
- ✅ Sub-step 1: [Brief description of output]
- ✅ Sub-step 2: [Brief description of output]

**In Progress**:
- 🔄 Sub-step 3: [Current status]

**Progress**: X/Y steps completed (approximately XX%)
**Expected Completion**: Unchanged / Ahead / Delayed to XX

<!-- goal-update
{"sgId":"SG-X","status":"in_progress","progress":60,"blockers":[],"deliverables":["API Design Document"]}
-->
```

### 2.3 When Blocked

If blocked by dependencies from other SGs, encountering technical issues, or needing decisions:

```
🚧 Blocked [SG-X]

**Blocking Reason**: [Specific description]
**Impact**: [If not resolved, will lead to...]
**Need**: [@Master Control / @another-lobster] [What specifically is needed]
**Suggested Solution**: [If any]

<!-- goal-update
{"sgId":"SG-X","status":"blocked","progress":40,"blockers":["Waiting for SG-1 design mockups"]}
-->
```

### 2.4 Cross-Lobster Collaboration

When needing to align with other lobsters, directly message @mention them in **the same channel**:

```
@alice-clawd Regarding [SG-2] invite API interface design, need to align with you (SG-3 frontend):

1. POST /api/invite/generate — Generate invite link
   - Request: { user_id }
   - Response: { invite_code, invite_url, qr_code_url }

2. GET /api/invite/records — Query invite records
   - Request: { user_id, page, limit }
   - Response: { records: [...], total_earned, remaining_cap }

Are all the fields you need here? Anything to add?

(Goal: GOAL-20260314-001)
```
**Rules**:
- Collaboration messages must include Goal ID so the other party's skill can identify context
- @mention in thread or channel both work, but discussions for the same SG should stay in the same thread when possible
- After the other party replies, sync conclusions back to your own thread
---

## Phase 3: Task Completion

### 3.1 Completion Report

After all acceptance criteria are met, in the thread:

```
🎉 Completed [SG-X]

**Deliverables**:
1. ✅ [Deliverable1]: [Link/Description]
2. ✅ [Deliverable2]: [Link/Description]

**Acceptance Criteria Verification**:
- ✅ Criteria1: [How it's satisfied]
- ✅ Criteria2: [How it's satisfied]

**Time Spent**: X hours
**Notes**: [Any items that need attention]

@Master Control Task completed, please confirm ✅

<!-- goal-update
{"sgId":"SG-X","status":"done","progress":100,"blockers":[],"deliverables":["API Documentation","Interface Implementation","Unit Tests"]}
-->
```

### 3.2 Update Task Board

> **📋 Operation Method**: Use "update task status" template in `company-skills/task-management/SKILL.md (read the active backend)` to change status to `Done`; use "update notes" template to input deliverable links + completion time.

### 3.3 Notify Downstream

If your task has downstream dependencies (will be mentioned in message), proactively @ downstream lobsters:

```
@alice-clawd [SG-2] Backend API completed ✅

Your SG-3 frontend can start now, API documentation here: [link]
Key interfaces:
- POST /api/invite/generate
- GET /api/invite/records
- GET /api/invite/energy-balance

@ me anytime if you have questions 🦞

(Goal: GOAL-20260314-001, Dependency unlocked: SG-2 → SG-3)
```

---

## Phase 4: Being Collaboration Requested

When other lobsters @ you in goal context:

1. **Identify context**: Find Goal ID and SG number from message
2. **Reply in same thread** (if exists) or in channel (if new topic)
3. **Reply with substantial content**: Answer questions / confirm interfaces / provide feedback
4. **If not within your responsibility scope**: Explain and suggest @mentioning the correct lobster

---

## goal-meta Protocol (Optional)

If master control embeds structured metadata in message:

```html
<!-- goal-meta
{
  "goalId": "GOAL-20260314-001",
  "sgId": "SG-2",
  "assignee": "eve",
  "deadline": "2026-03-15",
  "dependencies": ["SG-1"],
  "downstream": ["SG-3", "SG-4"],
  "taskBoardId": "YOUR-DATABASE-ID",
  "taskPageId": "YOUR-PAGE-ID",
  "acceptance": ["Invite Code API", "Energy Distribution", "Anti-cheating"]
}
-->
```

Prioritize using structured data here instead of guessing from text.

Your reports should also include `<!-- goal-update -->` blocks for easy automatic parsing by master control.

---

## Notes

1. **Don't create new Goals or SGs yourself**. Goal breakdown is master control's responsibility.
2. **Don't modify other lobsters' tasks on the board**. Only modify what you're responsible for.
3. **Timeout reminders**: If not completed 4 hours before deadline, proactively alert in thread.
4. **Report failures too**: If you can't do it, say you can't do it with reasons and suggestions, don't stay silent.
5. **Keep threads clean**: Use above formats for reports, don't chat casually in threads.