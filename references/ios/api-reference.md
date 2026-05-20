# iOS API Reference

## Initialization

### `Purchasely.start(withAPIKey:appUserId:runningMode:paywallActionsInterceptor:storekitSettings:logLevel:completion:)`

Initialize the SDK. Must be called on the main thread in `didFinishLaunchingWithOptions`.

```swift
Purchasely.start(withAPIKey: "YOUR_API_KEY",
                  appUserId: "user_123",          // optional, nil for anonymous
                  runningMode: .full,              // .full or .observer
                  paywallActionsInterceptor: nil,  // optional global interceptor
                  storekitSettings: .storeKit2,    // .storeKit1 or .storeKit2
                  logLevel: .debug,                // .debug, .info, .warn, .error
                  completion: { success, error in
    // SDK ready when success == true
})
```

## Paywall Presentation

### `Purchasely.display(...)` / `PLYPresentation.display(from:)`

Default display API for full-screen or modal paywalls and Flows. Prefer this unless the app explicitly needs to embed or push the Purchasely screen inside its own container.

```swift
Purchasely.fetchPresentation(for: "PLACEMENT_ID") { presentation, error in
    guard let presentation,
          presentation.type == .normal || presentation.type == .fallback else { return }

    presentation.display(from: self)
} completion: { result, plan in
    // result: .purchased, .restored, .cancelled
}
```

### `Purchasely.presentationController(for:contentId:loaded:completion:)`

Returns a `UIViewController` for the given placement. Use this only when the app needs to own the container: push onto a custom navigation stack, embed in SwiftUI via `UIViewControllerRepresentable`, host in a custom `UIWindow`, or render a nested/inline Purchasely Screen.

```swift
let controller = Purchasely.presentationController(
    for: "PLACEMENT_ID",
    contentId: "content_123",        // optional content ID for targeting
    loaded: { presentationController, isLoaded, error in
        // Called when the paywall content has loaded (or failed)
    },
    completion: { result, plan in
        // Called when the paywall is closed
        // result: .purchased, .restored, .cancelled
    }
)
present(controller, animated: true)
```

### `Purchasely.fetchPresentation(for:contentId:fetchCompletion:completion:)`

Fetch presentation metadata first, then decide whether to display it.

```swift
Purchasely.fetchPresentation(
    for: "PLACEMENT_ID",
    contentId: nil,
    fetchCompletion: { presentation, error in
        // Inspect presentation type, plans, metadata
        // presentation.type: .normal, .fallback, .deactivated, .client
        guard presentation?.type != .deactivated else { return }

        // Default Flow-safe display path
        presentation?.display(from: self)
    },
    completion: { result, plan in
        // Purchase result callback
    }
)
```

## Action Interceptor

### `Purchasely.setPaywallActionsInterceptor(handler:)`

Set a global interceptor for paywall actions. This allows you to intercept user actions (login, purchase, etc.) and inject custom behavior.

```swift
Purchasely.setPaywallActionsInterceptor { [weak self] action, parameters, presentationInfo, proceed in
    switch action {
    case .login:
        // Present your login screen
        self?.presentLogin { loggedIn in
            if loggedIn {
                Purchasely.userLogin(with: "user_id") { refresh in
                    return true // refresh the paywall
                }
            }
            proceed(loggedIn)
        }
    case .navigate:
        // Handle custom navigation
        if let url = parameters?.url {
            // Open URL
        }
        proceed(false) // don't close the paywall
    case .purchase:
        proceed(true) // let Purchasely handle the purchase
    case .restore:
        proceed(true) // let Purchasely handle the restore
    case .close:
        proceed(true) // allow closing
    default:
        proceed(true)
    }
}
```

**Important:** You must call `proceed()` in every code path. Failing to do so will freeze the paywall UI.

## Deeplinks

### `Purchasely.handleDeeplink(_:)`

