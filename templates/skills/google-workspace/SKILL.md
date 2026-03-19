# Google Workspace Skill

Access Google Docs, Sheets, Drive, Calendar, Gmail, Analytics (GA4), and Indexing API for your owner.

## First Use: Guide Owner to Authorize

When owner first requests Google-related features (read docs, check Drive, view calendar, etc.), first check if token exists:

```bash
python3 SKILL_DIR/scripts/google-oauth.py token 2>/dev/null
```

**If error (no token)**, guide owner through this flow:

### Step 1: Generate authorization link
```bash
python3 SKILL_DIR/scripts/google-oauth.py auth
```

### Step 2: Message template for owner (use this directly)

> 🔗 **First time connecting Google account**
>
> I need you to authorize your Google account, then I can help you operate Docs / Sheets / Drive. Only need to do this once!
>
> **Steps:**
> 1. Click the link below
> 2. Login with your `@your-domain.com` email
> 3. Click "Allow" to authorize
> 4. After authorization, the page will redirect to an **inaccessible page** (showing "This site can't be reached"), this is **normal**!
> 5. Copy the **complete URL from browser address bar** and send it to me (the string starting with `http://localhost/?...`)
>
> Authorization link: {put generated link here}

### Step 3: After receiving owner's URL, extract code and exchange for token

Extract value between `code=` and `&` from URL (note URL decode), then:
```bash
python3 SKILL_DIR/scripts/google-oauth.py exchange '<extracted code>'
```

### Step 4: Verify
```bash
TOKEN=$(python3 SKILL_DIR/scripts/google-oauth.py token)
curl -s "https://www.googleapis.com/drive/v3/files?pageSize=3&fields=files(id,name,mimeType)" -H "Authorization: Bearer $TOKEN"
```

After success, tell owner: "✅ Google account connected successfully! I can help you operate Google docs directly from now on."

---

## Daily Use

### Get Token
```bash
TOKEN=$(python3 SKILL_DIR/scripts/google-oauth.py token)
```
Token valid for 1 hour, auto-refreshes with refresh token when expired, owner doesn't need to do anything.

### Google Drive
```bash
# List recent files
curl -s "https://www.googleapis.com/drive/v3/files?pageSize=10&fields=files(id,name,mimeType,modifiedTime)&orderBy=modifiedTime desc" -H "Authorization: Bearer $TOKEN"

# Search files
curl -s "https://www.googleapis.com/drive/v3/files?q=name+contains+'keyword'&fields=files(id,name,mimeType)" -H "Authorization: Bearer $TOKEN"

# Export Google Doc as plain text
curl -s "https://www.googleapis.com/drive/v3/files/{fileId}/export?mimeType=text/plain" -H "Authorization: Bearer $TOKEN"

# Export Google Sheet as CSV
curl -s "https://www.googleapis.com/drive/v3/files/{fileId}/export?mimeType=text/csv" -H "Authorization: Bearer $TOKEN"
```

### Google Docs
```bash
# Read document
curl -s "https://docs.googleapis.com/v1/documents/{documentId}" -H "Authorization: Bearer $TOKEN"

# Create document
curl -s -X POST "https://docs.googleapis.com/v1/documents" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"title": "Document Title"}'

# Insert text
curl -s -X POST "https://docs.googleapis.com/v1/documents/{documentId}:batchUpdate" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"requests":[{"insertText":{"location":{"index":1},"text":"Content"}}]}'
```

### Google Sheets
```bash
# Read range
curl -s "https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}/values/{range}" -H "Authorization: Bearer $TOKEN"

# Write range
curl -s -X PUT "https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}/values/{range}?valueInputOption=USER_ENTERED" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"values":[["a","b"],["c","d"]]}'

# Append row
curl -s -X POST "https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}/values/{range}:append?valueInputOption=USER_ENTERED" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"values":[["New row data 1","New row data 2"]]}'

# Get sheet metadata
curl -s "https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}?fields=properties,sheets.properties" -H "Authorization: Bearer $TOKEN"
```

