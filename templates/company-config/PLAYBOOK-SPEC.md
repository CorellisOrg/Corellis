# Agent Playbook Specification v2.0

> **Positioning**: Complete process specification from "Requirements Document" → "Standardized Playbook" → "Executable Agent".
> **Scope**: All company AI Agents (Lobster Farm native execution or code implementation).
> **Source**: Distilled from 27 existing Skills + omnichannel product selection Agent practices.

---

## 0. Agent Classification — Different Complexity Levels Use Different Specifications

| Level | Definition | Documentation Requirements | Code Requirements | Existing Cases |
|-------|------------|---------------------------|-------------------|----------------|
| **L1 Tool-based** | Encapsulates single data source/API | SKILL.md only | Query scripts (bash/node) | seo-tool, mysql, observability, attribution-tool, bot-monitor |
| **L2 Process-based** | Chains multi-step fixed processes | SKILL.md + embedded Workflow | Process scripts | landing-page-optimizer, weekly-report, bottleneck-reporting |
| **L3 Pipeline-based** | Multi-data source + filtering/sorting + scheduled execution | ⭐ **Complete Playbook** | Pipeline code | Omnichannel product selection Agent, deep-research |
| **L4 Collaborative** | Involves multi-person interaction/decisions | Playbook + interaction protocol | Optional | structured-decision-alignment |

> **Decision Rule**: Data sources ≤1 → L1; Steps ≤5 and single source → L2; Multi-source + sorting/scheduling → L3; Multi-person involved → L4.
> **Only L3/L4 need complete Playbook, L1/L2 use SKILL.md only.**

---

## 1. Playbook Documentation Specification (L3/L4 Agents)

### File Structure

```
Simple Agent → Single file PLAYBOOK.md
Complex Agent → Directory:
  playbook/
  ├── PLAYBOOK.md       ← Main document (required)
  ├── datasources/      ← Detailed integration docs for each data source (optional split)
  └── examples/         ← Output sample files
```

### Required Sections (6 ⭐)

---

#### §1 Meta + Objectives ⭐

```yaml
name: "Agent Name"
version: "1.0.0"
owner: "Owner"
team: ["Team Members"]
created: "YYYY-MM-DD"
status: "draft | active | deprecated"
```

**Three Essential Objectives** (all required):

| Element | Question | Example |
|---------|----------|---------|
| What | What problem does it solve? | Automatically discover high-potential uncovered keywords |
| Who | Who uses it? | Operations team |
| Metric | How to measure success? | Produce ≥20 high-priority new opportunities weekly |

---

#### §2 Data Source Inventory ⭐

Each data source **must meet five standards**:

| # | Standard | Content |
|---|----------|---------|
| 1 | **Integration Method** | API / Apify Actor / Scraping / Database / Existing Skill |
| 2 | **Data Fields** | Field name + type + description (table) |
| 3 | **Display Example** | Code block with fixed header + ≥3 sample rows |
| 4 | **Query Scenarios** | When to query, what parameters to pass |
| 5 | **Return Format** | JSON / CSV examples |

**Data Source Integration Priority** (decision tree):

```
Have existing company Skill? ──Yes──→ Use directly (seo-tool/attribution-tool/mysql/observability/...)
       │No
Have free official API? ──Yes──→ Write integration code
       │No
Apify has Actor? ──Yes──→ Use Apify Skill to call
       │No
Can scrape? ──Yes──→ Playwright/scraping
       │No
Don't integrate for now, record in Backlog
```

**Single Data Source Template**:

```markdown
### [Data Source Name]
- **Integration Method**: [Existing Skill `seo-tool` / Apify `actor-id` / API / Scraping]
- **Authentication**: `ENV_VAR_NAME`
- **Cost**: Free / $X / Pay-per-use
- **Rate Limits**: X times/day
- **Status**: ✅Connected / ⚠️Pending Config / ❌Unavailable

| Field | Type | Description |
|-------|------|-------------|
| field | string | description |

**Query Scenarios**:
| Scenario | Parameters | Expected Results |
|----------|------------|------------------|

**Return Example**:
```json
{}
```
```

---

#### §3 Execution Flow ⭐

**Pipeline Description Format** (unified ASCII flowchart + step table):

```
[Trigger] → [Step 1] → [Step 2] → ... → [Output]
              ↑ Mark parallel [Parallel]
```

**Required for each step**:

