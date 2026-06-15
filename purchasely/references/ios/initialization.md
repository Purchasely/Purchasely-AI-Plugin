# iOS SDK Initialization

> Documents the **v6.0.0-rc1** fluent initialization builder. Migrating from v5? See [`migration-v6.md`](migration-v6.md). Universal concepts (running modes, log levels, etc.) also live in [`../concepts/`](../concepts/README.md).

## Installation

### CocoaPods

Add to your `Podfile`:

```ruby
pod 'Purchasely', '6.0.0-rc1'
```

Then run:

```bash
pod install
```

### Swift Package Manager

Add the package URL in Xcode (File ▸ Add Packages ▸ enter the URL):

```
https://github.com/Purchasely/Purchasely-iOS
```

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Purchasely/Purchasely-iOS", exact: "6.0.0-rc1")
]
```

## Import

```swift
import Purchasely
```

> For Swift 6 strict concurrency, use `@preconcurrency import Purchasely` at call sites that touch SDK types from a `@MainActor` context. See [`migration-v6.md`](migration-v6.md).

## SDK Initialization — fluent builder

The v5 one-shot `Purchasely.start(withAPIKey:…)` is **removed**. Start with `Purchasely.apiKey(_:)`, chain modifiers, finish with `start()`. Call it in `AppDelegate.didFinishLaunchingWithOptions`, **on the main thread**.

> ⚠️ **The default running mode changed from `.full` (v5) to `.observer` (v6).** This change is silent — your code compiles, but the SDK stops validating purchases. **If you want Purchasely to handle and validate purchases, set `.runningMode(.full)` explicitly.** In Observer mode, presentations also no longer auto-close after purchase/restore.

### Swift — async (recommended)

```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    Task {
        do {
            try await Purchasely
                .apiKey("YOUR_API_KEY")
                .appUserId(nil)                 // optional, nil for anonymous
                .runningMode(.full)             // ← REQUIRED for purchase handling/validation; default is .observer
                .storekitSettings(.storeKit2)
                .logLevel(.debug)
                .start()
            // SDK is configured — refresh entitlements, etc.
        } catch {
            print("Purchasely init failed: \(error.localizedDescription)")
        }
    }
    return true
}
```

### Swift — completion handler

```swift
Purchasely
    .apiKey("YOUR_API_KEY")
    .runningMode(.full)
    .storekitSettings(.storeKit2)
    .logLevel(.debug)
    .start { error in
        if let error {
            print("Purchasely init failed: \(error.localizedDescription)")
        } else {
            // SDK is configured
        }
    }
```

The completion receives a single optional `Error` (`nil` on success) — there is no `Bool success` parameter anymore. The callback dispatches on the main actor.

### Objective-C

```objc
[[[[Purchasely apiKey:@"YOUR_API_KEY"]
    appUserId:nil]
    runningMode:PLYRunningModeFull]
    startWithInitialized:^(NSError * _Nullable error) {
        if (error == nil) {
            // SDK is configured
        }
    }];
```

### SwiftUI App Lifecycle

If you use `@main` with a SwiftUI `App` struct, initialize in an `init()` or use an `AppDelegate` adaptor:

```swift
@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

## Chain modifiers and defaults

| Modifier | Default | Notes |
|----------|---------|-------|
| `apiKey(_:)` | — | Required; entry point. Empty key throws `PLYError.configuration` |
| `appUserId(_:)` | `nil` | Anonymous if nil; call `Purchasely.userLogin(with:)` later |
| `runningMode(_:)` | `.observer` ⚠️ | **Was `.full` in v5.** Set `.full` for purchase handling/validation |
| `storekitSettings(_:)` | `.storeKit2` | `.storeKit1` or `.storeKit2` |
| `logLevel(_:)` | `.error` | `.debug` / `.info` / `.warn` / `.error` |
| `environment(_:)` | `.prod` | |
| `themeMode(_:)` | `.system` | |
| `allowDeeplink(_:)` | `true` | Deeplinks display immediately; pass `false` to defer until `Purchasely.allowDeeplink(true)` |
| `allowCampaigns(_:)` | `true` | Campaigns display immediately; pass `false` to defer until `Purchasely.allowCampaigns(true)` |
| `handleDeeplink(_:)` | unset | Pass a cold-start deeplink to display once the SDK has started |

> 📘 The pre-`start` class funcs `setEnvironment(_:)`, `setShowPromotedInAppPurchasePaywall(_:)`, `setAppTechnology(_:)`, `setSdkBridgeVersion(_:)`, `setThemeMode(_:)` are **deprecated** (removal in v7). Use the chain modifiers above instead.

## Important Notes

- **Always call on the main thread** and in `didFinishLaunchingWithOptions`. Calling it later may cause missed events or deeplinks.
- The completion / `await` confirms the SDK has fetched its configuration. Display paywalls only after it returns without error.
- If `appUserId` is `nil`, Purchasely generates an anonymous user ID. Call `Purchasely.userLogin(with:)` later when the user authenticates.

## Running Modes

| Mode | Swift | Objective-C | Description |
|------|-------|-------------|-------------|
| **Full** | `.full` | `PLYRunningModeFull` | Purchasely handles and validates the entire purchase flow |
| **Observer** | `.observer` | `PLYRunningModeObserver` | Your app handles purchases; Purchasely observes transactions for analytics and paywall display |

### Full Mode

```swift
try await Purchasely
    .apiKey("YOUR_API_KEY")
    .runningMode(.full)
    .storekitSettings(.storeKit2)
    .start()
```

### Observer Mode (the v6 default)

Use this when you already have a purchase system (e.g. another subscription platform or a custom StoreKit integration) and want Purchasely only for paywall presentation and analytics. Pair it with per-action interceptors for `.purchase` / `.restore` (see [`common-patterns.md`](common-patterns.md)):

```swift
try await Purchasely
    .apiKey("YOUR_API_KEY")
    .runningMode(.observer)         // also the default if omitted
    .storekitSettings(.storeKit2)
    .start()
```

## StoreKit Settings

| Setting | Enum Value | Description |
|---------|-----------|-------------|
| **StoreKit 2** | `.storeKit2` | Default. Modern StoreKit 2 API (iOS 15+) |
| **StoreKit 1** | `.storeKit1` | Legacy StoreKit API. Use if you must support iOS < 15 |

**Recommendation:** use `.storeKit2` unless you have a specific reason to use StoreKit 1.

## Log Levels

| Level | Description |
|-------|-------------|
| `.debug` | Verbose logging for development |
| `.info` | General informational messages |
| `.warn` | Warnings only |
| `.error` | Errors only (the default) |

Use `.debug` during development and `.warn` or `.error` in production.
