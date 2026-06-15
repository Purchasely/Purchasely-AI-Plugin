# iOS API Reference

> Documents the **v6.0.0** public surface (Swift + Objective-C). Migrating from v5? See [`migration-v6.md`](migration-v6.md) and the legacy [`v5-api-reference.md`](v5-api-reference.md). Universal concepts (running modes, log levels, presentation types) also live in [`../concepts/`](../concepts/README.md).

## Initialization — fluent builder

The v5 one-shot `Purchasely.start(withAPIKey:appUserId:runningMode:storekitSettings:logLevel:initialized:)` is **removed**. Start with `Purchasely.apiKey(_:)`, chain modifiers, finish with `start()`.

> ⚠️ **The default running mode changed from `.full` (v5) to `.observer` (v6).** This is silent — your code compiles, but the SDK no longer validates purchases. **If the app relies on Purchasely to process / validate purchases, set `.runningMode(.full)` explicitly.** In Observer mode, presentations also no longer auto-close after purchase/restore.

### Swift — async (recommended)

```swift
do {
    try await Purchasely
        .apiKey("YOUR_API_KEY")
        .appUserId("user_123")          // optional, nil for anonymous
        .runningMode(.full)             // ← REQUIRED for purchase handling & validation; default is .observer
        .storekitSettings(.storeKit2)   // .storeKit1 or .storeKit2
        .logLevel(.debug)
        .start()
} catch {
    // PLYError.configuration if the apiKey is empty, or any other error
}
```

### Swift — completion handler (Objective-C-compatible)

```swift
Purchasely
    .apiKey("YOUR_API_KEY")
    .runningMode(.full)
    .start { error in
        // error is nil on success; callback dispatches on the main actor
    }
```

### Objective-C

```objc
[[[[Purchasely apiKey:@"YOUR_API_KEY"]
    appUserId:@"user_123"]
    runningMode:PLYRunningModeFull]
    startWithInitialized:^(NSError * _Nullable error) {
        // error is nil on success
    }];
```

### Chain modifiers and defaults

| Modifier | Default |
|----------|---------|
| `appUserId(_:)` | `nil` (anonymous) |
| `runningMode(_:)` | `.observer` ⚠️ (was `.full` in v5) |
| `storekitSettings(_:)` | `.storeKit2` |
| `logLevel(_:)` | `.error` |
| `environment(_:)` | `.prod` |
| `themeMode(_:)` | `.system` |
| `allowDeeplink(_:)` | `true` — deeplinks display immediately; pass `false` to defer until `Purchasely.allowDeeplink(true)` |
| `allowCampaigns(_:)` | `true` — campaigns display immediately; pass `false` to defer until `Purchasely.allowCampaigns(true)` |
| `handleDeeplink(_:)` | unset — pass a cold-start deeplink to display once the SDK has started |

> 📘 The pre-`start` class funcs `setEnvironment(_:)`, `setShowPromotedInAppPurchasePaywall(_:)`, `setAppTechnology(_:)`, `setSdkBridgeVersion(_:)`, `setThemeMode(_:)` are **deprecated** (removal in v7). Use the chain modifiers instead.

### `PLYRunningMode`

| Mode | Swift | Objective-C | Description |
|------|-------|-------------|-------------|
| **Full** | `.full` | `PLYRunningModeFull` | Purchasely handles and validates the entire purchase flow |
| **Observer** | `.observer` | `PLYRunningModeObserver` | Your app handles purchases; Purchasely observes for analytics and paywall display |

## Action Interceptor — per-action API

The global `Purchasely.setPaywallActionsInterceptor { … }` is **removed**. Register one interceptor per action; each closure receives a `PLYInterceptorInfo` plus the action parameters and returns an explicit `PLYInterceptResult`.

### `Purchasely.interceptAction(_:completion:)`

```swift
// Swift — async form (recommended)
Purchasely.interceptAction(.login) { info, params in
    let loggedIn = await showLoginScreen()
    return loggedIn ? .notHandled : .success
}

// Swift — completion-handler form (also usable from Objective-C)
Purchasely.interceptAction(.purchase) { info, params, completion in
    customPurchase(params?.plan) { success in
        completion(success ? .success : .failed)
    }
}
```

```objc
// Objective-C
[Purchasely interceptAction:PLYPresentationActionPurchase
                    handler:^(PLYInterceptorInfo *info,
                              PLYPresentationActionParameters *params,
                              void (^completion)(enum PLYInterceptResult)) {
    completion(PLYInterceptResultSuccess);
}];
```

