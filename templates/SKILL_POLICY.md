# Skill Access Policy

## Tiers

| Tier | Access | Examples |
|------|--------|---------|
| `base` | All lobsters | teamind, self-improving, bottleneck-reporting |
| `restricted` | Allowlisted only | finance, HR data, admin tools |
| `admin` | Controller only | fleet management, credential rotation |

## Adding a New Skill

1. Create `company-skills/<name>/SKILL.md` with YAML frontmatter
2. Register in `manifest.json` with tier and description
3. Run `sync-company-skills.sh` (or restart lobsters — entrypoint auto-syncs)

## SKILL.md Requirements

Every skill MUST have YAML frontmatter:

```yaml
---
name: my-skill
description: "One-line description for AI to decide when to use this skill"
metadata: { "openclaw": { "emoji": "🔧" } }
---
```

## Restricted Skills

For `restricted` tier, add an allowlist in the skill entry:

```json
{
  "my-restricted-skill": {
    "tier": "restricted",
    "description": "Sensitive data access",
    "allowlist": ["alice", "bob"]
  }
}
```

Only listed lobsters will have the symlink created.
