# iOS Common Integration Patterns

> **Platform-specific elaborations.** This file covers iOS idioms (SwiftUI, UIKit, Swift 6 concurrency, RevenueCat / StoreKit 2 bridging). Concepts that apply to **every** Purchasely SDK (Observer-mode post-purchase flow, presentation type guard, presentation cache, audience-targeting attributes, GDPR consent, subscription checks) live in `../concepts/`:
>
> - [`../concepts/running-modes.md`](../concepts/running-modes.md), [`../concepts/paywall-actions.md`](../concepts/paywall-actions.md), [`../concepts/presentation-types.md`](../concepts/presentation-types.md), [`../concepts/presentation-cache.md`](../concepts/presentation-cache.md), [`../concepts/observer-mode-post-purchase.md`](../concepts/observer-mode-post-purchase.md), [`../concepts/user-attributes-targeting.md`](../concepts/user-attributes-targeting.md), [`../concepts/subscription-checks.md`](../concepts/subscription-checks.md), [`../sdk-versions.md`](../sdk-versions.md) (iOS pinned at **5.7.5**).

## Displaying a Paywall from SwiftUI

Use a `UIViewControllerRepresentable` wrapper to embed the Purchasely paywall in SwiftUI:

```swift
import SwiftUI
import Purchasely

struct PaywallView: UIViewControllerRepresentable {
    let placementId: String
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = Purchasely.presentationController(
            for: placementId,
            loaded: { _, isLoaded, error in
                if let error = error {
                    print("Paywall load error: \(error)")
                }
            },
            completion: { result, plan in
                dismiss()
            }
        )
        return controller ?? UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// Usage in a SwiftUI View:
struct ContentView: View {
    @State private var showPaywall = false

    var body: some View {
        Button("Show Paywall") {
            showPaywall = true
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(placementId: "ONBOARDING")
        }
    }
}
```

## Displaying a Paywall from UIKit

### Modal Presentation

```swift
let controller = Purchasely.presentationController(
    for: "ONBOARDING",
    loaded: { _, isLoaded, error in
        // Paywall content loaded
    },
    completion: { result, plan in
        self.dismiss(animated: true)
    }
)
if let controller = controller {
    controller.modalPresentationStyle = .fullScreen
    present(controller, animated: true)
}
```

### Push onto Navigation Stack

```swift
let controller = Purchasely.presentationController(
    for: "SETTINGS_PAYWALL",
    loaded: nil,
    completion: { result, plan in
        self.navigationController?.popViewController(animated: true)
    }
)
if let controller = controller {
    navigationController?.pushViewController(controller, animated: true)
}
```

## Handling the LOGIN Action

When users tap "Login" on a paywall, intercept the action and present your login flow:

```swift
Purchasely.setPaywallActionsInterceptor { [weak self] action, parameters, presentationInfo, proceed in
    switch action {
    case .login:
        self?.presentLoginScreen { success, userId in
            if success, let userId = userId {
                Purchasely.userLogin(with: userId) { _ in
                    return true // refresh paywall with user's entitlements
                }
                proceed(true)
            } else {
                proceed(false) // user cancelled login
            }
        }
    default:
        proceed(true)
    }
}

func presentLoginScreen(completion: @escaping (Bool, String?) -> Void) {
    let loginVC = LoginViewController()
    loginVC.onComplete = completion
    if let topVC = UIApplication.shared.topViewController() {
        topVC.present(loginVC, animated: true)
    }
}
```

## PaywallObserver Mode with RevenueCat

Use Purchasely for paywall display only while RevenueCat handles purchases:

```swift
// Initialize in observer mode
Purchasely.start(withAPIKey: "YOUR_API_KEY",
                  runningMode: .observer,
                  storekitSettings: .storeKit2) { success, error in }

// Intercept purchase actions to route through RevenueCat
Purchasely.setPaywallActionsInterceptor { action, parameters, presentationInfo, proceed in
    switch action {
    case .purchase:
        guard let plan = parameters?.plan,
              let productId = plan.appleProductId else {
            proceed(false)
            return
        }
        // Use RevenueCat to make the purchase
        Purchases.shared.purchase(product: product) { transaction, info, error, cancelled in
            if let error = error {
                proceed(false)
            } else {
                // Notify Purchasely of the purchase for analytics
                Purchasely.synchronize(success: {}, failure: { _ in })
                proceed(true)
            }
        }
    case .restore:
        Purchases.shared.restorePurchases { info, error in
            Purchasely.synchronize(success: {}, failure: { _ in })
            proceed(error == nil)
        }
    default:
        proceed(true)
    }
}
```

