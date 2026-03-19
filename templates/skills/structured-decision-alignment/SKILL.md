---
name: structured-decision-alignment
description: >
  Guide cross-team multi-person solution alignment discussions, transforming loose conversations into structured decision processes.
  Trigger scenarios: (1) User says "help me organize a discussion/solution alignment" (2) User provides documents + participant list and requests multi-person confirmation
  (3) User says "create a thread to confirm issues one by one" (4) Cross-team sign-off / technical solution review
  (5) User says "structured decision" or "decision alignment".
  Not applicable: 1-on-1 simple Q&A, decisions that don't require multi-person participation, pure information notifications.
---

# Structured Decision Alignment — Structured Multi-Person Decision Alignment

Transform cross-team solution discussions from random chats into a four-stage structured process, outputting trackable decision documents.

## Four-Stage Playbook

### Stage 1: Prepare

1. Collect background materials provided by user (documents, PRD, design drafts, any format)
2. Extract all issues that need discussion, sorted by priority
3. Prepare for each issue:
   - Issue description (one sentence)
   - Preset options + respective pros and cons
   - Related stakeholders (who needs to participate in decision)
4. Output structured Playbook for user confirmation

**Information completeness check** — If materials are insufficient, proactively ask:
> To organize efficient discussion, suggest supplementing: known constraints? open questions? participant responsibilities? what most needs to be unblocked?

### Stage 2: Kick-off

1. Post one main message in designated channel (brief topic, no more than two lines)
2. Start discussion in thread: explain objective, expect to discuss N issues
3. Post first issue + options + @relevant people
4. **Clarify one issue before moving to next one**

**Main message format**:
```
🗳️ [Project Name] Solution Alignment Discussion
```
Expand detailed content in thread.

### Stage 3: Facilitate

Each discussion round follows:
1. Post issue + options + @relevant people
2. Wait for replies, summarize all viewpoints in real-time
3. After reaching consensus, mark conclusion with ✅
4. Move to next issue

**Facilitation principles**:
- Immediately summarize and confirm after someone replies to avoid misunderstandings
- Identify disagreements → list viewpoints from all sides → guide decision-making (don't make decisions for others)
- Handle unplanned new issues:
  - Strongly related to current issue → discuss on the spot, merge into current conclusion
  - Independent topic → record in "follow-up discussion" list, don't interrupt current flow
- Dynamically adjust order: if issue B depends on conclusion of issue A, solve A first
- Long periods without replies → politely @remind

**Conclusion confirmation format**:
```
✅ Issue N: [Issue Title]
Conclusion: [One sentence conclusion]
Owner: @xxx
```

### Stage 4: Close

**Completion condition check** (all must be satisfied to close):
- [ ] All open issues have clear conclusions
- [ ] Each TODO has an owner
- [ ] All information needed for first step is in place (no blocking items)

After discussion completion, generate decision document including:

```markdown
# [Project Name] Decision Document

## Discussion Information
- Date: YYYY-MM-DD
- Participants: @A, @B, @C
- Channel: #channel-name

## Decision Summary
| # | Issue | Conclusion | Owner |
|---|-------|------------|-------|
| 1 | xxx   | xxx        | @xxx  |

## TODO List
- [ ] [Task description] — @owner — deadline (if any)

## Items Pending Confirmation
- [Item pending confirmation] — waiting for @xxx reply

## Original Discussion
[Link to thread]
```

Output methods:
1. Post summary in thread
2. **Pin decision document to channel** to ensure it's not buried by chat history
3. If project document path exists, sync update
4. If user requests, generate file and upload to channel

## Key Constraints

- **Slack output specifications**: Keep main message brief, put detailed content in thread; use code blocks for tables
- **Don't make decisions for others**: Provide options and analysis, decision authority belongs to stakeholders
- **One issue at a time**: Avoid information overload
- **Real-time recording**: Confirm each conclusion on the spot, don't wait until the end to summarize

## Reference Cases

See `references/example-rec-engine.md` — Complete practical record of recommendation algorithm launch discussion.