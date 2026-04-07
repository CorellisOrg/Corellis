---
name: coding-workflow
slug: coding-workflow
description: "Structured workflow for collaborating with ACP coding agents (Claude Code, Codex, Cursor, etc). Confidence-based routing, structured prompts, output verification, and session management. Ensures code changes are correct, tested, and reviewed before merging."
---

# Coding Workflow — ACP Agent Collaboration

> Assess → Route → Prompt → Verify → Ship
>
> A structured approach to working with AI coding agents (ACP sessions).
> Prevents blind code generation by enforcing verification at every step.

## When to Use

- Any task that involves writing, modifying, or reviewing code
- When you need to spawn an ACP coding session (Claude Code, Codex, etc.)
- Code-related subtasks from task-autopilot or goal-ops

**Skip when**: Simple file edits you can do directly with `edit` tool (< 5 lines)

## Confidence-Based Routing

Before spawning a coding agent, assess your confidence in the task:

| Confidence | Score | Action |
|------------|-------|--------|
| High | 8-10 | Auto-execute: spawn agent with clear instructions, verify output |
| Medium | 5-7 | Structured prompt: provide detailed context, review carefully |
| Low | 1-4 | Ask human: present the problem and proposed approach first |

### Confidence Assessment Factors

| Factor | High (8-10) | Medium (5-7) | Low (1-4) |
|--------|-------------|--------------|-----------|
| Codebase familiarity | Worked in this repo before | Read the code, understand structure | Never seen this codebase |
| Task clarity | Exact requirements known | General direction clear | Ambiguous requirements |
| Risk level | Isolated change, easy rollback | Touches multiple files | Core logic, breaking changes possible |
| Test coverage | Good tests exist | Some tests | No tests, can't verify |

## Workflow

### Step 1: Prepare Context

Before spawning a coding agent, gather:

```markdown
## Context Package
- **Repository**: [repo name and path]
- **Branch**: [working branch]
- **Relevant files**: [list key files the agent needs to read]
- **Task**: [clear description of what to change]
- **Constraints**: [style guide, framework version, no-go areas]
- **Tests**: [how to verify — test command, manual check, etc.]
- **Reference**: [related PRs, docs, or examples]
```

### Step 2: Spawn Agent Session

```
sessions_spawn:
  runtime: "acp"
  task: |
    [Structured prompt — see templates below]
  mode: "run"  # one-shot for simple tasks
  # mode: "session"  # persistent for complex multi-step work
```

### Step 3: Verify Output

After the agent completes, verify before committing:

#### Automated Checks
- [ ] Tests pass: `npm test` / `go test ./...` / `pytest`
- [ ] Lint clean: `eslint` / `golangci-lint` / `ruff`
- [ ] Build succeeds: `npm run build` / `go build`
- [ ] No regressions: existing tests still pass

#### Manual Review
- [ ] Changes match the task requirements
- [ ] No unnecessary file modifications
- [ ] No hardcoded values (secrets, URLs, IDs)
- [ ] Code style consistent with existing codebase
- [ ] Error handling present for edge cases

### Step 4: Iterate or Ship

| Verification Result | Action |
|--------------------|--------|
| All checks pass | Commit, push, create PR |
| Minor issues | Send follow-up instructions to same session |
| Major issues | Kill session, reassess approach, restart |
| Fundamentally wrong | Stop, report to owner for guidance |

## Prompt Templates

### Feature Implementation

```
Task: Implement [feature name]

Context:
- Repository: [path]
- This is a [framework] project
- Related existing code: [file paths]

Requirements:
1. [Specific requirement 1]
2. [Specific requirement 2]
3. [Specific requirement 3]

Constraints:
- Follow existing code style in [reference file]
- Use [specific library] for [purpose]
- Do NOT modify [protected files]

Verification:
- Run: [test command]
- Expected: [what success looks like]

Please implement this and run the tests before finishing.
```

### Bug Fix

```
Task: Fix [bug description]

Reproduction:
1. [Step to reproduce]
2. [Expected behavior]
3. [Actual behavior]

Likely location: [file path, function name]

Root cause hypothesis: [your theory]

Fix requirements:
- Fix the bug without changing public API
- Add a test that would have caught this
- Run existing tests to check for regressions

Verification:
- Run: [test command]
- The new test should pass
- All existing tests should still pass
```

### Code Review

```
Task: Review this PR / these changes

Files changed:
- [file list]

Review checklist:
1. Correctness: Does the logic do what it claims?
2. Edge cases: Missing null checks, empty arrays, error paths?
3. Performance: Any N+1 queries, unnecessary loops, memory leaks?
4. Security: Input validation, SQL injection, XSS, auth checks?
5. Style: Consistent with codebase conventions?

Output format:
- List issues as: [SEVERITY] file:line — description
- Severity: CRITICAL / WARNING / SUGGESTION
- End with overall assessment: APPROVE / REQUEST_CHANGES
```

## Session Management

### When to Reuse Sessions

| Scenario | Mode | Reason |
|----------|------|--------|
| Single file change | `run` (one-shot) | Simple, no state needed |
| Multi-step feature | `session` (persistent) | Needs context across steps |
| Iterating on feedback | `session` | Agent remembers prior attempts |
| Independent tasks | Separate `run` sessions | Clean context for each |

### Session Hygiene

- **Kill stale sessions**: If a session hasn't produced output in 10 minutes
- **Don't reuse across tasks**: Start fresh for unrelated work
- **Save important output**: Copy key files/diffs before killing sessions

## File Structure

```
skills/coding-workflow/
├── SKILL.md              # This file
└── references/
    ├── prompt-templates.md    # Extended prompt templates
    └── verification-checklist.md  # Detailed verification steps
```

## Dependencies

- ACP runtime configured (acp.json with allowed agents)
- Git access to target repositories
- Test/lint tooling installed in workspace
- sessions_spawn capability
