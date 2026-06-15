# iOS SDK v5.x → v6.0.0 Migration

This guide is iOS-only (Swift / SwiftUI / UIKit). Android, React Native, Flutter, and Cordova have their own migration notes — do not apply this one to them.

Version 6.0.0 introduces a fluent initialization builder, a granular per-action interceptor API, clearer naming, and a consolidated paywall display surface built around `PLYPresentationBuilder`. `PLYPresentation` becomes a protocol (most call sites compile unchanged). For the full v6 API surface see [`api-reference.md`](api-reference.md); for the legacy symbols this guide replaces see [`v5-api-reference.md`](v5-api-reference.md).

## Summary of breaking changes

| v5 | v6 |
|----|----|
| Default running mode `.full` | Default running mode **`.observer`** ⚠️ |
| `Purchasely.start(withAPIKey:…)` | `Purchasely.apiKey(…)…start()` (fluent builder) |
| `setPaywallActionsInterceptor { … }` | `Purchasely.interceptAction(.x) { … }` returning `PLYInterceptResult` |
| `PLYPresentationInfo` | `PLYInterceptorInfo` |
| `Purchasely.fetchPresentation(...)` | `PLYPresentationBuilder.…build().preload { … }` |
| `Purchasely.display(for:displayMode:)` | `Purchasely.display(for:transition:)` |
| `Purchasely.closeDisplayedPresentation()` | `Purchasely.closeAllScreens()` |
| `controller.PresentationView` | `presentation.swiftUIView` (SwiftUI) / `presentation.controller` (UIKit) |
| `readyToOpenDeeplink(_:)` | `allowDeeplink(_:)` |
| `isDeeplinkHandled(deeplink:)` | `handleDeeplink(_:)` |
| `PLYProductViewControllerResult` | `PLYPresentationOutcome` |
| Objective-C `PLYPresentation *` | `id<PLYPresentation>` |

## Dependency

Bump the Purchasely iOS package to `6.0.0`.

**Swift Package Manager** — in `Package.swift` or the Xcode package list:

```swift
.package(url: "https://github.com/Purchasely/Purchasely-iOS", from: "6.0.0")
```

**CocoaPods** — in the `Podfile`:

```ruby
pod 'Purchasely', '~> 6.0'
```

After bumping, resolve packages (`File ▸ Packages ▸ Resolve Package Versions`, or `pod install`) and clean the build folder before the first compile.

### Swift 6 strict concurrency

The v6 SDK is annotated for Swift Concurrency. Import it with `@preconcurrency` at call sites that touch SDK types from a `@MainActor` context:

```swift
@preconcurrency import Purchasely
```

`XCTestCase` is non-`Sendable` and predates async/await, so `complete` strict-concurrency checking flags every `try await super.setUp()` in test targets. Keep production code on `complete` and relax the **test target** to `SWIFT_STRICT_CONCURRENCY = minimal`.

## 1. Initialization — fluent builder

The v5 one-shot `Purchasely.start(withAPIKey:appUserId:runningMode:storekitSettings:logLevel:initialized:)` is **removed**. Start with `Purchasely.apiKey(_:)`, chain modifiers, finish with `start()`. The completion now receives a single optional `Error` (no `Bool` first parameter).

> ⚠️ **The default running mode changed from `.full` (v5) to `.observer` (v6).** This is silent — your code compiles, but if you relied on the implicit `.full` default the SDK **stops validating transactions**. Add `.runningMode(.full)` explicitly for purchase handling/validation. In Observer mode, presentations also no longer auto-close after purchase/restore.

### Before (v5)

```swift
Purchasely.start(withAPIKey: "YOUR_API_KEY",
                 appUserId: "user_123",
                 runningMode: .full,
                 logLevel: .debug) { success, error in
    // SDK initialized
}
```

### After (v6) — Swift async (recommended)

```swift
do {
    try await Purchasely
        .apiKey("YOUR_API_KEY")
        .appUserId("user_123")
        .runningMode(.full)         // ← required for purchase handling & validation
        .storekitSettings(.storeKit2)
        .logLevel(.debug)
        .start()
} catch {
    // PLYError.configuration if the apiKey is empty, or any other error
}

Purchasely.setEventDelegate(self)   // delegates are set separately after start
```

### After (v6) — completion handler (Objective-C-compatible)

