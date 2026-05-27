# iOS SDK v5.x -> v6.0.0 Migration

This guide is iOS-only (Swift / SwiftUI / UIKit). Android, React Native, Flutter, and Cordova have their own migration notes — do not apply this one to them.

The mapping below was validated against the Shaker sample app's v6 migration. Where v6 behavior depends on an unreleased `develop` snapshot, it is called out explicitly.

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

> **Unreleased snapshot only.** While v6 ships from `Purchasely-iOS-Sources/develop`, that branch has **no `Package.swift` at the repository root**, so it cannot be consumed as a normal SPM remote. Shaker works around this with a small **local Swift package** (`ios/LocalPackages/Purchasely`) that symlinks to the source checkout, declares a `Purchasely` SPM product, includes the `common` / `specific/ios` / `specific/uikit` / `specific/swiftUI` source sets, excludes tvOS and SDK tests, adds an `Exports.swift` for the UIKit/Foundation re-exports, and replaces the lone Objective-C `PLYLottieView` with a Swift shim (SwiftPM rejects mixed Swift/ObjC in one target). **Once 6.0.0 is published, delete the local package and point the dependency back at the released SPM/CocoaPods version.**

### Swift 6 strict concurrency

The v6 SDK is annotated for Swift Concurrency. Import it with `@preconcurrency` at call sites that touch SDK types from a `@MainActor` context:

```swift
@preconcurrency import Purchasely
```

`XCTestCase` is non-`Sendable` and predates async/await, so `complete` strict-concurrency checking flags every `try await super.setUp()` in test targets. Keep production code on `complete` and relax the **test target** to `SWIFT_STRICT_CONCURRENCY = minimal`.

## Initialization

The v5 one-shot `Purchasely.start(withAPIKey:appUserId:running:eventDelegate:uiConfiguration:logLevel:completion:)` is replaced by a **fluent builder** terminated by `.start { error in }`. The completion now receives a single optional `Error` (no `Bool` first parameter):

```swift
Purchasely.apiKey(apiKey)
    .appUserId(appUserId)            // optional
    .runningMode(selectedMode)       // .full or .observer
    .storekitSettings(.storeKit1)    // see note below
    .logLevel(logLevel)
    .start { error in
        if let error {
            // handle error.localizedDescription
        } else {
            // configured — refresh entitlements, etc.
        }
    }

Purchasely.allowDeeplink(true)
Purchasely.setEventDelegate(self)
```

Changes that apply to initialization:
- `PLYRunningMode.paywallObserver` -> `PLYRunningMode.observer`.
- `readyToOpenDeeplink(true)` -> `Purchasely.allowDeeplink(true)`.
- Delegates are set separately after `start`: `Purchasely.setEventDelegate(_:)`, `Purchasely.setUserAttributeDelegate(_:)`.

> **`storekitSettings` on the `develop` snapshot.** The v6 `develop` build scans **StoreKit 2** transactions *before* firing the init completion, which can stall the callback on simulator. Shaker starts Purchasely with `.storeKit1` and keeps its own native Observer-mode purchases on StoreKit 2 in `PurchaseManager`. Re-evaluate this once 6.0.0 is released.

## Action Interceptor

The global `Purchasely.setPaywallActionsInterceptor { action, parameters, info, proceed in }` is removed. Register **typed** interceptors whose closures are `async` and **return** a `PLYInterceptResult` instead of calling `proceed(_:)`:

```swift
Purchasely.removeAllActionInterceptors()

Purchasely.interceptAction(.login) { _, _ in
    showLogin()
    return .success
}

Purchasely.interceptAction(.navigate) { _, parameters in
    if let url = parameters?.url {
        await MainActor.run { UIApplication.shared.open(url) }
    }
    return .success
}

Purchasely.interceptAction(.purchase) { [weak self] _, parameters in
    guard let self else { return .notHandled }
    return await self.handlePurchase(parameters: parameters)
}

Purchasely.interceptAction(.restore) { [weak self] _, _ in
    guard let self else { return .notHandled }
    return await self.handleRestore()
}
```

`proceed(_:)` → `PLYInterceptResult` mapping:
- `proceed(true)` ("let the SDK continue the action") -> `.notHandled`.
- `proceed(false)` ("the app handled it") -> `.success`.
- New failure path -> `.failed`, or `.error("message")` to surface a reason.

Action data still comes from `PLYPresentationActionParameters`:
- Purchase product id: `parameters?.plan?.appleProductId`.
- Promotional offer: `parameters?.promoOffer?.storeOfferId`.
- Navigation URL: `parameters?.url`.

### Observer-mode bridge (iOS is simpler than Android)

On Android the v6 interceptor is a `suspend` function and Observer mode needs a `suspendCancellableCoroutine` bridge. **On iOS the interceptor closure is already `async`**, so just `await` the native StoreKit flow and return its result directly — no coroutine bridge:

