# GitHub Projects Backend

API reference for the task-management skill using GitHub Projects (v2) as the backend.

## Setup

1. Install [GitHub CLI](https://cli.github.com/) and authenticate: `gh auth login`
2. Create a GitHub Project (v2) in your organization or personal account
3. Set `TASK_BACKEND=github-projects` in your environment
4. Note your project number (from the URL: `github.com/orgs/ORG/projects/NUMBER`)

## Configuration

```bash
GH_ORG="your-org"           # or username for personal projects
PROJECT_NUM="1"              # Project number from URL
```

## Field Mapping

| Universal Field | GitHub Projects Field | Notes |
|----------------|----------------------|-------|
| Title | Title | Issue/draft title |
| Owner | Assignees | GitHub username |
| Status | Status | Custom field (single select) |
| Priority | Priority | Custom field (single select) |
| Sprint | Iteration | Built-in iteration field |
| Notes | Body | Issue body (markdown) |

## Operations

### CREATE_TASK

```bash
# Option A: Create as draft item (no repo needed)
gh project item-create "$PROJECT_NUM" --owner "$GH_ORG" \
  --title "TASK_TITLE" --body "NOTES"

# Option B: Create as repo issue (linked to a repo)
gh issue create --repo "$GH_ORG/REPO" \
  --title "TASK_TITLE" --body "NOTES" \
  --assignee "OWNER_USERNAME" --label "LABEL"
# Then add to project:
gh project item-add "$PROJECT_NUM" --owner "$GH_ORG" --url "ISSUE_URL"
```

### LIST_TASKS / QUERY_BY_OWNER

```bash
# List all items in the project
gh project item-list "$PROJECT_NUM" --owner "$GH_ORG" --format json --limit 100

# Filter by assignee (post-process with jq)
gh project item-list "$PROJECT_NUM" --owner "$GH_ORG" --format json | \
  jq '[.items[] | select(.assignees[]?.login == "OWNER_USERNAME")]'
```

### QUERY_BY_SPRINT

```bash
# Filter by iteration (post-process)
gh project item-list "$PROJECT_NUM" --owner "$GH_ORG" --format json | \
  jq '[.items[] | select(.iteration?.title == "SPRINT_LABEL")]'
```

### UPDATE_STATUS

```bash
# Get field ID and option ID first
gh project field-list "$PROJECT_NUM" --owner "$GH_ORG" --format json

# Update status
gh project item-edit --project-id "PROJECT_ID" --id "ITEM_ID" \
  --field-id "STATUS_FIELD_ID" --single-select-option-id "OPTION_ID"
```

### ADD_NOTE

```bash
# For issues: add a comment
gh issue comment "ISSUE_NUMBER" --repo "$GH_ORG/REPO" --body "NOTE_TEXT"

# For draft items: edit the body
gh project item-edit --project-id "PROJECT_ID" --id "ITEM_ID" --body "UPDATED_BODY"
```

### CLOSE_TASK

```bash
# For issues
gh issue close "ISSUE_NUMBER" --repo "$GH_ORG/REPO"

# For draft items: update status to "Done"
# (use UPDATE_STATUS with the Done option)
```

## Tips

- GitHub Projects v2 uses GraphQL under the hood; `gh project` commands wrap it nicely
- Custom fields (Status, Priority) must be created in the project settings first
- Iterations must be configured in project settings before they can be assigned
- Rate limit: 5000 GraphQL points/hour; CLI calls are efficient

## Getting Project and Field IDs

```bash
# Get project ID (needed for item-edit)
gh project list --owner "$GH_ORG" --format json | jq '.projects[] | select(.number == '$PROJECT_NUM')'

# Get field IDs and options
gh project field-list "$PROJECT_NUM" --owner "$GH_ORG" --format json
```
