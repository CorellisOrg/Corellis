---
name: deep-research
version: 1.0.0
description: "Multi-model deep research — supports Claude/Gemini/OpenAI routing, parallel search, cross-validation, with referenced reports"
metadata:
  openclaw:
    triggers:
      - "deep research"
      - "deep research"
      - "use openai for deep research"
      - "use gemini for deep research"
      - "use claude for deep research"
---

# Deep Research Skill 🔬

Multi-model deep research capability that supports user-specified model routing.

## Trigger Words and Model Routing

Parse user messages and match the following patterns:

| User Input | Model Used | Invocation Method |
|--------|---------|---------|
| `use openai for deep research xxx` | GPT-5.3 | Azure OpenAI API (synthesize.sh openai) |
| `use gemini for deep research xxx` | Gemini 3.1 Pro | Google AI Studio API (synthesize.sh gemini) |
| `use gemini-dr for deep research xxx` | Google Deep Research Pro | Google DR API (synthesize.sh gemini-dr) |
| `use claude for deep research xxx` | Claude Opus 4.6 | Current model direct output |
| `deep research xxx` | Google Deep Research Pro (default) | Google DR API (synthesize.sh gemini-dr) |

**Routing Logic**: Check for "use openai"/"use gemini"/"use claude" keywords at message start. No specification → default gemini-dr.

> 💡 `use gemini-dr` uses Google's Deep Research specialized model (deep-research-pro-preview), specifically optimized for comprehensive research, potentially higher quality than general-purpose Gemini 3.1 Pro.

## Complete Workflow

### Phase 1: Parse Request

1. Identify model routing (openai/gemini/claude/default)
2. Extract research topic
3. If topic is too vague, ask at most 1 clarifying question

### Phase 2: Plan Sub-questions

Break down the topic into 4-6 independent searchable sub-questions.

### Phase 3: Multi-round Search

Call `web_search` for each sub-question (max 10 results each), total 4-6 search rounds.

### Phase 4: Deep Fetch

Select 3-5 most valuable URLs from search results, use `web_fetch(url, maxChars=8000)` to read full text.

Selection criteria: Academic papers > Official reports > Authoritative media > Industry analysis > Blogs

### Phase 5: Secondary Deep Dive

Analyze existing materials, conduct 1-2 supplementary search rounds for sub-questions with insufficient information.

### Phase 6: Synthesis & Analysis (Model Routing)

**Default routing (gemini-dr)**: Call Google Deep Research Pro API (asynchronous Interactions API), has built-in search capability, no additional search needed.

**claude routing**: Directly use current Claude model to generate comprehensive report.

**gemini/openai routing**:
Save all collected materials to temporary file, then call synthesis script:

```bash
SKILL_DIR="$(find /home -path "*/company-skills/deep-research" -type d 2>/dev/null | head -1)"
# First write materials to temp file
echo '<all source materials JSON>' > /tmp/dr-sources.json
# Call synthesis script
bash "${SKILL_DIR}/scripts/synthesize.sh" <provider> "<research topic>" /tmp/dr-sources.json
```

provider = `gemini` or `openai`

If API call fails, fallback to Claude processing, note in report.

### Phase 7: Output Report

**Output Priority (try in order):**

1. **Slack Canvas available** → Create Canvas with complete report (best experience)
   - Requires Bot to have `canvases:write` permission
   - If creation fails, prompt user to configure Canvas permissions, then fallback to method 2
   - Canvas setup: Slack App → OAuth & Permissions → Add `canvases:write`, `canvases:read` scope
2. **Report >4000 characters** → Generate PDF upload to thread
   - Use Playwright: `npx -y playwright pdf <html_file> <output.pdf>`
   - Send via Slack file upload three-step process
3. **Shorter report** → Direct Slack message output (Markdown format)

Unified report format:

```markdown
# [Topic]: Deep Research Report
*Generated: [Date] | Model Used: [Model Name] | Sources: [N] | Confidence: [High/Medium/Low]*

## Executive Summary
[3-5 key findings]

## 1. [First Major Finding]
[Detailed analysis with inline citations]

## 2. [Second Major Finding]
...

## Key Conclusions
- [Actionable insights]

## Source List
1. [Title](url) — [One-liner] ✅ Verified / ⚠️ Single source

## Research Methodology
Searched [N] keyword groups, analyzed [M] sources. Model: [Name Version]
```

## Quality Standards

1. Every key claim must have sources, mark unsourced as "AI inference"
2. Important facts require ≥2 independent sources for confirmation; single sources marked ⚠️
3. Prioritize sources from recent 12 months
4. Clearly state when information is insufficient, do not fabricate
5. Match user's language (Chinese question → Chinese answer)

## Environment Variables

| Variable | Purpose | When Needed |
|------|------|---------|
| GEMINI_API_KEY | Gemini routing | When using gemini |
| AZURE_OPENAI_API_KEY | OpenAI routing | When using openai |
| AZURE_OPENAI_ENDPOINT | Azure endpoint | When using openai |
| AZURE_OPENAI_DEPLOYMENT | Deployment name | When using openai |