Remove interceptors with `Purchasely.removeActionInterceptor(.login)` / `Purchasely.removeAllActionInterceptors()`.

> The `paywallActionsInterceptor:` start parameter and the `PLYPaywallActionsInterceptor` typealias no longer exist.

### `PLYInterceptResult`

| Swift | Objective-C | Meaning | SDK behavior |
|-------|-------------|---------|--------------|
| `.success` | `PLYInterceptResultSuccess` | App handled the action successfully | Chain advances to next action |
| `.failed` | `PLYInterceptResultFailed` | App tried but failed | Remaining actions from this interaction are skipped |
| `.notHandled` | `PLYInterceptResultNotHandled` | App doesn't want to handle this | SDK executes the action itself |

Legacy mapping: `processAction(false)` → `.success`, `processAction(true)` → `.notHandled`.

> 📘 `.notHandled` for `.purchase` / `.restore` in Observer mode logs a warning and skips — the SDK cannot execute purchases in Observer mode.

### `PLYInterceptorInfo` (replaces `PLYPresentationInfo`)

The interceptor's first argument is a `PLYInterceptorInfo`:

| `PLYInterceptorInfo` field | Notes |
|----------------------------|-------|
| `info.presentation?.id` | (was `info.presentationId`) |
| `info.presentation?.placementId` | (was `info.placementId`) |
| `info.presentation?.audienceId` | (was `info.audienceId`) |
| `info.presentation?.abTestId` / `…abTestVariantId` | A/B test identifiers |
| `info.presentation?.campaignId` | Campaign identifier |
| `info.contentId` | Unchanged |
| `info.controller` | Unchanged |

Objective-C type: `PLYInterceptorInfo *`.

## Paywall Presentation — `PLYPresentationBuilder`

The `Purchasely.fetchPresentation(...)` family and the `UIViewController`-returning methods are **removed**. Build a request with `PLYPresentationBuilder`, then `preload` and/or `display`.

### Factories

| Factory | Use |
|---------|-----|
| `PLYPresentationBuilder.forPlacementId(_:)` | Display by placement (the usual case). Also the Objective-C entry point `forPlacementId:` |
| `PLYPresentationBuilder.from(placementId:)` | Same, labelled form |
| `PLYPresentationBuilder.forScreenId(_:)` | Display a specific Screen directly. Objective-C entry point `forScreenId:` |

### Preload then display

```swift
do {
    let presentation = try await PLYPresentationBuilder
        .forPlacementId("ONBOARDING")
        .contentId("content_123")       // optional content ID for targeting
        .build()
        .preload()
    presentation.display(from: self)
} catch {
    // handle error
}
```

### Builder hooks (map of the legacy callbacks)

| Legacy v5 callback | Fires when | Builder hook |
|--------------------|------------|--------------|
| `fetchCompletion:` | The presentation was fetched | `.preload { presentation, error in … }` |
| `loadedCompletion:` | The paywall is on screen | `.onPresented { presentation, error in … }` |
| `completion:` | The paywall was dismissed | `.onDismissed { outcome in … }` |

```swift
PLYPresentationBuilder.from(placementId: "ONBOARDING")
    .backgroundColor(.systemBackground)            // optional color override
    .onPresented { presentation, error in /* paywall is on screen */ }
    .onDismissed { outcome in /* user closed; outcome carries the purchase result */ }
    .build()
    .display(completion: nil)
```

From Objective-C, use the factories `forPlacementId:` / `forScreenId:`:

```objc
PLYPresentationBuilder *builder = [PLYPresentationBuilder forPlacementId:@"ONBOARDING"];
[[builder contentId:@"content_123"]
    onDismissed:^(PLYPresentationOutcome *outcome) { /* … */ }];
[[builder build] preloadWithCompletion:^(id<PLYPresentation> presentation, NSError *error) {
    [presentation displayFrom:self];
}];
```

> 📘 `displayCloseButton(_:)` / `displayBackButton(_:)` are **suppression-only** on iOS: passing `false` hides a button the backend would show; passing `true` does **not** force a backend-hidden button to appear. Set them at build time, before `build()`.

### `PLYPresentationRequest` (builder return type)

`PLYPresentationBuilder.build()` returns a `PLYPresentationRequest` exposing:

- `preload()` (async) / `preload { presentation, error in }` — fetch the presentation
- `display(transition:completion:)` — fire-and-forget with an explicit transition
- `display(completion:)` — fire-and-forget with the backend-defined transition

### `Purchasely.display(for:transition:)` — one-line convenience

The four v5 `display(...)` overloads are replaced by two conveniences. The parameter is renamed from `displayMode:` to **`transition:`**:

