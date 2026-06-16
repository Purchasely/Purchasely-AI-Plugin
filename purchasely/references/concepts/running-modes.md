# Running Modes — Universal Concept

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

The SDK can run in one of two modes. The mode is set once at initialization and changes how the SDK handles the purchase flow.

## ⚠️ Default running mode changed in v6 (native iOS & Android)

This is the single most impactful change of SDK v6 and it is **silent** — the project keeps compiling.

| SDK version | Default running mode |
|-------------|----------------------|
| v5.x (and current React Native / Flutter / Cordova plugins) | **Full** |
| **v6.0.0-rc.1+ (native iOS & Android)** | **Observer** ⚠️ |

> 🚧 In v6, if your app relies on Purchasely to process purchases and validate receipts, you **must set the running mode to Full explicitly**. If you forget, the SDK still compiles and runs but **stops validating transactions**. In Observer mode, presentations also **no longer auto-close** after a purchase/restore (v5 Full auto-appended a `close_all`).

```swift
// iOS — set Full explicitly when Purchasely owns the purchase flow
Purchasely.apiKey("YOUR_API_KEY").runningMode(.full).start { error in }
```
```kotlin
// Android — set Full explicitly when Purchasely owns the purchase flow
Purchasely {
    context(applicationContext)
    apiKey("YOUR_API_KEY")
    stores(listOf(GoogleStore()))
    runningMode(PLYRunningMode.Full)
    onInitialized { error -> }
}
```

## The two modes

| Mode | Description | When to use |
|------|-------------|-------------|
| **Full** | Purchasely owns the entire purchase flow: it talks to StoreKit / Google Play Billing / Huawei IAP, validates the receipt, and reports the result. | Most apps. Use it unless you already have a custom billing stack. **Default in v5; must be set explicitly in v6.** |
| **Observer** (was `PaywallObserver` on Android in v5) | Your app owns the purchase flow. Purchasely only *displays* paywalls and *observes* the resulting transactions for analytics and SDK-level state. | You have an existing billing system (custom StoreKit 2 / Google Play Billing, another subscription platform, in-house IAP layer) and want Purchasely only for paywall presentation, A/B testing and analytics. **Default in v6 (native iOS & Android).** |

**Important:** in Observer mode, the [action interceptor](paywall-actions.md) **must** be wired up — otherwise nothing happens when the user taps a purchase button.

## Setting the mode

### iOS — Swift (v6)

```swift
do {
    try await Purchasely
        .apiKey("YOUR_API_KEY")
        .runningMode(.full)              // or .observer — default is .observer in v6
        .storekitSettings(.storeKit2)
        .logLevel(.warn)
        .start()
} catch {
    // handle initialization error
}

// Completion-handler form (also used from Objective-C):
Purchasely.apiKey("YOUR_API_KEY").runningMode(.full).start { error in }
```

### iOS — Objective-C (v6)

```objc
[[[Purchasely apiKey:@"YOUR_API_KEY"]
    runningMode:PLYRunningModeFull]      // or PLYRunningModeObserver
    startWithInitialized:^(NSError * _Nullable error) { }];
```

### Android — Kotlin (v6)

```kotlin
Purchasely {
    context(applicationContext)
    apiKey("YOUR_API_KEY")
    stores(listOf(GoogleStore()))
    runningMode(PLYRunningMode.Full)     // or PLYRunningMode.Observer — default is Observer in v6
    logLevel(LogLevel.WARN)
    onInitialized { error -> }
}
```

> `PLYRunningMode.PaywallObserver` (v5) was renamed `PLYRunningMode.Observer` in v6.

### Android — Java (v6)

```java
new Purchasely.Builder(getApplicationContext())
    .apiKey("YOUR_API_KEY")
    .stores(Collections.singletonList(new GoogleStore()))
    .runningMode(PLYRunningMode.Full)    // or PLYRunningMode.Observer
    .logLevel(LogLevel.WARN)
    .build()
    .start(error -> { });
```

### React Native (TypeScript) — v5 plugin

```ts
import Purchasely, { LogLevels, RunningMode } from 'react-native-purchasely';

await Purchasely.start({
  apiKey: 'YOUR_API_KEY',
  storeKit1: false,
  logLevel: LogLevels.WARNING,
  runningMode: RunningMode.FULL,        // or RunningMode.PAYWALL_OBSERVER
});
```

### Flutter (Dart)

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

await Purchasely.start(
  apiKey: 'YOUR_API_KEY',
  storeKit1: false,
  logLevel: PLYLogLevel.warning,
  runningMode: PLYRunningMode.full,     // or PLYRunningMode.paywallObserver
);
```

### Cordova (JavaScript) — v5 plugin

```js
Purchasely.start(
  'YOUR_API_KEY',
  ['Google'],
  false,
  null,
  Purchasely.LogLevel.WARN,
  Purchasely.RunningMode.full, // or paywallObserver
  success => {},
  error => {},
);
```

> **Cross-platform note.** React Native, Flutter, and Cordova plugins are still on the v5 API (default Full, `start({...})` / positional `start(...)`). Their v6 migrations are pending — keep their existing initialization. Always confirm the exact plugin signature in that platform's integration reference and in [`sdk-versions.md`](../sdk-versions.md).

## Log Levels

| Level | Description |
|-------|-------------|
| `debug` | Verbose — internal SDK state, network requests, presentation lifecycle. Use during development. |
| `info` | General informational messages. |
| `warn` | Warnings only. **Recommended default for production.** |
| `error` | Errors only — quietest level. **Native v6 default.** |

Enum names vary slightly by platform:

| Platform | Enum |
|----------|------|
| iOS | `LogLevel.debug` / `.info` / `.warn` / `.error` |
| Android | `LogLevel.DEBUG` / `.INFO` / `.WARN` / `.ERROR` |
| React Native | `LogLevels.DEBUG` / `.INFO` / `.WARNING` / `.ERROR` |
| Flutter | `PLYLogLevel.debug` / `.info` / `.warning` / `.error` |
| Cordova | `Purchasely.LogLevel.DEBUG` / `.INFO` / `.WARN` / `.ERROR` |

> On native Android v6, `Purchasely.logcatEnabled` controls Logcat output independently of `logLevel`, and custom loggers receive all messages regardless of level.

## See also

- [paywall-actions.md](paywall-actions.md) — what to do in Observer mode when the user taps Buy
- [observer-mode-post-purchase.md](observer-mode-post-purchase.md) — recommended sequence after a successful Observer-mode purchase
- [../ios/initialization.md](../ios/initialization.md) / [../android/initialization.md](../android/initialization.md) — full v6 initialization details
