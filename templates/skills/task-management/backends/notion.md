# Notion Backend

API reference for the task-management skill using Notion as the backend.

## Setup

1. Create a [Notion Integration](https://www.notion.so/my-integrations) and get an API key (starts with `ntn_`)
2. Store the key: add `NOTION_API_KEY` to your lobster's `personal-secrets.json`
3. Create a database in Notion (or use an existing one) with the columns listed below
4. Connect the Integration to the database (Share → Invite → select your integration)
5. Set `TASK_BACKEND=notion` in your environment

## Configuration

```bash
NOTION_TOKEN="$NOTION_API_KEY"          # From personal-secrets.json
DB_ID="your-database-id"                # From the Notion database URL
API="https://api.notion.com/v1"
HEADERS=(-H "Authorization: Bearer $NOTION_TOKEN" -H "Notion-Version: 2025-09-03" -H "Content-Type: application/json")
```

## Column Mapping

| Universal Field | Notion Property | Notion Type |
|----------------|----------------|-------------|
| Title | Task Name | title |
| Owner | Owner | select |
| Status | Status | select |
| Priority | Priority | select |
| Level | Level | select |
| Sprint | Sprint | select |
| Team | Team | select |
| Needs Coordination | Needs Coordination | checkbox |
| Notes | Notes | rich_text |

## Operations

### CREATE_TASK

```bash
curl -s -X POST "$API/pages" "${HEADERS[@]}" -d '{
  "parent": {"database_id": "'$DB_ID'"},
  "properties": {
    "Task Name": {"title": [{"text": {"content": "TASK_TITLE"}}]},
    "Status": {"select": {"name": "STATUS"}},
    "Owner": {"select": {"name": "OWNER_NAME"}},
    "Priority": {"select": {"name": "PRIORITY"}},
    "Sprint": {"select": {"name": "SPRINT_LABEL"}},
    "Team": {"select": {"name": "TEAM"}},
    "Level": {"select": {"name": "LEVEL"}},
    "Needs Coordination": {"checkbox": BOOLEAN},
    "Notes": {"rich_text": [{"text": {"content": "NOTES"}}]}
  }
}'
```

### LIST_TASKS / QUERY_BY_OWNER

```bash
curl -s -X POST "$API/databases/$DB_ID/query" "${HEADERS[@]}" -d '{
  "filter": {
    "and": [
      {"property": "Owner", "select": {"equals": "OWNER_NAME"}},
      {"or": [
        {"property": "Status", "select": {"equals": "Open"}},
        {"property": "Status", "select": {"equals": "In Progress"}},
        {"property": "Status", "select": {"equals": "Backlog"}}
      ]}
    ]
  }
}'
```

### QUERY_BY_SPRINT

```bash
curl -s -X POST "$API/databases/$DB_ID/query" "${HEADERS[@]}" -d '{
  "filter": {
    "and": [
      {"property": "Owner", "select": {"equals": "OWNER_NAME"}},
      {"property": "Sprint", "select": {"equals": "SPRINT_LABEL"}}
    ]
  }
}'
```

> **Fallback**: If sprint filter returns 400 or empty (sprint option doesn't exist yet), drop the sprint filter and query by owner + active status only.

### UPDATE_STATUS

```bash
curl -s -X PATCH "$API/pages/PAGE_ID" "${HEADERS[@]}" -d '{
  "properties": {
    "Status": {"select": {"name": "NEW_STATUS"}}
  }
}'
```

### ADD_NOTE

```bash
curl -s -X PATCH "$API/pages/PAGE_ID" "${HEADERS[@]}" -d '{
  "properties": {
    "Notes": {"rich_text": [{"text": {"content": "NOTE_TEXT"}}]}
  }
}'
```

### CLOSE_TASK

Same as UPDATE_STATUS with `"name": "Resolved"`.

## Batch Operations

When creating/updating multiple tasks, add `sleep 0.5` between API calls (Notion rate limit: ~3 req/s).

## Parsing Responses

```bash
# Extract task list from query results
curl -s -X POST "$API/databases/$DB_ID/query" "${HEADERS[@]}" -d '...' | jq '[
  .results[] | {
    id: .id,
    title: .properties["Task Name"].title[0].text.content,
    status: .properties["Status"].select.name,
    owner: .properties["Owner"].select.name,
    priority: .properties["Priority"].select.name
  }
]'
```

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| 401 | Token invalid/expired | Check `personal-secrets.json` |
| 400 | Property name mismatch | Verify database column names match |
| 429 | Rate limited | Wait 1s, retry; add sleep for batch ops |
| 404 | Wrong page/database ID | Re-check the ID from Notion URL |