### Google Calendar
```bash
# View today's events
curl -s "https://www.googleapis.com/calendar/v3/calendars/primary/events?maxResults=10&timeMin=$(date -u +%Y-%m-%dT%H:%M:%SZ)&orderBy=startTime&singleEvents=true" -H "Authorization: Bearer $TOKEN"

# Create event
curl -s -X POST "https://www.googleapis.com/calendar/v3/calendars/primary/events" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"summary":"Meeting Title","start":{"dateTime":"2026-03-01T10:00:00+08:00"},"end":{"dateTime":"2026-03-01T11:00:00+08:00"}}'
```

### Gmail (Read-only)
```bash
# List recent emails
curl -s "https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=10" -H "Authorization: Bearer $TOKEN"

# Read email
curl -s "https://gmail.googleapis.com/gmail/v1/users/me/messages/{messageId}?format=full" -H "Authorization: Bearer $TOKEN"

# Search emails
curl -s "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=from:someone@example.com" -H "Authorization: Bearer $TOKEN"
```

### Google Analytics (GA4)
```bash
# Run report (requires Property ID)
# Product B: <APP_ID_1>, Product A: <APP_ID_2>
curl -s -X POST "https://analyticsdata.googleapis.com/v1beta/properties/{propertyId}:runReport" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"dateRanges":[{"startDate":"7daysAgo","endDate":"today"}],"metrics":[{"name":"activeUsers"},{"name":"sessions"}]}'

# Report with dimensions (by country)
curl -s -X POST "https://analyticsdata.googleapis.com/v1beta/properties/{propertyId}:runReport" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"dateRanges":[{"startDate":"30daysAgo","endDate":"today"}],"dimensions":[{"name":"country"}],"metrics":[{"name":"activeUsers"},{"name":"sessions"}],"orderBys":[{"metric":{"metricName":"activeUsers"},"desc":true}],"limit":10}'

# Realtime report
curl -s -X POST "https://analyticsdata.googleapis.com/v1beta/properties/{propertyId}:runRealtimeReport" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"metrics":[{"name":"activeUsers"}]}'

# Common metrics: activeUsers, sessions, screenPageViews, conversions, totalRevenue
# Common dimensions: country, city, deviceCategory, sessionSource, pagePath, date
```

### Google Indexing API
```bash
# Submit URL update (notify Google to crawl)
curl -s -X POST "https://indexing.googleapis.com/v3/urlNotifications:publish" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"url":"https://example.com/page","type":"URL_UPDATED"}'

# Notify URL deleted
curl -s -X POST "https://indexing.googleapis.com/v3/urlNotifications:publish" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"url":"https://example.com/page","type":"URL_DELETED"}'

# Query URL index status
curl -s "https://indexing.googleapis.com/v3/urlNotifications/metadata?url=https://example.com/page" \
  -H "Authorization: Bearer $TOKEN"
```
⚠️ **Indexing API Requirement**: OAuth-authorized Google account must be Owner of corresponding site in Search Console.

## Complete API Documentation
- Drive: https://developers.google.com/drive/api/reference/rest/v3
- Docs: https://developers.google.com/docs/api/reference/rest/v1
- Sheets: https://developers.google.com/sheets/api/reference/rest/v4
- Calendar: https://developers.google.com/calendar/api/v3/reference
- Gmail: https://developers.google.com/gmail/api/reference/rest

## FAQ

**Q: What if token expires?**
A: Script auto-refreshes with refresh token, owner doesn't need to do anything.

**Q: See "This app isn't verified" during authorization?**
A: Click "Advanced" → "Go to [app name]", this is an internal app and safe.

**Q: No code in URL owner sent?**
A: Have owner confirm they clicked "Allow", if they denied there's no code. Resend authorization link.