## Examples

```
deep research Global AI chip market landscape for 2026
use gemini for deep research React vs Vue 2026 technology selection
use openai for deep research Southeast Asia e-commerce market entry strategy
use gemini-dr for deep research Quantum computing commercialization prospects analysis
```

## ⚠️ Gemini DR Asynchronous Execution (Important! — Sub-Agent Orchestration Pattern)

Gemini DR is a long-running task (typically 3-10 minutes), **must use sub-agent independent orchestration, do not block main session**.

Scripts have been split into two commands:
- `synthesize.sh gemini-dr-start "<topic>" <sources>` → Start interaction, **immediately returns interaction ID**
- `synthesize.sh gemini-dr-check "<interaction_id>" <dummy>` → Check status. exit 0=completed(report in stdout), exit 10=in progress, exit 3=failed
### Correct approach: spawn sub-agent

**Main session workflow:**
1. Reply to user: "🔬 Deep research has been initiated, estimated 3-8 minutes, report will be sent automatically upon completion."
2. Use `sessions_spawn` to launch DR orchestrator sub-agent (see template below)
3. Main session remains idle, can continue with other tasks

**Sub-agent task template:**
```
sessions_spawn(
  task: "You are DR Orchestrator. Execute the following steps:

  1. Start Gemini DR:
     SKILL_DIR=$(find /home -path '*/company-skills/deep-research' -type d 2>/dev/null | head -1)
     echo '<detailed prompt for research topic>' > /tmp/dr-sources.json
     ID=$(bash $SKILL_DIR/scripts/synthesize.sh gemini-dr-start '<topic>' /tmp/dr-sources.json)
     Record interaction ID: $ID

  2. Check every 30 seconds:
     bash $SKILL_DIR/scripts/synthesize.sh gemini-dr-check '$ID' /tmp/dr-sources.json
     - exit 10 → stdout format: 'status|updated_timestamp', record updated
     - exit 0  → got report, proceed to step 3
     - exit 3  → failed, report error

  3. Deadlock detection (important!):
     - Record updated timestamp on each check
     - If updated hasn't changed for 5 consecutive minutes → interaction is stuck
     - Deadlock handling: abandon current interaction, restart with new gemini-dr-start request
     - Retry maximum 2 times, if still stuck then report failure

  4. After getting report: format as standard research report format, send to user via announce.

  Timeout limit: 15 minutes. After timeout report interaction ID for user manual query.",
  label: "dr-<slug>",
  mode: "run",
  runTimeoutSeconds: 900
)
```

### ❌ Wrong approaches (will cause result loss)
- ❌ Using exec background + process poll in main session (lost after session reset)
- ❌ Using old `synthesize.sh gemini-dr` sync mode (exec timeout kills process, interaction ID lost)
- ❌ Not saving interaction ID (cannot recover after script is killed)
- ❌ **Using cron for DR polling** (stateless, needs cleanup, wastes tokens, easily becomes orphaned cron)

**DR polling must be completed in sub-agent internal loop**, don't create cron jobs. Sub-agent automatically exits when complete, no cleanup issues.

### 🔄 Multi-path concurrent research

**⚠️ Google Gemini DR API has concurrency limits!** Sending 5 interactions simultaneously may cause later ones to be silently queued/stuck (`updated` timestamp never changes).

**Concurrency rules:**
- **Maximum 3 concurrent** Gemini DR interactions
- More than 3 subtopics → batch processing: send 3 first, wait for 1 to complete before sending next
- Each interaction must have deadlock detection (5 minutes no updated change → retry)

**Orchestration approach (recommended: single orchestrator):**
1. Spawn one master orchestrator sub-agent
2. Orchestrator maintains a queue with maximum 3 concurrent slots
3. Check all active interactions every 30 seconds in rotation
4. Detect deadlock → retry that interaction (using same slot)
5. One completes → release slot, take next from queue and start
6. All complete → consolidate report → announce

**Why not one sub-agent per subtopic:**
- Cannot control total concurrency (5 sub-agents starting simultaneously → triggers rate limiting)
- Single orchestrator can perform global scheduling

### 🧹 Cron cleanup (hard rule!)

**If any cron jobs are created during DR process (monitoring, polling, etc.), they must be deleted immediately after DR completion.**

- Sub-agent orchestrator must `cron(action="remove", jobId=xxx)` to clean up all DR-related crons as the final step after consolidation
- If using cron for periodic checking (instead of sub-agent internal loop), **immediately delete cron** after getting final results
- ❌ Prohibited to leave orphaned crons (research finished but cron still running, wasting tokens every N minutes)
- Recommendation: unified cron job name prefix `dr-monitor-` for easy identification and cleanup

### 💡 Legacy mode (gemini-dr) still available

`synthesize.sh gemini-dr` maintains backward compatibility (sync polling), suitable for sub-agent internal calls (sub-agent has independent timeout control).
But **main session is prohibited from direct calls**.