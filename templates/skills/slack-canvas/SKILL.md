---
name: slack-canvas
description: "Read and write Slack Canvas content via API. Use when user mentions 'canvas', 'Slack Canvas', asks to read/edit/create a canvas, or shares a canvas link (slack.com/docs/...). NOT for general drawing/diagram tools — this is Slack-specific."
---

# Slack Canvas Read/Write

## Overview

Read and edit Slack Canvas (Slack's built-in canvas) content through the Slack API.

> ⚠️ **"Canvas" in this skill specifically refers to Slack Canvas**, not a general canvas concept.
> ⚠️ **Comment functionality is not available** — Slack has not opened Canvas comment-related APIs.

## Prerequisites

Bot requires the following OAuth scopes (add in api.slack.com App configuration page):
- `canvases:read` — Find Canvas sections
- `canvases:write` — Create and edit Canvas
- `files:read` — Read complete Canvas content (via files.info + download)

If calls return `missing_scope` error, inform the user to add the corresponding scope in the Slack App configuration page and reinstall.

## ⚠️ Canvas Link Specification (Must Follow)

When sharing Canvas links after creation:

1. **Prioritize using the permalink returned by API** (`canvas_url` field returned by `canvases.create`)
2. **Never construct URLs yourself** — any `<workspace>.slack.com/docs/...` format is wrong
3. If API doesn't return permalink, the **only correct format** is:
   ```
   https://app.slack.com/docs/<TEAM_ID>/<CANVAS_ID>
   ```
   - Domain must be **app.slack.com** (not your-workspace.slack.com or any other domain)
   - Get TEAM_ID through `auth.test` API

**Wrong Examples** (never write like this):
- ❌ `https://your-workspace.slack.com/docs/FXXXXXXXXXX`
- ❌ `https://slack.com/docs/FXXXXXXXXXX`
- ❌ `https://xxx.slack.com/docs/...`

**Correct Example**:
- ✅ `https://app.slack.com/docs/TXXXXXXXXXX/FXXXXXXXXXX`

Get TEAM_ID:
```bash
TOKEN=$(jq -r '.channels.slack.botToken' ~/.openclaw/openclaw.json 2>/dev/null || jq -r '.channels.slack.botToken' /etc/openclaw/openclaw.json 2>/dev/null)
curl -s -X POST https://slack.com/api/auth.test -H "Authorization: Bearer $TOKEN" | jq -r '.team_id'
```

## Canvas ID Extraction

Extract ID from Canvas link:
- Correct link format: `https://app.slack.com/docs/<TeamID>/<CanvasID>`
- Example: `https://app.slack.com/docs/TXXXXXXXXXX/FXXXXXXXXXX` → Canvas ID = `FXXXXXXXXXX`

## API Reference

### 1. Read Complete Canvas Content ⭐

**This is the only method to read Canvas content.** Two steps:

**Step 1: Get download URL**
```bash
TOKEN="$SLACK_BOT_TOKEN"

curl -s -X POST https://slack.com/api/files.info \
  -H "Authorization: Bearer $TOKEN" \
  -d "file=FXXXXXXXXXX" | jq -r '.file.url_private_download'
```

**Step 2: Download content**
```bash
curl -s -L -H "Authorization: Bearer $TOKEN" \
  "https://files.slack.com/files-pri/TEAM_ID-CANVAS_ID/download/canvas"
```

Returns complete Canvas content in **HTML format**, including all headers, paragraphs, lists, tables, etc.

> 💡 **One-command combination**:
> ```bash
> TOKEN=$(jq -r '.channels.slack.botToken' ~/.openclaw/openclaw.json 2>/dev/null || jq -r '.channels.slack.botToken' /etc/openclaw/openclaw.json 2>/dev/null)
> URL=$(curl -s -X POST https://slack.com/api/files.info -H "Authorization: Bearer $TOKEN" -d "file=CANVAS_ID" | jq -r '.file.url_private_download')
> curl -s -L -H "Authorization: Bearer $TOKEN" "$URL"
> ```

### 2. Find Sections (Locate Edit Target)

```bash
curl -s -X POST https://slack.com/api/canvases.sections.lookup \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{
    "canvas_id": "FXXXXXXXXXX",
    "criteria": {
      "section_types": ["any_header"],
      "contains_text": "search keyword"
    }
  }'
```

**criteria parameters** (at least one required):
- `section_types`: `["h1"]`, `["h2"]`, `["h3"]`, `["any_header"]`
- `contains_text`: search for sections containing specified text

**Returns**: list of section IDs (IDs only, no content text).

> 💡 **Tip**: First use method 1 to read complete HTML, extract section IDs (`id` attributes) from it, then use for edit operations.

### 3. Create Canvas

```bash
curl -s -X POST https://slack.com/api/canvases.create \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{
    "title": "Canvas Title",
    "document_content": {
      "type": "markdown",
      "markdown": "# Title\n\nBody content\n\n## Subtitle\n\n- List item"
    }
  }'
```

**Returns**: `{"ok": true, "canvas_id": "F1234ABCD"}`

### 4. Create Channel Canvas

```bash
curl -s -X POST https://slack.com/api/conversations.canvases.create \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{
    "channel_id": "C1234567",
    "document_content": {
      "type": "markdown",
      "markdown": "# Channel Canvas\n\nContent"
    }
  }'
```

### 5. Edit Canvas

```bash
curl -s -X POST https://slack.com/api/canvases.edit \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{
    "canvas_id": "FXXXXXXXXXX",
    "changes": [
      {
        "operation": "insert_after",
        "section_id": "temp:C:xxx",
        "document_content": {
          "type": "markdown",
          "markdown": "New content"
        }
      }
    ]
  }'
```
**operation types**:
- `insert_after` — Insert after specified section
- `insert_before` — Insert before specified section
- `insert_at_start` — Insert at Canvas beginning (no section_id needed)
- `insert_at_end` — Insert at Canvas end (no section_id needed)
- `replace` — Replace specified section content (replace entire Canvas if no section_id)
- `delete` — Delete specified section
- `rename` — Rename Canvas (use `title_content` instead of `document_content`)

### 6. Manage Access Permissions

```bash
curl -s -X POST https://slack.com/api/canvases.access.set \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{
    "canvas_id": "FXXXXXXXXXX",
    "access_level": "write",
    "channel_ids": ["C1234567"],
    "user_ids": ["U1234567"]
  }'
```

## Markdown Format (For Writing)

Canvas uses standard markdown with additional support:

| Element | Syntax |
|---------|--------|
| @user | `![](@U1234567)` |
| #channel | `![](#C1234567)` |
| Canvas link | `![](https://app.slack.com/docs/TEAM_ID/CANVAS_ID)` |
| Emoji | `:emoji_name:` |
| Checkbox | `- [ ] Incomplete` / `- [x] Complete` |
| Table | Standard markdown table (max 300 cells) |

## Capability Boundaries

| Capability | Status | Description |
|------------|--------|-------------|
| Read complete content | ✅ | files.info + download (returns HTML) |
| Create Canvas | ✅ | Independent or channel Canvas |
| Find Section | ✅ | Search by header type and keywords |
| Edit content | ✅ | Insert, replace, delete |
| Read comments | ❌ | No API |
| Write comments | ❌ | No API |
| Listen to comment/change events | ❌ | Events API not supported |

## Typical Workflows

### Read → Analyze → Edit
1. `files.info` + download to get complete HTML content
2. Parse HTML to extract section IDs and text
3. `canvases.edit` using section_id for precise modifications

### Create from Scratch
1. `canvases.create` to create Canvas with initial content
2. Returns canvas_id, can share link with users

## Token Retrieval

```bash
TOKEN=$(jq -r '.channels.slack.botToken' ~/.openclaw/openclaw.json 2>/dev/null || jq -r '.channels.slack.botToken' /etc/openclaw/openclaw.json 2>/dev/null)
```

## Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `missing_scope` | Bot lacks required scope | Add scope and reinstall |
| `canvas_not_found` | Wrong Canvas ID or no access | Confirm ID, or add Bot to relevant channel |
| `canvas_deleted` | Canvas has been deleted | Cannot recover |
| `not_allowed` | Insufficient operation permissions | Need canvases:write scope |
| `file_not_found` | files.info can't find file | Confirm file ID, need files:read scope |