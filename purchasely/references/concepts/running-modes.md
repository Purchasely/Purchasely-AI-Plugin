# Running Modes — Universal Concept

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

The SDK can run in one of two modes. The mode is set once at initialization and changes how the SDK handles the purchase flow.

## The two modes

| Mode | Description | When to use |
|------|-------------|-------------|
| **Full** (default) | Purchasely owns the entire purchase flow: it talks to StoreKit / Google Play Billing / Huawei IAP, validates the receipt, and reports the result. | Most apps. Recommended unless you already have a custom billing stack. |
| **Observer** (a.k.a. PaywallObserver) | Your app owns the purchase flow. Purchasely only *displays* paywalls and *observes* the resulting transactions for analytics and SDK-level state. | You have an existing billing system (custom StoreKit 2 / Google Play Billing, another subscription platform, in-house IAP layer) and want Purchasely only for paywall presentation, A/B testing and analytics. |

**Important:** in Observer mode, the [action interceptor](paywall-actions.md) **must** be wired up — otherwise nothing happens when the user taps a purchase button.

## Setting the mode

### iOS (Swift)

```swift
Purchasely.start(
    withAPIKey: "YOUR_API_KEY",
    runningMode: .full,                  // or .observer
    storekitSettings: .storeKit2,
    logLevel: .warn
) { success, error in }
```

### Android (Kotlin)

```kotlin
Purchasely.Builder(applicationContext)
    .apiKey("YOUR_API_KEY")
    .stores(listOf(GoogleStore()))
    .runningMode(PLYRunningMode.Full)    // or .PaywallObserver
    .logLevel(LogLevel.WARN)
    .build()
    .start { _, _ -> }
```

### React Native (TypeScript)

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

### Cordova (JavaScript)

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

## Log Levels

| Level | Description |
|-------|-------------|
| `debug` | Verbose — internal SDK state, network requests, presentation lifecycle. Use during development. |
| `info` | General informational messages. |
| `warn` | Warnings only. **Recommended default for production.** |
| `error` | Errors only — quietest level. |

Enum names vary slightly by platform:

| Platform | Enum |
|----------|------|
| iOS | `PLYLogger.LogLevel.debug` / `.info` / `.warn` / `.error` |
| Android | `LogLevel.DEBUG` / `.INFO` / `.WARN` / `.ERROR` |
| React Native | `LogLevels.DEBUG` / `.INFO` / `.WARNING` / `.ERROR` |
| Flutter | `PLYLogLevel.debug` / `.info` / `.warning` / `.error` |
| Cordova | `Purchasely.LogLevel.DEBUG` / `.INFO` / `.WARN` / `.ERROR` |

## See also

- [paywall-actions.md](paywall-actions.md) — what to do in Observer mode when the user taps Buy
- [observer-mode-post-purchase.md](observer-mode-post-purchase.md) — recommended sequence after a successful Observer-mode purchase
