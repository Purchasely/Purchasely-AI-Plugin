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

### `Purchasely.presentationController(for:contentId:loaded:completion:)`

Returns a `UIViewController` for the given placement. Use this to push or present the paywall.

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

        // Display the presentation
        let controller = presentation?.controller
        self.present(controller!, animated: true)
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

### `Purchasely.allowDeeplink(_:)`

Indicate when the app is ready to display deeplinked content (e.g., after onboarding). Replaces the deprecated `readyToOpenDeeplink`.

```swift
// Call when your root view controller is ready
Purchasely.allowDeeplink(true)
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

### `Purchasely.setAttribute(_:value:)`

Set user attributes for audience targeting and personalization.

```swift
// Built-in attributes
Purchasely.setAttribute(.firstName, value: "John")
Purchasely.setAttribute(.lastName, value: "Doe")
Purchasely.setAttribute(.age, value: 30)
Purchasely.setAttribute(.gender, value: "male")

// Custom attributes
Purchasely.setAttribute(.custom("loyalty_tier"), value: "gold")
Purchasely.setAttribute(.custom("articles_read"), value: 42)
```

## Subscriptions

### `Purchasely.userSubscriptions`

Fetch the user's active subscriptions.

```swift
Purchasely.userSubscriptions { subscriptions in
    for subscription in subscriptions ?? [] {
        print("Plan: \(subscription.plan.vendorId)")
        print("Expires: \(subscription.subscriptionSource.nextRenewalDate)")
    }
}
```

## Synchronize

### `Purchasely.synchronize()`

Force a synchronization of the user's purchases with Purchasely servers.

```swift
Purchasely.synchronize()
```

## Events

### `Purchasely.setEventDelegate(_:)`

Set a delegate to receive SDK events (paywall views, purchases, etc.).

```swift
class MyEventDelegate: PLYEventDelegate {
    func eventTriggered(_ event: PLYEvent, properties: [String: Any]?) {
        print("Event: \(event.name)")
        // Forward to your analytics provider
    }
}

Purchasely.setEventDelegate(MyEventDelegate())
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
