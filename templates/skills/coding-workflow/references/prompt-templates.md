# Prompt Templates

Extended prompt templates for common coding tasks. Use these as starting points
and customize for your specific codebase and requirements.

## Refactoring

```
Task: Refactor [module/function]

Current state:
- [Description of current code and its problems]
- [Specific code smells or issues]

Goals:
1. [Specific improvement 1]
2. [Specific improvement 2]
3. Maintain all existing behavior (no functional changes)

Constraints:
- Do NOT change public API signatures
- Keep backward compatibility
- Follow existing naming conventions in [reference file]

Verification:
- All existing tests pass: [test command]
- No new warnings from linter: [lint command]
```

## Database Migration

```
Task: Create migration for [change description]

Database: [PostgreSQL/MySQL/SQLite]
ORM: [if applicable]

Changes needed:
1. [Table/column change 1]
2. [Table/column change 2]

Requirements:
- Migration must be reversible (include rollback)
- Handle existing data gracefully (no data loss)
- Add appropriate indexes for new columns
- Test with sample data

Verification:
- Migration runs forward without errors
- Migration rolls back without errors
- Existing queries still work
```

## API Endpoint

```
Task: Implement [HTTP method] [endpoint path]

Framework: [Express/Gin/FastAPI/etc.]

Specification:
- Request: [body/query params schema]
- Response: [success response schema]
- Errors: [error codes and messages]
- Auth: [authentication requirements]

Requirements:
- Input validation for all parameters
- Proper error handling with appropriate HTTP status codes
- Add to API documentation / OpenAPI spec
- Write integration test

Reference: [similar existing endpoint for style]

Verification:
- curl test: [example curl command]
- Run: [test command]
```

## Test Suite

```
Task: Write tests for [module/function]

Testing framework: [Jest/pytest/Go testing/etc.]
Current coverage: [if known]

Test cases needed:
1. Happy path: [normal input → expected output]
2. Edge cases: [empty input, null, boundary values]
3. Error cases: [invalid input, missing dependencies]
4. [Any specific scenarios]

Style guide:
- Follow existing test patterns in [reference test file]
- Use descriptive test names
- One assertion per test when practical
- Mock external dependencies

Verification:
- All new tests pass
- No existing tests broken
- Coverage improved (if measurable)
```
