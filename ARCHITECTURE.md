# Architecture

## Design Philosophy

Lobster Farm uses **Skill-based orchestration**. Skills are not configuration — they are the implementation. There is no separate "orchestration engine" because the orchestration logic lives in the skills themselves, executed by the OpenClaw runtime.

This is a deliberate design choice, not a gap:

- **Skills are executable specifications.** A skill like `goal-participant` contains the full protocol for receiving, decomposing, executing, and reporting on goals. The OpenClaw runtime interprets and executes these specifications with full tool access.
- **The runtime IS the engine.** OpenClaw provides the execution environment (tool calls, memory, sessions, cron, sub-agents). Lobster Farm provides the organizational layer (what to do, when, and how to coordinate).
- **Analogy:** Kubernetes doesn't have a "deployment engine" binary — it has YAML specs and a runtime that interprets them. Lobster Farm follows the same pattern: declarative skill specs + capable runtime.

## System Layers

```
┌─────────────────────────────────────────────┐
│  Layer 4: Governance & Skills               │
│  AGENTS.md, manifest.json, 17 skills        │
│  → Defines behavior, protocols, permissions │
├─────────────────────────────────────────────┤
│  Layer 3: Fleet Operations                  │
│  24 shell scripts + Teamind (Node.js)       │
│  → Spawn, sync, upgrade, monitor, backup    │
├─────────────────────────────────────────────┤
│  Layer 2: Container Isolation               │
│  Docker + bind mounts + secrets             │
│  → Per-lobster isolation with shared reads  │
├─────────────────────────────────────────────┤
│  Layer 1: OpenClaw Runtime                  │
│  Gateway, sessions, tools, cron, ACP        │
│  → Execution engine for each lobster        │
└─────────────────────────────────────────────┘
```

**Lobster Farm owns Layers 2–4. Layer 1 (OpenClaw) is the upstream dependency.**

## GoalOps: How Goals Become Results

```mermaid
sequenceDiagram
    participant Owner as 👤 Owner
    participant Ctrl as 🎛️ Controller
    participant LobA as 🦞 Lobster A
    participant LobB as 🦞 Lobster B
    participant Board as 📋 Task Board

    Owner->>Ctrl: "Launch competitive analysis for product X"
    
    Note over Ctrl: Phase 1: Decompose
    Ctrl->>Ctrl: Break into sub-goals (SGs)
    Ctrl->>LobA: SG-1: Market research
    Ctrl->>LobB: SG-2: Feature comparison
    
    Note over LobA,LobB: Phase 2: Self-Decompose & Execute
    LobA->>Board: Create tasks for SG-1
    LobA->>LobA: Execute tasks (web search, analysis)
    LobB->>Board: Create tasks for SG-2
    LobB->>LobB: Execute tasks (competitor docs, feature matrix)
    
    Note over LobA,LobB: Phase 3: P2P Coordination
    LobB->>LobA: "Need your market data for comparison"
    LobA->>LobB: Share findings via Slack thread
    
    Note over LobA,LobB: Phase 4: Completion
    LobA->>Ctrl: SG-1 complete ✓
    LobB->>Ctrl: SG-2 complete ✓
    Ctrl->>Owner: Full analysis delivered
```

**Key insight:** The Controller doesn't micromanage. It decomposes and delegates. Lobsters self-organize, coordinate peer-to-peer, and report back. The `goal-participant` skill defines the complete protocol each lobster follows.

## Memory Architecture

```mermaid
graph TD
    subgraph "Layer 4: Company (read-only)"
        CK[company-memory/]
        CS[company-skills/]
        CC[company-config/]
    end
    
    subgraph "Layer 3: Channel"
        CH[team/channels/ChannelID.md]
    end
    
    subgraph "Layer 2: Member"
        M[team/members/UserID.md]
    end
    
    subgraph "Layer 1: Private"
        P[MEMORY.md + daily logs]
    end
    
    CK --> CH
    CH --> M
    M --> P
    
    style CK fill:#e8f5e9
    style CS fill:#e8f5e9
    style CC fill:#e8f5e9
    style CH fill:#e3f2fd
    style M fill:#fff3e0
    style P fill:#fce4ec
```

**Information flows downward only.** Company knowledge is visible to all. Private memory is visible only to the owner and their lobster. Promoting information upward (private → shared) requires explicit action.

## Self-Improving Loop

```mermaid
flowchart LR
    A[User corrects lobster] -->|Semantic detection| B[Record in .learnings/]
    B --> C{Daily cron scan}
    C -->|Pattern appears 3x| D[Promote to MEMORY.md]
    C -->|Affects all lobsters| E[Promote to AGENTS.md]
    E --> F[Fleet-wide sync]
    F --> G[All lobsters learn]
```

The correction detection is **semantic, not keyword-based**. A lobster recognizes corrections from context: direct negation, alternative answers, gentle guidance, demonstrations, or even the user giving up ("forget it, I'll do it myself" — a strong failure signal).

## Bottleneck Detection Flow

```mermaid
flowchart TD
    L[Lobster detects blocker] -->|Write report| BI[/shared/bottleneck-inbox/]
    BI --> P{Controller polls}
    P -->|Every 5 min| T[Triage: severity + category]
    P -->|Daily scan| A[Aggregate patterns]
    T -->|Systemic| CM[Promote to company-memory]
    T -->|Individual| N[Notify team lead]
    A -->|Common pattern| SK[Create new skill]
```

## Why Shell Scripts?

Fleet management is fundamentally about orchestrating Docker, files, and APIs on a host machine. Shell is the natural language for this:

- **Direct Docker/system access** — no abstraction layer needed
- **Composable** — pipe, grep, jq work out of the box
- **Auditable** — every script is readable, greppable, diffable
- **No build step** — clone and run
- **Battle-tested patterns** — `set -euo pipefail`, `--dry-run`, `--verbose`, `--json` output

The Node.js modules (Teamind) are used where they should be: async I/O, embeddings, database access.

## FAQ

**Q: Why does Corellis depend on OpenClaw instead of being standalone?**
A: OpenClaw provides the AI runtime (LLM sessions, tool execution, cron, sub-agents). Reimplementing this would be wasteful. Lobster Farm adds the fleet layer: multi-agent coordination, shared memory, governance, and operational tooling. This is the same relationship as "Helm depends on Kubernetes."

**Q: Can I use this without Slack?**
A: Teamind and some broadcast scripts require Slack. The core fleet management (spawn, health-check, upgrade, backup) works with any OpenClaw-supported channel. Skill-based features (GoalOps, self-improving) are channel-agnostic.

**Q: How does this compare to other multi-agent frameworks (CrewAI, AutoGen, etc.)?**
A: Most multi-agent frameworks focus on task-level orchestration (chain agents for a single task). Lobster Farm operates at the organizational level: persistent agents with memory, identity, and relationships, running 24/7. See [Alternatives](#alternatives) in README for a detailed comparison.