## PaywallObserver Mode with StoreKit 2

```swift
Purchasely.start(withAPIKey: "YOUR_API_KEY",
                  runningMode: .observer,
                  storekitSettings: .storeKit2) { success, error in }

Purchasely.setPaywallActionsInterceptor { action, parameters, presentationInfo, proceed in
    switch action {
    case .purchase:
        guard let plan = parameters?.plan,
              let productId = plan.appleProductId else {
            proceed(false)
            return
        }
        Task {
            do {
                let product = try await Product.products(for: [productId]).first!
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    Purchasely.synchronize(success: {}, failure: { _ in })
                    proceed(true)
                case .pending:
                    proceed(false)
                case .userCancelled:
                    proceed(false)
                @unknown default:
                    proceed(false)
                }
            } catch {
                proceed(false)
            }
        }
    case .restore:
        Task {
            try? await AppStore.sync()
            Purchasely.synchronize(success: {}, failure: { _ in })
            proceed(true)
        }
    default:
        proceed(true)
    }
}
```

## Observer Mode — Recommended Post-Purchase Flow

After a successful Observer-mode purchase, the recommended sequence is:

1. **Await `synchronize()`** (only if you chain a follow-up placement that targets users based on subscription state — otherwise fire-and-forget is fine)
2. **`proceed(false)`** — tell the SDK interceptor we handled the purchase (skip its own flow)
3. **`Purchasely.closeAllScreens()`** — force-dismiss the paywall

The order **proceed → closeAllScreens** matters: the interceptor must learn the action was handled BEFORE the paywall tears down.

```swift
@MainActor
private func handlePurchaseSuccess(proceed: @escaping (Bool) -> Void) async {
    do {
        try await synchronizeReceipt()   // only await if you chain a placement that targets subscribers
        proceed(false)                   // tell interceptor we handled it
        Purchasely.closeAllScreens()     // dismiss
    } catch {
        proceed(false)                   // dismiss anyway on sync error
        Purchasely.closeAllScreens()
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

> `closeAllScreens()` requires Purchasely iOS SDK **5.7.5+** and is `@MainActor`-isolated. From a non-isolated context, wrap in `Task { @MainActor in Purchasely.closeAllScreens() }`.

### Chaining a Follow-up Placement After Purchase (optional)

Some apps display a follow-up paywall after a successful purchase — a thank-you screen, an onboarding tour for premium features, a one-tap upsell, etc. This is **not part of the SDK contract**: it's just `fetchPresentation` called again with whatever placement ID you've configured on the Console (e.g. `"post_purchase"`, `"thank_you"`, `"premium_welcome"` — pick your own).

If you do chain a placement and its audience targets users based on subscription state, **`synchronize()` must complete first** — otherwise the fetch resolves against stale state and may return a deactivated/fallback presentation. On iOS, that's why the `synchronizeReceipt()` await above matters.

```swift
// After closeAllScreens() above, fetch and display the chained placement
private func showPostPurchaseScreen() {
    Purchasely.fetchPresentation(
        for: "YOUR_POST_PURCHASE_PLACEMENT_ID",
        fetchCompletion: { presentation, error in
            guard let presentation = presentation,
                  presentation.type == .normal || presentation.type == .fallback,
                  let topVC = UIApplication.shared.topViewController()
            else { return }
            presentation.display(from: topVC)
        },
        completion: { _, _ in /* dismissed */ }
    )
}
```

**Naming gotcha:** the placement ID string must match the Console exactly — typos silently return a deactivated presentation.

## Presentation Cache & Audience Invalidation

The iOS SDK fetches presentations from the network on every call. If you display the same placement repeatedly (`.onAppear` fires several times, sheet/back navigation, etc.), each call hits the network and — for flow placements — accumulates `flowSteps` entries in the SDK's `FlowsManager`. A known SDK issue: dismissing the only visible step then leaves a stuck `PLYWindow` that intercepts touches.

**Fix:** wrap the fetch in an app-side cache keyed by `placementId[/contentId]`:

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

> Invalidation is intentionally coarse-grained (`invalidateAll`) because the SDK doesn't expose attribute→audience dependencies. Purchasely SDK 6.x is expected to add native placement-level caching — remove the app-side cache then.

## Swift 6 Concurrency Notes

- Use `@preconcurrency import Purchasely` where needed — the current SDK exposes Objective-C class properties / callback types without full Swift 6 concurrency annotations.
- SDK callbacks fire on unknown threads. Hop to the main actor with `Task { @MainActor [weak self] in … }`, **not** `DispatchQueue.main.async`, to keep one consistent concurrency model.
- Mark Purchasely-facing protocols (`PurchaselyWrapping`, etc.) `@MainActor` so call sites don't accidentally cross actor boundaries.
- Keep `PLYEventDelegate` / `PLYUserAttributeDelegate` callbacks `nonisolated` and do only thread-safe work in them (logging, cache invalidation).

## Guard Against Overlapping Observer Purchases

In Observer mode, the interceptor fires once per user tap. If a second purchase/restore action arrives while one is already running, you'll have two overlapping StoreKit flows and two independent `proceed(_:)` closures to call. Guard with a single in-flight task:

```swift
private var observerActionTask: Task<Void, Never>?

