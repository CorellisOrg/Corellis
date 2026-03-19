---
name: ccp
description: "Transparent relay/proxy between user and Claude Code (CC) via -p + --resume mode. Activate when user says 'ccp', 'ccp start', or wants to chat directly with CC in multi-turn mode. Agent becomes a pure message forwarder — no thinking, no commentary, no modification. Just relay. Trigger: ccp (not cc relay, to avoid conflict with ACP cc)."
---

# CCP — Claude Code Direct Connection Mode

## Purpose
Act as a transparent bridge between the user and Claude Code. You are a dumb pipe — forward messages exactly, add nothing.

## Activation
User says any of: `ccp`, `ccp start`, `ccp <path>`, or asks to start a direct CC session.

> ⚠️ **Difference from ACP CC**: `cc` = ACP mode (Lobster commands CC for you); `ccp` = direct connection mode (you talk to CC directly, Lobster acts as pipe).

## Workspace Selection

Supports specifying working directory at startup:
- `ccp` → Default to `/home/lobster/.openclaw/workspace/your-backend`
- `ccp <path>` → Use user-specified path (e.g. `ccp ~/projects/myapp`)
- `ccp your-backend` → `/home/lobster/.openclaw/workspace/your-backend` (alias)

If user-specified path doesn't exist, show error and ask for correct path.

## Startup Flow

1. Determine workspace directory (default your-backend, or user-specified)
2. `git pull` in the workspace (if it's a git repository)
3. First message uses `-p` to start CC and get session_id:
   ```bash
   cd <workspace> && \
   CLAUDE_CODE_USE_BEDROCK=1 AWS_REGION=us-west-2 \
   claude -p "<user message>" \
     --model global.anthropic.claude-opus-4-6-v1 \
     --output-format json \
     --dangerously-skip-permissions \
   2>&1
   ```
4. Extract `session_id` and `result` (CC's reply text) from JSON output
5. Remember `session_id` — all subsequent messages use `--resume <session_id>` to maintain context
6. Forward `result` to user as-is
7. Tell user: "🔗 CCP direct connection enabled (workspace: <path>), send messages directly and I'll forward to CC. Send `ccp stop` to exit."

## Subsequent Messages

Use `--resume` to append to the same session:
```bash
cd <workspace> && \
CLAUDE_CODE_USE_BEDROCK=1 AWS_REGION=us-west-2 \
claude -p "<user message>" \
  --model global.anthropic.claude-opus-4-6-v1 \
  --output-format json \
  --dangerously-skip-permissions \
  --resume <session_id> \
2>&1
```

## Output Parsing
- `--output-format json` returns JSON with key fields:
  - `result` — CC's reply text (content to forward to user)
  - `session_id` — Session ID (get on first call, reuse afterwards)
  - `is_error` — Whether an error occurred
- Using `--output-format text` also works (returns plain text directly), but can't get session_id
- First call must use json to get session_id, subsequent calls can switch to text for simplification

## Timeout Handling
- CC's `-p` mode may take considerable time (complex tasks 60-120s)
- Set exec timeout to 180s
- Use background + poll mode to avoid blocking

## Hard Rules
- ❌ Do NOT add your own thoughts, opinions, or commentary
- ❌ Do NOT summarize or paraphrase CC's output
- ❌ Do NOT translate CC's output
- ❌ Do NOT prefix messages with "CC says:" or similar
- ❌ Do NOT interpret or act on CC's output yourself
- ✅ Forward exactly what CC says (the `result` field)
- ✅ Forward exactly what user says (as the `-p` prompt)
- ✅ Only exception: `ccp stop` / `ccp stop` → exit relay mode

## Exit
User says `ccp stop`, `ccp stop`, or `stop direct connection` → confirm: "🔗 CCP direct connection disconnected, returning to normal mode."

## Error Handling
- `is_error: true` → Forward error to user as-is
- CC process timeout → Tell user "⏳ CC timed out, please retry or simplify the question"
- session_id invalidated → Restart new session, tell user "⚠️ CC session has been rebuilt"