| Item | Description |
|------|-------------|
| Input | What data, from where |
| Process | What exactly to do (one sentence) |
| Output | What to produce, for whom |
| Dependencies | Prerequisite steps / data sources |
| Executor | Lobster Farm native / script / Skill |
| Duration | Estimated seconds |
| Failure Handling | What to do if failed |

**"Executor" is the key field** — it determines whether Lobster Farm does it directly or needs code:

| Executor | Meaning | Example |
|----------|---------|---------|
| `skill:seo-tool` | Call existing company Skill | SEO keyword queries |
| `skill:apify` | Call Actor through Apify Skill | FB Ads scraping |
| `native` | Lobster Farm native capabilities (inference/summarization/formatting) | AI analysis, scoring, translation |
| `script:xxx.sh` | Script to be written | Data aggregation Pipeline |
| `manual` | Manual operation required | Token application |

---

#### §4 Decision Logic ⭐

Rules for Agent decision-making/judgment/classification during execution. Different types of Agents have different decision logic:

| Agent Type | Decision Logic Examples |
|------------|-------------------------|
| Data Product Selection | Filtering thresholds + scoring/ranking algorithms |
| Content Generation | Quality assessment standards + review rules |
| Monitoring & Alerting | Trigger conditions + severity level determination |
| Research & Analysis | Information credibility assessment + comprehensive judgment standards |
| Process Automation | Branch conditions + state transition rules |
**General Format**:

```markdown
## Decision Rules

### Rule 1: [Rule Name]
- Condition: [When to trigger]
- Judgment: [How to judge / What criteria to use]
- Result: [What to output after judgment / Which branch to take]
- Reason: [Why it's designed this way]
```

**If there are quantitative algorithms** (scoring/ranking/grading etc., optional):
```markdown
## Algorithm
Formula: [Write clearly]
Weight for each dimension: [List]
Grading criteria: [Threshold + meaning]
```

> **Core requirement**: Write "the decision process in the lobster's brain" into explicit rules, leaving no ambiguity.
> If another lobster executes the same Playbook, it should get consistent results.

---

#### §5 Output Specification ⭐

| Item | Required |
|------|----------|
| Output channel | Slack / Sheet / Notion / File |
| Push target | #channel-name or @person |
| Push frequency | Real-time / Daily / Weekly / On-demand |
| Format | Code block table (Slack) / Sheet row / JSON |
| Complete output sample | At least one ⭐ |

**Slack output must use code blocks** (to ensure alignment):

```
[emoji] [title] — [date]
📅 [time range] | 🇺🇸 [region]

Rank  Name          Metric1  Metric2
───  ──────────  ──────  ──────
 1   Sample data     100     50
```

---

#### §6 Exception Handling + Scheduling ⭐

**Fallback Chain** (unified format):

```
[Primary data source] → [Alternative solution] → [Cache/Last result] → [Skip+Alert]
```

**Scheduling Method**:

| Trigger | Frequency | Timeout |
|---------|-----------|---------|
| Cron / User command / Event | Specific frequency | Single step X min / Full process Y min |

---

### Optional Sections

| Section | When needed |
|---------|------------|
| §7 Configurable Parameters | When there are user-adjustable parameters (region/time/TopN) |
| §8 Interaction Protocol | L4 collaborative (multi-person discussion/approval process) |
| §9 Change Log | During version iterations |

---

## II. Code Specification (When Agent needs code implementation)

> **When code is needed**: Parts where "Executor" is `script:*` in Pipeline steps.
> **When code is not needed**: All steps are `skill:*` or `native` → Lobster directly executes Playbook, no code needed.

### 2.1 Project Structure

```
agent-<name>/
├── README.md               ← Project description (references Playbook)
├── PLAYBOOK.md             ← Agent operation manual (core document)
├── src/
│   ├── datasources/        ← Data source modules (one file per source)
│   │   ├── seo-tool.py      ← Call wrapper for existing Skills
│   │   ├── apify_fb_ads.py
│   │   └── __init__.py
│   ├── pipeline/           ← Pipeline steps
│   │   ├── step1_fetch.py
│   │   ├── step2_clean.py
│   │   ├── step3_score.py
│   │   └── step4_output.py
│   ├── filters.py          ← Filtering and sorting logic
│   ├── formatters.py       ← Output formatting (separated from business logic)
│   └── config.py           ← Parameter configuration
├── config/
│   ├── params.yaml         ← Configurable parameters (corresponds to Playbook §7)
│   └── .env.example        ← Environment variable template
├── data/
│   ├── cache/              ← Cache (for Fallback use)
│   └── output/             ← Output archive
├── tests/
│   ├── test_datasources.py ← Independent test for each data source
│   ├── test_pipeline.py    ← Pipeline integration test
│   └── fixtures/           ← Mock data
├── scripts/
│   ├── run.sh              ← Entry script (Cron calls)
│   └── run_step.sh         ← Single step debug entry
└── package.json / requirements.txt
```

