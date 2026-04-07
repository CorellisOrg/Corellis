# Verification Checklist

Detailed checklist for verifying coding agent output before committing.

## Pre-Merge Checklist

### 1. Correctness

- [ ] Changes match the task requirements exactly
- [ ] No extra files modified beyond scope
- [ ] Logic handles all specified edge cases
- [ ] Error paths return appropriate messages/codes

### 2. Testing

- [ ] Existing tests still pass
- [ ] New tests added for new functionality
- [ ] Edge cases covered in tests
- [ ] Test names are descriptive and clear

### 3. Security

- [ ] No hardcoded secrets, tokens, or API keys
- [ ] No hardcoded internal URLs or IPs
- [ ] Input validation present for user-facing inputs
- [ ] SQL queries use parameterized statements (no string concatenation)
- [ ] File operations validate paths (no path traversal)

### 4. Code Quality

- [ ] Linter passes with zero warnings
- [ ] Consistent style with existing codebase
- [ ] No commented-out code blocks
- [ ] No debug/print statements left in
- [ ] Functions have reasonable length (< 50 lines)

### 5. Dependencies

- [ ] No unnecessary new dependencies added
- [ ] New dependencies are well-maintained and license-compatible
- [ ] Lock file updated if dependencies changed

### 6. Documentation

- [ ] Public functions/methods have doc comments
- [ ] README updated if user-facing behavior changed
- [ ] API docs updated if endpoints changed
- [ ] CHANGELOG updated for notable changes

### 7. Performance

- [ ] No N+1 query patterns introduced
- [ ] No unnecessary loops or repeated computations
- [ ] Large data sets handled with pagination/streaming
- [ ] No memory leaks (event listeners cleaned up, connections closed)

## Common Agent Mistakes to Watch For

| Mistake | How to Spot |
|---------|-------------|
| Hallucinated imports | `import` for packages not in dependencies |
| Wrong API signatures | Function called with wrong argument count/types |
| Incomplete error handling | `catch` blocks that swallow errors silently |
| Hardcoded test values | Tests that only work with specific data |
| Over-engineering | Added abstractions not asked for |
| Under-engineering | Skipped validation, error handling, or edge cases |
| Copy-paste artifacts | Duplicated code that should be shared |
| Outdated patterns | Using deprecated APIs or old syntax |

## Decision Matrix: Ship or Iterate?

| Condition | Action |
|-----------|--------|
| All checks pass | ✅ Ship it |
| 1-2 minor style issues | ✅ Ship, fix in follow-up |
| Failing tests | ❌ Iterate: send fix instructions to agent |
| Security issue | ❌ Stop: fix manually, don't trust agent with security fixes |
| Wrong approach entirely | ❌ Kill session: reassess requirements, start fresh |
| Missing edge cases | ⚠️ Iterate: specify exact edge cases for agent to handle |
