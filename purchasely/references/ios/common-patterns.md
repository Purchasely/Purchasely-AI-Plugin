# iOS Common Integration Patterns

> **Platform-specific elaborations for v6.0.0-rc1.** This file covers iOS idioms (SwiftUI, UIKit, Swift 6 concurrency, external billing / StoreKit 2 bridging). Concepts that apply to **every** Purchasely SDK (Observer-mode post-purchase flow, presentation type guard, presentation cache, audience-targeting attributes, GDPR consent, subscription checks) live in `../concepts/`:
>
> - [`../concepts/running-modes.md`](../concepts/running-modes.md), [`../concepts/paywall-actions.md`](../concepts/paywall-actions.md), [`../concepts/presentation-types.md`](../concepts/presentation-types.md), [`../concepts/presentation-cache.md`](../concepts/presentation-cache.md), [`../concepts/observer-mode-post-purchase.md`](../concepts/observer-mode-post-purchase.md), [`../concepts/user-attributes-targeting.md`](../concepts/user-attributes-targeting.md), [`../concepts/subscription-checks.md`](../concepts/subscription-checks.md). Migrating from v5? See [`migration-v6.md`](migration-v6.md).

## Displaying a Paywall from SwiftUI

For SwiftUI apps, build the presentation with `PLYPresentationBuilder`, preload it, and read `presentation.swiftUIView` — a native SwiftUI `View`. No `UIViewControllerRepresentable` wrapper needed.

```swift
import SwiftUI
import Purchasely

@MainActor
final class PaywallLoader: ObservableObject {
    @Published var paywallView: AnyView?

    func load(placementId: String) {
        PLYPresentationBuilder
            .forPlacementId(placementId)
            .onDismissed { outcome in
                // user closed; outcome.purchaseResult / outcome.closeReason
            }
            .build()
            .preload { presentation, error in
                if let error { print("Paywall load error: \(error)") }
                // swiftUIView is nil for .deactivated presentations
                if let view = presentation?.swiftUIView {
                    self.paywallView = AnyView(view)
                }
            }
    }
}

struct ContentView: View {
    @StateObject private var loader = PaywallLoader()

    var body: some View {
        Group {
            if let view = loader.paywallView {
                view
            } else {
                ProgressView()
            }
        }
        .onAppear { loader.load(placementId: "ONBOARDING") }
    }
}
```

For a full-screen / modal presentation that the SDK presents for you, the one-liner is enough:

```swift
Purchasely.display(for: "ONBOARDING", transition: nil)   // backend-defined transition
```

## Displaying a Paywall from UIKit

For regular modal display, preload via the builder and call `display(from:)`:

```swift
Task {
    do {
        let presentation = try await PLYPresentationBuilder
            .forPlacementId("ONBOARDING")
            .build()
            .preload()
        guard presentation.type == .normal || presentation.type == .fallback else { return }
        presentation.display(from: self)   // flows: presentation.display() — see isFlow
    } catch {
        print("Paywall error: \(error)")
    }
}
```

When SwiftUI/UIKit must own the embedded container (push onto a navigation stack, host in a custom window, render a nested Screen), read `presentation.controller` (a `UIViewController`):

```swift
PLYPresentationBuilder
    .forPlacementId("SETTINGS_PAYWALL")
    .onDismissed { outcome in /* dismissed */ }
    .build()
    .preload { presentation, error in
        guard let controller = presentation?.controller else { return }
        controller.modalPresentationStyle = .fullScreen
        self.present(controller, animated: true)
    }
```

## Handling the LOGIN Action

When users tap "Login" on a paywall, intercept the action and present your login flow. Register one interceptor per action; the closure returns a `PLYInterceptResult`:

```swift
Purchasely.interceptAction(.login) { [weak self] info, params in
    guard let self else { return .notHandled }
    let (success, userId) = await self.presentLoginScreen()
    if success, let userId {
        Purchasely.userLogin(with: userId) { _ in
            return true   // refresh paywall with the user's entitlements
        }
        return .success   // app handled the login
    }
    return .failed        // user cancelled / login failed
}

@MainActor
func presentLoginScreen() async -> (Bool, String?) {
    await withCheckedContinuation { cont in
        let loginVC = LoginViewController()
        loginVC.onComplete = { success, userId in cont.resume(returning: (success, userId)) }
        UIApplication.shared.topViewController()?.present(loginVC, animated: true)
    }
}
```

Completion-handler form (no async context):

```swift
Purchasely.interceptAction(.login) { info, params, completion in
    presentLoginScreen { success, userId in
        if success, let userId {
            Purchasely.userLogin(with: userId) { _ in true }
            completion(.success)
        } else {
            completion(.failed)
        }
    }
}
```

## Observer Mode with an Existing Purchase Manager

Use Purchasely for paywall display only while your existing purchase manager handles purchases. Initialize in Observer mode, then intercept `.purchase` / `.restore`:

```swift
// Initialize in observer mode (the v6 default)
try await Purchasely
    .apiKey("YOUR_API_KEY")
    .runningMode(.observer)
    .storekitSettings(.storeKit2)
    .start()

// Route purchases through your existing purchase manager
Purchasely.interceptAction(.purchase) { info, params in
    guard let plan = params?.plan, let productId = plan.appleProductId else {
        return .notHandled
    }
    let error = await ExistingPurchaseManager.shared.purchase(productId: productId)
    if error == nil {
        Purchasely.synchronize()   // notify Purchasely for analytics + receipt validation
        return .success            // app handled the purchase
    }
    return .failed
}

Purchasely.interceptAction(.restore) { info, params in
    let error = await ExistingPurchaseManager.shared.restorePurchases()
    Purchasely.synchronize()
    return error == nil ? .success : .failed
}
```

> 📘 `.notHandled` for `.purchase` / `.restore` in Observer mode logs a warning and skips — the SDK cannot execute purchases in Observer mode. Always return `.success` / `.failed` from your own flow.

## Observer Mode with StoreKit 2

```swift
try await Purchasely
    .apiKey("YOUR_API_KEY")
    .runningMode(.observer)
    .storekitSettings(.storeKit2)
    .start()

Purchasely.interceptAction(.purchase) { info, params in
    guard let plan = params?.plan, let productId = plan.appleProductId else {
        return .notHandled
    }
    do {
        guard let product = try await Product.products(for: [productId]).first else {
            return .failed
        }
        let result = try await product.purchase()
        switch result {
        case .success:
            Purchasely.synchronize()
            return .success
        case .pending, .userCancelled:
            return .notHandled    // not an error — user backed out
        @unknown default:
            return .failed
        }
    } catch {
        return .failed
    }
}

Purchasely.interceptAction(.restore) { info, params in
    do {
        try await AppStore.sync()
        Purchasely.synchronize()
        return .success
    } catch {
        return .failed
    }
}
```

## Observer Mode — Recommended Post-Purchase Flow

After a successful Observer-mode purchase, the recommended sequence is:

1. **Await `synchronize()`** (only if you chain a follow-up placement that targets users based on subscription state — otherwise fire-and-forget is fine)
2. **Return `.success`** from the interceptor — tells the SDK the action was handled
3. **`Purchasely.closeAllScreens()`** — force-dismiss the paywall

The order **return result → closeAllScreens** matters: the interceptor must learn the action was handled before the paywall tears down.

```swift
@MainActor
func handlePurchase(params: PLYPresentationActionParameters?) async -> PLYInterceptResult {
    guard let productId = params?.plan?.appleProductId else { return .notHandled }
    let result = await PurchaseManager.shared.purchase(productId: productId)
    switch result {
    case .success:
        try? await synchronizeReceipt()    // only await if you chain a placement that targets subscribers
        Purchasely.closeAllScreens()       // dismiss after returning .success
        return .success
    case .cancelled:
        return .notHandled                 // user backed out
    case .error:
        return .failed
    }
}

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

> `closeAllScreens()` is `@MainActor`-isolated. From a non-isolated context, wrap in `Task { @MainActor in Purchasely.closeAllScreens() }`. It replaces the removed `closeDisplayedPresentation()`.

### Chaining a Follow-up Placement After Purchase (optional)

Some apps display a follow-up paywall after a successful purchase — a thank-you screen, a premium onboarding tour, a one-tap upsell. This is **not part of the SDK contract**: it's just `PLYPresentationBuilder` called again with whatever placement ID you've configured on the Console (e.g. `"post_purchase"`, `"thank_you"` — pick your own).

If you chain a placement whose audience targets users by subscription state, **`synchronize()` must complete first** — otherwise the fetch resolves against stale state and may return a deactivated/fallback presentation.

```swift
@MainActor
private func showPostPurchaseScreen() {
    PLYPresentationBuilder
        .forPlacementId("YOUR_POST_PURCHASE_PLACEMENT_ID")
        .onDismissed { _ in /* dismissed */ }
        .build()
        .preload { presentation, error in
            guard let presentation,
                  presentation.type == .normal || presentation.type == .fallback,
                  let topVC = UIApplication.shared.topViewController()
            else { return }
            presentation.display(from: topVC)
        }
}
```

**Naming gotcha:** the placement ID string must match the Console exactly — typos silently return a deactivated presentation.

## Presentation Cache & Audience Invalidation

The SDK fetches presentations from the network on every `preload`. If you display the same placement repeatedly (`.onAppear` fires several times, sheet/back navigation, etc.), each call hits the network. Wrap the preload in an app-side cache keyed by `placementId[/contentId]` and reuse the loaded presentation (`display(from:)` on a kept reference does not re-fetch):

```swift
actor PresentationCache {
    static let shared = PresentationCache()
    private var cache: [String: PLYPresentation] = [:]

    func get(_ key: String) -> PLYPresentation? { cache[key] }
    func set(_ key: String, _ presentation: PLYPresentation) { cache[key] = presentation }
    func invalidateAll() { cache.removeAll() }
}
```

**Invalidation triggers** (when the cached result may be stale):
- `PLYUserAttributeDelegate.onUserAttributeSet` / `onUserAttributeRemoved` — any attribute change can alter audience targeting
- Successful `Purchasely.synchronize()` — subscription state may have changed
- SDK mode change (Full ↔ Observer)

> Invalidation is intentionally coarse-grained (`invalidateAll`) because the SDK doesn't expose attribute→audience dependencies.

## Swift 6 Concurrency Notes

- Use `@preconcurrency import Purchasely` where needed — the SDK exposes Objective-C class properties / callback types without full Swift 6 concurrency annotations.
- SDK callbacks fire on unknown threads. Hop to the main actor with `Task { @MainActor [weak self] in … }`, **not** `DispatchQueue.main.async`, to keep one consistent concurrency model.
- The v6 `interceptAction(_:)` closure is already `async` — `await` your native StoreKit flow directly and return the `PLYInterceptResult`; no `suspendCancellableCoroutine`/continuation bridge is needed (unlike Android).
- Keep `PLYEventDelegate` / `PLYUserAttributeDelegate` callbacks `nonisolated` and do only thread-safe work in them (logging, cache invalidation).
- Relax **test targets** to `SWIFT_STRICT_CONCURRENCY = minimal` — `XCTestCase` predates async/await and `complete` checking flags every `try await super.setUp()`. Keep production code on `complete`.

## Guard Against Overlapping Observer Purchases

In Observer mode, the interceptor fires once per user tap. If a second purchase/restore action arrives while one is already running, you'll have two overlapping StoreKit flows. Guard with a single in-flight task:

```swift
private var observerActionTask: Task<PLYInterceptResult, Never>?