```swift
Purchasely
    .apiKey("YOUR_API_KEY")
    .runningMode(.full)
    .start { error in
        // error is nil on success; callback dispatches on the main actor
    }
```

```objc
// Objective-C
[[[[Purchasely apiKey:@"YOUR_API_KEY"]
    appUserId:@"user_123"]
    runningMode:PLYRunningModeFull]
    startWithInitialized:^(NSError * _Nullable error) {
        // error is nil on success
    }];
```

Other initialization changes:
- `PLYRunningMode.paywallObserver` → `PLYRunningMode.observer` (Objective-C: `PLYRunningModePaywallObserver` → `PLYRunningModeObserver`).
- `readyToOpenDeeplink(true)` → `Purchasely.allowDeeplink(true)`.
- Delegates are set after `start`: `Purchasely.setEventDelegate(_:)`, `Purchasely.setUserAttributeDelegate(_:)`.
- The pre-`start` `set*` class funcs (`setEnvironment`, `setThemeMode`, `setShowPromotedInAppPurchasePaywall`, `setAppTechnology`, `setSdkBridgeVersion`) are deprecated — use chain modifiers (`.environment(_:)`, `.themeMode(_:)`, …).

See [`initialization.md`](initialization.md) for the full chain-modifier defaults table.

## 2. Action Interceptor — per-action API

The global `Purchasely.setPaywallActionsInterceptor { action, parameters, info, proceed in }` is **removed**. Register one interceptor per action; each closure is `async` and **returns** a `PLYInterceptResult` instead of calling `proceed(_:)`.

### Before (v5)

```swift
Purchasely.setPaywallActionsInterceptor { action, params, info, proceed in
    switch action {
    case .login:    showLogin { loggedIn in proceed(loggedIn) }
    case .purchase: customPurchase(params?.plan) { success in proceed(!success) }
    default:        proceed(true)
    }
}
```

### After (v6) — async (recommended)

```swift
Purchasely.removeAllActionInterceptors()   // optional: clear any prior registration

Purchasely.interceptAction(.login) { info, params in
    let loggedIn = await showLoginScreen()
    return loggedIn ? .notHandled : .success
}

Purchasely.interceptAction(.navigate) { info, params in
    if let url = params?.url {
        await MainActor.run { UIApplication.shared.open(url) }
    }
    return .success
}

Purchasely.interceptAction(.purchase) { [weak self] info, params in
    guard let self else { return .notHandled }
    return await self.handlePurchase(params: params)
}
```

### After (v6) — completion handler

```swift
Purchasely.interceptAction(.login) { info, params, completion in
    showLoginScreen { loggedIn in
        completion(loggedIn ? .notHandled : .success)
    }
}
```

### `proceed(_:)` → `PLYInterceptResult` mapping

| `PLYInterceptResult` | Meaning | Legacy equivalent | SDK behavior |
|----------------------|---------|-------------------|--------------|
| `.success` | App handled the action successfully | `proceed(false)` | Chain advances to next action |
| `.failed` | App tried but failed | (new) | Remaining actions are skipped |
| `.notHandled` | App doesn't want to handle this | `proceed(true)` | SDK executes the action itself |

> The mapping reads backwards from intuition: `proceed(true)` = "let the SDK continue" → `.notHandled`; `proceed(false)` = "the app handled it" → `.success`. `.notHandled` for `.purchase` / `.restore` in Observer mode logs a warning and skips.

Action data still comes from `PLYPresentationActionParameters`:
- Purchase product id: `params?.plan?.appleProductId`.
- Promotional offer: `params?.promoOffer?.storeOfferId`.
- Navigation URL: `params?.url`.

Remove interceptors with `Purchasely.removeActionInterceptor(.login)` / `Purchasely.removeAllActionInterceptors()`. The `paywallActionsInterceptor:` start parameter and the `PLYPaywallActionsInterceptor` typealias no longer exist.

### `PLYPresentationInfo` → `PLYInterceptorInfo`

`PLYPresentationInfo` is removed; the interceptor's first argument is a `PLYInterceptorInfo`:

| `PLYPresentationInfo` (removed) | `PLYInterceptorInfo` (new) |
|---------------------------------|----------------------------|
| `info.presentationId` | `info.presentation?.id` |
| `info.placementId` | `info.presentation?.placementId` |
| `info.audienceId` | `info.presentation?.audienceId` |
| `info.abTestId` / `info.abTestVariantId` | `info.presentation?.abTestId` / `…abTestVariantId` |
| `info.campaignId` | `info.presentation?.campaignId` |
| `info.contentId` / `info.controller` | `info.contentId` / `info.controller` (unchanged) |

