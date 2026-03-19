---
name: task-management
slug: task-management
description: "Unified task management — sprint planning, task breakdown, board CRUD, proactive scanning, and TODO extraction. Backend-agnostic: works with Notion, Linear, GitHub Projects, or plain markdown. Trigger words: sprint planning, task breakdown, task board, what to do today, extract TODOs, autopilot."
metadata:
  openclaw:
    emoji: "📋"
    tier: base
    requires:
      bins: ["curl"]
---

# Task Management — Unified Task Board Skill

One skill for all task operations. Backend-agnostic: swap Notion for Linear, GitHub Projects, or plain markdown without changing any logic.

---

## Backend Configuration

**Before using any task operation, determine the active backend.**

1. Check environment variable `TASK_BACKEND` (values: `notion`, `linear`, `github-projects`, `markdown`)
2. If not set, check `MEMORY.md` for a `task_backend: xxx` entry
3. If neither exists, default to `markdown` (zero-dependency fallback — tasks tracked in `MEMORY.md`)

**Then read the backend file** at `backends/<TASK_BACKEND>.md` for API-specific instructions. The backend file tells you exactly how to:

| Abstract Operation | What the Backend File Explains |
|--------------------|-------------------------------|
| `CREATE_TASK` | How to create a task (API call, fields, auth) |
| `LIST_TASKS` | How to query tasks (filters: owner, status, sprint) |
| `UPDATE_STATUS` | How to change a task's status |
| `ADD_NOTE` | How to append notes to a task |
| `CLOSE_TASK` | How to mark a task as resolved |
| `QUERY_BY_OWNER` | How to filter tasks by assignee |
| `QUERY_BY_SPRINT` | How to filter tasks by iteration/sprint |

**Never hardcode API calls in this SKILL.md.** Always read the backend file first, then follow its instructions.

---

## Task Schema (Universal)

Every task has these fields, regardless of backend:

| Field | Type | Values |
|-------|------|--------|
| Title | text | Brief description (≤50 chars) |
| Owner | text | Assignee name |
| Status | enum | `Backlog` / `Open` / `In Progress` / `Testing` / `Resolved` / `Rejected` |
| Priority | enum | `P0-Urgent` / `P1-High` / `P2-Medium` / `P3-Low` |
| Level | enum | `SG` (sub-goal) / `Task` (small task) |
| Sprint | text | Iteration label, e.g. `W12 (0317)` |
| Team | text | e.g. `Frontend` / `Backend` / `iOS` / `DevOps` |
| Needs Coordination | bool | Whether this task requires cross-person alignment |
| Notes | text | Context, source links, parent task reference |

Backend files map these universal fields to tool-specific properties.

---

## Capability 1: Sprint Planning

> Break down a requirements document into person-level sub-goals, then distribute to lobsters.

### When to Use
- User shares a requirements doc and says "break down tasks" / "sprint planning" / "create iteration"
- After a standup/planning meeting with a document to process

### Two-Layer Breakdown Model

**Layer 1: Controller → Sub-Goals (SG)**

Read the requirements document and group by assignee:

1. Parse task items and status labels from the document
2. Match modules to owners using `references/module-owners.md`
3. Merge all items for the same owner into one SG row
4. Assess difficulty (Low/Medium/High) and coordination needs

For each person, create one task with `Level=SG`:
- Title: `[SG] alice: Frontend redesign + payment page update`
- Notes: List all sub-items this person needs to complete

**Layer 2: Lobsters → Small Tasks**

Each lobster receives their SG and autonomously breaks it down:
- Each small task should be completable in 1-4 hours
- Create tasks with `Level=Task` and a parent reference to the SG
- Start with low-difficulty independent tasks first, hold coordination tasks

### Distribution

After creating all SG rows, notify each lobster via Slack:
- @mention the lobster's bot user
- Include a link to the task board and their SG reference
- Lobster claims and self-breaks down into Task-level items

---

## Capability 2: Task Autopilot

> Receive a large goal → break into small tasks → classify → get owner approval → execute.

### When to Use
- Lobster receives an SG-level assignment from the controller
- Owner says "break down tasks" / "autopilot" / "start working"

### Process

**Step 1: Collect** — Read the assigned goal and any related context from Teamind (if available):

```bash
# If Teamind is configured, search for related discussions
# Read $TEAMIND_API_URL from environment or MEMORY.md
curl -s -X POST "$TEAMIND_API_URL" \
  -H 'Content-Type: application/json' \
  -d '{"action":"search","query":"relevant keywords","limit":5}'
```

**Step 2: Break Down** — Split into small tasks (1-4h each). Label each with:
- Difficulty: Low / Medium / High
- Needs Coordination: Yes / No
- Estimated Time
- Prerequisites (dependencies on other tasks)

**Step 3: Classify** — Organize into a 2×3 grid:

```
              No Coordination          Needs Coordination
Low Diff.     ✅ Start immediately     Explain who to align with
Medium Diff.  Assess if more info      Explain coordination + own part
              needed from owner
High Diff.    Explain challenges       Explain coordination + challenges
```

**Step 4: Send Approval Message** — DM the owner:

```
📋 Task Breakdown — [Source Task Name]

━━ 🟢 No Coordination ━━
【Low】 ✅① Task A — 1h
【Med】 ✅② Task B — 2h

━━ 🤝 Needs Coordination ━━
【Low】 ✅③ Task C → align with bob
【High】❓④ Task D → needs input on [specific question]

📌 Suggest starting: ①② (3h total)
❓ Need your input: ④ [what specifically]

Confirm to start?
```

**Step 5: Wait for Approval** — Never auto-execute. After approval:
1. Update task status to `In Progress` via backend
2. Execute in recommended order
3. Update status to `Resolved` when done
4. Report completion to owner