### 2.2 Data Source Module Specification

**Each data source file must implement a unified interface**:

```python
# Python example
class DataSource:
    """Unified data source interface"""
    
    def fetch(self, params: dict) -> dict:
        """
        Unified entry point
        Returns: { "ok": bool, "data": list[dict], "error": str|None, "cached": bool }
        """
        pass
    
    def validate(self) -> bool:
        """Check if API key / connection is available"""
        pass
```

```javascript
// Node.js example
module.exports = {
  async fetch(params) {
    // Returns: { ok, data, error, cached }
  },
  async validate() {
    // Returns: boolean
  }
}
```

**Key Rules**:

| Rule | Description |
|------|-------------|
| No exceptions | On failure return `{ ok: false, error: "...", data: [] }`, don't interrupt Pipeline |
| Has cache | On success write to `data/cache/<source>_<date>.json`, on failure read cache |
| Has Mock | `tests/fixtures/<source>_mock.json` for offline testing |
| Has timeout | Set timeout for each request (default 30s) |
| Has logging | Record request duration, return row count, error info |
| Reuse Skill | If company already has Skill, wrap the call instead of rewriting |
**Writing Style for Reusing Existing Skills**:

```python
# Reuse company seo-tool Skill
import subprocess, json

def fetch_seo-tool(domain, limit=100):
    """Call company SEO Tool Skill script"""
    result = subprocess.run(
        ["bash", "/shared/company-skills/seo-tool/scripts/query.sh",
         "--type", "domain_organic", "--domain", domain, "--limit", str(limit)],
        capture_output=True, text=True, timeout=60
    )
    if result.returncode != 0:
        return {"ok": False, "error": result.stderr, "data": []}
    return {"ok": True, "data": parse_csv(result.stdout), "error": None}
```

```javascript
// Reuse company Apify Skill
const { execSync } = require('child_process');

function fetchApify(actorId, input) {
  // Call through Apify Skill
  const cmd = `APIFY_TOKEN=$APIFY_TOKEN node /shared/company-skills/apify/run-actor.js "${actorId}" '${JSON.stringify(input)}'`;
  try {
    const output = execSync(cmd, { timeout: 120000 }).toString();
    return { ok: true, data: JSON.parse(output), error: null };
  } catch (e) {
    return { ok: false, data: [], error: e.message };
  }
}
```

### 2.3 Pipeline Specification

```python
# pipeline/step1_fetch.py

def run(context: dict) -> dict:
    """
    Each Step is an independent function
    
    Args:
        context: Pipeline context (output from previous steps + global configuration)
    Returns:
        { "ok": bool, "data": any, "error": str|None, "stats": dict }
    """
    pass
```

**Pipeline Orchestration** (main entry):

```python
# run_pipeline.py
from pipeline import step1_fetch, step2_clean, step3_score, step4_output

STEPS = [
    ("fetch",  step1_fetch.run),
    ("clean",  step2_clean.run),
    ("score",  step3_score.run),
    ("output", step4_output.run),
]

def run(config):
    context = {"config": config, "results": {}}
    
    for name, step_fn in STEPS:
        print(f"[{name}] Starting...")
        result = step_fn(context)
        context["results"][name] = result
        
        # Persist intermediate results (for checkpoint recovery)
        save_checkpoint(name, result)
        
        if not result["ok"]:
            print(f"[{name}] Failed: {result['error']}")
            # Don't interrupt, mark as failed, subsequent steps can check
    
    return context
```

**Key Rules**:

| Rule | Description |
|------|-------------|
| Independent Steps | Each Step can run independently: `python -m pipeline.step2_clean` |
| Intermediate Persistence | Each step result writes to `data/cache/step_<N>_<date>.json`, Pipeline can resume from checkpoint after interruption |
| Parallel Support | Steps without dependencies can run in parallel (using `asyncio.gather` or `Promise.all`) |
| Unified Return | `{ ok, data, error, stats }` — stats records duration, row count, etc. |
| Idempotent | Multiple executions with same parameters yield consistent results |

