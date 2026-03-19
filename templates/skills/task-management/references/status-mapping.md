# Status Mapping

Map status labels from requirements documents to universal task statuses.

## Document Tag → Task Status

| Document Tag | Task Status |
|-------------|------------|
| *(no tag)* | Backlog |
| To Fix / To Do | Open |
| In Development / In Progress | In Progress |
| In Testing / In Review | Testing |
| In Acceptance / QA | Testing |
| Pending Schedule | Backlog |
| Requirements Incomplete | Backlog |
| Rejected / Won't Do | Rejected |
| Milestone / Epic | *(use as Level=SG)* |

## Customization

Adjust this mapping to match your team's document conventions. The task-management skill reads this file when parsing requirements documents during sprint planning.
