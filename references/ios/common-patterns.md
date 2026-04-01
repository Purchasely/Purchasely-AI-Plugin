# iOS Common Integration Patterns

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
                Purchasely.synchronize()
                proceed(true)
            }
        }
    case .restore:
        Purchases.shared.restorePurchases { info, error in
            Purchasely.synchronize()
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
                    Purchasely.synchronize()
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
            Purchasely.synchronize()
            proceed(true)
        }
    default:
        proceed(true)
    }
}
```

## Setting User Attributes for Targeting

Set attributes to enable audience targeting and paywall personalization:

```swift
// After user login or profile update
func updatePurchaselyAttributes(user: User) {
    Purchasely.setAttribute(.firstName, value: user.firstName)
    Purchasely.setAttribute(.email, value: user.email)
    Purchasely.setAttribute(.age, value: user.age)

    // Custom attributes for targeting rules
    Purchasely.setAttribute(.custom("subscription_tier"), value: user.tier)
    Purchasely.setAttribute(.custom("articles_read"), value: user.articlesRead)
    Purchasely.setAttribute(.custom("signup_date"), value: user.signupDate)
    Purchasely.setAttribute(.custom("is_power_user"), value: user.isPowerUser)
}
```

## Handling Subscription Status Checks

Check active subscriptions to gate content:

```swift
func checkSubscriptionAccess(completion: @escaping (Bool) -> Void) {
    Purchasely.userSubscriptions { subscriptions in
        let hasActiveSubscription = subscriptions?.contains { subscription in
            subscription.plan.vendorId == "premium_monthly" ||
            subscription.plan.vendorId == "premium_yearly"
        } ?? false
        completion(hasActiveSubscription)
    }
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
    Purchasely.setAttribute(.custom("gdpr_consent"), value: true)
    Purchasely.setAttribute(.custom("consent_date"), value: ISO8601DateFormatter().string(from: Date()))
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
