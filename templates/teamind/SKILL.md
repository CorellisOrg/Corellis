---
name: teamind
description: "Search group chat memory — semantic search across Slack channel history. Use when you need to find what was discussed, look up decisions/conclusions, find context about a topic not in your MEMORY.md, or answer questions about team conversations."
metadata: { "openclaw": { "emoji": "🧠", "requires": { "bins": ["node"] } } }
---

# Teamind — Group Chat Memory Search

Search across your team's Slack group chat history using semantic search. Teamind indexes messages with vector embeddings and generates thread-level summaries, letting you find relevant discussions even without exact keywords.

## Architecture

```
Slack channels → [indexer.js] → SQLite (messages + embeddings + thread summaries)
                                    ↓
Lobster search → [search.js] → Semantic similarity → Results
                                    ↓
Digest cron   → [digest.js]  → Per-lobster personalized daily digest
```

Everything runs locally. No external API needed (except embedding provider).

## Setup

```bash
cd scripts/teamind
npm install
node setup.js                                        # init database
node indexer.js --add-channel C0XXXXXXX general     # register channels
node indexer.js                                       # run first index
```

### Cron (recommended)

```bash
# Incremental index every hour
0 * * * * cd $(pwd)/scripts/teamind && node indexer.js >> /tmp/teamind-index.log 2>&1

# Daily digest at 04:00 UTC
0 4 * * * cd $(pwd)/scripts/teamind && node digest.js >> /tmp/teamind-digest.log 2>&1
```

## When to Use

✅ **USE this skill when:**
- You need context about a topic discussed in group chats but not in your MEMORY.md
- User asks about past team discussions, decisions, or conclusions
- Looking up technical decisions, architecture choices, or meeting outcomes
- User asks "what was discussed about X" or "who talked about Y"

❌ **DON'T use when:**
- The answer is already in your MEMORY.md (check there first!)
- You need to send a message (use the message tool)
- You need real-time channel activity (use message read)

## Commands

### Search (preferred — fast, cheap)

```bash
# Basic search
node search.js "API design decision" --json

# With filters
node search.js "API design" --channel C0XXXXXXX --type decision --after 2026-03-01 --json --limit 10
```

**Filters** (all composable):
- `--channel <ID>` — specific channel
- `--type <type>` — `decision` | `bug_fix` | `brainstorm` | `status_update` | `qa` | `casual` | `announcement`
- `--after <date>` — ISO date/datetime
- `--before <date>` — ISO date/datetime
- `--participant <name>` — filter by participant name (partial match)
- `--limit <N>` — max results (default: 5)
- `--json` — JSON output (recommended for programmatic use)

**Response** (JSON mode):
```json
{
  "query": "API design decision",
  "threads": [
    {
      "thread_ts": "1772606486.369999",
      "title": "API Redesign Proposal V2",
      "summary": "Discussed DB schema, API endpoints...",
      "thread_type": "decision",
      "key_points": ["Create landing_page_recommendation table"],
      "participants": [{"name": "alice", "role": "solution design"}],
      "open_items": [{"item": "tracking confirmation", "assignee": null}],
      "msg_count": 43,
      "score": 0.892
    }
  ],
  "messages": [
    {
      "username": "bob",
      "text": "message content...",
      "created_at": "2026-03-04T06:41:26",
      "score": 0.834
    }
  ]
}
```

### Index (admin)

```bash
node indexer.js                                # incremental
node indexer.js --full                          # full re-index
node indexer.js --channel C0XXXXXXX          # specific channel
node indexer.js --hours 48                     # last 48h only
node indexer.js --add-channel C0XXX general    # register channel
node indexer.js --dry-run                      # preview
```

### Digest (admin)

```bash
node digest.js                     # all lobsters
node digest.js --lobster alice     # single lobster
node digest.js --hours 48          # custom window
node digest.js --dry-run           # preview
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SLACK_BOT_TOKEN` | Yes (indexer) | — | Slack bot token |
| `EMBEDDING_PROVIDER` | Yes | `openai` | `openai` or `gemini` |
| `OPENAI_API_KEY` | If openai | — | OpenAI API key |
| `GEMINI_API_KEY` | If gemini | — | Google Gemini API key |
| `LLM_PROVIDER` | For indexer | `anthropic` | `anthropic` or `openai` |
| `ANTHROPIC_API_KEY` | If anthropic | — | For thread summaries |
| `SUMMARY_MODEL` | No | `claude-sonnet-4-20250514` | LLM model for summaries |
| `EMBEDDING_MODEL` | No | `text-embedding-3-small` | Embedding model |
| `EMBEDDING_DIM` | No | `1536` | Embedding dimensions |
| `DB_PATH` | No | `./teamind.db` | SQLite database path |
| `BATCH_SIZE` | No | `50` | Messages per embedding batch |

## Decision Guide

```
Do I know the answer from my own memory?
  → YES: Don't call Teamind
  → NO: Is it about group chat history?
    → YES: Use search.js (cheap + fast)
    → NO: Don't call Teamind
```

## Tips

- **Always try search first** — you can synthesize from raw results
- **Use time filters** — `--after` / `--before` are your best friend
- **Use `--type` filter** — skip `casual` for technical questions
- **key_points** have the most specific, actionable info
- **participants** great for "who decided X" questions
- Database is a single SQLite file — easy to backup, move, or inspect
