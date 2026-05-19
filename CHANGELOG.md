# Changelog

All notable changes to this project are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### Universal concept references (`references/concepts/`)
- `user-identity.md` — `userLogin` / `userLogout` ordering, anonymous→logged-in receipt merge, foreground resync per platform
- `promotional-offers.md` — Apple promotional offers, Google developer-determined offers, offer codes (one-time + custom), win-back recipe, full vs observer mode purchase code
- `subscription-management.md` — opening the native Manage Subscription page (iOS 15+ in-app sheet + universal URL fallback, Google Play per-product deeplink)
- `analytics-integration.md` — server-side (3rd-party / webhooks) vs client-side (UI event listener) routing, recommended single analytics wrapper / manager / controller, GDPR consent gating
- `campaigns.md` — no-code Console automations (trigger / placement-based), `readyToOpenDeeplink` setup, SDK ≥ 5.1.0 requirement, capping caveats, use cases

#### Testing & troubleshooting (`references/testing/`, `references/troubleshooting/`)
- `testing/README.md` — sandbox testing for Apple (Sandbox Apple ID, TestFlight) and Google (License Tester, Internal track), recommended per-release testing checklist
- `troubleshooting/debug-mode.md` — SDK debug logging (per platform) vs Purchasely Console-side Debug Mode (QR-code activation, `Internal Testers` audience, deeplink prerequisite)
- `troubleshooting/error-codes.md` — `PLYError` reference for iOS (`PLYError` enum) and Android (`PLYError` sealed class), promotional-offer-specific cases, Google Play Billing v8 hang and fix
- `troubleshooting/screen-issue-report.md` — escalation template for Purchasely Support (Screen Composer bugs)

#### Skill updates
- `skills/debug` — new **Step 0** (enable SDK debug logging) prepended to the diagnostic flow; new **Step 5** (escalate to Purchasely Support via the screen-issue-report template); new **Step 6** (`PLYError` decoding via the error-codes reference); pointers to debug-mode and testing references in the header
- `skills/integrate` — new sections **Step 5b** (Restore Purchases with the Purchasely-paywall caveat) and **Step 5c** (Manage Subscription entry point); new **Step 9** (Beyond the Basics — preload, campaigns, promo offers, analytics, subscription gating, attributes); identity-ordering note added to Step 5; references header extended with new concept files
- `skills/review` — new checks: `userLogin` ordering vs `fetchPresentation`, foreground `synchronize` on resume, Restore button (with Purchasely-paywall awareness), Manage Subscription entry point, `PrivacyInfo.xcprivacy` (iOS 17 SDK / May 2024 App Store requirement), Google Play Billing v8 awareness, `LogLevel.DEBUG` build-flag gating; new sections **3.9 Campaigns**, **3.10 Promotional Offers**, **3.11 Analytics & Events Forwarding**

#### Command routing
- `/purchasely:question` now explicitly delegates to the `purchasely:sdk-expert` agent via the `Task` tool, instead of priming the main session as an expert. This honors the agent's `model: sonnet` selection, isolates the Q&A context, and makes the routing symmetric with the other three commands (which trigger their matching skill). The command's `description` and `argument-hint` are unchanged — the user-visible UX is the same.

#### Documentation hygiene
- `CLAUDE.md` now mandates keeping `CHANGELOG.md` up to date on every user-visible change
- `README.md` clarifies the **skill vs slash command** distinction (`/purchasely:question` is a slash command only — no matching skill); SECURITY and CHANGELOG sections now actively reference the disclosure / release-notes flow
- `references/concepts/README.md` index updated with the new concept files
- `references/concepts/subscription-checks.md` adds the Purchasely-paywall caveat to the Restore section
- **Closed reference-coverage gaps**: every `.md` reference file is now cited by at least one skill/agent (the previously-orphan `references/ios/*`, `references/android/*`, `references/react-native/integration.md`, `references/flutter/integration.md`, `references/cordova/integration.md` are now linked from `skills/integrate`, `skills/review`, and `skills/debug` under a "Platform-specific deep dives" section)
- `agents/sdk-expert.md` now lists every reference file path explicitly (was previously vague: "platform-specific integration guides")
- `skills/integrate` and `skills/review` now reference `cross-platform-subscriptions.md`, `troubleshooting/common-issues.md`, and `troubleshooting/screen-issue-report.md` for issues that surface during integration or review

### Changed
- `install.sh` now detects and installs the Mistral config (was already in Unreleased)

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

[Unreleased]: https://github.com/Purchasely/Purchasely-AI-Plugin/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Purchasely/Purchasely-AI-Plugin/releases/tag/v1.0.0
