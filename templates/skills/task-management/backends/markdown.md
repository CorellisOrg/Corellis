# Markdown Backend (Zero-Dependency Fallback)

Track tasks directly in MEMORY.md. No external services, no API keys, no setup.

## Setup

Nothing. This is the default backend when no other is configured.

## How It Works

Tasks are stored as a markdown table in your lobster's `MEMORY.md` under a `## 📋 Task Board` section.

## Operations

### CREATE_TASK

Append a row to the task table in MEMORY.md:

```markdown
## 📋 Task Board

| # | Task | Owner | Status | Priority | Sprint | Notes |
|---|------|-------|--------|----------|--------|-------|
| 1 | Set up CI pipeline | alice | Open | P1-High | W12 | From standup |
| 2 | Review API design | bob | Backlog | P2-Medium | W12 | |
```

If the `## 📋 Task Board` section doesn't exist, create it.

### LIST_TASKS / QUERY_BY_OWNER

Read the `## 📋 Task Board` section from MEMORY.md. Filter rows by the Owner or Status column.

### QUERY_BY_SPRINT

Filter the table rows where Sprint matches the target value.

### UPDATE_STATUS

Edit the Status cell of the matching row in the markdown table.

### ADD_NOTE

Append text to the Notes cell of the matching row.

### CLOSE_TASK

Change Status to `Resolved`. Optionally, during MEMORY.md cleanup (heartbeat), move resolved tasks to an archive section or daily log.

## Limitations

- No concurrent access (single lobster only)
- No rich querying (lobster reads the whole table)
- MEMORY.md size limit applies — archive completed tasks regularly
- No external visibility (teammates can't see your board)

## When to Use

- Solo lobster setups
- Getting started quickly without configuring external tools
- Teams that prefer minimal tooling
- As a fallback when the primary backend is unavailable

## Archiving

During heartbeat or when MEMORY.md gets large, move completed tasks to the daily log:

```markdown
<!-- In memory/YYYY-MM-DD.md -->
## Completed Tasks
- ✅ Set up CI pipeline (P1, completed 14:30 UTC)
- ✅ Review API design (P2, completed 16:00 UTC)
```

Then remove them from the active board in MEMORY.md.
