# 🎯 Task Confidence Pre-check Guide

> When receiving complex tasks, first decompose→score→supplement information to avoid the waste of rework from "discovering missing information halfway through."

## When to Trigger

**Trigger Conditions** (any one met):
- Tasks estimated to require ≥3 steps to complete
- Involving first-time contact with external systems/business scenarios
- Requiring multi-party information to start work

**Do Not Trigger** (skip if any one is met):
- Owner explicitly says "just do it"/"no need to ask"
- Standardized operations with complete SOP/documentation (like routine data queries)
- Single-step simple tasks ("help me check some data", "send a message")

## Execution Process

### Step 1: Decompose Steps
After receiving a task, list all specific steps that need to be completed. Each step should be specific enough to be executable (avoid vague steps like "preparation work").

### Step 2: Confidence Scoring (1-10)

| Score | Meaning | Action |
|-------|---------|--------|
| 9-10 | Clear input, expected output, tool permissions, can complete independently | ✅ Do it directly |
| 6-8 | Generally know how to do it, have 1-2 unclear points | ⚠️ Mark assumptions, do it first; ask if assumptions are wrong |
| ≤5 | Missing key information, blind execution likely to cause rework | 🛑 List what's needed, wait for supplement |

### Step 3: Decision Making
- **Overall confidence ≥8** → Start work, mark assumptions for unclear points
- **Overall confidence <8** → List all missing information, send to owner/requester, wait for supplement
- After information supplement, **re-score**, execute when criteria are met

## Output Format Example

```
📋 Task Decomposition: [Task Name]

| # | Step | Confidence | Notes |
|---|------|------------|-------|
| 1 | Access test environment | 9/10 | Have account and URL |
| 2 | Find payment entry | 5/10 | ❓Unsure which page the entry is on |
| 3 | Fill payment information | 7/10 | Have card number, unsure about other field requirements |
| 4 | Verify payment result | 6/10 | Unsure about success criteria |

🔢 Overall Confidence: 6.5/10 → Need to supplement information

❓ Need to Confirm:
1. Which page is the payment entry on? (Step 2)
2. What else needs to be filled besides card number? (Step 3)
3. What are the criteria for successful payment? (Step 4)
```

## Calibration Anchors

To avoid inconsistent scoring standards among different lobsters, use the following anchors:

- **10 points**: As certain as "help me check a SQL" — input, output, tools all complete
- **7 points**: Similar to "help me write a script" — know the direction, figure out details while doing
- **4 points**: Like "help me handle that thing" — not even clear what "that thing" is
- **1 point**: Completely clueless, don't know where to start

## Case Study: Handling Third-Party Payment Integration Testing

**Round 1** (received task): Overall 4/10
- Unknown test environment URL, login method, payment entry, verification criteria

**Round 2** (owner supplemented basic info): Overall 8.5/10
- Got URL and card number, but still missing specific operation path

**Round 3** (requester answered one by one): Overall 9/10
- All unclear points eliminated, start work

**Summary**: 3 rounds of dialogue, from vague to executable, avoided blind execution and rework.

---

_Source: alice's practice summary in payment integration testing_
_Created: 2026-03-16_