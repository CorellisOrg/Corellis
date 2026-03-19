# Linear Backend

API reference for the task-management skill using Linear as the backend.

## Setup

1. Go to [Linear Settings → API](https://linear.app/settings/api) and create a personal API key
2. Store the key: add `LINEAR_API_KEY` to your lobster's `personal-secrets.json`
3. Set `TASK_BACKEND=linear` in your environment

## Configuration

```bash
LINEAR_TOKEN="$LINEAR_API_KEY"
API="https://api.linear.app/graphql"
```

## Field Mapping

| Universal Field | Linear Field | Notes |
|----------------|-------------|-------|
| Title | `title` | Issue title |
| Owner | `assignee` | Linear user (by name or ID) |
| Status | `state` | Linear workflow state |
| Priority | `priority` | 0=None, 1=Urgent, 2=High, 3=Medium, 4=Low |
| Level | `label` | Use labels for SG/Task distinction |
| Sprint | `cycle` | Linear Cycle |
| Team | `team` | Linear Team |
| Notes | `description` | Markdown supported |

## Priority Mapping

| Universal | Linear Priority |
|-----------|----------------|
| P0-Urgent | 1 (Urgent) |
| P1-High | 2 (High) |
| P2-Medium | 3 (Medium) |
| P3-Low | 4 (Low) |

## Operations

### CREATE_TASK

```bash
curl -s -X POST "$API" \
  -H "Authorization: $LINEAR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation($input: IssueCreateInput!) { issueCreate(input: $input) { success issue { id identifier title url } } }",
    "variables": {
      "input": {
        "teamId": "TEAM_ID",
        "title": "TASK_TITLE",
        "description": "NOTES",
        "priority": 3,
        "assigneeId": "USER_ID"
      }
    }
  }'
```

> To find `teamId` and `assigneeId`, use the introspection queries below.

### LIST_TASKS / QUERY_BY_OWNER

```bash
curl -s -X POST "$API" \
  -H "Authorization: $LINEAR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ issues(filter: { assignee: { name: { eq: \"OWNER_NAME\" } }, state: { type: { nin: [\"completed\", \"canceled\"] } } }, first: 50) { nodes { id identifier title state { name } priority assignee { name } cycle { name } } } }"
  }'
```

### QUERY_BY_SPRINT

```bash
curl -s -X POST "$API" \
  -H "Authorization: $LINEAR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ issues(filter: { assignee: { name: { eq: \"OWNER_NAME\" } }, cycle: { name: { eq: \"CYCLE_NAME\" } } }, first: 50) { nodes { id identifier title state { name } priority } } }"
  }'
```

### UPDATE_STATUS

```bash
curl -s -X POST "$API" \
  -H "Authorization: $LINEAR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { issueUpdate(id: \"ISSUE_ID\", input: { stateId: \"STATE_ID\" }) { success } }"
  }'
```

> Get available state IDs: `{ workflowStates { nodes { id name type } } }`

### ADD_NOTE

```bash
# Add a comment to an issue
curl -s -X POST "$API" \
  -H "Authorization: $LINEAR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { commentCreate(input: { issueId: \"ISSUE_ID\", body: \"NOTE_TEXT\" }) { success } }"
  }'
```

### CLOSE_TASK

Use UPDATE_STATUS with the "Done" or "Completed" state ID.

## Helper Queries

```bash
# List teams
curl -s -X POST "$API" -H "Authorization: $LINEAR_TOKEN" -H "Content-Type: application/json" \
  -d '{"query": "{ teams { nodes { id name } } }"}'

# List team members
curl -s -X POST "$API" -H "Authorization: $LINEAR_TOKEN" -H "Content-Type: application/json" \
  -d '{"query": "{ users { nodes { id name email } } }"}'

# List workflow states
curl -s -X POST "$API" -H "Authorization: $LINEAR_TOKEN" -H "Content-Type: application/json" \
  -d '{"query": "{ workflowStates { nodes { id name type } } }"}'
```

## Rate Limits

Linear API: 1500 requests/hour for regular keys. No per-second burst limit, but add `sleep 0.2` for batch operations to be safe.
