# Changelog

## [0.1.0] - 2026-03-19

### Initial Release

**Infrastructure**
- `docker/Dockerfile.lite`: Production image with OpenClaw + Chrome + VNC + ACP (~1.5GB)
- `docker/entrypoint.sh`: dbus-launch fix, X11/ICE permissions, auto company-skill sync
- `docker-compose.base.yml`: Compose template for fleet management
- `install.sh`: Quick-start installer

**Fleet Management (24 scripts)**
- `spawn-lobster.sh`: Create new lobster with Slack bot, ACP, and secrets
- `create-slack-app.sh`: Auto-create Slack App via Manifest API
- `health-check.sh`: Check gateway, Slack, disk, memory for all lobsters
- `rolling-upgrade.sh`: Zero-downtime OpenClaw upgrades across fleet
- `backup-lobsters.sh`: Full backup of all lobster data
- `broadcast.sh` / `broadcast-direct.sh`: Fleet-wide messaging
- `sync-fleet.sh` / `sync-company-skills.sh`: Sync shared knowledge and skills
- `resource-monitor.sh`: Memory and disk monitoring with alerts
- `credential-healthcheck.sh`: Verify all lobster credentials
- `log-patrol.sh`: Automated log scanning for errors
- And more — see `scripts/` directory

**Teamind** — Group chat memory system
- SQLite + embeddings for semantic search across Slack history
- Indexer, search, digest, and setup scripts
- Supports OpenAI and Gemini embedding providers

**Self-Improving (2nd Me)**
- Auto-learn from corrections, errors, and reflections
- Daily scan triggers for fleet-wide learning

**25 Built-in Skills**
- See `templates/manifest.json` for the full list
- Includes: deep-research, goal-participant, approval-flow, quick-data-dashboard, and more

**Governance Templates**
- `templates/company-config/`: AGENTS.md, DIRECTORY.md, REGISTRY.md, PLAYBOOK-SPEC.md
- `templates/company-memory/`: INDEX.md, SPEC.md
- `templates/SKILL_POLICY.md`: Skill tier system (base/standard/restricted)

**Documentation**
- `docs/tutorial-3-person-team.md`: End-to-end setup walkthrough (30 min)
- `docs/capabilities.md`: Complete product reference (544 lines)
- `docs/slack-bot-setup.md`: Slack bot creation guide (automated + manual)
- `docs/guides/`: 7 operational guides