### Observer-mode bridge (iOS is simpler than Android)

On Android the v6 interceptor is a `suspend` function and Observer mode needs a `suspendCancellableCoroutine` bridge. **On iOS the interceptor closure is already `async`**, so just `await` the native StoreKit flow and return its result directly — no coroutine bridge:

```swift
@MainActor
func handlePurchase(params: PLYPresentationActionParameters?) async -> PLYInterceptResult {
    guard let productId = params?.plan?.appleProductId else { return .notHandled }
    let result = await PurchaseManager.shared.purchase(productId: productId)
    switch result {
    case .success:   try? await synchronizeReceipt(); return .success
    case .cancelled: return .notHandled    // user backed out — not an error
    case .error:     return .failed
    }
}
```

Return `.notHandled` in Full mode so the SDK runs its own purchase/restore flow.

## 3. Presentation API — `PLYPresentationBuilder`

`Purchasely.fetchPresentation(for:contentId:fetchCompletion:completion:)` and the UIViewController-returning methods (`presentationController(...)`) are **removed**. Build a request with `PLYPresentationBuilder`, then `preload` and/or `display`.

### Before (v5)

```swift
Purchasely.fetchPresentation(for: "onboarding") { presentation, error in
    presentation?.display(from: self)
} completion: { result, plan in
    // result: .purchased / .restored / .cancelled
}
```

### After (v6)

```swift
do {
    let presentation = try await PLYPresentationBuilder
        .forPlacementId("onboarding")
        .build()
        .preload()
    presentation.display(from: self)   // flows: presentation.display() — see isFlow
} catch {
    // handle error
}
```

Legacy callbacks map to builder hooks (replace v5 `onClose` thinking with `onPresented` / `onDismissed`):

| Legacy v5 callback | Fires when | Builder hook |
|--------------------|------------|--------------|
| `fetchCompletion:` | The presentation was fetched | `.preload { presentation, error in … }` |
| `loadedCompletion:` | The paywall is on screen | `.onPresented { presentation, error in … }` |
| `completion:` | The paywall was dismissed | `.onDismissed { outcome in … }` |

```swift
PLYPresentationBuilder.from(placementId: "onboarding")
    .contentId(contentId)
    .backgroundColor(.systemBackground)
    .onPresented { presentation, error in /* paywall is on screen */ }
    .onDismissed { outcome in handle(outcome) }
    .build()
    .display(completion: nil)
```

From Objective-C, use the factories `forPlacementId:` / `forScreenId:`. `displayCloseButton(_:)` / `displayBackButton(_:)` are **suppression-only** on iOS (passing `false` hides a backend-shown button; `true` does not force a hidden one to appear) and are build-time only — set them before `build()`.

### `Purchasely.display(...)` — `displayMode:` → `transition:`

The four `display(...)` overloads are replaced by two one-line conveniences, and the parameter is renamed `displayMode:` → **`transition:`**:

```swift
// Fire-and-forget (Swift + Objective-C)
Purchasely.display(for: placementId, transition: nil)     // backend-defined display mode
Purchasely.display(for: placementId, transition: .modal)  // override

// Async/await (Swift only)
let presentation = try await Purchasely.display(for: placementId, transition: .modal)
```

### `PLYDisplayMode` sizing (new) + `PLYDimension` public

`PLYDisplayMode` exposes new sizing for drawer / popin; `PLYDimension` is now public (`.value(Int)` in points, `.percentage(Double)`):

```swift
let drawer  = PLYDisplayMode.drawer(height: .value(400))
let popin   = PLYDisplayMode.popin(width: .percentage(0.9), height: .value(500))
let blocked = PLYDisplayMode.modal(dismissible: false)   // block ambient dismiss
```

When `dismissible` is `false`, ambient dismiss (background tap, swipe-down, iPad form-sheet tap-outside) is blocked; the close button and programmatic dismiss still work.

### Result type — `PLYPresentationOutcome`

The v5 dismissal tuple `(PLYProductViewControllerResult, PLYPlan?)` becomes a single **`PLYPresentationOutcome`** with a new `closeReason`:

