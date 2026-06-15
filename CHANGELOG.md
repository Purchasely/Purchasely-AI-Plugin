# Changelog

All notable changes to this project are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `references/ios/v5-api-reference.md` and `references/android/v5-api-reference.md` — compact snapshots of the v5 public API (legacy symbols, signatures, and a `→ v6` pointer for each) so the `migrate` skill can recognize the code it is replacing.
- `references/concepts/lottie-animations.md` — covers Purchasely Screen Lottie setup with the iOS `PLYLottieBridge`, Android `PLYLottieInterface` / `Purchasely.lottieView`, cross-platform host-project notes, and troubleshooting for missing bridges, file size, and Console template availability.

### Changed

- **Native iOS and Android references fully aligned with the published SDK v6.0.0 API.** Reworked `references/ios/*` and `references/android/*` (`api-reference`, `initialization`, `common-patterns`, `migration-v6`) around the fluent init builder, per-action `interceptAction` + `PLYInterceptResult`, the `PLYPresentationBuilder` / `PLYPresentation { }` builder→preload→display model, `PLYPresentationOutcome` (with `closeReason`), `screenId`, SwiftUI `swiftUIView`, `StateFlow<PLYPresentationState>`, Android deeplink auto-interception, `synchronize(onSuccess, onError)`, and the v6 removals — covering Swift, Objective-C, Kotlin and Java.
- `migrate` skill — now leads with the silent default-running-mode change (Observer in v6; set Full explicitly for purchase handling & validation), covers Kotlin/Java/Swift/Objective-C, uses the new v5 API snapshots to detect legacy code, and instructs fact-checking against the official v6 docs (`docs.purchasely.com` / the `v6.0` branch of `Purchasely/Documentation`).
- `references/concepts/running-modes.md` — documents the v6 default-mode change (Observer) with v6 initialization for iOS (Swift/Obj-C) and Android (Kotlin/Java); cross-platform examples kept on v5.
- Concept references, the `purchasely-integrate` / `purchasely-review` / `purchasely-debug` skills, and the `sdk-expert` agent updated to the v6 native API.
- `references/sdk-versions.md` — native iOS bumped to `6.0.0`; iOS pinning snippets updated.
- `purchasely-integrate`, `purchasely-review`, and `purchasely-debug` now require a final app build; build failures must be fixed and rechecked before reporting success.

### Fixed

- Removed the non-existent `io.purchasely:presentation-compose` artifact and `PLYPresentationView` composable from the Android docs — `buildView(...)` returns an Android `View`; for Jetpack Compose, wrap it in an `AndroidView`.
- Removed `flowId(...)` / `productId(...)` / `planId(...)` from the Android `PLYPresentation { }` builder examples — they are not exposed in v6; display a Flow via its `app_scheme://ply/flows/FLOW_ID` deeplink.

## [1.1.0] — 2026-05-25

### Changed

- **Skills renamed to `purchasely-integrate` / `purchasely-review` / `purchasely-debug`** (was `integrate` / `review` / `debug`) — disambiguates the skills when installed alongside other repos via the [`skills` CLI](https://www.skills.sh/docs) (`npx skills add Purchasely/Purchasely-AI-Plugin`). The matching slash commands keep their existing names (`/purchasely:integrate`, `/purchasely:review`, `/purchasely:debug`) since they're already namespaced by the Claude Code plugin prefix. Migration: re-run `npx skills update` (or `npx skills add Purchasely/Purchasely-AI-Plugin` again) to pick up the new names.

### Added

- **skills.sh distribution** — the three renamed skills can now be installed in any AGENTS.md-compatible harness via `npx skills add Purchasely/Purchasely-AI-Plugin`. README gains a top-level Skills CLI section, a [skills.sh](https://skills.sh/Purchasely/Purchasely-AI-Plugin) install-count badge, and a Discoverability entry. The `skills` CLI picks up the existing `skills/` symlink and `.claude-plugin/` manifests automatically — no on-disk layout change beyond the directory rename.
- `references/concepts/byos.md` — Bring Your Own Screen reference: when to use it (native login step in a Flow, A/B against an existing paywall, reordering onboarding), Console configuration (Screen ID + connections), iOS implementation (`PLYCustomScreenViewControllerDelegate` / SwiftUI `PLYCustomScreenViewDelegate`), Android implementation (`PLYCustomScreenProvider` + `PLYCustomScreen.View` / `.Fragment`), `executeConnection(...)` / `execute(connection)` contract for resuming a Flow or running a standalone action, `Purchasely.synchronize()` requirement for in-screen purchases, analytics behaviour, and a list of anti-patterns BYOS replaces (custom VC over Purchasely, manual close-then-push, skipping `display()`). iOS + Android only, SDK ≥ 5.6.0.
- `references/concepts/paywall-actions.md` § **Chaining multiple actions on a single button** — documents how a Composer button can carry several actions (purchase + open_screen / open_placement / deeplink / close, login + purchase, etc.) executed sequentially, the default behaviour when no second action is configured (close in Full mode, stay open in Observer mode), how the interceptor sees each action separately, and the fact that `proceed(false)` short-circuits the chain.
- `sdk-expert` agent: new response rule for BYOS / "show my own screen inside a paywall or Flow" / "native login step inside a Flow" — forces loading `references/concepts/byos.md`, gates the answer on SDK ≥ 5.6.0 + iOS/Android platform, and steers users away from anti-patterns (presenting a custom VC over the Purchasely controller, `Purchasely.close()` then push, skipping `display()`).
- `purchasely-review` skill: new section **3.12 BYOS** — conditional checklist (platform support, SDK version, `display()` usage, delegate/provider completeness, `executeConnection` on every exit, connection ID consistency, `synchronize()` after in-screen purchases, no manual navigation around the SDK controller, in-screen analytics instrumentation).
- `purchasely-review` skill § 3.3: new checkpoint flagging interceptors that try to override the post-purchase flow (holding the interceptor open, skipping `proceed`, manual `Purchasely.close()`) — recommends configuring a second Composer action instead, or BYOS for a custom next step.
- `purchasely-integrate` skill § Step 9 (Beyond the Basics): two new entries — BYOS and chained Composer actions — so they surface during onboarding when the user's roadmap matches.

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

[1.1.0]: https://github.com/Purchasely/Purchasely-AI-Plugin/releases/tag/1.1.0
[1.0.1]: https://github.com/Purchasely/Purchasely-AI-Plugin/releases/tag/1.0.1
[1.0.0]: https://github.com/Purchasely/Purchasely-AI-Plugin/releases/tag/1.0.0
