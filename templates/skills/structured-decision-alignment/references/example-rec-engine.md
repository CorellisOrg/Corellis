# Reference Case: Recommendation Algorithm Launch Discussion (2026-03-04)

## Background
The recommendation algorithm needs to go live on the your-company landing page, involving multiple teams: backend, frontend, data, and product. There are 7 major topics and 19 TODO items that need cross-team alignment.

## Participants
- alice (Algorithm)
- Carol (Product Quality)
- Eve (Backend Integration)
- alice (Frontend/Technical)
- Grace (Data/Coordination)

## Playbook Execution Record

### Preparation Phase
- Input: Recommendation engine technical documentation + draft launch plan
- Extracted 7 discussion topics: DB solution, entity ID mapping, refresh strategy, hot switching, preview asset pool, event tracking, quality acceptance
- Each topic prepared with options + pros/cons + @relevant people

### Initiation Phase
- Posted main message in #channel: "🗳️ Recommendation Algorithm Launch Plan Alignment"
- Explained objectives and list of 7 questions in thread

### Facilitation Phase
- Discussed each question individually, marking with ✅ after confirmation
- Key decisions:
  - Use your_database for DB, table name landing_page_recommendation
  - Use slug ID instead of raw entity_id
  - Daily full refresh with dual-table hot switching
  - Permanently store preview asset pool

### Wrap-up Phase
- Generated complete decision document: 7 conclusions + 19 TODO items + owners
- Pending confirmation items: Modal network, event tracking owner (TBD), event tracking timeline
- Document synced to project docs/launch-plan.md

## Results
- Completed all alignment within 1 thread, taking approximately 1 hour
- All conclusions confirmed on the spot, no omissions
- TODOs have clear owners and are trackable