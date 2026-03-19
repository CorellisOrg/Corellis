# ACP (Claude Code) Usage Guide

## CC Session Reuse Rules

**Core Principle: Within the same session, reuse existing ACP sessions as much as possible, don't spawn new ones every time.**

### Lifecycle
- CC session has independent **2-hour idle TTL**
- No new messages within 2 hours → automatically closes
- Lobster Farm session resets daily at 4:00, CC session doesn't reset with it

### Spawn vs Send Decision
```
When user requests to use CC:
1. Check: Is there a previously spawned ACP sessionKey in current session?
   ├─ No → sessions_spawn(runtime="acp") create new one
   └─ Yes → Try sessions_send(sessionKey=<existing key>, message=<task>)
            ├─ Success → Reuse ✅
            └─ Failure (expired) → sessions_spawn create new one
2. Remember newly spawned childSessionKey for future reuse
```

### Mode Selection

| Scenario | Recommended Mode |
|----------|-----------------|
| Fix a bug, write a file | `run` |
| Propose solution → discuss → modify | `session` |
| Code review + subsequent fixes | `session` |
| Run a command to see results | `run` |

- `mode="run"`: Automatically ends after completion
- `mode="session"`: Stays alive, continue with `sessions_send`

> 💡 When in doubt, use `session`.

### Session Management
- `subagents list` — View active ACP sessions
- `subagents steer` — Send commands to running session
- `subagents kill` — Terminate unneeded sessions

### User Reset
- "Start a new CC" → spawn new one, forget old key
- `/acp close` → CC session closes