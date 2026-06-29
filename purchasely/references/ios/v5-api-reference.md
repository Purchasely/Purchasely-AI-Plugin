# iOS SDK v5.x API — reference for MIGRATION ONLY (replaced in v6)

> **Do not write new v5 code.** This is a compact snapshot of the legacy v5.x public API so the `purchasely-migrate` skill can **recognize** existing v5 code in a project and map it forward. Every symbol below is **removed or deprecated in v6.0.0-rc.1**. For the v6 surface, see [`api-reference.md`](api-reference.md); for the step-by-step migration, see [`migration-v6.md`](migration-v6.md).

## How to recognize a v5 iOS integration

Grep the project for any of these legacy tokens — a hit means the integration is on v5:

```
start(withAPIKey      .paywallObserver       PLYRunningModePaywallObserver
setPaywallActionsInterceptor                 PLYPresentationInfo
fetchPresentation     presentationController .PresentationView
productView           planView               presentationView
ply/products          ply/plans
PLYProductViewControllerResult               readyToOpenDeeplink
isDeeplinkHandled     closeDisplayedPresentation                displayMode:
PLYPaywallActionsInterceptor
```

> `PLYPresentationActionParameters` is **not** a v5-only token on iOS: v6 still passes it to each interceptor as `params`. Only the `PLYPaywallActionsInterceptor` typealias and the `paywallActionsInterceptor:` start parameter were removed.

## Initialization

### `Purchasely.start(withAPIKey:appUserId:runningMode:storekitSettings:logLevel:initialized:)` — **removed**

```swift
Purchasely.start(withAPIKey: "YOUR_API_KEY",
                 appUserId: "user_123",
                 runningMode: .full,             // default in v5 was .full
                 storekitSettings: .storeKit2,
                 logLevel: .debug) { success, error in }
```

→ **v6 equivalent:** the fluent builder `Purchasely.apiKey("YOUR_API_KEY").runningMode(.full).start { error in }` (or `try await …start()`). The completion drops the `Bool success` parameter. The default running mode is now `.observer`.

### `PLYRunningMode.paywallObserver` — **renamed**

→ **v6 equivalent:** `PLYRunningMode.observer` (Objective-C: `PLYRunningModePaywallObserver` → `PLYRunningModeObserver`).

### Pre-`start` class funcs: `setEnvironment` / `setThemeMode` / `setShowPromotedInAppPurchasePaywall` / `setAppTechnology` / `setSdkBridgeVersion` — **deprecated**

→ **v6 equivalent:** chain modifiers before `start()` (`.environment(_:)`, `.themeMode(_:)`, …).

## Action Interceptor

### `Purchasely.setPaywallActionsInterceptor { action, params, info, proceed in }` — **removed**

```swift
Purchasely.setPaywallActionsInterceptor { action, params, info, proceed in
    switch action {
    case .login:    showLogin { ok in proceed(ok) }
    case .purchase: customPurchase(params?.plan) { ok in proceed(!ok) }
    default:        proceed(true)
    }
}
```

→ **v6 equivalent:** one interceptor per action, `Purchasely.interceptAction(.login) { info, params in … }`, returning a `PLYInterceptResult`. Remove with `removeActionInterceptor(_:)` / `removeAllActionInterceptors()`.

### `proceed(_:)` closure — **removed**

→ **v6 equivalent:** return a `PLYInterceptResult`. Mapping: `proceed(false)` → `.success`, `proceed(true)` → `.notHandled`, plus the new `.failed`.

### `PLYPresentationInfo` (interceptor `info` argument) — **removed**

```swift
info.presentationId; info.placementId; info.audienceId; info.abTestId; info.campaignId
```

→ **v6 equivalent:** `PLYInterceptorInfo` — `info.presentation?.id`, `info.presentation?.placementId`, `info.presentation?.audienceId`, `info.presentation?.abTestId`, `info.presentation?.campaignId`. `info.contentId` / `info.controller` unchanged.

### `PLYPresentationActionParameters` / `PLYPaywallActionsInterceptor` typealias

→ **v6:** `PLYPresentationActionParameters` is still passed to each interceptor as `params` (e.g. `params?.plan`, `params?.url`, `params?.promoOffer`). The `PLYPaywallActionsInterceptor` typealias and the `paywallActionsInterceptor:` start parameter are **removed**.

## Paywall Presentation

### `Purchasely.fetchPresentation(for:contentId:fetchCompletion:completion:)` — **removed**

```swift
Purchasely.fetchPresentation(for: "PLACEMENT_ID", contentId: nil,
    fetchCompletion: { presentation, error in presentation?.display(from: self) },
    completion: { result, plan in })
```

→ **v6 equivalent:** `PLYPresentationBuilder.forPlacementId("PLACEMENT_ID").contentId(nil).build().preload { presentation, error in }`. The `fetchCompletion:` maps to `.preload`, `loadedCompletion:` to `.onPresented`, `completion:` to `.onDismissed`.

### `Purchasely.presentationController(for:contentId:loaded:completion:)` — **removed**

```swift
let controller = Purchasely.presentationController(for: "PLACEMENT_ID",
    loaded: { vc, isLoaded, error in }, completion: { result, plan in })
present(controller, animated: true)
```

