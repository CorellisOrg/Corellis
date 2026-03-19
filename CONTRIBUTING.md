# Contributing to Lobster Farm

Thanks for your interest in contributing! 🦞

## Ways to Contribute

- **Bug reports**: Open an issue with steps to reproduce
- **Feature requests**: Open an issue describing the use case
- **Scripts**: Improve existing scripts or add new fleet management tools
- **Skills**: Create reusable company-skills templates
- **Documentation**: Fix typos, improve guides, add examples
- **Teamind**: Improve indexing, search, or add new embedding providers

## Development Setup

1. Fork and clone the repo
2. Set up a test environment:
   ```bash
   cp .env.example .env
   # Fill in at least one LLM API key
   docker build -f docker/Dockerfile.lite -t lobster-openclaw:latest .
   ```
3. Spawn a test lobster:
   ```bash
   cp docker-compose.base.yml docker-compose.yml
   ./scripts/spawn-lobster.sh test-lobster U0XXXXXXXXX xoxb-test xapp-test
   ```

## Code Style

- **Shell scripts**: Use `set -euo pipefail`, add help text, support `--dry-run` where applicable
- **Node.js**: Standard style, no transpilation needed
- **SKILL.md**: Must have YAML frontmatter with `name` and `description`

## Pull Requests

1. Create a feature branch from `main`
2. Test your changes with at least one running lobster
3. Run `bash -n` on any modified shell scripts
4. Update documentation if adding new features
5. Open a PR with a clear description

## Skill Contributions

To add a new company-skills template:

1. Create `templates/<skill-name>/SKILL.md` with YAML frontmatter
2. Add entry to `templates/manifest.json`
3. Document usage in the SKILL.md

## Questions?

- 💬 [OpenClaw Community Discord](https://discord.com/invite/clawd)
- 🐛 [GitHub Issues](https://github.com/CorellisOrg/corellis/issues)
