# Skill Contribution - Contribute Skill to Company

## Description
Allow member lobsters to contribute personally developed skills to the company's shared skill library.

## Trigger Methods
User says any of the following:
- "contribute skill xxx to company"
- "share skill xxx"
- "submit skill xxx"
- "contribute skill xxx"

## Execution Process

### Step 1: Locate Skill
Check if `workspace/skills/<name>/` exists.
If it doesn't exist, prompt the user to develop the skill first.

### Step 2: Local Pre-check (Fail Fast)
Check each item, if any fails, inform the user to make corrections:

1. **SKILL.md** exists and is not empty
2. **description** field exists (in SKILL.md)
3. **No hardcoded credentials**: Scan all files for patterns like `api_key=`, `token=`, `password=`, `secret=` followed by long strings. If found, tell the user to remove and use environment variables instead.
4. **Total size < 5MB**, single file < 2MB
5. **No binary files**: No .exe, .bin, .so, .dll allowed

### Step 3: Generate SUBMISSION.md
Create metadata file in submission directory:

```markdown
# Skill Submission

- **skill_name**: <skill name>
- **author**: <username> (<Slack User ID>)
- **submitted_at**: <ISO 8601 time>
- **description**: <extracted from SKILL.md>
- **reason**: <user's explanation for contribution, ask if not provided>
- **files**: <file list>
- **total_size**: <total size>
- **status**: pending
```

### Step 4: Write to Shared Submission Box
Target path: `/shared/skill-submissions/<author>-<skillname>-<timestamp>/`

Structure:
```
/shared/skill-submissions/<author>-<skillname>-<YYYYMMDDTHHmmss>/
  SUBMISSION.md
  skill/          ← complete skill directory copy
    SKILL.md
    ...other files
```

⚠️ When copying files, ensure exclusion of `node_modules/`, `.git/`, `__pycache__/`, etc.

### Step 5: Confirmation
Tell the user:
> ✅ Skill `<name>` has been submitted to company approval queue. The master control will automatically review and notify administrators. Please wait for approval results.

### Step 6: Clean Local Copy (Execute Immediately After Successful Submission)
After successful submission, **immediately delete** all copies of that skill in the local workspace to avoid local files overriding the company shared version:

```bash
# Delete skill directory
rm -rf ~/workspace/skills/<name>/

# Delete possible scattered files (old format)
rm -f ~/workspace/<name>-SKILL.md
rm -f ~/workspace/<name>.skill
```

Tell the user:
> 🧹 Local copy has been cleaned up. After approval, the skill will be automatically available through the company-skills shared directory, no need to keep local version.

⚠️ **Why delete**: Local skill files have higher priority than company-skills shared directory. If not deleted, lobsters will always read the old local version, ignoring updates to the company shared version.

## Notes
- If `/shared/skill-submissions/` directory doesn't exist, tell the user this feature is not yet enabled
- If a skill with the same name already exists in company-skills, indicate this is an upgrade request in the reason
- Don't modify company-skills/ directory (read-only mount)
- Cannot modify files in submission box after submission (unless status is marked as revise)