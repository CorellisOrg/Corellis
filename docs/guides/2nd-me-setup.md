# 2nd Me: Self-Improvement & Task Management

The 2nd Me system has two parts:
1. **Self-Improving** — Learn from corrections and mistakes (core, no external tools needed)
2. **Task Tracking** — Optional integration with a task board (Notion, Linear, GitHub Issues, etc.)

---

## Part 1: Self-Improving (Core)

This works out of the box with no external services. The lobster automatically:

- Detects when it's corrected (semantic detection, not keyword matching)
- Records lessons in `.learnings/corrections.md`
- Promotes validated patterns to `MEMORY.md` and `AGENTS.md`

### Enable the daily scan

```bash
# Add to crontab — scans all lobsters for promotable lessons
echo "5 4 * * * $(pwd)/scripts/trigger-2nd-me-all.sh >> /tmp/2nd-me-scan.log 2>&1" | crontab -
```

### What gets recorded

| Trigger | Example | Stored in |
|---------|---------|-----------|
| User corrects lobster | "No, we use Python 3.12" | `.learnings/corrections.md` |
| Command/tool fails | API returns unexpected error | `.learnings/errors.md` |
| Better approach found | Discovered faster query method | `.learnings/best-practices.md` |
| Complex task completed | 5+ step workflow finished | `.learnings/reflections.md` |

### Promotion rules

- Same lesson appears ≥3 times → auto-promoted to `MEMORY.md`
- Affects daily workflow → promoted to `AGENTS.md` (behavioral rules)
- Tool-specific pattern → promoted to `TOOLS.md`

---

## Part 2: Task Tracking (Optional)

If your team uses a task board, lobsters can sync task status automatically. This is **optional** — 2nd Me works fine without it.

### Supported integrations

| Tool | Skill | How |
|------|-------|-----|
| Notion | `task-management` (Notion backend) | API-based CRUD on a Notion database |
| GitHub Issues | Built-in `gh` CLI | Read/write issues via GitHub CLI |
| Linear | Custom skill | Build a skill using Linear's API |
| Plain markdown | None needed | Lobster tracks tasks in `MEMORY.md` directly |

### If using Notion

1. Create a Notion database with columns: Task, Owner, Status, Notes
2. Get a [Notion API key](https://www.notion.so/my-integrations)
3. Store it: add `NOTION_API_KEY` to the lobster's `personal-secrets.json`
4. Install the `task-management` skill to `company-skills/`
5. Configure the database ID in the skill's settings

### Task status flow (any tool)

```
Open → In Progress → Testing → Resolved
                        ↑
                   Lobster auto-sets when it judges task is done
                   (only the owner can set Resolved)
```

**Key rule**: Lobsters never close tasks on their own. They set "Testing" and ask the owner to confirm.

### Daily sync (optional cron)

If using a task board, add a daily sync to scan conversation logs and update task status:

```bash
# Example: daily at 23:00 UTC, scan daily logs → update task board
echo "0 23 * * * $(pwd)/scripts/run-2nd-me-scan.sh >> /tmp/2nd-me-scan.log 2>&1" | crontab -
```

---

## Quick Start (Minimum Setup)

Just want self-improving without task tracking? Two steps:

1. Copy the skill: `cp -r templates/self-improving/ company-skills/self-improving/`
2. Sync: `./scripts/sync-company-skills.sh`

Done. Your lobsters now learn from their mistakes automatically.
