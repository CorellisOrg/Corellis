# SecretRef Credential Operations Guide

## Credential Files

| File | Path | Permission | Manager |
|------|------|------------|---------|
| **secrets.json** | `~/.openclaw/secrets.json` | **Read-only** | Centrally managed by master control (shared credentials) |
| **personal-secrets.json** | `~/.openclaw/personal-secrets.json` | **Read-write** | Managed by yourself (personal credentials) |

## personal-secrets.json Operations

**Store credential**:
```bash
python3 -c "
import json
with open('$HOME/.openclaw/personal-secrets.json', 'r+') as f:
    d = json.load(f)
    d['GITHUB_TOKEN'] = 'ghp_your_token_here'
    f.seek(0); json.dump(d, f, indent=2); f.truncate()
"
```

**Use credential** (in scripts/commands):
```bash
export GITHUB_TOKEN=$(python3 -c "import json; print(json.load(open('$HOME/.openclaw/personal-secrets.json'))['GITHUB_TOKEN'])")
```

**View stored credentials (keys only, not values)**:
```bash
python3 -c "import json; print(list(json.load(open('$HOME/.openclaw/personal-secrets.json'))))"
```

**Hot reload** (after modifying credentials):
```bash
openclaw secrets reload
```

## Credential Scenario Guidance

When users give you tokens/API keys to store, standard response:
> I'll help you store this credential in the standard location `personal-secrets.json`. Unified storage, hot loading, secure.

Then execute the storage steps above.

## Prohibited Actions

- ❌ Create `.env`, `.env.xxx`, `.env.local` to store personal credentials
- ❌ Write to `~/.bashrc`, `~/.profile` with export
- ❌ Modify secrets.json (read-only, managed by master control)
- ❌ Display credential plaintext in chat

**Only exception**: Project code's own `.env` (like Next.js `.env.local`) — project runtime configuration, not personal credentials.

## New Skill Credential Standards

- Single key → personal-secrets.json
- Multiple fields → personal-secrets.json, skill scripts use python3 to read
- Shared credentials → Apply through checkpoint reporting, master control injects into secrets.json

## Memory File Recording Format

- ✅ "GH token configured, stored in personal-secrets.json, 2026-03-07"
- ❌ "GH token is ghp_xxxxxxxxxxxx" (plaintext prohibited)