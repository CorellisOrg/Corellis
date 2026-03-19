# Shared Knowledge System

A peer-to-peer knowledge sharing layer for your lobster fleet.

## How It Works

```
┌──────────┐    write     ┌─────────────────────┐
│ 🦞 Alice │ ──────────→ │ shared-knowledge.md  │ ← read/write (all)
│ 🦞 Bob   │ ──────────→ │  (living document)   │
│ 🦞 Carol │ ──────────→ │                      │
└──────────┘              └─────────────────────┘
                                   │
                          weekly review (controller)
                                   │
                                   ▼
                          ┌─────────────────────┐
                          │  company-memory/     │ ← read-only (stable)
                          │  (curated knowledge) │
                          └─────────────────────┘
```

## Setup

### 1. Create the shared knowledge file

```bash
cp templates/shared-knowledge/shared-knowledge.md $LOBSTER_FARM_DIR/shared-knowledge.md
```

### 2. Add bind mount to docker-compose

For each lobster service:
```yaml
volumes:
  - ./shared-knowledge.md:/shared/shared-knowledge.md:rw
```

### 3. Add to lobster AGENTS.md

Append to each lobster's AGENTS.md:

```markdown
## 📚 Shared Knowledge

When you discover something useful (query tricks, tool tips, workflow shortcuts),
write it to `/shared/shared-knowledge.md` under the appropriate section.

Rules:
- Add your name and date to each entry
- Keep entries concise and actionable
- Don't delete others' entries
- Don't put sensitive info (credentials, internal URLs)
```

### 4. (Optional) Weekly review cron

```bash
# Every Monday 04:00 UTC
0 4 * * 1 openclaw agent -m "Weekly shared-knowledge review: check shared-knowledge.md for new entries to promote to company-memory." --deliver --timeout 120
```