```swift
.onDismissed { outcome in
    switch outcome.purchaseResult {        // .purchased / .restored / .cancelled / .none
    case .purchased: unlock(planName: outcome.plan?.name)
    case .restored:  unlock(planName: outcome.plan?.name)
    default:         break
    }
    switch outcome.closeReason {           // .button / .interactiveDismiss / .programmatic / .none
    case .button:             break
    case .interactiveDismiss: break
    case .programmatic:       break
    case .none:               break
    @unknown default:         break
    }
    // outcome.presentation: PLYPresentation?  |  outcome.error: Error? (reserved, nil in 6.0)
}
```

## 4. `PLYPresentation` is now a protocol

`PLYPresentation` changed from a class to a public `@objc protocol`. **Reading members and calling methods works unchanged** — every property (`id`, `placementId`, `plans`, `metadata`, `isFlow`, …) and method (`display(from:)`, `close()`, `back()`, …) resolves identically. Swift may write `any PLYPresentation`.

## 5. SwiftUI — `swiftUIView` (UIKit keeps `controller`)

The PascalCase `controller.PresentationView` bridge is **removed**. For SwiftUI, read `swiftUIView` off the preloaded presentation:

```swift
PLYPresentationBuilder
    .forScreenId(id)
    .build()
    .preload { presentation, error in
        if let view = presentation?.swiftUIView {   // SwiftUI View; nil for .deactivated
            self.paywallView = view
        }
    }
```

`swiftUIView` is named to disambiguate from `UIKit.UIView`. **UIKit consumers continue to use `presentation.controller`** (a `UIViewController`), wrapped in `UIViewControllerRepresentable` only when SwiftUI must own the container:

```swift
private struct EmbeddedPresentationController: UIViewControllerRepresentable {
    let controller: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { controller }
    func updateUIViewController(_ vc: UIViewController, context: Context) {}
}
```

## 6. Closing presentations — `closeDisplayedPresentation()` → `closeAllScreens()`

`Purchasely.closeDisplayedPresentation()` is **removed** — use `Purchasely.closeAllScreens()`, which handles every display path (full-screen, modal, flows):

```swift
Purchasely.closeAllScreens()   // was Purchasely.closeDisplayedPresentation()
```

It is `@MainActor`-isolated. From a non-isolated context wrap it: `Task { @MainActor in Purchasely.closeAllScreens() }`.

## 7. Deeplinks (deprecated renames)

The old methods still compile but are deprecated (removal in v7):

| v5 (deprecated) | v6 |
|-----------------|----|
| `Purchasely.readyToOpenDeeplink(_:)` | `Purchasely.allowDeeplink(_:)` |
| `Purchasely.isDeeplinkHandled(deeplink:)` | `Purchasely.handleDeeplink(_:)` (still returns `Bool`) |

```swift
let handled = Purchasely.handleDeeplink(url)
```

In v6, deeplinks display **immediately** by default. Call `Purchasely.allowDeeplink(false)` to defer (e.g. during onboarding) and `allowDeeplink(true)` when ready. Hand a cold-start deeplink at init: `Purchasely.apiKey("…").handleDeeplink(url).start { error in }`. Unlike Android, iOS does **not** auto-intercept — keep passing deeplinks via `Purchasely.handleDeeplink(_:)` from your `AppDelegate` / `SceneDelegate`.

## 8. Objective-C migration

| v5 (Objective-C) | v6 (Objective-C) |
|------------------|------------------|
| `[Purchasely startWithAPIKey:…]` | `[[[[Purchasely apiKey:…] appUserId:…] runningMode:PLYRunningModeFull] startWithInitialized:^(NSError *e){}]` |
| `PLYRunningModePaywallObserver` | `PLYRunningModeObserver` |
| `PLYPresentation *presentation` | `id<PLYPresentation> presentation` |
| `PLYPresentationInfo *info` | `PLYInterceptorInfo *info` |
| `setPaywallActionsInterceptor:` | `[Purchasely interceptAction:PLYPresentationActionPurchase handler:^(…){ completion(PLYInterceptResultSuccess); }]` |
| `[PLYProductViewController …]` result | `PLYPresentationOutcome *outcome` (`.purchaseResult`, `.plan`, `.presentation`, `.closeReason`, `.error`) |
| `[Purchasely closeDisplayedPresentation]` | `[Purchasely closeAllScreens]` |
| `fetchPresentationFor:…` | `[PLYPresentationBuilder forPlacementId:@"…"]` / `forScreenId:` then `build` + `preloadWithCompletion:` |
| `displayFor:displayMode:` | `[[[PLYPresentationBuilder forPlacementId:@"…"] build] displayWithCompletion:nil]` (or `displayWithTransition:completion:`) |

