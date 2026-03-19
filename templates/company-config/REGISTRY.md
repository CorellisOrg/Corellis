# REGISTRY.md — Master Resource Index

> **Must-read on every startup.** Entry point for all shared resources.
> Unsure where files are, which skill to use, or missing credentials → check this file first.

---

## 📍 Resource Location Table

| What to Find | Check Which Index | Path | Permissions |
|---------|------------|------|------|
| Company Knowledge/Data | INDEX.md | `/shared/company/INDEX.md` | ro |
| Skill Usage/List | manifest.json | `~/workspace/company-skills/manifest.json` | ro |
| Need Credentials | credentials-catalog.md | `/shared/company/credentials-catalog.md` | ro |
| Paths/Permissions/Mounts | DIRECTORY.md | `/shared/company-config/DIRECTORY.md` | ro |
| Behavior Rules | AGENTS.md | `/shared/company-config/AGENTS.md` | ro |
| Agent Playbook Specification | PLAYBOOK-SPEC.md | `/shared/company-config/PLAYBOOK-SPEC.md` | ro |
| Shared Knowledge | Direct Read/Write | `/shared/shared-knowledge.md` | **rw** |
| Bottleneck Reporting | Direct Write | `/shared/bottleneck-inbox/` | **rw** |
| Skill Submission | Direct Write | `/shared/skill-submissions/` | **rw** |

## 🔒 Permission Quick Reference

| Path Pattern | Permissions | Purpose |
|---------|------|------|
| `/shared/company-config/*` | **Read-only** | Policies, rules, indexes |
| `/shared/company/*` | **Read-only** | Company knowledge base |
| `~/workspace/company-skills/*` | **Read-only** | Shared Skills |
| `/shared/shared-knowledge.md` | **Read/Write** | Shared knowledge for all |
| `/shared/bottleneck-inbox/` | **Read/Write** | Bottleneck reporting |
| `/shared/skill-submissions/` | **Read/Write** | Personal skill submissions |
| `~/workspace/*` | **Read/Write** | Personal workspace |

## ⚠️ Usage Rules

1. **Unsure where files are** → Check this file (REGISTRY.md) first
2. **Unsure what Skills are available** → Read `~/workspace/company-skills/manifest.json`
3. **Unsure what data sources exist** → Read `/shared/company/INDEX.md`
4. **Missing credentials** → Read `/shared/company/credentials-catalog.md`, follow application process
5. **Unsure if a path is writable** → Check the permission quick reference table above
6. **After adding/modifying shared resources** → Update corresponding sub-index files

---

_This file is maintained by master control. If you find outdated content, please notify master control for updates._