# state/

This directory stores runtime state files for the controller:

- `goals.json` — Active goal tree (created by GoalOps)
- `skill-submissions-seen.json` — Tracked skill submissions (created by poll-skill-submissions.sh)

These files are created automatically at runtime. Do not commit runtime data.
