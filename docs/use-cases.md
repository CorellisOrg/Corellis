# Use Cases — What Problems Does Lobster Farm Solve?

> **TL;DR**: Lobster Farm isn't 17 separate tools. It's one system with 17 capabilities, organized around five real problems teams face when deploying AI assistants.

---

## Problem 1: "My AI just sits there waiting for instructions"

Most AI assistants are reactive — they answer when asked, then go idle. Your team has an OKR board, a backlog, and recurring deadlines, but the AI doesn't know about any of it unless someone tells it what to do, every time.

**What Lobster Farm does:**

| Capability | How it helps |
|---|---|
| **Task Management** | Proactive scanning: lobsters periodically check the task board, find overdue/blocked items, and notify owners before things slip. |
| **Goal Participant (GoalOps)** | Controller assigns sub-goals → lobsters self-decompose into tasks → execute → report back. No one needs to micromanage. |
| **Approval Flow** | When a lobster identifies work to do, it proposes an action plan and waits for human approval — not a blank "what should I do?" |
| **Non-Blocking Wait** | Long-running tasks (CI, external reviews) don't block the session. Lobsters hand off to cron/subagents and come back when ready. |

**Before**: Manager assigns task → AI does it → goes idle → repeat.
**After**: Lobster scans board → finds work → proposes plan → gets approval → executes → moves to next item.

---

## Problem 2: "We discussed it in Slack, but nobody wrote it down"

Teams make decisions in Slack threads that never get documented. Three weeks later, no one remembers why a feature was cut or what the agreed API design was.

**What Lobster Farm does:**

| Capability | How it helps |
|---|---|
| **Task Management** (TODO Extraction) | Extracts actionable items from Slack threads, assigns owners, writes them to the task board automatically. |
| **Slack Canvas** | Lobsters write structured meeting notes, decisions, and summaries to Slack Canvases — searchable and permanent. |
| **Structured Decision Alignment** | For cross-team decisions: creates a structured thread, walks through each open question, collects sign-offs, and documents the outcome. |
| **Teamind** | Every Slack conversation is indexed with embeddings. Any lobster can search "what was decided about the payment API" and get sourced answers. |

**Before**: "I think we decided to use REST? Check the thread from two weeks ago..."
**After**: Lobster already extracted the TODOs, wrote the decision to a Canvas, and Teamind can surface the thread in 2 seconds.

---

## Problem 3: "My AI keeps making the same mistakes"

You correct your AI assistant on Monday. On Wednesday, it makes the same mistake. It has no persistent memory of what went wrong or why.

**What Lobster Farm does:**

| Capability | How it helps |
|---|---|
| **Self-Improving** | Lobsters detect when they're corrected (semantically, not just "you're wrong"), record the lesson, and never repeat it. Validated lessons promote to permanent memory. |
| **Bottleneck Reporting** | When a lobster hits a wall (3+ failures, missing info, tool errors), it files a structured report. The controller sees patterns across the fleet. |
| **Skill Contribution** | A lobster discovers a better way to do something → packages it as a skill → submits for review → gets promoted to the whole fleet. One lobster's learning benefits everyone. |

**Before**: Correct the AI → it forgets → correct again → repeat forever.
**After**: Correct once → lesson recorded → promoted fleet-wide → no lobster makes that mistake again.

---

## Problem 4: "I need real research, not a list of search results"

You ask for "competitive analysis" and get 10 bullet points scraped from the first page of Google. No synthesis, no cross-validation, no structure.

**What Lobster Farm does:**

| Capability | How it helps |
|---|---|
| **Deep Research** | Multi-model (Claude + Gemini + OpenAI) parallel research with cross-validation. Produces 10,000+ word reports with citations, not summaries. |
| **Browser CDP** | When research requires authenticated access (internal tools, paywalled sites), lobsters use the shared Chrome session via CDP — no manual cookie copying. |
| **Google Workspace** | Write research directly to Google Docs/Sheets. Pull data from existing spreadsheets. |
| **Excalidraw Diagrams** | Generate visual diagrams (architecture, flowcharts, mind maps) from natural language — output as `.excalidraw` files. |
| **Quick Data Dashboard** | Turn database queries into visual PNG dashboards with pure CSS charts. No JS dependencies, works everywhere. |

**Before**: "Summarize the market" → 5 generic paragraphs.
**After**: Multi-model deep dive → 15-page report with competitor matrix, architecture diagrams, and data dashboards.

---

## Problem 5: "We have 10 AI agents but they can't coordinate"

Each person has their own AI assistant, but they operate in silos. Agent A doesn't know what Agent B is working on. There's no shared context, no handoffs, no team awareness.

**What Lobster Farm does:**

| Capability | How it helps |
|---|---|
| **GoalOps** | Controller decomposes goals → assigns sub-goals → lobsters coordinate P2P via Slack threads. Dependency resolution happens automatically. |
| **Task Management** | Shared task board (backend-agnostic: Notion, Linear, GitHub Projects, or plain markdown). Everyone sees the same state. |
| **Teamind** | Shared memory across the fleet. Any lobster can search what others discussed, decided, or learned. |
| **CCP (Claude Code Proxy)** | When a lobster needs to write code, it can delegate to Claude Code with full context passing and session reuse. |
| **GitHub CLI** | Coordinated PR workflows: one lobster creates the PR, another reviews, a third monitors CI. All through the same GitHub integration. |

**Before**: 10 isolated assistants, each reinventing context from scratch.
**After**: A coordinated fleet where lobsters share memory, coordinate tasks, and hand off work seamlessly.

---

## Skills by Category

### 🎯 Task & Workflow
| Skill | What it does |
|---|---|
| `task-management` | Sprint planning, task breakdown, board CRUD, proactive scanning, TODO extraction. Backend-agnostic. |
| `goal-participant` | GoalOps participant: receive sub-goals, self-decompose, execute, report, cross-lobster coordination. |
| `approval-flow` | Send proposals to Slack, parse human decisions (approve/partial/skip/reject), callback execution. |
| `non-blocking-wait` | Never block a session on long waits. Use subagents or cron for async monitoring. |

### 🧠 Learning & Memory
| Skill | What it does |
|---|---|
| `teamind` | Semantic search across all Slack conversations. Thread summaries, daily digests. |
| `self-improving` | Auto-detect corrections, record lessons, promote validated patterns fleet-wide. |
| `bottleneck-reporting` | Detect blockers (repeated failures, missing info, tool errors) and file structured reports. |
| `skill-contribution` | Package personal discoveries as reusable skills, submit for fleet-wide promotion. |

### 🔬 Research & Analysis
| Skill | What it does |
|---|---|
| `deep-research` | Multi-model parallel research with cross-validation and cited reports. |
| `browser-cdp` | Chrome browser via CDP — reuse authenticated sessions for web access. |
| `google-workspace` | Google Docs, Sheets, Drive, Calendar, Gmail via OAuth. |
| `excalidraw-diagram-generator` | Natural language → Excalidraw diagrams (flowcharts, architecture, mind maps). |
| `quick-data-dashboard` | DB queries → visual PNG dashboards with pure CSS charts. |

### 🤝 Coordination & Communication
| Skill | What it does |
|---|---|
| `structured-decision-alignment` | Guide multi-person decisions: structured thread → per-question sign-off → documented outcome. |
| `slack-canvas` | Read and write Slack Canvases for persistent, searchable documentation. |
| `ccp` | Claude Code proxy — transparent relay for coding tasks with session reuse. |
| `github-cli` | Full GitHub CLI: issues, PRs, CI, code review, Actions, releases. |