```swift
// Fire-and-forget (Swift + Objective-C)
Purchasely.display(for: placementId, transition: nil)     // backend-defined display mode
Purchasely.display(for: placementId, transition: .modal)  // override

// Async/await (Swift only)
let presentation = try await Purchasely.display(for: placementId, transition: .modal)
```

```objc
// Objective-C — go through the builder (confirmed selectors)
[[[PLYPresentationBuilder forPlacementId:@"PLACEMENT_ID"] build] displayWithCompletion:nil];
```

For a direct Screen, a completion, or richer configuration, use `PLYPresentationBuilder.forScreenId(...)` / `forPlacementId:` directly. The builder exposes the confirmed Objective-C selectors `preloadWithCompletion:`, `displayWithCompletion:`, `displayWithTransition:completion:`, and the loaded presentation `displayFrom:` / `displayFrom:transitionType:`.

### `PLYPresentation.display(from:)` and `isFlow`

A preloaded presentation displays itself. Flows do not need a source view controller:

```swift
if presentation.isFlow {
    presentation.display()            // flows manage their own presentation
} else {
    presentation.display(from: self)  // regular presentations need a source VC
}
```

### Display mode & sizing — `PLYDisplayMode` / `PLYDimension`

`PLYDisplayMode` exposes sizing for drawer / popin; `PLYDimension` is public (`.value(Int)` in points or `.percentage(Double)`):

```swift
let drawer  = PLYDisplayMode.drawer(height: .value(400))                  // 400 pt tall
let popin   = PLYDisplayMode.popin(width: .percentage(0.9), height: .value(500))
let blocked = PLYDisplayMode.modal(dismissible: false)                    // block ambient dismiss
```

When `dismissible` is `false`, ambient dismiss (background tap, swipe-down, iPad form-sheet tap-outside) is blocked; the close button and programmatic dismiss still work.

### `PLYPresentationOutcome` — the dismissal result

`onDismissed` (and the async display result) delivers a `PLYPresentationOutcome`, replacing the v5 `(PLYProductViewControllerResult, PLYPlan?)` tuple:

| Field | Type | Meaning |
|-------|------|---------|
| `purchaseResult` | `PLYPurchaseResult` | `.purchased` / `.cancelled` / `.restored` / `.none` |
| `plan` | `PLYPlan?` | The purchased plan, when applicable |
| `presentation` | `PLYPresentation?` | The presentation that produced this outcome |
| `closeReason` | `PLYCloseReason` | **New** — why the paywall closed |
| `error` | `Error?` | Reserved (always `nil` in 6.0) |

```swift
.onDismissed { outcome in
    switch outcome.closeReason {
    case .button:             /* user tapped close/back */ break
    case .interactiveDismiss: /* swiped down or popped */  break
    case .programmatic:       /* app called close */       break
    case .none:               /* purchased/restored, or not applicable */ break
    @unknown default: break
    }
    if outcome.purchaseResult == .purchased { /* unlock content */ }
}
```

Objective-C reads the same fields on `PLYPresentationOutcome *`: `outcome.purchaseResult`, `outcome.plan`, `outcome.presentation`, `outcome.closeReason`, `outcome.error`.

### `PLYPresentation` is now a protocol

`PLYPresentation` changed from a class to a public `@objc protocol`. **Reading members and calling methods works unchanged** — every property (`id`, `placementId`, `plans`, `metadata`, `isFlow`, …) and method (`display(from:)`, `close()`, `back()`, …) is a protocol requirement that resolves identically.

- **Objective-C** signatures `(PLYPresentation *)` → `(id<PLYPresentation>)`. Method bodies typically need no other edits.
- **Swift** may write `any PLYPresentation` (both `PLYPresentation` and `any PLYPresentation` compile).
- The delegate protocols `PLYUIHandler`, `PLYCustomScreenViewControllerDelegate`, `PLYCustomScreenViewDelegate` now declare `any PLYPresentation`.

### SwiftUI — `swiftUIView`

The PascalCase `controller.PresentationView` bridge is **removed**. Read `swiftUIView` off the preloaded presentation:

```swift
PLYPresentationBuilder
    .forScreenId(paywallIdentifier)
    .contentId(contentId)
    .build()
    .preload { presentation, error in
        self.paywallView = presentation?.swiftUIView   // SwiftUI View
    }
```

`swiftUIView` is named (not `view`) to disambiguate from `UIKit.UIView`. It returns `nil` for `.deactivated` presentations. UIKit consumers continue to use `presentation.controller`.

