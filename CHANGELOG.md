# Changelog

All notable changes to this project are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `purchasely/.claude-plugin/plugin.json` and `purchasely/hooks` — make the root `purchasely/` plugin folder self-contained for Claude Code, matching the existing Codex plugin folder layout.
- GitHub Copilot CLI quickstart using `copilot plugin marketplace add Purchasely/Purchasely-AI-Plugin` and `copilot plugin install purchasely@Purchasely-AI-Plugin`.

### Changed

- `.claude-plugin/marketplace.json` now points to `./purchasely`, and `purchasely/.codex-plugin/plugin.json` uses lowercase Codex capability names.
- `AGENTS.md` and `GEMINI.md` now act as thin bootstraps to the canonical `skills/` playbooks instead of duplicating SDK guidance.
- Skill reference links now use paths relative to each `SKILL.md`, so Copilot CLI, Claude Code, and Codex installs resolve bundled `references/` files correctly.

### Removed

- Removed legacy `configs/` rule copies and `install.sh`; supported harnesses should install the plugin/extension or use root bootstraps that point to `skills/`.

## [1.0.0] — 2026-05-19

Initial public release of the Purchasely AI Plugin.

### Added

#### Cross-harness support
- `AGENTS.md` at the repository root — cross-vendor [agents.md](https://agents.md) standard, auto-detected by Codex, Cursor, Zed, Mistral `vibe`, and other harnesses without running `install.sh`.
- `GEMINI.md` at the repository root — imports the `integrate`, `review`, and `debug` skills via `@./skills/...` so Gemini CLI picks up the full playbook automatically.
- `gemini-extension.json` at the repository root — unlocks one-shot install via `gemini extensions install https://github.com/Purchasely/Purchasely-AI-Plugin`.
- OpenCode plugin support via `.opencode/INSTALL.md` — covers prerequisites, the one-line `opencode.json` install, usage examples, updating, and Windows troubleshooting (`npm install --prefix` workaround).
- `SessionStart` hook (`hooks/hooks.json`, `hooks/hooks-cursor.json`, `hooks/session-start`, `hooks/run-hook.cmd`, `hooks/intro.md`) auto-injects pointers to the `integrate` / `review` / `debug` skills and `/purchasely:question` command so the plugin is discoverable without the user typing a slash command first. Works on Claude Code, Cursor, and any host honoring the standard SDK `additionalContext` envelope. Zero-dependency POSIX shell + polyglot `.cmd` wrapper for Windows (Git Bash / WSL).
- `.claude-plugin/plugin.json` now points at `./hooks/hooks.json`.
- `docs/distribution.md` — public roadmap listing the official marketplaces we want to ship to (Anthropic `claude-plugins-official`, OpenAI Codex `openai/plugins`, Factory Droid, GitHub Copilot CLI, Anthropic Skill Marketplace) with status, target install command, and work-to-do for each.

#### Core plugin infrastructure
- Claude Code plugin manifest (`.claude-plugin/plugin.json` and `marketplace.json`)
- 3 AI-invoked skills: `integrate`, `review`, `debug`
- 4 user-invoked slash commands: `/purchasely:integrate`, `/purchasely:review`, `/purchasely:debug`, `/purchasely:question`
- `sdk-expert` agent
- Pre-built configs for Cursor, GitHub Copilot, Windsurf, Codex, Gemini, Mistral
- POSIX-compatible `install.sh` with auto-detection of installed AI tools (including Mistral)
- MIT License

#### Universal concept references (`references/concepts/`)
- `user-identity.md` — `userLogin` / `userLogout` ordering, anonymous→logged-in receipt merge, foreground resync per platform
- `promotional-offers.md` — Apple promotional offers, Google developer-determined offers, offer codes (one-time + custom), win-back recipe, full vs observer mode purchase code
- `subscription-management.md` — opening the native Manage Subscription page (iOS 15+ in-app sheet + universal URL fallback, Google Play per-product deeplink)
- `analytics-integration.md` — server-side (3rd-party / webhooks) vs client-side (UI event listener) routing, recommended single analytics wrapper / manager / controller, GDPR consent gating
- `campaigns.md` — no-code Console automations (trigger / placement-based), `readyToOpenDeeplink` setup, SDK ≥ 5.1.0 requirement, capping caveats, use cases
- `subscription-checks.md` — subscription gating including the Purchasely-paywall caveat for Restore
- `cross-platform-subscriptions.md` — handling subscriptions across iOS and Android stores

#### Platform-specific references
- Integration guides for iOS, Android, React Native, Flutter, and Cordova
- Cross-platform architecture diagrams
- `architecture-patterns.md` — wrapper / service / gateway pattern (recommended, not required)

#### Testing & troubleshooting (`references/testing/`, `references/troubleshooting/`)
- `testing/README.md` — sandbox testing for Apple (Sandbox Apple ID, TestFlight) and Google (License Tester, Internal track), recommended per-release testing checklist
- `troubleshooting/debug-mode.md` — SDK debug logging (per platform) vs Purchasely Console-side Debug Mode (QR-code activation, `Internal Testers` audience, deeplink prerequisite)
- `troubleshooting/error-codes.md` — `PLYError` reference for iOS (`PLYError` enum) and Android (`PLYError` sealed class), promotional-offer-specific cases, Google Play Billing v8 hang and fix
- `troubleshooting/screen-issue-report.md` — escalation template for Purchasely Support (Screen Composer bugs)
- `troubleshooting/common-issues.md` — common integration pitfalls and fixes

#### Skills
- `skills/debug` — diagnostic flow including **Step 0** (enable SDK debug logging), **Step 5** (escalate to Purchasely Support via the screen-issue-report template), and **Step 6** (`PLYError` decoding via the error-codes reference); pointers to debug-mode and testing references
- `skills/integrate` — covers initialization, paywall display, purchase handling, action interceptor, **Step 5b** (Restore Purchases with the Purchasely-paywall caveat), **Step 5c** (Manage Subscription entry point), and **Step 9** (Beyond the Basics — preload, campaigns, promo offers, analytics, subscription gating, attributes); identity-ordering note in Step 5
- `skills/review` — 24-point checklist including `userLogin` ordering vs `fetchPresentation`, foreground `synchronize` on resume, Restore button (with Purchasely-paywall awareness), Manage Subscription entry point, `PrivacyInfo.xcprivacy` (iOS 17 SDK / May 2024 App Store requirement), Google Play Billing v8 awareness, and `LogLevel.DEBUG` build-flag gating; sections **3.9 Campaigns**, **3.10 Promotional Offers**, and **3.11 Analytics & Events Forwarding**

#### Command routing
- `/purchasely:question` delegates to the `purchasely:sdk-expert` agent via the `Task` tool, honoring the agent's `model: sonnet` selection and isolating the Q&A context

#### Documentation hygiene
- `CLAUDE.md` mandates keeping `CHANGELOG.md` up to date on every user-visible change
- `README.md` clarifies the **skill vs slash command** distinction (`/purchasely:question` is a slash command only — no matching skill); SECURITY and CHANGELOG sections reference the disclosure / release-notes flow
- `references/concepts/README.md` indexes the concept files
- Every `.md` reference file is cited by at least one skill or agent (no orphaned references)
- `agents/sdk-expert.md` lists every reference file path explicitly

### Changed

- Restructured the `README.md` installation section into a per-harness *Quickstart* (Claude Code, Codex CLI, Codex App, Cursor, Gemini CLI, OpenCode, GitHub Copilot CLI, Mistral `vibe`, Windsurf, JetBrains, Continue). The legacy `install.sh` one-shot install moves into a dedicated *Installation (legacy / all-in-one)* section below it.

[1.0.0]: https://github.com/Purchasely/Purchasely-AI-Plugin/releases/tag/v1.0.0
