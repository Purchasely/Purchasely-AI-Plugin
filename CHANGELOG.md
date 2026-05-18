# Changelog

All notable changes to this project are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Mistral `vibe` support via `configs/mistral/AGENTS.md` (cross-vendor `AGENTS.md` format)
- Open-source governance: `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CHANGELOG.md`, `.gitignore`, GitHub issue & PR templates
- Badges and `agentskill.sh` discoverability section in the README

### Changed
- `install.sh` now detects and installs the Mistral config

### Removed
- *(internal preparation — no public migration paths shipped yet)*

## [1.0.0] — 2026-04-01

### Added
- Initial release of the Purchasely AI Plugin
- Claude Code plugin manifest (`.claude-plugin/plugin.json` and `marketplace.json`)
- 3 AI-invoked skills: `integrate`, `review`, `debug`
- 4 user-invoked slash commands: `/purchasely:integrate`, `/purchasely:review`, `/purchasely:debug`, `/purchasely:question`
- `sdk-expert` agent
- Pre-built configs for Cursor, GitHub Copilot, Windsurf, Codex, Gemini
- Reference docs for iOS, Android, React Native, Flutter, Cordova
- Cross-platform architecture diagrams
- Troubleshooting guide and architecture-patterns reference
- POSIX-compatible `install.sh` with auto-detection of installed AI tools
- MIT License

[Unreleased]: https://github.com/Purchasely/AI-Plugin/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Purchasely/AI-Plugin/releases/tag/v1.0.0
