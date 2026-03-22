# Tests

## Running Tests

```bash
# Run all tests
./tests/run-all.sh

# Run specific test suite
./tests/test-scripts.sh     # Shell script validation
./tests/test-templates.sh   # Template integrity checks
./tests/test-teamind.sh     # Teamind module validation
```

## Test Categories

| Suite | What it tests |
|-------|--------------|
| `test-scripts.sh` | All 24 scripts: syntax, permissions, --help flags, --dry-run safety |
| `test-templates.sh` | Template completeness, required sections, cross-references |
| `test-teamind.sh` | Node.js syntax, package.json validity, module imports |

## CI

Tests run automatically on push/PR via GitHub Actions. See `.github/workflows/ci.yml`.
