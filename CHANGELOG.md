# Changelog

All notable changes to this project are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] — 2026-05-20

### Changed

- `sdk-expert` agent: forces loading `references/concepts/campaigns.md` whenever a question mentions *campaign / campagne / trigger / `APP_STARTED` / `readyToOpenDeeplink` / "afficher au lancement"*, and explicitly distinguishes trigger-based (SDK-managed, only `readyToOpenDeeplink(true)` required) from placement-based delivery.
- `sdk-expert` agent: for any Console-driven topic (campaigns, audiences, A/B tests, placement configuration, Screens, Flows, surveys), the agent now fetches the current official documentation via `ctx_fetch_and_index(https://docs.purchasely.com/docs/<topic>)` before answering, and reconciles with the bundled references.

### Fixed

- `sdk-expert` agent no longer conflates Campaigns with the manual `fetchPresentation` / `presentPresentation` flow when the user asks about displaying a campaign at app launch.

## [1.0.0] — 2026-05-20

Initial release of the Purchasely AI Plugin for Claude Code, GitHub Copilot CLI, and Codex.

### Added

- Cross-harness plugin support for Claude Code, GitHub Copilot CLI, Codex, and compatible AI coding agents.
- Purchasely SDK skills for integration, code review, debugging, and SDK Q&A.
- Purchasely SDK expert agent and slash-command entry points for guided assistance.
- Reference documentation for Purchasely SDK setup, paywall display, purchases, subscriptions, privacy/GDPR, promotional offers, campaigns, and troubleshooting across iOS, Android, React Native, Flutter, and Cordova.
- Installation and marketplace metadata for supported agent environments.

[1.0.1]: https://github.com/Purchasely/Purchasely-AI-Plugin/releases/tag/1.0.1
[1.0.0]: https://github.com/Purchasely/Purchasely-AI-Plugin/releases/tag/1.0.0
