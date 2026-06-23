# Changelog

All notable changes to this project are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0-rc.1] — 2026-06-23

Cordova joins the **v6 line**, mirroring the native iOS/Android & Flutter work. Cordova is carved out of the former "v5 cross-platform" grouping and documented for **Purchasely v6.0.0-rc.1**. Unlike the Flutter / React Native v6 plugins, the Cordova plugin keeps its **method-based JS API** (it bridges the v6 native SDKs behind the same `cordova.exec` actions), so only the breaking renames change. **React Native stays on v5 (`5.7.3`).**

### Added

- **`references/cordova/migration-v6.md`** — Cordova v5 → v6 migration mapping (running mode Observer default, `allowDeeplink` / `handleDeeplink`, `setDefaultPresentationDismissHandler`, `synchronize(success, error)`, `presentSubscriptions` no-op).
- **`references/cordova/v5-api-reference.md`** — legacy v5 Cordova tokens so `purchasely-migrate` can recognize and map them forward.

### Changed

- **`references/cordova/integration.md` rewritten as a v6 reference** — pins `6.0.0-rc.1` (iOS 13.4 / Android minSdk 23 / compileSdk 36), default running mode Observer, real method names (dropped the invented `startWithAPIKey` / `setPaywallActionInterceptorCallback`), v6 deeplinks (`allowDeeplink` / `handleDeeplink`), `setDefaultPresentationDismissHandler`, `synchronize(success, error)`, `presentSubscriptions` no-op.
- **`references/sdk-versions.md`** — the Cordova row, package.json pins and the transitive-version table move to the v6 generation (`6.0.0-rc.1`). React Native stays `5.7.3`.
- **Skills updated for Cordova v6.** `purchasely-integrate`, `purchasely-review`, `purchasely-debug`, `purchasely-migrate`, the `purchasely-sdk-expert` agent and `commands/integrate` now document Cordova on v6 (positional `Purchasely.start(...)` with default Observer, `allowDeeplink` / `handleDeeplink`, `setDefaultPresentationDismissHandler`, `synchronize(success, error)`, `presentSubscriptions` no-op) while keeping its method-based JS surface. Cordova is carved out of the "v5 cross-platform" grouping; React Native keeps its v5 guidance.
- **`purchasely-migrate`** now migrates Cordova v5.x → `6.0.0-rc.1` (alongside native iOS & Android and Flutter), with a dedicated Cordova workflow.
- **`scripts/guard-known-bad-snippets.mjs`** — `allowDeeplink` is no longer flagged as a v5 mistake for Cordova (it is the correct v6 deeplink-readiness name).

## [2.0.0-rc.3] — 2026-06-17

Flutter joins the **v6 line**, and skills-only installs gain first-class expert Q&A. Flutter guidance moves off v5 to match native iOS & Android — the published Flutter SDK now targets **Purchasely v6.0.0-rc.1** with the builder API. A new portable `purchasely-sdk-expert` skill brings free-form SDK Q&A to harnesses without the Claude Code subagent. **React Native and Cordova stay on v5 (`5.7.3`).**

### Added

- Added the portable `purchasely-sdk-expert` skill for free-form Purchasely SDK questions. Skills-only installs now get expert Q&A guidance without requiring the Claude Code subagent.

### Changed

- **All skills updated for Flutter v6.** `purchasely-integrate`, `purchasely-review`, `purchasely-debug`, `purchasely-migrate`, and the `purchasely-sdk-expert` agent now document the **Flutter v6 builder API**: `PurchaselyBuilder` fluent init (default `RunningMode.observer`), `PresentationBuilder` / `PresentationRequest` (replacing `fetchPresentation` / `presentPresentation[ForPlacement]`), per-action `Purchasely.interceptAction` + `InterceptResult` (replacing `setPaywallActionInterceptorCallback` + `onProcessAction`), `presentation.close()` to dismiss (there is no `closePresentation()` / `closeAllScreens()` in Flutter v6), `allowDeeplink` / `handleDeeplink`, and awaitable `synchronize()`. Flutter is carved out of the former "v5 cross-platform" grouping; React Native and Cordova keep their v5 guidance.
- **`references/flutter/integration.md` and `references/flutter/migration-v6.md`** rewritten as shippable v6 docs (dropped the "preview / not published / use 5.7.3 today" framing); pin `purchasely_flutter` / `purchasely_google` / `purchasely_android_player` to `6.0.0-rc.1`.
- **`references/sdk-versions.md`** — the Flutter row, pubspec pins, and transitive-version notes move to the v6 generation (`6.0.0-rc.1`, which pulls the `6.0.0-rc.1` native SDKs). React Native / Cordova rows kept on `5.7.3`.
- **`purchasely-migrate`** now migrates Flutter v5.x → `6.0.0-rc.1` (alongside native iOS & Android), with a dedicated Flutter workflow and `flutter analyze` / `flutter test` / `flutter build` verification. React Native and Cordova remain out of scope.
- Concept references (running modes, observer-mode post-purchase, paywall actions, presentation types/cache, promotional offers, campaigns, architecture, troubleshooting) updated so Flutter examples use the v6 API.
- Renamed the Claude Code expert agent from `sdk-expert` to `purchasely-sdk-expert` and made it a wrapper around the portable skill to avoid duplicate guidance.
- README now presents Claude Code as the recommended full-plugin install path and documents `npx skills add` as a skills-only installation that installs five portable skills (`purchasely-sdk-expert`, `purchasely-integrate`, `purchasely-review`, `purchasely-debug`, `purchasely-migrate`) but not the Claude Code subagent, hooks, or slash commands.
- `purchasely-integrate`, `purchasely-review`, `purchasely-debug`, and `purchasely-migrate` now use `purchasely:purchasely-sdk-expert` when the Claude Code subagent is available and fall back to an inline expert checkpoint in skills-only environments.

