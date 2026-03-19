# Company Memory Design Specification

> All sub-memory documents under company-memory/ must follow this specification.
> Last updated: 2026-02-28

---

## 1. File Naming

- **Format**: `kebab-case.md` (all lowercase, hyphen-separated)
- **Requirements**: Names must be self-explanatory, no meaningless naming like `doc-1.md`, `temp.md`
- ✅ `payment-compliance.md`, `infrastructure-architecture.md`
- ❌ `notes.md`, `stuff.md`, `2026-02-28.md`

## 2. Document Header (Required)

Each document must include the following metadata at the beginning:

```markdown
# Title (Concise, no more than 15 characters)

> Summary: One sentence describing the topic and scope covered by this document
> Keywords: keyword1, keyword2, keyword3 (5-15 keywords, mixed Chinese and English)
> Last updated: YYYY-MM-DD
> Maintainer: Who is responsible for updating this document (optional)

---
```

### Why is a header needed?
- **Summary**: Semantic search prioritizes the first few lines, good summary = high hit rate
- **Keywords**: Cover synonyms and abbreviations, ensure different ways of asking can all find it
- **Update date**: Determine information timeliness

## 3. Content Structure

### 3.1 Use Headings for Sections (Required)
- Use `##` second-level headings to divide main chapters
- Use `###` third-level headings to divide sub-topics
- Each paragraph focuses on one topic, facilitating `memory_get` line-by-line retrieval

### 3.2 Paragraph Length
- Single paragraph no more than **20 lines**
- Split longer ones into sub-chapters
- Reason: Semantic search returns fragments, paragraphs that are too long waste tokens

### 3.3 Tables First
- Use tables for comparative information, not long paragraphs
- Tables are friendlier to both AI understanding and user reading

### 3.4 Action Lists
- If the document contains to-do items, place them in the `## Action Items` section at the end of the document
- Use `- [ ]` / `- [x]` format

## 4. Content Principles

### 4.1 Write Conclusions, Not Processes
- ✅ "Chargeback rate red line = monthly >1% and ≥$5,000"
- ❌ "In our discussion on February 28, Alice asked about the definition of chargeback..."

### 4.2 Keep Actionable
- Each knowledge point should directly guide decisions
- Avoid pure theoretical descriptions, include "what this means for us"

### 4.3 Mark Information Sources
- When citing external documents, attach links
- Place in the `## Reference Documents` section at the end of the document

### 4.4 Distinguish Facts from Opinions
- State facts directly
- Mark team decisions/opinions with `>` quote blocks

## 5. Index Maintenance (INDEX.md)

### 5.1 When Adding New Documents
After creating a new document, **must** synchronously update INDEX.md, adding a line:

```markdown
| filename.md | Topic description | Keyword list | YYYY-MM-DD |
```

### 5.2 When Deleting/Renaming Documents
Synchronously update INDEX.md, remove or modify corresponding lines.

### 5.3 Regular Audits
Check quarterly:
- Are there documents not indexed
- Are there indexes pointing to non-existent documents
- Do keywords need updating

## 6. File Size Limits

- Single document no more than **500 lines / 15KB**
- Split larger ones into multiple sub-documents
- Reason: `memory_get` reads by line, files that are too large affect efficiency

## 7. Prohibited Content

- ❌ API Keys, passwords, tokens and other plaintext credentials
- ❌ Personal privacy information (phone numbers, ID cards, etc.)
- ❌ Temporary information (should go in daily log)
- ❌ Code snippets over 30 lines (should go in separate script files)

## 8. Skill Credential Management Specification

### 8.1 Classification Standards

**Judgment basis**: If this token is leaked or abused, what is the worst consequence?

- 🔴 **High Security** (can spend money, change data, affect production) → `.env` environment variables, requires `docker restart`
- 🟢 **Normal** (read-only queries, limited third-party APIs) → `.env.<skill-name>` file, `/magic` can hot update

### 8.2 High Security Credentials (.env environment variables)

Applicable: AWS credentials, database passwords, payment/financial, credentials with write permissions or unlimited calls
Storage: `$LOBSTER_FARM_DIR/.env` (global, restart to take effect)

### 8.3 Normal Credentials (.env.xxx files)

Applicable: Third-party read-only APIs (SEO Tool, Attribution Tool, Apify), observability platforms, search/tool types
Storage: `~/.openclaw/workspace/.env.<skill-name>`
Format: `KEY=value` (shell source compatible)
SKILL.md reference: `source ~/.openclaw/workspace/.env.custom`

### 8.4 Existing Credentials

Credentials already in `.env` remain unchanged, only newly added credentials follow this specification for classification.

### 8.5 Security Rules

- `.env.*` files are only used when skills execute `source`
- Prohibited to `read`/`cat` credential files and output content to users
- Prohibited to display API key / token plaintext in conversations

## 9. Template

Copy this template when creating new documents:

```markdown
# [Title]

> Summary: [One sentence description]
> Keywords: [5-15 keywords]
> Last updated: YYYY-MM-DD

---

## 1. [Main Section]

### 1.1 [Sub-topic]

Content...

## 2. [Main Section]

Content...

## Action Items

- [ ] To-do 1
- [ ] To-do 2

## Reference Documents

- [Document Name](URL)
```