→ **v6 equivalent:** preload via `PLYPresentationBuilder`, then read `presentation.controller` (a `UIViewController`) for UIKit hosting, or `presentation.swiftUIView` for SwiftUI.

### `controller.PresentationView` (SwiftUI embed) — **removed**

→ **v6 equivalent:** `presentation.swiftUIView` (a SwiftUI `View`; `nil` for `.deactivated`). UIKit hosting uses `presentation.controller`.

### `Purchasely.productView(...)` / `planView(...)` / `presentationView(...)` (SwiftUI factories) — **removed**

```swift
let view = Purchasely.presentationView(for: "PLACEMENT_ID",
    loaded: { _ in }, completion: { result, plan in })   // returned PLYPresentationView?
```

The eight `PLYPresentationView?`-returning factories (`productView` / `planView` / `presentationView` and their `contentId:` variants) carried the legacy `(PLYProductViewControllerResult, PLYPlan?)` completion block.

→ **v6 equivalent:** preload via `PLYPresentationBuilder`, read `presentation.swiftUIView`, and take the dismissal result from `.onDismissed { outcome in }`.

### `Purchasely.display(for:displayMode:)` — **renamed parameter**

```swift
Purchasely.display(for: "PLACEMENT_ID", displayMode: .modal)
```

→ **v6 equivalent:** `Purchasely.display(for: "PLACEMENT_ID", transition: .modal)` (parameter `displayMode:` → `transition:`). `PLYDisplayMode` also gains sizing: `.drawer(height:)`, `.popin(width:height:)`, `.modal(dismissible:)`.

### `Purchasely.closeDisplayedPresentation()` — **removed**

→ **v6 equivalent:** `Purchasely.closeAllScreens()` (`@MainActor`-isolated; handles every display path including flows).

### `PLYProductViewControllerResult` (dismissal result) — **removed**

```swift
// v5 dismissal delivered (PLYProductViewControllerResult, PLYPlan?)
completion: { result, plan in /* result: .purchased / .restored / .cancelled */ }
```

→ **v6 equivalent:** a single `PLYPresentationOutcome` carrying `purchaseResult` (`PLYPurchaseResult`), `plan`, `presentation`, the new `closeReason` (`PLYCloseReason`), and `error`.

### `Purchasely.setDefaultPresentationResultHandler { result, plan in }` — **renamed** (iOS)

```swift
Purchasely.setDefaultPresentationResultHandler { result, plan in /* .purchased / .restored / .cancelled */ }
```

→ **v6 equivalent:** `Purchasely.setDefaultPresentationDismissHandler { outcome in }` — renamed, and now delivers the full `PLYPresentationOutcome` (`outcome.purchaseResult` / `outcome.plan` / `outcome.closeReason` / `outcome.presentation`). It is mutually exclusive with per-presentation `onDismissed` / completion callbacks. (Note: **Android keeps the name** `setDefaultPresentationResultHandler` and only changes the callback to a single `outcome`; the rename is iOS-only.)

### `PLYPresentation` was a **class**

→ **v6:** `PLYPresentation` is now an `@objc protocol`. Reading members/methods is unchanged; Objective-C `PLYPresentation *` → `id<PLYPresentation>`; Swift may write `any PLYPresentation`.

## Deeplinks

### `Purchasely.readyToOpenDeeplink(_:)` — **deprecated** (removal v7)

```swift
Purchasely.readyToOpenDeeplink(true)
```

→ **v6 equivalent:** `Purchasely.allowDeeplink(_:)` (deeplinks now display immediately by default; pass `false` to defer). Companion flag `Purchasely.allowCampaigns(_:)`.

### `Purchasely.isDeeplinkHandled(deeplink:)` — **deprecated** (removal v7)

```swift
let handled = Purchasely.isDeeplinkHandled(deeplink: url)
```

→ **v6 equivalent:** `Purchasely.handleDeeplink(_:)` (still returns `Bool`). Cold-start variant: `Purchasely.apiKey("…").handleDeeplink(url).start { error in }`.

### `ply/products/*` and `ply/plans/*` deeplink formats — **removed**

```
app_scheme://ply/products/PRODUCT_ID/PRESENTATION_ID
app_scheme://ply/plans/PLAN_ID/PRESENTATION_ID
```

→ **v6 equivalent:** deep-link to a presentation (`app_scheme://ply/presentations/PRESENTATION_ID`) or a placement (`app_scheme://ply/placements/PLACEMENT_ID`). The internal `productController` factory that served these is removed too.

## Unchanged in v6 (no migration needed)

These v5 APIs are identical in v6 — they are listed here only so the `purchasely-migrate` skill does **not** flag them: `userLogin(with:shouldRefresh:)`, `userLogout()`, `setUserAttribute(with*Value:forKey:)`, `userSubscriptions(success:failure:)`, `restoreAllProducts(success:failure:)`, `synchronize(success:failure:)`, `purchase(plan:contentId:success:failure:)`, `setEventDelegate(_:)`.

> **Not** identical in v6: `setDefaultPresentationResultHandler(_:)` was **renamed** to `setDefaultPresentationDismissHandler(_:)` and **retyped** — its closure now receives a single `PLYPresentationOutcome` instead of `(result, plan)`. The `purchasely-migrate` skill must migrate it; see the v5 → v6 mapping in `purchasely-migrate`.