### 2.4 Output Formatting Specification

**Separate formatting from business logic**:

```python
# formatters.py — Only responsible for formatting, not business logic

def to_slack_table(data: list[dict], columns: list, title: str) -> str:
    """Generate Slack code block table"""
    pass

def to_sheet_rows(data: list[dict], columns: list) -> list[list]:
    """Generate Google Sheet row data"""
    pass

def to_notion_blocks(data: list[dict]) -> list[dict]:
    """Generate Notion block format"""
    pass
```

### 2.5 Configuration Specification

```yaml
# config/params.yaml
# Corresponds to configurable parameters in Playbook §7

defaults:
  region: "US"
  timerange: "daily"
  top_n: 10

filters:
  min_volume: 500
  max_kd: 65
  exclude_regions: ["IN"]

scoring:
  volume_weight: 40
  kd_weight: 30
  ads_weight: 15
  base_score: 15
  dedup_penalty: 30

schedule:
  cron: "0 9 * * *"
  timeout_per_step: 300  # seconds
  timeout_total: 1800
```

### 2.6 Testing Specification

```
tests/
├── fixtures/
│   ├── seo-tool_mock.json      ← Mock responses for each data source
│   └── pipeline_input.json    ← Pipeline test input
├── test_datasources.py        ← Data source unit tests
├── test_filters.py            ← Filtering logic tests
├── test_pipeline.py           ← Pipeline integration tests
└── test_formatters.py         ← Output format tests
```
**Minimum Testing Requirements**:

| Test Type | Coverage | Required |
|---------|---------|------|
| Data Source Mock | Each data source normal/error/timeout | ⭐ Yes |
| Filtering Logic | Boundary values, empty data | ⭐ Yes |
| Output Format | Format correctness | Yes |
| Pipeline | Complete process dry-run | Yes |
| Breakpoint Recovery | Recovery after intermediate step failure | Recommended |

### 2.7 Language Selection Guide

| Scenario | Recommended Language | Reason |
|------|---------|------|
| Data Processing/Analysis | Python | pandas/strongest data ecosystem |
| API Calls/Scraping | Node.js | Lobster Farm native environment, Apify SDK |
| Skill Scripts | Bash | Company Skill standard (query.sh) |
| Frontend Dashboard | React + Vite | your existing frontend dashboard already uses this |

> **Unified language not mandatory**, but try to use one primary language within the same Agent.

---

## III. Requirements Input → Playbook Conversion SOP

### Requirements Input Methods (Three types, all supported)

| Method | Description | Lobster Farm Processing |
|------|------|---------|
| **① Slack Canvas** ⭐Recommended | User writes requirements in Slack Canvas | Use `slack-canvas` Skill to read directly, zero permission configuration |
| **② Direct Text** | User describes requirements directly in conversation/Thread | Extract information from conversation, ask for missing items |
| **③ Notion Page** | User provides Notion link | Use Notion API to read (requires Connect integration first) |

> **Priority**: Canvas > Direct Text > Notion (ordered by usability).
> **Core Principle**: Regardless of input method, Lobster Farm's processing flow is consistent — Extract six elements → Generate Playbook.

**Processing Details for Each Method**:

**① Slack Canvas (Recommended)**
- User creates Canvas with requirements → pin to channel or send link
- Lobster Farm reads Canvas content → extracts six elements
- Generated Playbook can also be written back to new Canvas (convenient for team review)
- *Advantages*: Bot has natural read/write permissions, visible to all channel members, discussion and documentation in same place

**② Direct Text**
- User describes requirements directly in Slack messages / Thread (free format)
- Lobster Farm extracts structured information from conversation
- *Key Point*: Information often incomplete → Lobster Farm must actively ask for missing items (see Step 2)
- *Applicable*: Simple requirements, rapid iteration, supplementary explanations

**③ Notion Page**
- User provides Notion page link
- Prerequisite: Page needs to Connect to integration (permission granularity is page-level)
- If permission fails → suggest user switch to Canvas or paste text directly
- *Applicable*: Scenarios with existing detailed Notion documentation

---

### Conversion Process (7 Steps)

### Step 1: Determine Agent Level

```
Number of data sources?
  ≤1 → L1 (SKILL.md sufficient, no Playbook needed)
  >1 and steps ≤5 → L2 (SKILL.md + embedded Workflow)
  >1 with sorting/scheduling → L3 (complete Playbook)
  Involves multi-person decisions → L4 (Playbook + interaction protocol)
```