---

## Capability 3: Board Operations (CRUD)

> Read, create, update, and close tasks on the board.

All operations go through the backend file. Common patterns:

### Create a Task

Read `backends/<TASK_BACKEND>.md` → follow `CREATE_TASK` instructions with these fields:
- Title, Owner, Status (default: `Backlog`), Priority, Sprint, Team, Notes

### Query Tasks

Read `backends/<TASK_BACKEND>.md` → follow `QUERY_BY_OWNER` or `QUERY_BY_SPRINT`:
- Filter by owner + current sprint + active statuses (Open, In Progress, Backlog)
- Fallback: if sprint filter returns empty, drop sprint filter and query by owner only

### Update Status

Read `backends/<TASK_BACKEND>.md` → follow `UPDATE_STATUS`:
- Task ID + new status

### Status Flow

```
Backlog → Open → In Progress → Testing → Resolved
                                  ↑
                          Lobster auto-sets when done
                          (only owner sets Resolved)
```

**Key rule**: Lobsters never close tasks themselves. Set `Testing` and ask owner to confirm.

### Sprint Calculation

```bash
WEEK_NUM=$(date +%V)
MONDAY=$(date -d "last monday" +%m%d 2>/dev/null || date -v-monday +%m%d)
SPRINT="W${WEEK_NUM} (${MONDAY})"
```

---

## Capability 4: Proactive Scan

> Periodically scan task board + chat context → find what needs doing → propose to owner.

### When to Use
- Heartbeat check (every 4h, max 2x/day)
- Owner says "what to do today" / "task planning"
- ≥4h since last scan AND no pending unapproved proposals

### Three Information Sources

| Source | What to Read | How |
|--------|-------------|-----|
| Task Board | This week's tasks under own name | Backend `QUERY_BY_OWNER` + `QUERY_BY_SPRINT` |
| Chat Context | Related discussions, coordination signals | Teamind search (if configured) or recent Slack messages |
| Owner Instructions | Recent DMs, MEMORY.md priorities | Read MEMORY.md + recent DM history |

### Decision Engine

1. **Merge** all sources into a unified task list
2. **Assess executability**: dependencies resolved? coordination party ready?
3. **Sort by priority**: owner-specified > deadline urgency > dependencies ready > board priority > low difficulty first
4. **Output six-grid classification**:

```
📋 Task Scan — [Name] [Date]
✅ = can do now | ❓ = need info

           🟢 No coordination        🤝 Needs coordination
Low Diff.  ✅① Task A (1h)           ✅③ Task C → align with bob
           ✅② Task B (0.5h)
Med Diff.  ❓④ Task D                ❓⑤ Task E → wait for carol
High Diff. —                          ❓⑥ Task F → coordinate bob+carol

📌 Suggest today: ①②③ (2.5h)
❓ Need info: ④ [question] | ⑤ [what's blocking]
```

### Execution Rules
- **Never auto-execute** — wait for owner approval
- **Only this week** — ignore past/overdue tasks
- **Low noise** — stay silent when nothing changed
- **No late night** — skip 23:00-08:00 unless owner asks
- **Idempotent** — don't re-propose same unchanged batch

---

## Capability 5: TODO Extraction

> Extract actionable TODOs from a Slack thread → confirm with user → write to board.

### When to Use
- User says "extract TODOs" / "list tasks" / "sync to board"
- User @mentions lobster in a thread with TODO-like content

### Scope Rules

**Default**: Only extract TODOs assigned to the lobster's owner.
- Only include tasks where owner is @mentioned or matches by module mapping
- Switch to all-members mode only when user explicitly says "list everyone's TODOs"

### Process

**Step 1**: Read all thread messages via `message(action=read, ...)`

**Step 2**: Identify TODOs by these signals:
| Signal | Pattern | Example |
|--------|---------|---------|
| Explicit assignment | `@name + action verb` | "@bob review this PR" |
| Request | "Please XXX", "Need XXX" | "Please set up CI pipeline" |
| Awaiting action | "Waiting for XXX" | "Waiting for alice to confirm" |
| Decision output | "OK, do XXX" | "OK, remove the legacy API" |

**Step 3**: For each TODO, determine: Title, Owner, Priority, Team, Sprint

**Step 4**: Present to user for confirmation:
```
📋 Extracted TODOs from thread:

 #  Task                          Owner   Priority
──  ────────────────────────────  ──────  ────────
 1  Set up CI pipeline            alice   P1-High
 2  Review API design doc         bob     P2-Medium

Reply "confirm" to write to board
"#2 change to P1" / "delete #1" / "add: new task" to modify
"cancel" to abort
```

**Step 5**: After confirmation, create tasks via backend. Summary:
```
✅ Written to board: 2 tasks
By owner: alice(1) | bob(1)
```

---

## Assignment Logic

Priority for determining task owner:

1. Explicitly @mentioned in source → use directly
2. "Confirm with XXX" / "waiting for XXX" → that person
3. Match module by task content → check `references/module-owners.md`
4. Cannot match → "Unassigned"

---

## References

- `backends/` — Backend-specific API instructions (choose one)
- `references/module-owners.md` — Module → owner mapping template
- `references/status-mapping.md` — Document tags → board status mapping

---

## Notes

1. **Never hardcode API calls** — always read the backend file first
2. **Never auto-execute** — all task execution requires owner approval
3. **Only this week** — ignore past tasks, no overdue reminders
4. **Low noise** — no empty reports, no spam proposals
5. **Idempotent** — don't create duplicate tasks (check by title before creating)
6. **Respect rate limits** — batch creates should sleep between calls (backend file specifies timing)
