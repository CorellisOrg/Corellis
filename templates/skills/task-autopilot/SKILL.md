---
name: task-autopilot
slug: task-autopilot
description: "Automatic task decomposition and execution planning. Receives a high-level task, breaks it into subtasks, classifies each (code/research/design/ops), estimates effort, identifies dependencies, and generates a structured plan for owner approval. Works standalone or as part of goal-ops workflows."
---

# Task Autopilot — Automatic Task Decomposition

> Big task in → Structured plan out → Execute on approval
>
> Takes a vague or complex task and produces a concrete, actionable plan
> with subtasks, classifications, effort estimates, and dependency ordering.

## When to Trigger

- **Goal-ops integration**: Controller assigns you a sub-goal (SG) — decompose it into subtasks
- **Direct assignment**: Owner says "do X" where X is complex (multiple steps, multiple concerns)
- **Proactive engine**: After proactive-task-engine identifies a task, autopilot decomposes it
- **Manual**: "break this down" / "plan this out" / "decompose this task"

**Skip autopilot when**: Task is simple and single-step (just do it directly)

## Decomposition Flow

```
┌────────────┐     ┌────────────┐     ┌────────────┐     ┌────────────┐
│   Parse    │ ──▶ │ Decompose  │ ──▶ │  Classify  │ ──▶ │  Present   │
│   Input    │     │ into Steps │     │  & Score   │     │   Plan     │
└────────────┘     └────────────┘     └────────────┘     └────────────┘
```

## Phase 1: Parse Input

Extract from the task description:

| Field | Source | Default |
|-------|--------|---------|
| Objective | Task description | Required |
| Deadline | Explicit date or "ASAP" / "this week" | None |
| Constraints | Budget, tech stack, dependencies | None |
| Acceptance criteria | Explicit deliverables | Infer from objective |
| Context | Related threads, docs, prior work | Search memory |

If acceptance criteria are missing, generate them and ask for confirmation.

## Phase 2: Decompose

Break the task into subtasks. Rules:

1. **Each subtask should be completable in one work session** (< 4 hours)
2. **Each subtask has a single clear deliverable** (a file, a PR, a report, a config)
3. **Minimize dependencies between subtasks** — prefer parallel execution
4. **Include verification steps** — don't just "write code", also "test code"

### Decomposition Strategy

| Task Size | Approach |
|-----------|----------|
| Small (< 2h) | 2-3 subtasks max, often just do/verify |
| Medium (2-8h) | 4-6 subtasks with clear phases |
| Large (> 8h) | Flag to owner — may need goal-ops level orchestration |

## Phase 3: Classify & Score

For each subtask, assign:

### Classification

| Type | Description | Typical Tools |
|------|-------------|---------------|
| `code` | Write/modify code, create PRs | ACP agents, exec, git |
| `research` | Investigate options, read docs, analyze data | web_search, web_fetch, read |
| `design` | UI/UX specs, architecture decisions, diagrams | browser, canvas, design tools |
| `ops` | Deploy, configure, monitor, debug | exec, docker, ssh |
| `comms` | Write docs, send updates, coordinate | message, write |

### Effort Estimate

| Label | Time | Description |
|-------|------|-------------|
| `trivial` | < 15 min | Config change, simple lookup |
| `small` | 15-60 min | Single-file change, short research |
| `medium` | 1-3 hours | Multi-file feature, detailed research |
| `large` | 3-8 hours | Complex feature, integration work |

### Confidence Score (1-10)

How confident are you that you can complete this subtask successfully?

- **8-10**: Done this before, clear path
- **5-7**: Mostly clear, some unknowns
- **1-4**: Significant unknowns, may need help

## Phase 4: Present Plan

Output a structured plan for approval:

```markdown
📋 **Task Plan: [Task Title]**

**Objective**: [1-sentence summary]
**Total Effort**: ~X hours
**Deadline**: [date or "none"]

| # | Subtask | Type | Effort | Confidence | Depends On |
|---|---------|------|--------|------------|------------|
| 1 | Research existing solutions | research | small | 9/10 | — |
| 2 | Design API schema | design | medium | 8/10 | #1 |
| 3 | Implement backend endpoints | code | medium | 7/10 | #2 |
| 4 | Write integration tests | code | small | 8/10 | #3 |
| 5 | Deploy to staging | ops | trivial | 9/10 | #4 |
| 6 | Update documentation | comms | small | 9/10 | #3 |

**Execution Order**:
- Parallel: #1 can start immediately
- Sequential: #2 → #3 → #4 → #5
- Parallel: #6 can start after #3

**Risks**:
- #3 depends on [external API] — if unavailable, will mock and flag

**Acceptance Criteria**:
- [ ] All endpoints return correct responses
- [ ] Test coverage > 80%
- [ ] Deployed and accessible on staging

Approve this plan? (reply "go" / "adjust #3 to ..." / "skip #6")
```

## After Approval

1. **Update task board** (if integrated): Create subtask entries
2. **Execute sequentially**: Complete each subtask, report progress
3. **Checkpoint after each subtask**: Brief status update in thread
4. **On completion**: Summary report with all deliverables

## Integration with Goal-Ops

When used within a goal-ops workflow:

1. Controller assigns SG → triggers task-autopilot
2. Autopilot decomposes → posts plan in SG thread
3. Controller (or owner) approves → lobster executes
4. Subtask completions update the task board
5. All subtasks done → lobster reports to controller for acceptance

## Configuration

Optional `autopilot-config.json` in workspace:

```json
{
  "autoDecompose": true,
  "maxSubtasks": 8,
  "requireApproval": true,
  "defaultTaskBoard": "notion",
  "confidenceThreshold": 5
}
```

## File Structure

```
skills/task-autopilot/
├── SKILL.md              # This file
└── references/
    └── classification-guide.md  # Detailed type/effort classification examples
```

## Dependencies

- Task board integration (optional, for creating subtask entries)
- goal-participant skill (when used within goal-ops)
- Owner/controller for plan approval