### Step 2: Extract Six Elements

Identify from user input (Canvas / Text / Notion):
1. 🎯 Goal (What / Who / Metric)
2. 📊 Data source list
3. 🔄 Execution steps
4. 📋 Filter conditions / Sorting logic
5. 📤 Output format and examples
6. ⏰ Trigger frequency

**Missing items → Actively confirm with user**, don't assume.

> 💡 **For direct text input**, information is usually scattered and incomplete, Lobster Farm should:
> - First organize acquired information, list it for user confirmation
> - Clearly list missing items, ask about each one
> - Can provide reasonable suggestions for user to choose from (rather than asking empty questions)

### Step 3: Check Each Data Source Against Five Standards

For each data source, check:
- [ ] Access method clear? (Priority: check existing Skill → free API → Apify → scraping)
- [ ] Field definitions complete?
- [ ] Header examples available?
- [ ] Query scenarios clear?
- [ ] Return format confirmed?

### Step 4: Determine Execution Method

For each Pipeline step, annotate "executor":
- Can use existing Skill → `skill:xxx`
- Lobster Farm reasoning capability can complete → `native`
- Need to write code → `script:xxx` (trigger code standards)
- Need manual work → `manual`

### Step 5: Generate Playbook

Output complete Playbook according to this specification §1-§6.

**Output Medium Selection**:
- Team-visible Agent → Write to *Slack Canvas* (recommended), pin to relevant channel
- Personal Agent → Write to Lobster Farm `workspace/playbooks/`
- Company-level Agent → Write to `company-skills/<agent>/PLAYBOOK.md`

### Step 6: Determine if Code is Needed

```
Are there script:* steps in Pipeline?
  No  → Lobster Farm executes directly according to Playbook, complete✅
  Yes → Create project structure according to code standards (Chapter 2) → Implement coding
```

### Step 7: Validation

- [ ] Playbook quality self-check (see checklist below)
- [ ] Dry-run execute once
- [ ] Compare output with expectations
- [ ] Update Changelog

---

## IV. Quality Self-Check List

### Playbook Check