private func handlePurchaseAction(productId: String, proceed: @escaping (Bool) -> Void) {
    guard observerActionTask == nil else {
        proceed(false) // already busy — ignore this action
        return
    }
    observerActionTask = Task { @MainActor [weak self] in
        defer { self?.observerActionTask = nil }
        let result = await PurchaseManager.shared.purchase(productId: productId)
        await self?.handleTransactionResult(result, proceed: proceed)
    }
}
```

## Setting User Attributes for Targeting

Set attributes to enable audience targeting and paywall personalization:

```swift
// After user login or profile update
func updatePurchaselyAttributes(user: User) {
    Purchasely.setUserAttribute(withStringValue: user.firstName, forKey: "first_name")
    Purchasely.setUserAttribute(withStringValue: user.email, forKey: "email")
    Purchasely.setUserAttribute(withIntValue: user.age, forKey: "age")

    // Custom attributes for targeting rules
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
            let hasActiveSubscription = subscriptions?.contains { subscription in
                subscription.plan.vendorId == "premium_monthly" ||
                subscription.plan.vendorId == "premium_yearly"
            } ?? false
            completion(hasActiveSubscription)
        },
        failure: { _ in
            completion(false)
        }
    )
}

// Usage
checkSubscriptionAccess { hasAccess in
    if hasAccess {
        // Show premium content
    } else {
        // Show paywall
        let controller = Purchasely.presentationController(for: "PREMIUM_UPSELL",
                                                            completion: { result, plan in
            self.dismiss(animated: true)
            if result == .purchased {
                // Refresh content access
            }
        })
        if let controller = controller {
            self.present(controller, animated: true)
        }
    }
}
```

## GDPR Consent Management

Handle consent before initializing Purchasely or enabling tracking:

```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // Always initialize Purchasely (required for paywall display)
    Purchasely.start(withAPIKey: "YOUR_API_KEY",
                      runningMode: .full,
                      storekitSettings: .storeKit2,
                      logLevel: .warn) { success, error in }

    // Check consent status
    if hasUserConsent() {
        enableTracking()
    } else {
        showConsentDialog { granted in
            if granted {
                enableTracking()
            }
        }
    }

    return true
}

func enableTracking() {
    // Set attribute to indicate consent for server-side processing
    Purchasely.setUserAttribute(withBoolValue: true, forKey: "gdpr_consent")
    Purchasely.setUserAttribute(withStringValue: ISO8601DateFormatter().string(from: Date()), forKey: "consent_date")
}
```

## Fetch Presentation with Type Guard

Always check the presentation type before displaying, especially when using `fetchPresentation`:

```swift
Purchasely.fetchPresentation(for: "PREMIUM_PAYWALL") { presentation, error in
    guard let presentation = presentation else {
        print("Failed to fetch: \(error?.localizedDescription ?? "")")
        return
    }

    switch presentation.type {
    case .normal, .fallback:
        // Safe to display
        if let controller = presentation.controller {
            self.present(controller, animated: true)
        }
    case .deactivated:
        // Do NOT display -- the presentation was disabled in the dashboard
        print("Presentation is deactivated")
    case .client:
        // Use your own UI with Purchasely plan data
        let plans = presentation.plans
        self.showCustomPaywall(plans: plans)
    @unknown default:
        break
    }
} completion: { result, plan in
    // Handle purchase result
}
```
