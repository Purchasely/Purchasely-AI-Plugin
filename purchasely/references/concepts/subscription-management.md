# Subscription Management Page — Universal Patterns

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

A "Manage subscription" entry point is required by both Apple (App Store Review Guidelines §3.1.2) and Google (Play Console policy) for any auto-renewable subscription. The page is **owned by the store**, not by your app — your job is to open the right deeplink.

## What the page does

The native subscription management page lets the user:

- See the renewal date and price
- Upgrade, downgrade, or cross-grade within the subscription group
- Cancel auto-renewal (without losing access until the end of the period)
- Resubscribe to a lapsed subscription
- Apply offer codes (App Store) or redeem promo codes (Play Store)

Purchasely does not gate this — the SDK simply opens the OS-native URL.

## iOS

### iOS 15+ (recommended)

```swift
import StoreKit

@MainActor
func openManageSubscriptions() async {
    guard let scene = UIApplication.shared.connectedScenes
        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
    else { return }

    do {
        try await AppStore.showManageSubscriptions(in: scene)
    } catch {
        // Fall back to the URL below
        await UIApplication.shared.open(URL(string: "https://apps.apple.com/account/subscriptions")!)
    }
}
```

`AppStore.showManageSubscriptions(in:)` opens an in-app sheet — the user stays in your app.

### Universal fallback (all iOS versions, including macOS Catalyst)

```swift
if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
    UIApplication.shared.open(url)
}
```

This sends the user to the App Store app. Use this from contexts where you cannot reach a `UIWindowScene` (e.g. notification handlers).

## Android

The Google Play subscriptions page is opened via a Play Store deeplink. If you know the `productId` (the SKU / subscriptionId), prefer the per-product URL — it lands directly on the right subscription.

### Per-product deeplink (recommended)

```kotlin
fun openManageSubscription(context: Context, sku: String) {
    val packageName = context.packageName
    val uri = "https://play.google.com/store/account/subscriptions?sku=$sku&package=$packageName".toUri()
    val intent = Intent(Intent.ACTION_VIEW, uri).apply {
        // Optional: target Play Store explicitly
        setPackage("com.android.vending")
    }
    runCatching { context.startActivity(intent) }
        .onFailure {
            // Fall back to the general subscriptions list
            context.startActivity(Intent(Intent.ACTION_VIEW,
                "https://play.google.com/store/account/subscriptions".toUri()))
        }
}
```

### General subscriptions list

```kotlin
context.startActivity(Intent(Intent.ACTION_VIEW,
    "https://play.google.com/store/account/subscriptions".toUri()))
```

> Setting `setPackage("com.android.vending")` keeps the user inside the Play Store app instead of bouncing through a browser disambiguation. On devices without Play Store installed (Huawei, Amazon), the launch will fail — catch the `ActivityNotFoundException`.

## React Native (TypeScript)

```ts
import { Linking, Platform } from 'react-native';

async function openManageSubscription(sku?: string) {
  if (Platform.OS === 'ios') {
    await Linking.openURL('https://apps.apple.com/account/subscriptions');
  } else {
    const pkg = '<your.android.package.name>'; // from native-config or Application.applicationId
    const url = sku
      ? `https://play.google.com/store/account/subscriptions?sku=${sku}&package=${pkg}`
      : 'https://play.google.com/store/account/subscriptions';
    await Linking.openURL(url);
  }
}
```

## Flutter (Dart)

```dart
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

Future<void> openManageSubscription({String? sku, String? packageName}) async {
  late final Uri uri;
  if (Platform.isIOS) {
    uri = Uri.parse('https://apps.apple.com/account/subscriptions');
  } else {
    uri = sku != null && packageName != null
        ? Uri.parse('https://play.google.com/store/account/subscriptions?sku=$sku&package=$packageName')
        : Uri.parse('https://play.google.com/store/account/subscriptions');
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
```

## Cordova (JavaScript)

```js
function openManageSubscription(sku, packageName) {
  let url;
  if (cordova.platformId === 'ios') {
    url = 'https://apps.apple.com/account/subscriptions';
  } else {
    url = sku
      ? `https://play.google.com/store/account/subscriptions?sku=${sku}&package=${packageName}`
      : 'https://play.google.com/store/account/subscriptions';
  }
  cordova.InAppBrowser.open(url, '_system');
}
```

## Where to surface it

| Surface | Recommendation |
|---------|----------------|
| App settings → "Subscription" | Always. Required by store policy. |
| Paywall close action when the user is already a subscriber | Optional but reduces "how do I cancel" tickets. |
| Cancel-flow / win-back paywall | Wire it as a custom action — see the cancel-survey use case in [campaigns.md](campaigns.md). |

## Anti-patterns

- ❌ **Building a custom cancellation UI inside your app.** Stores reject apps that try to capture cancellation server-side instead of opening the native page (App Store §3.1.2).
- ❌ **Calling `Purchasely.restoreAllProducts()` to "cancel"**. Restore re-imports receipts — it does not cancel.
- ❌ **Hardcoding the Android package name.** Read it from `BuildConfig.APPLICATION_ID` (Android), `Bundle.main.bundleIdentifier` (iOS bridge), or your native-config layer (RN / Flutter). Hardcoded strings drift on rename.
- ❌ **Hiding the button behind audience targeting.** Subscription management must be reachable for any subscriber — including users you'd rather retain.

## See also

- [subscription-checks.md](subscription-checks.md) — show/hide the "Manage" button based on `userSubscriptions`
- [paywall-actions.md](paywall-actions.md) — wiring a custom `NAVIGATE` action from a paywall to this flow
- [campaigns.md](campaigns.md) — pairing the management entry point with a retention campaign