```objc
// v6 builder from Objective-C
PLYPresentationBuilder *builder = [PLYPresentationBuilder forPlacementId:@"ONBOARDING"];
[[builder contentId:@"content_123"]
    onDismissed:^(PLYPresentationOutcome *outcome) { /* outcome.purchaseResult … */ }];
[[builder build] preloadWithCompletion:^(id<PLYPresentation> presentation, NSError *error) {
    [presentation displayFrom:self];
}];
```

## Unchanged APIs (no migration needed)

These v5 signatures are identical in v6 — leave them alone:
- `Purchasely.userLogin(with:shouldRefresh:)` / `Purchasely.userLogout()`.
- `Purchasely.setUserAttribute(withStringValue:/withBoolValue:/withIntValue:/withDoubleValue:/withDateValue:forKey:)`, `incrementUserAttribute(withKey:)`.
- `Purchasely.userSubscriptions(success:failure:)`, `restoreAllProducts(success:failure:)`.
- `Purchasely.synchronize(success:failure:)`.
- `Purchasely.signPromotionalOffer(storeProductId:storeOfferId:success:failure:)`.
- `Purchasely.revokeDataProcessingConsent(for:)`.

## Migration checklist

### Breaking (must fix to compile)

- [ ] Replace `Purchasely.start(withAPIKey:…)` with the fluent chain `Purchasely.apiKey("…")…start()`
- [ ] If using Full mode, add explicit `.runningMode(.full)` — default changed to `.observer`
- [ ] Update the completion to a single `Error?` (drop the `Bool success` parameter)
- [ ] Replace `setPaywallActionsInterceptor { … }` with per-action `Purchasely.interceptAction(.x) { … }`
- [ ] Map `proceed(false)` → `.success`, `proceed(true)` → `.notHandled`; use `.failed` for failures
- [ ] Replace `PLYPresentationInfo` with `PLYInterceptorInfo` (`info.presentationId` → `info.presentation?.id`, etc.)
- [ ] Remove the `paywallActionsInterceptor:` start parameter and any `PLYPaywallActionsInterceptor` typealias
- [ ] Replace `Purchasely.fetchPresentation(...)` / `presentationController(...)` with `PLYPresentationBuilder.…build().preload { … }`
- [ ] Replace `controller.PresentationView` with `presentation.swiftUIView` (SwiftUI) / `presentation.controller` (UIKit)
- [ ] Replace `Purchasely.closeDisplayedPresentation()` with `Purchasely.closeAllScreens()`
- [ ] Update `Purchasely.display(for:displayMode:)` to `Purchasely.display(for:transition:)`
- [ ] Replace the `(PLYProductViewControllerResult, PLYPlan?)` tuple with `PLYPresentationOutcome` (`purchaseResult` / `plan` / `closeReason`)
- [ ] In Objective-C, change `PLYPresentation *` to `id<PLYPresentation>` and `PLYRunningModePaywallObserver` to `PLYRunningModeObserver`

### Deprecated (fix before v7)

- [ ] Migrate the pre-`start` `set*` class funcs to chain modifiers
- [ ] Replace `readyToOpenDeeplink(_:)` with `allowDeeplink(_:)` and `isDeeplinkHandled(deeplink:)` with `handleDeeplink(_:)`
- [ ] Build and verify no deprecation warnings remain

### Verify

Search must return no v5-only API usages in app source/tests:

```bash
rg "paywallObserver|readyToOpenDeeplink|isDeeplinkHandled|setPaywallActionsInterceptor|fetchPresentation|presentationController|PresentationView|PLYProductViewControllerResult|PLYPresentationInfo|closeDisplayedPresentation|start\(withAPIKey" Sources
```

> An app may keep a wrapper method *named* `isDeeplinkHandled` that internally calls `Purchasely.handleDeeplink` — that is fine; only the `Purchasely.isDeeplinkHandled(...)` SDK call must be gone.