### Fixed

- Corrected Flutter v6 snippets to use `PresentationType`, pass `Transition.fullScreen()` directly to `display(...)`, and avoid calling `presentation.close()` inside the purchase interceptor before returning `InterceptResult.success`.
- Corrected login action interceptor examples so successful app-owned login returns `.success` / `InterceptResult.success` (or `onProcessAction(false)` on v5 bridges), not `.notHandled`.
- Updated troubleshooting guidance for frozen paywalls to show v6 return-value interceptors alongside v5 bridge callbacks.
- Aligned marketplace and plugin manifest versions to `2.0.0-rc.3`.
- Made the Flutter promotional-offer Observer-mode snippet safe to copy by running app-side billing before `synchronize()` and returning `InterceptResult.failed` when no purchase occurred.

### Removed

- Flutter docs no longer present `Purchasely.presentSubscriptions()` — it is **removed** in Flutter v6 (the native subscriptions screen was dropped on both platforms; build your own from `userSubscriptions()` / `userSubscriptionsHistory()`). `displaySubscriptionCancellationInstruction()` is a no-op.
- Removed the `/purchasely:question` slash command. Free-form Purchasely SDK questions should be asked naturally and routed to `purchasely-sdk-expert` guidance when available.

## [2.0.0-rc.2] — 2026-06-16

### Changed

