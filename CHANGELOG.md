# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- P1: Controller goal-ops skill — distributed goal orchestration (decompose, distribute, monitor, complete)
- P1: Proactive task engine skill — self-driving lobster task discovery with confidence scoring
- P1: Task autopilot skill — automatic task decomposition and execution planning
- P1: Coding workflow skill — ACP coding agent collaboration with confidence-based routing
- P1: Controller HEARTBEAT.md — auto-pilot checklist template
- P1: Crontab example — recommended cron schedule for controller
- P1: Skill submission pipeline — poll, review, and deploy scripts
- P1: Company-config AGENTS.md — lobster governance template
- P1: Company-skills manifest.json — skill registry with tier system

### Fixed
- P0: JSON syntax errors in config templates
- P0: secrets.json template missing required fields
- P0: Docker CLI socket path in spawn script
- P0: Docker socket permission in compose template
- P0: mcporter.json syntax error
- P0: CPU limit corrected from 0.5 to 1.5

## [0.1.0] - 2026-04-06

### Added
- Initial release: multi-agent orchestration framework for OpenClaw
- Spawn scripts for controller and lobster containers
- Docker Compose base configuration
- Template system: controller config, lobster config, skills
- 15+ template skills (goal-participant, deep-research, task-management, etc.)
- Company shared infrastructure (config, memory, skills)
- Documentation: README, tutorial, architecture, guides
- Test suite: script validation, template checks, integration smoke tests
- CI: GitHub Actions workflow for automated testing
