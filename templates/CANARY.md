# CANARY.md — Canary/Gradual Rollout Tracking

Track gradual rollouts of new features, configs, or skills across the fleet.

## Template

### #N — Feature Name (Status: 🟡 canary | 🟢 stable | 🔴 rolled back)

- **What**: Brief description
- **Why**: Problem it solves
- **Canary group**: lobster-alice, lobster-bob (2/20)
- **Started**: YYYY-MM-DD
- **Metrics**: What to watch (error rate, memory usage, user feedback)
- **Rollout plan**: Canary 2d → 25% → 50% → 100%

**Log**:
- `MM-DD` Deployed to canary group
- `MM-DD` No issues, expanding to 25%
- `MM-DD` Full rollout complete

---

## Active Rollouts

_(add entries as you deploy)_

## Completed

_(move here after full rollout)_

## Rolled Back

_(move here if reverted, with reason)_