## Deeplinks

### `Purchasely.handleDeeplink(_:)`

Pass an incoming deeplink to the SDK. iOS does **not** auto-intercept deeplinks — call this from your `AppDelegate` / `SceneDelegate`. Replaces the deprecated `isDeeplinkHandled(deeplink:)` (removal in v7).

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
    return Purchasely.handleDeeplink(url)   // returns Bool
}
```

You can also hand a cold-start deeplink to the SDK at initialization:

```swift
Purchasely.apiKey("YOUR_API_KEY").handleDeeplink(url).start { error in }
```

### `Purchasely.allowDeeplink(_:)` / `Purchasely.allowCampaigns(_:)`

In v6, deeplinks display **immediately** by default. Defer them (e.g. during onboarding) and re-enable when ready. Replaces the deprecated `readyToOpenDeeplink(_:)` (removal in v7).

```swift
Purchasely.allowDeeplink(false)   // defer display
Purchasely.allowDeeplink(true)    // any queued deeplink displays immediately
Purchasely.allowCampaigns(false)  // independent flag for campaigns
```

## Presentation Result Handler

### `Purchasely.setDefaultPresentationResultHandler(handler:)`

A default handler for paywalls you do **not** instantiate yourself — chiefly deeplink- and campaign-opened screens, where no `onDismissed` closure was supplied.

```swift
Purchasely.setDefaultPresentationResultHandler { result, plan in
    switch result {
    case .purchased: print("Purchased: \(plan?.vendorId ?? "")")
    case .restored:  print("Restored")
    case .cancelled: print("Cancelled")
    @unknown default: break
    }
}
```

## User Management

### `Purchasely.userLogin(with:shouldRefresh:)`

Identify the user after authentication. The `shouldRefresh` callback lets you decide whether to refresh the paywall after login. Unchanged from v5.

```swift
Purchasely.userLogin(with: "user_123") { shouldRefresh in
    return true // return true to refresh the current paywall
}
```

### `Purchasely.userLogout()`

Clear the current user identity. Call on sign-out. Unchanged from v5.

```swift
Purchasely.userLogout()
```

## User Attributes

### `Purchasely.setUserAttribute(with*Value:forKey:)`

Set user attributes for audience targeting and personalization. Use the typed variant matching the value type. Unchanged from v5.

```swift
Purchasely.setUserAttribute(withStringValue: "John", forKey: "first_name")
Purchasely.setUserAttribute(withIntValue: 30, forKey: "age")
Purchasely.setUserAttribute(withDoubleValue: 175.5, forKey: "height")
Purchasely.setUserAttribute(withBoolValue: true, forKey: "is_premium")
Purchasely.setUserAttribute(withDateValue: Date(), forKey: "signup_date")
```

To set multiple attributes at once:

```swift
Purchasely.setUserAttributes([
    "age": 30,
    "loyalty_tier": "gold",
    "is_premium": true,
    "signup_date": Date()
])
```

## Subscriptions

### `Purchasely.userSubscriptions(success:failure:)`

Fetch the user's active subscriptions. Unchanged from v5.

```swift
Purchasely.userSubscriptions(
    success: { subscriptions in
        for subscription in subscriptions ?? [] {
            print("Plan: \(subscription.plan.vendorId)")
        }
    },
    failure: { error in
        print("Error: \(error?.localizedDescription ?? "")")
    }
)
```

## Programmatic Purchases

Use this for app-side purchase buttons in Full mode. Fetch a `PLYPlan` first; there is no `purchase(planId:)` API. Unchanged from v5.

```swift
Purchasely.plan(with: "premium_yearly") { plan in
    Purchasely.purchase(
        plan: plan,
        contentId: nil,
        success: { /* refresh premium state */ },
        failure: { error in /* surface purchase error */ }
    )
} failure: { error in
    // Surface plan lookup error
}
```

## Restore Purchases

### `Purchasely.restoreAllProducts(success:failure:)`

Restore the user's previous purchases. Trigger from a user action (e.g. a "Restore Purchases" button). May prompt the user to sign in. Unchanged from v5.

```swift
Purchasely.restoreAllProducts(
    success: { print("Restore completed") },
    failure: { error in print("Restore failed: \(error?.localizedDescription ?? "")") }
)
```

## Close Screens

### `Purchasely.closeAllScreens()`

Force-dismiss any paywall currently on screen (including Flow paywalls with multiple steps). **Replaces the removed `closeDisplayedPresentation()`** — use this for every display path (e.g. after an Observer-mode purchase or when chaining a follow-up placement).

**Threading constraint:** the method is `@MainActor`-isolated. From a non-isolated synchronous context (inside a `DispatchQueue.main.async`, a `synchronize(success:)` callback, etc.), wrap it:

```swift
Task { @MainActor in
    Purchasely.closeAllScreens()
}
```

> In the action interceptor, return the result (`.success` / `.failed`) BEFORE calling `closeAllScreens()` — the SDK needs to know the action was handled before the paywall tears down.

## Synchronize

### `Purchasely.synchronize(success:failure:)`

Force a synchronization of the user's purchases with Purchasely servers. Use this for silent transfers (e.g. in Observer mode after a purchase). Unlike `restoreAllProducts`, it does not prompt the user. Unchanged from v5.

```swift
Purchasely.synchronize(
    success: { print("Synchronization successful") },
    failure: { error in print("Synchronization failed: \(error?.localizedDescription ?? "")") }
)
```

**Swift Concurrency wrapper:** when you need to await sync before doing more work (e.g. chaining a follow-up placement that targets users by their now-active subscription), bridge it:

```swift
private func synchronizeReceipt() async throws {
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
        Purchasely.synchronize(
            success: { cont.resume() },
            failure: { error in
                cont.resume(throwing: error ?? NSError(domain: "Purchasely", code: -1))
            }
        )
    }
}
```

By default the SDK runs `synchronize()` in the background — you do **not** need to await it before dismissing the paywall.

## Events

### `Purchasely.setEventDelegate(_:)`

Set a delegate to receive SDK events (paywall views, purchases, etc.). The `properties` argument is **optional** (`[String: Any]?`). Unchanged from v5.

```swift
class MyEventDelegate: PLYEventDelegate {
    func eventTriggered(_ event: PLYEvent, properties: [String: Any]?) {
        print("Event: \(event.name) | Properties: \(properties ?? [:])")
    }
}

