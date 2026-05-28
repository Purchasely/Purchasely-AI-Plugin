# Universal SDK Concepts

Platform-agnostic concepts and patterns that apply to **every** Purchasely SDK (iOS, Android, React Native, Flutter, Cordova).

These files exist because the SDK contract is the same on every platform — only the syntax changes. Each document includes code samples for all five platforms.

When a topic also has a deeper platform-specific take (e.g. SwiftUI lifecycle, Jetpack Compose embedding, Fragment patterns), the iOS/Android `common-patterns.md` still owns that platform-specific elaboration. The concept docs in this folder are the canonical, language-neutral source.

## Index

| File | Topic |
|------|-------|
| [running-modes.md](running-modes.md) | Full vs Observer modes, log levels |
| [paywall-actions.md](paywall-actions.md) | `PLYPresentationAction` enum + interceptor `proceed/processAction` rules + chaining multiple actions on a single button (purchase + open_screen / open_placement / deeplink) |
| [presentation-types.md](presentation-types.md) | `PLYPresentationType` enum (NORMAL / FALLBACK / DEACTIVATED / CLIENT) guard |
| [byos.md](byos.md) | Bring Your Own Screen — embed native screens (login, custom forms, legacy paywall) inside a Flow; iOS + Android only, SDK ≥ 5.6.0 |
| [lottie-animations.md](lottie-animations.md) | Lottie animations in Purchasely Screens — weak dependency bridge for iOS / Android native rendering |
| [presentation-cache.md](presentation-cache.md) | App-side caching + preload pattern (avoid `FlowsManager.flowSteps` accumulation) |
| [observer-mode-post-purchase.md](observer-mode-post-purchase.md) | `proceed → dismiss` ordering, native vs bridge close APIs, chaining follow-up placements |
| [user-attributes-targeting.md](user-attributes-targeting.md) | Setting user attributes for audience targeting + GDPR consent |
| [privacy-settings.md](privacy-settings.md) | `revokeDataProcessingConsent`, privacy purposes, essential vs optional processing |
| [user-identity.md](user-identity.md) | `userLogin` / `userLogout` timing, anonymous→logged-in merge, foreground resync |
| [programmatic-purchases.md](programmatic-purchases.md) | Exact app-side purchase APIs by platform |
| [subscription-checks.md](subscription-checks.md) | Gating content via `userSubscriptions`, restoring purchases (with Purchasely-paywall caveat) |
| [subscription-management.md](subscription-management.md) | Opening the native Manage Subscription page (App Store / Play Store) |
| [promotional-offers.md](promotional-offers.md) | Offer types, Apple promo offers, Google developer-determined offers, offer codes, win-back |
| [campaigns.md](campaigns.md) | No-code Console automations (trigger / placement-based), `readyToOpenDeeplink`, SDK ≥ 5.1.0 |
| [analytics-integration.md](analytics-integration.md) | Forwarding UI events to Firebase / Amplitude / AppsFlyer + analytics wrapper pattern |

## When to load

| Task | Load |
|------|------|
| Integrating from scratch | `running-modes.md`, `paywall-actions.md`, `presentation-types.md`, `user-identity.md` |
| Adding Observer mode | `observer-mode-post-purchase.md`, `paywall-actions.md` |
| Adding audience targeting / privacy consent | `user-attributes-targeting.md`, `privacy-settings.md` |
| Adding app-side purchase buttons | `programmatic-purchases.md`, `subscription-checks.md` |
| Adding subscription gating | `subscription-checks.md`, `subscription-management.md` |
| Adding retention / win-back paywalls | `promotional-offers.md`, `campaigns.md` |
| Adding scheduled or event-driven paywalls | `campaigns.md` |
| Wiring analytics / tracking | `analytics-integration.md`, `user-identity.md` |
| Improving paywall perceived performance | `presentation-cache.md` (preload pattern) |
| Debugging stuck paywalls / blank presentations | `presentation-types.md`, `presentation-cache.md`, `paywall-actions.md` |
| Embedding a native login / custom form / legacy paywall inside a Flow | `byos.md` (iOS + Android, SDK ≥ 5.6.0) |
| Adding or debugging Lottie animations in Purchasely Screens | `lottie-animations.md` (iOS / Android native bridge; cross-platform apps configure host projects) |
| Configuring multi-step buttons (purchase + next step, purchase + placement) | `paywall-actions.md` § Chaining multiple actions |
| Reviewing an existing integration | all of the above |