- [ ] §1: Complete goal three elements (What / Who / Metric)
- [ ] §2: Complete five standards for each data source
- [ ] §2: Data sources prioritize reusing existing Skills (don't reinvent the wheel)
- [ ] §3: Each step has input/processing/output/executor/failure handling
- [ ] §3: Parallel steps are marked
- [ ] §4: Clear decision rules (conditions/judgment/results/reasons), no ambiguous space
- [ ] §5: Complete output samples with fixed code blocks
- [ ] §6: Clear Fallback chain, scheduling frequency and timeout settings
- [ ] Dry-run passes at least once

### Code Check (if code exists)

- [ ] Project structure conforms to 2.1
- [ ] Data source implements unified interface (fetch → {ok, data, error})
- [ ] Data source failures don't throw exceptions, have cache, have Mock
- [ ] Pipeline steps can run independently
- [ ] Intermediate results persisted (breakpoint recovery)
- [ ] Formatting separated from business logic
- [ ] config/params.yaml externalizes adjustable parameters
- [ ] tests/ covers data source Mock + filtering boundary values
- [ ] .env.example lists all required environment variables
## 5. Quick Reference for Existing Agent Capabilities (Refer when Writing Playbooks)

> Check this table before writing Playbooks. Reuse existing capabilities directly, don't rewrite.

### Data Query Capabilities

| Skill | Data | Invocation Method |
|-------|------|---------|
| `seo-tool` | SEO keywords, competitor analysis, traffic | `bash /shared/company-skills/seo-tool/scripts/query.sh` |
| `mysql` | Production database 360+ tables | Embedded SQL in Skill |
| `observability` | Observability Platform DQL (metrics/logs/traces) | DQL queries |
| `tracing` | Production trace data | Trace queries |
| `attribution-tool` | Attribution data, installs, Campaign | Report API |
| `bot-monitor` | Bot call volume/error rate/latency | `node scripts/bot_monitor.js` |
| `cms-tool` | CMS/Landing Page data | `bash scripts/query.sh` |
| `app-store` | Mobile app downloads/revenue | App Store API |
| `notion-image-bots` | Image generation Bot database 1800+ entries | `bash query.sh` |
| `google-workspace` | Docs/Sheets/Drive/Calendar | OAuth API |

### External Data Collection

| Skill | Capability | Use Case |
|-------|------|------|
| `apify` | Call any Apify Actor | FB Ads / IG / TikTok etc. |
| `browser-cdp` | Chrome browser automation | Web pages requiring login state |
| `deep-research` | Multi-model parallel deep research | Research tasks |

### Output Capabilities

| Skill | Output | Use Case |
|-------|------|------|
| `slack-canvas` | Slack canvas read/write | Structured report display |
| `excalidraw-diagram-generator` | Flowcharts/architecture diagrams | Visualization |
| `google-workspace` | Google Sheet writing | Data archiving |
| `weekly-report` | Weekly report templates | Regular summaries |
| `task-management` | Task board operations (any backend) | Task creation/updates |

### Process Capabilities

| Skill | Process | Use Case |
|-------|------|------|
| `structured-decision-alignment` | Multi-person decision alignment | L4 collaborative Agent |
| `landing-page-optimizer` | Page SEO optimization | Batch page processing |
| `bottleneck-reporting` | Automatic bottleneck identification and reporting | Team efficiency |
| `skill-contribution` | Skill submission and approval | Capability sharing |

---

## 6. File Storage Conventions

| File | Location | Description |
|------|------|------|
| Playbook (Personal) | Lobster Farm `workspace/playbooks/PLAYBOOK-<name>.md` | Personal Agent |
| Playbook (Company-level) | `company-skills/<agent>/PLAYBOOK.md` | Available to all |
| Code Project (Personal) | Lobster Farm `workspace/agents/<name>/` or GitHub repo | Personal development |
| Code Project (Company-level) | GitHub org repo + `company-skills/` Skill entry | Team collaboration |

---

*Specification version: v2.1 | Updated: 2026-03-10 | Authors: Master Control + Bob*

---

## Appendix A: Task-type Agent Design Standards (2026-03-10)

> Applies to all Agents involving task creation/update/reading (not limited to Notion).
> Operational rules (Board read/write division, permission authorization) see `company-memory/team-guidelines.md`.

### A.1 Additional Playbook Requirements for Task Agents

In addition to the standard Playbook six elements, task-type Agents **must additionally satisfy**:

| Item | Requirement |
|------|------|
| **Task Deduplication** | Must query existing tasks before creation to avoid duplicates. Check dimensions: title similarity + associated source |
| **Task Ownership** | Each task must be associated with a specific person (inferred from `module-owners.md` or conversation context) |
| **Source Traceability** | Task description must include source ("from #channel YYYY-MM-DD conversation" or "assigned by user @xxx") |
| **Status Initialization** | New tasks default to `Backlog` status unless explicitly specified by user |
| **Priority Assessment** | Determine priority based on context (P0 urgent / P1 this week / P2 this iteration / P3 Backlog) |

### A.2 Standards for Reading Task Data

When Agents read others' task/responsibility data:

1. **Clear Purpose**: Only to assist task assignment decisions, no other uses
2. **Respect Permissions**: Follow read/write division in `team-guidelines.md`, don't write without authorization
3. **Caching Strategy**: Read once per day (avoid frequent API calls), cache locally
4. **Privacy Boundaries**: Personal task information read should not be displayed in public channels, only used for Agent internal decisions

---

## Appendix B: Credential Management Standards (2026-03-07)

### New Skill Credential Standards

**Priority**: SecretRef > secrets.json reading > .env environment variables

1. **If OpenClaw has corresponding configuration fields** (e.g., `models.providers.*.apiKey`, `tools.web.search.apiKey`):
   - Configure SecretRef in openclaw.json, store value in `secrets.json`
   - Skill doesn't need to manage credentials itself, OpenClaw auto-injects

2. **If no corresponding field** (e.g., MySQL, custom API):
   - Store credentials in `secrets.json`
   - Skill script reads from `secrets.json`: `python3 -c "import json; print(json.load(open('$SECRETS_PATH'))['KEY_NAME'])"`
   - `SECRETS_PATH` default: `/home/lobster/.openclaw/secrets.json` (inside container)

3. **Not recommended**: Creating new `.env.xxx` files (legacy ones can be kept, don't use for new skills)

### Why Not Use .env

- `.env` injects via Docker env, requires container rebuild when changed
- `secrets.json` can hot reload with `openclaw secrets reload` when changed
- Unified credential storage location, easier to audit and manage