@MainActor
private func handlePurchaseAction(productId: String) async -> PLYInterceptResult {
    if observerActionTask != nil { return .notHandled }   // already busy — ignore
    let task = Task<PLYInterceptResult, Never> { @MainActor in
        let result = await PurchaseManager.shared.purchase(productId: productId)
        return result.isSuccess ? .success : .failed
    }
    observerActionTask = task
    defer { observerActionTask = nil }
    return await task.value
}
```

## Setting User Attributes for Targeting

Set attributes to enable audience targeting and paywall personalization (unchanged from v5):

```swift
func updatePurchaselyAttributes(user: User) {
    Purchasely.setUserAttribute(withStringValue: user.firstName, forKey: "first_name")
    Purchasely.setUserAttribute(withStringValue: user.email, forKey: "email")
    Purchasely.setUserAttribute(withIntValue: user.age, forKey: "age")
    Purchasely.setUserAttribute(withStringValue: user.tier, forKey: "subscription_tier")
    Purchasely.setUserAttribute(withIntValue: user.articlesRead, forKey: "articles_read")
    Purchasely.setUserAttribute(withDateValue: user.signupDate, forKey: "signup_date")
    Purchasely.setUserAttribute(withBoolValue: user.isPowerUser, forKey: "is_power_user")
}
```

## Handling Subscription Status Checks

Check active subscriptions to gate content:

```swift
func checkSubscriptionAccess(completion: @escaping (Bool) -> Void) {
    Purchasely.userSubscriptions(
        success: { subscriptions in
            let hasActive = subscriptions?.contains { sub in
                sub.plan.vendorId == "premium_monthly" || sub.plan.vendorId == "premium_yearly"
            } ?? false
            completion(hasActive)
        },
        failure: { _ in completion(false) }
    )
}

// Usage
checkSubscriptionAccess { hasAccess in
    if hasAccess {
        // Show premium content
    } else {
        Purchasely.display(for: "PREMIUM_UPSELL", transition: .modal)
    }
}
```

## GDPR Consent Management

Handle consent alongside initialization:

```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    Task {
        try? await Purchasely
            .apiKey("YOUR_API_KEY")
            .runningMode(.full)
            .storekitSettings(.storeKit2)
            .logLevel(.warn)
            .start()
    }

    if hasUserConsent() {
        enableTracking()
    } else {
        showConsentDialog { granted in if granted { enableTracking() } }
    }
    return true
}

func enableTracking() {
    Purchasely.setUserAttribute(withBoolValue: true, forKey: "gdpr_consent")
    Purchasely.setUserAttribute(withStringValue: ISO8601DateFormatter().string(from: Date()), forKey: "consent_date")
}
```

## Preload with Type Guard

Always check the presentation type before displaying:

```swift
PLYPresentationBuilder
    .forPlacementId("PREMIUM_PAYWALL")
    .onDismissed { outcome in /* handle purchase result */ }
    .build()
    .preload { presentation, error in
        guard let presentation else {
            print("Failed to fetch: \(error?.localizedDescription ?? "")")
            return
        }
        switch presentation.type {
        case .normal, .fallback:
            presentation.display(from: self)
        case .deactivated:
            print("Presentation is deactivated — do not display")
        case .client:
            self.showCustomPaywall(plans: presentation.plans)
        @unknown default:
            break
        }
    }
```
