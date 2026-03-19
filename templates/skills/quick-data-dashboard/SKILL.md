---
description: "One-shot data query + quick visual dashboard generation. Build PNG dashboards from DB queries with pure CSS charts, no JS dependencies. For data visualization, reports, and KPI dashboards."
---

# Quick Data Dashboard — Rapid Data Visualization Dashboard

## Description
One-shot data query + rapid visualization dashboard generation. Suitable for: pulling data from databases and quickly generating visual reports that can be directly viewed on mobile/Slack.

## Trigger Conditions
Triggered when users need to **perform one-time data retrieval and quick visualization**, for example:
- "Help me check XX data and create a dashboard"
- "Generate XX report"
- "Visualize XX for me"
- Any requirements involving data query + visual presentation

## Core Principles

### 1. Output Format: PNG Image Priority
- **Don't use CDN-dependent HTML** (can't open on mobile, headless screenshots don't render)
- Use **pure HTML/CSS to build dashboards** (div for bars, no JS library dependencies)
- Use **headless Chrome screenshots** to generate PNG, directly send to Slack
- PNG can be viewed directly on mobile, desktop, any device

### 2. Visualization Design Standards
Follow ClawHub `frontend` + `data-visualization-2` skill specifications:

#### Color Scheme (Dark Theme)
- Background: `#0c0c0c`
- Cards: `#161618`, border `#2a2a2e`
- Text: `#f0f0f0` (primary), `#777` (secondary)
- Accent colors: Blue `#3b82f6`, Green `#22c55e`, Orange `#f59e0b`
- 70-20-10 color rule: 70% dark background, 20% neutral colors, 10% accent colors

#### Chart Selection
- ❌ **Don't use pie charts** ("pie charts are almost always the wrong choice")
- ✅ Horizontal bar charts for rankings
- ✅ Stacked bars for proportions
- ✅ Number cards (KPI cards) for key metrics

#### Titles and Narrative
- **Insight-driven titles**: Not "Top Creators", but "Top 8 creators earn 72% of budget"
- Tell stories with data, titles themselves are conclusions

#### Highlighting Strategy
- "Highlight one thing, grey everything else"
- Top 3 use blue gradient `linear-gradient(90deg, #3b82f6, #8b5cf6)`
- Others use grey `#334155`

### 3. Dashboard Structure Template
```
┌─────────────────────────────────────────────┐
│ 🦞 [Report Title]                           │
│ [Subtitle: Time Range · Key Parameters]      │
├──────┬──────┬──────┬──────┬──────┬──────────┤
│ KPI1 │ KPI2 │ KPI3 │ KPI4 │ KPI5 │ KPI6     │
├──────────────────────┬──────────────────────┤
│ Main Chart           │ Distribution/Aux Info │
│ (Horizontal Bar)     │ - Distribution Stats  │
│ Top N Rankings       │ - Proportion Bars     │
│                      │ - Concentration Bars  │
├──────────────────────┴──────────────────────┤
│ Detailed Table                               │
│ # | Name | Amount | % | Share Bar | Details │
└─────────────────────────────────────────────┘
```

### 4. CSS Bar Implementation (No JS)
```html
<!-- Horizontal Bar Chart -->
<div class="bar-row">
  <span class="name">Creator</span>
  <div class="bar-wrap">
    <div class="bar hi" style="width:85%"></div>
  </div>
  <span class="val">$34,286</span>
</div>

<!-- Highlight vs Normal -->
.hi { background: linear-gradient(90deg, #3b82f6, #8b5cf6) }
.lo { background: #334155 }
```

### 5. Screenshot Command
```bash
google-chrome --headless=new --disable-gpu --no-sandbox \
  --screenshot=output.png \
  --window-size=1100,2000 \
  --virtual-time-budget=3000 \
  "file:///tmp/dashboard.html"
```

## Complete Workflow

```
1. Clarify Requirements → Confirm data source, time range, key metrics
2. Query Data → MySQL / API / Files
3. Generate JSON → dashboard_data.json (structured data)
4. Build HTML → Pure CSS dashboard (reference template)
5. Screenshot → headless Chrome → PNG
6. Self-check → Read PNG to confirm all content renders correctly
7. Send → Send PNG + original CSV (if any) to Slack
```

## Lessons Learned

### ❌ Pitfalls We've Encountered
1. **Chart.js CDN doesn't load during headless Chrome screenshots** — canvas elements are blank
2. **Inlined Chart.js doesn't work either** — virtual-time-budget insufficient for JS execution
3. **HTML files can't open in mobile Slack** — only usable in desktop browsers
4. **Random noise causes different results each time** — don't add unnecessary random factors

### ✅ Best Practices
1. **Pure CSS charts, zero JS dependencies** — ensures 100% headless screenshot rendering
2. **PNG images are the most universal format** — viewable on mobile/desktop/any device
3. **Self-check: read PNG after generation to confirm** — avoid sending blank/incomplete images
4. **Provide both CSV + PNG** — data is traceable, visuals are quickly consumable
5. **Use large fonts for KPI numbers (28-32px)** — clear visibility on mobile

## Dependent Skills
- `frontend` — Design standards, color schemes, fonts
- `data-visualization-2` — Chart selection, narrative approach, highlighting strategies

## Technical Requirements
- headless Chrome (usually pre-installed)
- Data source access permissions (MySQL env vars, etc.)