Handle incoming deeplinks. Call this in your deeplink/universal link handler. Replaces the deprecated `isDeeplinkHandled`.

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
    return Purchasely.handleDeeplink(url)
}
```

### `Purchasely.readyToOpenDeeplink(_:)`

Indicate when the app is ready to display deeplinked content (e.g., after onboarding). Use `readyToOpenDeeplink` on the current 5.x SDK line.

```swift
// Call when your root view controller is ready
Purchasely.readyToOpenDeeplink(true)
```

## Presentation Result Handler

### `Purchasely.setDefaultPresentationResultHandler(handler:)`

Set a default handler for all paywall presentation results.

```swift
Purchasely.setDefaultPresentationResultHandler { result, plan in
    switch result {
    case .purchased:
        print("User purchased plan: \(plan?.vendorId ?? "")")
    case .restored:
        print("User restored purchases")
    case .cancelled:
        print("User cancelled")
    @unknown default:
        break
    }
}
```

## User Management

### `Purchasely.userLogin(with:shouldRefresh:)`

Identify the user after authentication. The `shouldRefresh` callback lets you decide whether to refresh the paywall after login.

```swift
Purchasely.userLogin(with: "user_123") { shouldRefresh in
    return true // return true to refresh current paywall
}
```

### `Purchasely.userLogout()`

Clear the current user identity. Call on sign-out.

```swift
Purchasely.userLogout()
```

## User Attributes

### `Purchasely.setUserAttribute(with*Value:forKey:)`

Set user attributes for audience targeting and personalization. Use the typed variant matching the value type.

```swift
Purchasely.setUserAttribute(withStringValue: "John", forKey: "first_name")
Purchasely.setUserAttribute(withStringValue: "gold", forKey: "loyalty_tier")
Purchasely.setUserAttribute(withIntValue: 30, forKey: "age")
Purchasely.setUserAttribute(withDoubleValue: 175.5, forKey: "height")
Purchasely.setUserAttribute(withBoolValue: true, forKey: "is_premium")
Purchasely.setUserAttribute(withDateValue: Date(), forKey: "signup_date")
```

To set multiple attributes at once:

```swift
Purchasely.setUserAttributes([
    "age": 30,
    "gender": "male",
    "loyalty_tier": "gold",
    "is_premium": true,
    "signup_date": Date()
])
```

## Subscriptions

### `Purchasely.userSubscriptions(success:failure:)`

Fetch the user's active subscriptions.

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

To force a cache refresh:

```swift
Purchasely.userSubscriptions(
    true,
    success: { subscriptions in ... },
    failure: { error in ... }
)
```

## Programmatic Purchases

Use this for app-side purchase buttons in Full mode. Fetch a `PLYPlan` first; there is no `purchase(planId:)` API.

```swift
Purchasely.plan(with: "premium_yearly") { plan in
    Purchasely.purchase(
        plan: plan,
        contentId: nil,
        success: {
            // Refresh premium state
        },
        failure: { error in
            // Surface purchase error
        }
    )
} failure: { error in
    // Surface plan lookup error
}
```

## Restore Purchases

### `Purchasely.restoreAllProducts(success:failure:)`

Restore the user's previous purchases. Should be triggered by a user action (e.g., a "Restore Purchases" button). May prompt the user to sign in on iOS.

```swift
Purchasely.restoreAllProducts(
    success: {
        print("Restore completed")
    },
    failure: { error in
        print("Restore failed: \(error?.localizedDescription ?? "")")
    }
)
```

## Close Screens

### `Purchasely.closeAllScreens()` *(SDK 5.7.5+)*

Force-dismiss any paywall currently on screen (including Flow paywalls with multiple steps). Use this instead of `closeDisplayedPresentation()` when you need to reliably tear down a paywall — for example after an Observer-mode purchase or when chaining a follow-up placement.

**Threading constraint:** the method is `@MainActor`-isolated. When called from a non-isolated synchronous context (inside a `DispatchQueue.main.async`, a `synchronize(success:)` callback, etc.), wrap it:

```swift
Task { @MainActor in
    Purchasely.closeAllScreens()
}
```

Calling it directly from a non-isolated context produces: *"Call to main actor-isolated class method 'closeAllScreens()' in a synchronous nonisolated context."*

**Ordering rule:** in the action interceptor, `proceed(false)` MUST be called BEFORE `closeAllScreens()` — the SDK needs to know not to proceed before the paywall tears down.

```swift
proceed(false)               // tell interceptor we handled it
Purchasely.closeAllScreens() // dismiss
```

## Synchronize

### `Purchasely.synchronize(success:failure:)`

Force a synchronization of the user's purchases with Purchasely servers. Use this for silent transfers (e.g., in Observer mode after a purchase). Unlike `restoreAllProducts`, this does not prompt the user.

```swift
Purchasely.synchronize(
    success: {
        print("Synchronization successful")
    },
    failure: { error in
        print("Synchronization failed: \(error?.localizedDescription ?? "")")
    }
)
```

**Swift Concurrency wrapper:** when you need to await sync before doing more work (e.g. chaining a follow-up placement that targets users based on their now-active subscription), bridge it with `withCheckedThrowingContinuation`:

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

By default the SDK runs `synchronize()` in the background — you do **not** need to await it before dismissing the paywall. Only await when the next step (e.g. fetching another placement whose audience targeting depends on the user's now-active subscription) needs the refreshed subscription state.

## Events

### `Purchasely.setEventDelegate(_:)`

Set a delegate to receive SDK events (paywall views, purchases, etc.). The `properties` argument is **optional** (`[String: Any]?`).

```swift
class MyEventDelegate: PLYEventDelegate {
    func eventTriggered(_ event: PLYEvent, properties: [String: Any]?) {
        print("Event: \(event.name) | Properties: \(properties ?? [:])")
        // Forward to your analytics provider
    }
}

Purchasely.setEventDelegate(MyEventDelegate())
```

> Delegate callbacks fire on unknown threads. Hop to the main actor via `Task { @MainActor in … }` (not `DispatchQueue.main.async`) when mutating UI state.

### `Purchasely.setUserAttributeDelegate(_:)`

React to user-attribute changes — useful to invalidate any app-side presentation cache, since attribute changes can alter audience targeting.

```swift
class MyAttributeDelegate: PLYUserAttributeDelegate {
    nonisolated func onUserAttributeSet(key: String, value: Any, source: PLYUserAttributeSource) {
        // Invalidate caches that depend on audience
    }
    nonisolated func onUserAttributeRemoved(key: String, source: PLYUserAttributeSource) {
        // Same
    }
}

Purchasely.setUserAttributeDelegate(MyAttributeDelegate())
```

## PLYPresentationAction Enum

Actions that can be intercepted from paywall user interactions:

| Action | Description |
|--------|-------------|
| `.purchase` | User tapped a purchase button |
| `.restore` | User tapped the restore button |
| `.login` | User tapped the login button |
| `.close` | User tapped the close button |
| `.navigate` | User tapped a custom navigation link |
| `.open_presentation` | User tapped a link to another presentation |
| `.promo_code` | User tapped the promo code button |

## PLYPresentationType Enum

Types returned when fetching a presentation:

| Type | Description |
|------|-------------|
| `.normal` | Standard presentation, ready to display |
| `.fallback` | Fallback presentation (network issue, original not found) |
| `.deactivated` | Presentation has been deactivated in the dashboard -- do not display |
| `.client` | Client-side presentation (use your own paywall with Purchasely data) |
