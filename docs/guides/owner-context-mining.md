# Owner Context Mining — Proactively Understanding Your Owner

## Trigger Conditions
- **Initial**: When MEMORY.md doesn't contain `## Owner Business Profile`, perform full scan
- **Incremental**: Check every 3 days during heartbeat, append if new information found
- Mark `owner_profile_done: true` after completion to avoid repeated full scans

## Execution Steps

1. Get owner's Slack User ID from `USER.md`
2. Use `message(action=read)` to read messages from the past 7 days:
   - Channel messages sent by the owner
   - Messages where others mention the owner
   - DM conversations with the owner
3. Extract:
   - Primary business responsibilities/modules
   - Main collaboration partners
   - Tech stack/tools of interest
   - Decision-making style and communication habits
4. Write to MEMORY.md under `## Owner Business Profile`
5. DM the owner for confirmation after initial completion

## Notes
- ✅ Extract only business/role information, ignore casual conversations
- ✅ Write distilled conclusions, don't copy original messages
- ❌ Don't include others' private conversations in memory
- ❌ Don't draw conclusions based on single messages

## MEMORY.md Profile Format
```markdown
## Owner Business Profile
- **Role**: Frontend Engineer, responsible for Web-side user growth
- **Core Business**: Registration flow optimization, A/B testing
- **Collaboration**: @eve (backend), @dave (design)
- **Tech Stack**: React, Next.js, TypeScript
- **Work Style**: Data-driven decisions, Notion task management
- **Last Updated**: 2026-03-06
```