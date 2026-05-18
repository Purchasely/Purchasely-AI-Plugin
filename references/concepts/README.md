# Universal SDK Concepts

Platform-agnostic concepts and patterns that apply to **every** Purchasely SDK (iOS, Android, React Native, Flutter, Cordova).

These files exist because the SDK contract is the same on every platform — only the syntax changes. Each document includes code samples for all five platforms.

When a topic also has a deeper platform-specific take (e.g. SwiftUI lifecycle, Jetpack Compose embedding, Fragment patterns), the iOS/Android `common-patterns.md` still owns that platform-specific elaboration. The concept docs in this folder are the canonical, language-neutral source.

## Index

| File | Topic |
|------|-------|
| [running-modes.md](running-modes.md) | Full vs Observer modes, log levels |
| [paywall-actions.md](paywall-actions.md) | `PLYPresentationAction` enum + interceptor `proceed/processAction` rules |
| [presentation-types.md](presentation-types.md) | `PLYPresentationType` enum (NORMAL / FALLBACK / DEACTIVATED / CLIENT) guard |
| [presentation-cache.md](presentation-cache.md) | App-side caching to avoid `FlowsManager.flowSteps` accumulation |
| [observer-mode-post-purchase.md](observer-mode-post-purchase.md) | `proceed → closeAllScreens` ordering, chaining follow-up placements |
| [user-attributes-targeting.md](user-attributes-targeting.md) | Setting user attributes for audience targeting + GDPR consent |
| [subscription-checks.md](subscription-checks.md) | Gating content via `userSubscriptions`, restoring purchases |

## When to load

| Task | Load |
|------|------|
| Integrating from scratch | `running-modes.md`, `paywall-actions.md`, `presentation-types.md` |
| Adding Observer mode | `observer-mode-post-purchase.md`, `paywall-actions.md` |
| Adding audience targeting | `user-attributes-targeting.md` |
| Adding subscription gating | `subscription-checks.md` |
| Debugging stuck paywalls / blank presentations | `presentation-types.md`, `presentation-cache.md`, `paywall-actions.md` |
| Reviewing an existing integration | all of the above |