```swift
@MainActor
func handlePurchase(parameters: PLYPresentationActionParameters?) async -> PLYInterceptResult {
    guard isObserverMode else { return .notHandled }          // Full mode → SDK owns it
    guard let productId = parameters?.plan?.appleProductId else {
        return .error("Missing product ID")
    }
    let result = await PurchaseManager.shared.purchase(productId: productId)
    switch result {
    case .success:        try? await synchronizeReceipt(); return .success
    case .cancelled:      return .notHandled
    case .error(let m):   return .failed
    case .idle:           return .notHandled
    }
}
```

Return `.notHandled` in Full mode so the SDK runs its own purchase/restore flow.

## Presentation API

`Purchasely.fetchPresentation(for:contentId:fetchCompletion:completion:)` is replaced by the **`PLYPresentationBuilder`** + `preload`:

```swift
let builder = PLYPresentationBuilder.from(placementId: placementId)
if let contentId { builder.contentId(contentId) }

builder.onClose { /* user dismissed without buying */ }
builder.onDismissed { outcome in handle(outcome) }

builder.build().preload { presentation, error in
    guard let presentation else { /* error */ return }

    // Defensive on develop snapshots: re-assign the lifecycle callbacks on the
    // loaded presentation — builder-seeded callbacks are not fired by every snapshot.
    presentation.onClose = { /* ... */ }
    presentation.onDismissed = { outcome in handle(outcome) }

    switch presentation.type {
    case .deactivated: // placement off
    case .client:      // client-side paywall — render your own UI
    default:           presentation.display(from: viewController)
    }
}
```

Result type change — the v5 dismissal tuple `(PLYProductViewControllerResult, PLYPlan?)` becomes a single **`PLYPresentationOutcome`**:

```swift
func displayResult(from outcome: PLYPresentationOutcome) -> DisplayResult {
    switch outcome.purchaseResult {
    case .purchased: return .purchased(planName: outcome.plan?.name)
    case .restored:  return .restored(planName: outcome.plan?.name)
    default:         return .cancelled
    }
}
```

### Embedded / inline paywalls (SwiftUI)

The `PLYProductViewController.PresentationView` property used to embed a paywall is **removed**. v6 exposes the embedded UI as a `PLYPresentationViewController` via `presentation.controller`. Wrap it in `UIViewControllerRepresentable`:

```swift
struct EmbeddedScreenBanner: View {
    let controller: PLYPresentationViewController
    var body: some View { EmbeddedPresentationController(controller: controller) }
}

private struct EmbeddedPresentationController: UIViewControllerRepresentable {
    let controller: PLYPresentationViewController
    func makeUIViewController(context: Context) -> PLYPresentationViewController { controller }
    func updateUIViewController(_ vc: PLYPresentationViewController, context: Context) {}
}
```

Get the controller from a preloaded presentation with `presentation.controller`.

## Deeplinks

- `Purchasely.readyToOpenDeeplink(true)` -> `Purchasely.allowDeeplink(true)`.
- `Purchasely.isDeeplinkHandled(deeplink:)` -> `Purchasely.handleDeeplink(_:)` (still returns `Bool`).

## Unchanged APIs (no migration needed)

These v5 signatures are identical in v6 — leave them alone:
- `Purchasely.userLogin(with:shouldRefresh:)` / `Purchasely.userLogout()`.
- `Purchasely.setUserAttribute(withStringValue:/withBoolValue:/withIntValue:/withDoubleValue:forKey:)`, `incrementUserAttribute(withKey:)`.
- `Purchasely.userSubscriptions(success:failure:)`, `restoreAllProducts(success:failure:)`.
- `Purchasely.synchronize(success:failure:)`.
- `Purchasely.signPromotionalOffer(storeProductId:storeOfferId:success:failure:)`.
- `Purchasely.revokeDataProcessingConsent(for:)`.

## Verification Checklist

Regenerate the project (if using XcodeGen) and run after each phase:

```bash
cd ios && xcodegen generate
cd ios && xcodebuild build -project Shaker.xcodeproj -scheme Shaker \
    -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
cd ios && xcodebuild test  -project Shaker.xcodeproj -scheme Shaker \
    -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Search must return no v5-only API usages in app source/tests:

```bash
rg "paywallObserver|readyToOpenDeeplink|isDeeplinkHandled|setPaywallActionsInterceptor|fetchPresentation|PresentationView|PLYProductViewControllerResult|start\(withAPIKey" ios/Shaker
```

`isDeeplinkHandled` may remain as the **name of a wrapper method** that internally calls `handleDeeplink` — that is fine; only the `Purchasely.isDeeplinkHandled(...)` SDK call must be gone.
