# Task Management Backends

This skill is backend-agnostic. It works with any task/project management tool.

## How to Choose

| Backend | File | Best For | Requires |
|---------|------|----------|----------|
| **Notion** | `notion.md` | Teams already using Notion | Notion API key |
| **Linear** | `linear.md` | Engineering teams on Linear | Linear API key |
| **GitHub Projects** | `github-projects.md` | Open-source / GitHub-centric teams | GitHub CLI (`gh`) |
| **Markdown** | `markdown.md` | Solo users, no external tools | Nothing (zero-dependency) |

## Setup

Set your backend in one of these ways:

1. **Environment variable**: `export TASK_BACKEND=notion`
2. **MEMORY.md entry**: Add `task_backend: notion` to your lobster's memory
3. **Default**: If neither is set, falls back to `markdown`

## Adding a New Backend

Create a new `<tool-name>.md` file in this directory. It must document how to perform these operations:

- `CREATE_TASK` — Create a task with: title, owner, status, priority, sprint, team, notes
- `LIST_TASKS` — Query tasks (with filters: owner, status, sprint)
- `UPDATE_STATUS` — Change a task's status
- `ADD_NOTE` — Append text to a task's notes
- `CLOSE_TASK` — Mark a task as resolved
- `QUERY_BY_OWNER` — Filter tasks by assignee
- `QUERY_BY_SPRINT` — Filter tasks by iteration/sprint

Each operation should include the exact API call (curl/CLI command) with placeholder values.