Purchasely.setEventDelegate(MyEventDelegate())
```

> Delegate callbacks fire on unknown threads. Hop to the main actor via `Task { @MainActor in … }` (not `DispatchQueue.main.async`) when mutating UI state.

### `Purchasely.setUserAttributeDelegate(_:)`

React to user-attribute changes — useful to invalidate any app-side presentation cache, since attribute changes can alter audience targeting.

```swift
class MyAttributeDelegate: PLYUserAttributeDelegate {
    nonisolated func onUserAttributeSet(key: String, value: Any, source: PLYUserAttributeSource) { }
    nonisolated func onUserAttributeRemoved(key: String, source: PLYUserAttributeSource) { }
}

Purchasely.setUserAttributeDelegate(MyAttributeDelegate())
```

## Objective-C type changes (v5 → v6)

| v5 (Objective-C) | v6 (Objective-C) |
|------------------|------------------|
| `PLYPresentation *` | `id<PLYPresentation>` (now a protocol) |
| `PLYRunningModeFull` / `PLYRunningModePaywallObserver` | `PLYRunningModeFull` / `PLYRunningModeObserver` |
| `PLYPresentationInfo *` | `PLYInterceptorInfo *` |
| `PLYProductViewControllerResult` | `PLYPresentationOutcome *` (struct with `purchaseResult`, `plan`, `presentation`, `closeReason`, `error`) |
| `[Purchasely closeDisplayedPresentation]` | `[Purchasely closeAllScreens]` |
| `displayMode:` parameter | `transition:` parameter |

## `PLYPresentationAction` Enum

Actions that can be intercepted from paywall user interactions:

| Swift | Objective-C | Description |
|-------|-------------|-------------|
| `.purchase` | `PLYPresentationActionPurchase` | User tapped a purchase button |
| `.restore` | `PLYPresentationActionRestore` | User tapped the restore button |
| `.login` | `PLYPresentationActionLogin` | User tapped the login button |
| `.close` | `PLYPresentationActionClose` | User tapped the close button |
| `.navigate` | `PLYPresentationActionNavigate` | User tapped a custom navigation link |
| `.open_presentation` | `PLYPresentationActionOpenPresentation` | User tapped a link to another presentation |
| `.promo_code` | `PLYPresentationActionPromoCode` | User tapped the promo code button |

## `PLYPresentationType` Enum

Type read from a loaded presentation:

| Type | Description |
|------|-------------|
| `.normal` | Standard presentation, ready to display |
| `.fallback` | Fallback presentation (network issue, original not found) |
| `.deactivated` | Presentation has been deactivated in the dashboard — do not display |
| `.client` | Client-side presentation (render your own paywall with Purchasely data) |
