# iOS SDK Initialization

## Installation

### CocoaPods

Add to your `Podfile`:

```ruby
pod 'Purchasely'
```

Then run:

```bash
pod install
```

### Swift Package Manager

Add the package URL in Xcode:

```
https://github.com/Purchasely/Purchasely-iOS
```

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Purchasely/Purchasely-iOS", from: "5.0.0")
]
```

## Import

```swift
import Purchasely
```

## SDK Initialization

Call `Purchasely.start()` in your `AppDelegate.didFinishLaunchingWithOptions` method, **on the main thread**:

```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    Purchasely.start(withAPIKey: "YOUR_API_KEY",
                      appUserId: nil,
                      runningMode: .full,
                      paywallActionsInterceptor: nil,
                      storekitSettings: .storeKit2,
                      logLevel: .debug) { success, error in
        if success {
            // SDK is ready
        } else {
            // Handle initialization error
            print("Purchasely init failed: \(error?.localizedDescription ?? "unknown")")
        }
    }

    return true
}
```

### SwiftUI App Lifecycle

If you use `@main` with a SwiftUI `App` struct, initialize in an `init()` method or use an `AppDelegate` adaptor:

```swift
@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Important Notes

- **Always call on the main thread** and in `didFinishLaunchingWithOptions`. Calling it later may cause missed events or deeplinks.
- The completion block confirms the SDK has fetched its configuration. You can display paywalls only after `success == true`.
- If `appUserId` is `nil`, Purchasely generates an anonymous user ID. Call `Purchasely.userLogin(with:)` later when the user authenticates.

## Running Modes

| Mode | Enum Value | Description |
|------|-----------|-------------|
| **Full** | `.full` | Purchasely SDK handles the entire purchase flow (recommended for most apps) |
| **Observer** | `.observer` | Your app handles purchases; Purchasely only observes transactions for analytics and paywall display |

### Full Mode (default)

```swift
Purchasely.start(withAPIKey: "YOUR_API_KEY",
                  runningMode: .full,
                  storekitSettings: .storeKit2) { success, error in }
```

### Observer Mode

Use this when you already have a purchase system (e.g., RevenueCat, custom StoreKit integration) and want Purchasely only for paywall presentation and analytics:

```swift
Purchasely.start(withAPIKey: "YOUR_API_KEY",
                  runningMode: .observer,
                  storekitSettings: .storeKit2) { success, error in }
```

## StoreKit Settings

| Setting | Enum Value | Description |
|---------|-----------|-------------|
| **StoreKit 2** | `.storeKit2` | Recommended. Uses the modern StoreKit 2 API (iOS 15+) |
| **StoreKit 1** | `.storeKit1` | Legacy StoreKit API. Use if you need to support iOS < 15 |

**Recommendation:** Use `.storeKit2` unless you have a specific reason to use StoreKit 1. StoreKit 2 provides better transaction handling, improved receipt validation, and native async/await support.

## Log Levels

| Level | Description |
|-------|-------------|
| `.debug` | Verbose logging for development |
| `.info` | General informational messages |
| `.warn` | Warnings only |
| `.error` | Errors only |

Use `.debug` during development and `.warn` or `.error` in production.
