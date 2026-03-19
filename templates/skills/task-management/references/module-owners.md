# Module Owner Mapping

> Customize this file to match your team structure. Used by the task-management skill to auto-assign tasks.

## Example: 3-Person Team

| Module | Owner | Lobster | Notes |
|--------|-------|---------|-------|
| Frontend | alice | lobster-alice | React/TypeScript |
| Backend | bob | lobster-bob | API, database, infrastructure |
| Backend Auth/Payments | bob | lobster-bob | Needs compliance review |
| DevOps/Infrastructure | carol | lobster-carol | CI/CD, monitoring |
| Data Analytics | carol | lobster-carol | Dashboards, reports |
| Design/UX | alice | lobster-alice | UI mockups, design system |
| QA/Testing | carol | lobster-carol | |

## Example: 5-Person Team

| Module | Owner | Lobster | Notes |
|--------|-------|---------|-------|
| Frontend | alice | lobster-alice | |
| Backend API | bob | lobster-bob | |
| Mobile/iOS | carol | lobster-carol | |
| DevOps | dave | lobster-dave | |
| Compliance | eve | lobster-eve | |
| Data Analytics | dave | lobster-dave | |
| Growth/Marketing | eve | lobster-eve | |

## Quick Matching Rules

Task text → Owner keyword mapping (customize for your team):

- `frontend`/`pages`/`UI`/`CSS` → alice
- `backend`/`API`/`database`/`server` → bob
- `iOS`/`mobile`/`App Store` → carol
- `deploy`/`CI`/`infrastructure`/`monitoring` → dave
- `compliance`/`legal`/`security` → eve
- `design`/`UX`/`mockup` → alice
- `data`/`analytics`/`dashboard` → dave
- `payment`/`subscription`/`billing` → bob
