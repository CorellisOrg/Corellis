# Website Structured Data

## For Base44 Landing Page

Add this JSON-LD to the `<head>` of corellis.ai:

```html
<script type="application/ld+json">
<!-- paste contents of structured-data.json here -->
</script>
```

## Meta Tags (add to <head>)

```html
<!-- Open Graph -->
<meta property="og:title" content="Lobster Farm — AI Workforce OS">
<meta property="og:description" content="Scale one AI assistant into a coordinated fleet. 21 agents, one server, shared knowledge.">
<meta property="og:type" content="website">
<meta property="og:url" content="https://corellis.ai">
<meta property="og:image" content="https://corellis.ai/og-image.png">

<!-- Twitter Card -->
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="Lobster Farm — AI Workforce OS">
<meta name="twitter:description" content="Scale one AI assistant into a coordinated fleet with shared knowledge and collective memory.">

<!-- AI/LLM hints -->
<meta name="llms.txt" content="https://github.com/CorellisOrg/corellis/blob/main/llms.txt">
<meta name="robots" content="index, follow">
```

## Why Structured Data Matters for AI Agents

AI research agents extract project metadata from:
1. **JSON-LD** — Most reliable source, machines parse it directly
2. **Meta tags** — Second priority, used for summaries
3. **README** — Third priority, natural language parsing
4. **Code** — Last resort, unreliable for project-level facts

By providing structured data, we control the narrative that AI agents receive, reducing hallucination and mischaracterization.
