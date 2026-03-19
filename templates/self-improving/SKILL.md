---
name: self-improving
description: "Automatically learn from corrections, errors, and reflections. Triggers when you're corrected, make mistakes, discover better approaches, or complete important tasks. Uses semantic detection — not keyword matching."
metadata:
---

# Self-Improving Skill (2nd Me)

Learn from corrections, errors, and self-reflection. Record lessons in a structured format and persist them so every correction becomes permanent capability.

> **Core principle: semantic detection, not keyword matching.** Users correct you in countless ways — "that's wrong", "actually it should be...", or simply giving the right answer calmly. If you detect a correction in any form, trigger the self-improving flow.

---

## Trigger Conditions

### Must Trigger

| Scenario | Detection | Action |
|----------|-----------|--------|
| **Corrected by user** | User points out your understanding/approach/conclusion is wrong (no matter how gently) | Record correction + review |
| **Operation failed** | Command error, API failure, tool exception | Record error |
| **Outdated knowledge** | Information you cited is no longer valid, API behavior differs from your understanding | Record knowledge gap |
| **Better approach found** | Discovered a more efficient method after using another | Record best practice |
| **Important task completed** | Finished a complex task (≥5 steps) | Self-reflection |

### Don't Trigger

- One-time instructions ("use X this time")
- Hypothetical discussions ("what if...")
- Silence doesn't mean confirmation
- Others' preferences ("Alice likes...", unless explicitly asked to remember)

---

## Storage Structure

All learning records go in `.learnings/` in the workspace:

```
~/.openclaw/workspace/.learnings/
├── corrections.md      # Correction records (core file)
├── errors.md           # Operation/command errors
├── reflections.md      # Self-reflections
└── best-practices.md   # Discovered best practices
```

Auto-create on first trigger:
```bash
mkdir -p ~/.openclaw/workspace/.learnings
```

---

## Correction Record Format (corrections.md)

```markdown
## YYYY-MM-DD HH:MM — Category

- **Correction**: What the user said / what the right approach is
- **My mistake**: What I did wrong / what I misunderstood
- **Root cause**: Why I made this error (knowledge gap / wrong assumption / tool misuse)
- **Lesson**: What to do next time (one sentence, actionable)
- **Status**: ⏳pending | ✅verified | 📤promoted
```

**Example**:
```markdown
## 2026-03-09 03:54 — Code Analysis Method

- **Correction**: Large codebase analysis must use Claude Code (CC), don't analyze directly
- **My mistake**: Analyzed an entire code repository in-session, reached wrong conclusions
- **Root cause**: Didn't understand CC's use case, assumed I could handle large codebases
- **Lesson**: For repository-level code analysis, always use CC — never analyze directly
- **Status**: ✅verified
```

---

## Error Record Format (errors.md)

```markdown
## YYYY-MM-DD HH:MM — Brief description

- **Action**: What command/tool was executed
- **Error**: Specific error message
- **Context**: Relevant details (path, params, version)
- **Fix**: How it was resolved
- **Prevention**: How to avoid next time
```

---

## Self-Reflection Format (reflections.md)

After completing important tasks, pause and self-assess:

```markdown
## YYYY-MM-DD — Task Description

- **What I did**: Task overview
- **Result**: Success / partial / failure
- **What could be better**: Specific improvement points
- **Lesson**: What to do next time (one sentence)
- **Status**: ⏳candidate | ✅promoted
```

---

## Promotion Rules

Lessons shouldn't just sit in `.learnings/` — important ones get promoted to permanent memory:

| Condition | Promote to | Example |
|-----------|-----------|---------|
| Lesson affects daily workflow | `MEMORY.md` | "Always use CC for code analysis" |
| Lesson involves tool usage | `TOOLS.md` | "MySQL queries need LIMIT" |
| Lesson involves behavior patterns | `AGENTS.md` or `SOUL.md` | "Confirm understanding before acting" |
| Same lesson appears ≥3 times | Promote immediately, don't wait for verification | — |

**After promotion**: Change original entry status to `📤promoted`, note which file it was promoted to.

---

## Size Limits

| File | Limit | Overflow handling |
|------|-------|-------------------|
| corrections.md | 50 entries | Archive old entries to `memory/archive/` |
| errors.md | 30 entries | Clean up resolved errors |
| reflections.md | 30 entries | Clean up promoted entries |
| best-practices.md | No hard limit | Periodically merge similar entries |

---

## Correction Flow (complete steps when corrected)

When you detect you've been corrected, **immediately** execute these steps:

1. **Acknowledge** — Briefly say "you're right, I got that wrong" (no excuses)
2. **Understand** — Make sure you truly understand the correct approach; ask if unsure
3. **Record** — Write to `.learnings/corrections.md`
4. **Evaluate promotion** — If the lesson is broadly applicable, promote to MEMORY.md immediately
5. **Verify** — If the conversation continues on the same topic, redo it the right way

**Don't**:
- Don't just "mentally note" it — write to a file
- Don't wait until the conversation ends to record
- Don't mix corrections with task progress notes
- Don't justify or minimize the error

---

## Periodic Review

During heartbeat or first conversation each day:

1. Read last 5 entries in `.learnings/corrections.md`
2. Check if any `⏳pending` can be marked `✅verified`
3. Check for repeated patterns worth promoting
4. If file exceeds limits, run cleanup

---

## Relationship with Existing Memory Systems

| System | Purpose | Relationship |
|--------|---------|-------------|
| `.learnings/` | Structured lessons/errors/reflections | **New** — focused on "learning from mistakes" |
| `MEMORY.md` | Long-term memory (decisions, preferences, facts) | Promotion **target** for lessons |
| `memory/YYYY-MM-DD.md` | Daily conversation logs | Raw material, unstructured |
| `AGENTS.md` | Behavioral rules | Promotion **target** for behavior lessons |

**Principle**: `.learnings/` is the "inbox" for lessons. MEMORY.md and AGENTS.md are "long-term storage". The inbox gets cleaned regularly; long-term storage only grows (unless outdated).