- **`migrate` skill renamed to `purchasely-migrate`** — for consistency with `purchasely-integrate` / `purchasely-review` / `purchasely-debug` and to disambiguate the skill when installed alongside other repos via the [`skills` CLI](https://www.skills.sh/docs). The slash command keeps its name (`/purchasely:migrate`) since it is already namespaced by the Claude Code plugin prefix. Migration: re-run `npx skills update` (or `npx skills add Purchasely/Purchasely-AI-Plugin` again) to pick up the new name.

### Fixed

- Corrected the native SDK version string to **`6.0.0-rc.1`** (was `6.0.0-rc1`) across every reference, skill, and pinning snippet — the published tag uses the SemVer dot separator, and **iOS and Android are both on `6.0.0-rc.1`**.

## [2.0.0-rc1] — 2026-06-15

First release candidate of the **v6 line**. The plugin now targets the **Purchasely SDK v6.0.0-rc.1** on **native iOS (Swift / Objective-C)** and **native Android (Kotlin / Java)**. Flutter, React Native and Cordova guidance stays on v5 in this RC and will move to v6 for the final `2.0.0`.

### Added

- **`migrate` skill — native v5.x → v6.0.0-rc.1 migration.** A dedicated skill that upgrades an existing Purchasely integration in a single prompt: it leads with the silent default-running-mode change (Observer in v6 — set Full explicitly for purchase handling & validation), covers **Kotlin, Java, Swift and Objective-C**, detects legacy code via the new v5 API snapshots, applies every v5→v6 breaking change (init builder, per-action interceptor, presentation builder/preload/display, deeplink renames, removed APIs), and verifies with the platform build/test commands. **iOS and Android only for now**; Flutter, React Native and Cordova will be added for the final `2.0.0`. Fact-checks uncertain details against the official v6 docs (`docs.purchasely.com` / the `v6.0` branch of `Purchasely/Documentation`).
- `references/ios/v5-api-reference.md` and `references/android/v5-api-reference.md` — compact snapshots of the v5 public API (legacy symbols, signatures, and a `→ v6` pointer for each) so the `migrate` skill can recognize the code it is replacing.
- `references/concepts/lottie-animations.md` — covers Purchasely Screen Lottie setup with the iOS `PLYLottieBridge`, Android `PLYLottieInterface` / `Purchasely.lottieView`, cross-platform host-project notes, and troubleshooting for missing bridges, file size, and Console template availability.

### Changed

- **All skills updated for SDK v6.** `purchasely-integrate`, `purchasely-review`, `purchasely-debug`, the new `migrate` skill, and the `sdk-expert` agent now document the **v6 native API** for iOS & Android. Cross-platform (Flutter / React Native / Cordova) guidance is intentionally kept on v5 until their v6 migrations ship in the final `2.0.0`.
- **Native iOS and Android references fully aligned with the published SDK v6.0.0-rc.1 API.** Reworked `references/ios/*` and `references/android/*` (`api-reference`, `initialization`, `common-patterns`, `migration-v6`) around the fluent init builder, per-action `interceptAction` + `PLYInterceptResult`, the `PLYPresentationBuilder` / `PLYPresentation { }` builder→preload→display model, `PLYPresentationOutcome` (with `closeReason`), `screenId`, SwiftUI `swiftUIView`, `StateFlow<PLYPresentationState>`, Android deeplink auto-interception, `synchronize(onSuccess, onError)`, and the v6 removals — covering Swift, Objective-C, Kotlin and Java.
- `references/concepts/running-modes.md` — documents the v6 default-mode change (Observer) with v6 initialization for iOS (Swift/Obj-C) and Android (Kotlin/Java); cross-platform examples kept on v5.
- `references/concepts/*` — concept references updated to the v6 native API (paywall-actions, observer-mode-post-purchase, presentation-types/-cache, promotional-offers, campaigns, byos, user identity/attributes, subscription-checks); cross-platform sections kept on v5.
- `references/sdk-versions.md` — native iOS bumped to `6.0.0-rc.1`; iOS pinning snippets updated.
- `purchasely-integrate`, `purchasely-review`, and `purchasely-debug` now require a final app build; build failures must be fixed and rechecked before reporting success.

### Fixed

- Removed the non-existent `io.purchasely:presentation-compose` artifact and `PLYPresentationView` composable from the Android docs — `buildView(...)` returns an Android `View`; for Jetpack Compose, wrap it in an `AndroidView`.
- Removed `flowId(...)` / `productId(...)` / `planId(...)` from the Android `PLYPresentation { }` builder examples — they are not exposed in v6; display a Flow via its `app_scheme://ply/flows/FLOW_ID` deeplink.
- Corrected the Observer-mode post-purchase dismissal guidance (`concepts/observer-mode-post-purchase.md`, `android/common-patterns.md`, `architecture-patterns.md`, and the integrate/review/debug skills): in **Observer** mode the SDK does **not** auto-close after a purchase/restore — the implicit `close_all` is appended only in **Full** mode (verified in the iOS/Android SDK source: Android `runningMode == PLYRunningMode.Full`, iOS `appendCloseIfNeeded` `validatesTransactions` guard). Apps must call `Purchasely.closeAllScreens()` after resolving the interceptor (from the async billing-result handler, not inside the interceptor closure), unless a `close` action is configured on the button in the Console. Also hardened the Observer-mode bridge with an orphan-guard + `invokeOnCancellation`.
- `references/concepts/campaigns.md` iOS Swift snippet: corrected `allowCampaigns` from property-assignment syntax (`= false/true`) to the documented method-call form (`allowCampaigns(false/true)`), consistent with the iOS v6 API reference.
- `skills/migrate/SKILL.md` Android step 3: removed `screenId` from the v5-symbol detection list — `screenId` is the v6 target name (step 9 renames `PLYPresentation.id` → `screenId`), not a v5 symbol to replace.

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

[2.0.0-rc.3]: https://github.com/Purchasely/Purchasely-AI-Plugin/releases/tag/2.0.0-rc.3
[2.0.0-rc.2]: https://github.com/Purchasely/Purchasely-AI-Plugin/releases/tag/2.0.0-rc.2
[2.0.0-rc1]: https://github.com/Purchasely/Purchasely-AI-Plugin/releases/tag/2.0.0-rc1
[1.1.0]: https://github.com/Purchasely/Purchasely-AI-Plugin/releases/tag/1.1.0
[1.0.1]: https://github.com/Purchasely/Purchasely-AI-Plugin/releases/tag/1.0.1
[1.0.0]: https://github.com/Purchasely/Purchasely-AI-Plugin/releases/tag/1.0.0
