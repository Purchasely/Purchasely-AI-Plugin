# Flutter Integration

## Published version: 5.7.3 (v5 API) — what to use today

> ⚠️ **The published Flutter package is `5.7.3`, which exposes the v5 API.** For any production integration today, pin `purchasely_flutter: 5.7.3` and use the v5 Dart surface: `Purchasely.start(...)`, `fetchPresentation` / `presentPresentation[ForPlacement]`, `setPaywallActionInterceptorCallback` + `onProcessAction`, and `closePresentation()`. See the [`purchasely-integrate` skill](../../skills/purchasely-integrate/SKILL.md) Flutter sections and the [v5 docs](https://docs.purchasely.com). Like React Native and Cordova, Flutter 5.7.3 sits on the **v5 bridge surface** (default Full mode, `onProcessAction`, `closePresentation()`).

## Preview: Flutter v6 builder API — ships in the final 2.0.0 release

> 🚧 **Everything below this point documents the Flutter v6 builder API, which is NOT published yet.** It ships with the final **2.0.0** release and is provided here as a **preview only** — do not treat these APIs as the current integration path. The paywall surface (start, display / preload / close, action interceptor) will move to a fluent builder API (`PurchaselyBuilder`, `PresentationBuilder` + `PresentationRequest`, `Purchasely.interceptAction`); the rest of the `Purchasely` class is unchanged. The preview packages carry `6.0.0-beta.0` version strings. See [`migration-v6.md`](./migration-v6.md) for the complete v5 → 2.0.0 old→new mapping (e.g. `Purchasely.start(...)` → `PurchaselyBuilder`, `fetchPresentation` / `presentPresentation` → `PresentationBuilder` + `PresentationRequest`, `setPaywallActionInterceptorCallback` / `onProcessAction` → `Purchasely.interceptAction`). There are no `v6` / `V6` symbols — the public Dart symbols keep their plain names.

> **Cross-platform reference.** This file covers Flutter-specific syntax. Many concepts (Observer-mode post-purchase flow, presentation type guard, presentation cache, programmatic purchases, audience-targeting attributes, GDPR consent, subscription checks) are **universal across iOS / Android / RN / Flutter / Cordova** and live in `../concepts/`. Load:
>
> - [`../concepts/running-modes.md`](../concepts/running-modes.md) — Full vs Observer + log levels
> - [`../concepts/paywall-actions.md`](../concepts/paywall-actions.md) — paywall action kinds + interceptor rules
> - [`../concepts/presentation-types.md`](../concepts/presentation-types.md) — `normal` / `fallback` / `deactivated` / `client` guard
> - [`../concepts/presentation-cache.md`](../concepts/presentation-cache.md) — app-side cache (recommended)
> - [`../concepts/observer-mode-post-purchase.md`](../concepts/observer-mode-post-purchase.md) — handling purchases in Observer mode, chaining follow-up placements
> - [`../concepts/programmatic-purchases.md`](../concepts/programmatic-purchases.md) — exact `purchaseWithPlanVendorId` syntax
> - [`../concepts/user-attributes-targeting.md`](../concepts/user-attributes-targeting.md) — audience targeting + GDPR consent
> - [`../concepts/privacy-settings.md`](../concepts/privacy-settings.md) — `revokeDataProcessingConsent` and privacy purposes
> - [`../concepts/subscription-checks.md`](../concepts/subscription-checks.md) — gating premium content, restore purchases
> - [`../sdk-versions.md`](../sdk-versions.md) — latest versions (pin to **5.7.3** for Flutter today; the v6 packages ship in the final 2.0.0 release)

## Installation

Requirements: iOS 11.0+, Android minSdk 21, compileSdk 33.

**For production today, pin all packages to `5.7.3`** (the published v5 release — see [`../sdk-versions.md`](../sdk-versions.md)):
```yaml
dependencies:
  purchasely_flutter: 5.7.3
  purchasely_google: 5.7.3
  purchasely_android_player: 5.7.3
```

The snippet below is the **preview** install for the upcoming v6 packages — they are **not published yet** and ship with the final 2.0.0 release.

```bash
# Core SDK (preview — not yet published)
flutter pub add purchasely_flutter:6.0.0-beta.0

# Google Play — required if targeting Google Play Store
flutter pub add purchasely_google:6.0.0-beta.0

# Video Player — optional, for video support in paywalls on Android
flutter pub add purchasely_android_player:6.0.0-beta.0
```

**CRITICAL: All Purchasely packages must be at the exact same version.** Check `pubspec.yaml`:
```yaml
dependencies:
  purchasely_flutter: 6.0.0-beta.0
  purchasely_google: 6.0.0-beta.0
  purchasely_android_player: 6.0.0-beta.0
```

> **Native dependency.** The published v5 plugin (`5.7.3`) pulls the **5.7.x** native SDKs. The preview v6 packages above will target the Purchasely 6.0 native SDKs (iOS `Purchasely 6.0.0`, Android `io.purchasely:core 6.0.0`) when they ship.

### iOS Setup

```bash
cd ios && pod install
```

### Android Setup

Edit `android/build.gradle`:
```groovy
buildscript {
    ext {
        minSdkVersion = 21
        compileSdkVersion = 33
        targetSdkVersion = 33
    }
}
allprojects {
    repositories {
        mavenCentral()
    }
}
```

## Import and Initialization

Start the SDK with the fluent `PurchaselyBuilder`. Only the API key is required; every other option has a sensible default. The builder replaces the old `Purchasely.start({...})` call.

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

Future<void> initializePurchasely() async {
  final bool started = await PurchaselyBuilder.apiKey('YOUR_API_KEY')
      .runningMode(RunningMode.full)               // RunningMode.observer (default) | full
      .logLevel(LogLevel.debug)                    // debug | info | warn | error
      .appUserId(null)                             // optional, set if user is already known
      .allowDeeplink(true)                         // allow the SDK to open deeplinks
      .stores([PLYStore.google])                   // Android: google | huawei | amazon
      .storekitVersion(StorekitVersion.storeKit2)  // iOS: storeKit2 (recommended) | storeKit1
      .start();

  if (started) {
    print('Purchasely SDK started');
  } else {
    print('Purchasely SDK failed to start');
  }
}
```

> **Default running mode changed.** With the 6.0 native SDK the default `RunningMode` is `RunningMode.observer` — the host app keeps control of the purchase flow. Pass `.runningMode(RunningMode.full)` to let Purchasely own the purchase flow.

Call this in your `main()` or root widget's `initState()`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializePurchasely();
  runApp(MyApp());
}
```

## Display a Paywall or Flow

`PresentationBuilder.placement(id).build()` returns a `PresentationRequest`. Call `display([Transition])` to show the screen; it resolves at **dismiss** with a `PresentationOutcome`. This replaces the old `fetchPresentation()` + `presentPresentation()` pair and handles Flows (close controls, step transitions) natively.

```dart
try {
  final outcome = await PresentationBuilder.placement('ONBOARDING')
      .contentId('my_content_id') // optional: associate content with the purchase
      .build()
      .display(const Transition.fullScreen());

  // outcome: presentation, purchaseResult, plan, closeReason, error
  if (outcome.error != null) {
    print('Display error: ${outcome.error!.message}');
  } else if (outcome.purchaseResult == PurchaseResult.purchased ||
      outcome.purchaseResult == PurchaseResult.restored) {
    print('User purchased ${outcome.plan}');
    // Update entitlements to unlock content
  } else {
    print('User dismissed: ${outcome.closeReason}'); // button | backSystem | programmatic
  }
} catch (e) {
  print('Presentation error: $e');
}
```

You can also target a specific screen or product:

```dart
// A specific presentation by screen id (was presentPresentationWithIdentifier)
await PresentationBuilder.screen('SCREEN_ID').build().display(const Transition.modal());

// A specific product (content) inside a screen (was presentProductWithIdentifier)
await PresentationBuilder.screen('SCREEN_ID').contentId('CONTENT_ID').build().display();
```

### Transitions

`display([Transition])` accepts an optional `Transition`:

```dart
const Transition.fullScreen();          // full-screen
const Transition.modal();               // modal sheet
const Transition.modal(dismissible: false);
const Transition.push();                // pushed onto the navigation stack
```

`TransitionType` also exposes `drawer`, `popin` and `inlinePaywall` for advanced layouts (with `heightPercentage` and `backgroundColors`).

### PresentationOutcome fields

| Field | Type | Description |
|-------|------|-------------|
| `presentation` | `Presentation?` | The displayed presentation (or `null` if it never reached display) |
| `purchaseResult` | `PurchaseResult?` | `purchased` \| `restored` \| `cancelled` \| `null` |
| `plan` | `Map<String, dynamic>?` | The purchased plan (when `purchaseResult` is `purchased` / `restored`) |
| `closeReason` | `CloseReason?` | `button` \| `backSystem` \| `programmatic` (when no purchase) |
| `error` | `PresentationError?` | Display error; mutually exclusive with `closeReason` |

### Inline Paywall with PLYPresentationView

Embed a paywall directly in your widget tree with the `PLYPresentationView` widget and a `PresentationRequest`. The widget preloads the request and hands the result to the native inline view (replaces the old `PurchaselyNativeView`).

```dart
import 'package:purchasely_flutter/native_view_widget.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

class InlinePaywallScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final request = PresentationBuilder.placement('INLINE_PAYWALL')
        .onDismissed((outcome) {
          if (outcome.purchaseResult == PurchaseResult.purchased) {
            // Handle purchase
          }
        })
        .build();

    return Scaffold(
      appBar: AppBar(title: Text('Premium')),
      body: PLYPresentationView(
        request: request,
        loadingBuilder: const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, error) => Text('Error: ${error.message}'),
      ),
    );
  }
}
```

## Action Interceptor

Intercept paywall actions to inject custom behavior. Register **one handler per action kind** with `Purchasely.interceptAction(kind, handler)`. The handler returns an `InterceptResult` that tells the SDK how the action was handled:

- `InterceptResult.success` — you handled the action successfully
- `InterceptResult.failed` — you tried to handle it but it failed
- `InterceptResult.notHandled` — let the SDK perform its default behaviour

This replaces the old `setPaywallActionInterceptorCallback` + `Purchasely.onProcessAction(bool)` pair — there is no more `onProcessAction`.

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

await Purchasely.interceptAction(
  PresentationActionKind.login,
  (info, payload) async {
    // Present your login screen
    final userId = await navigateToLogin();
    if (userId != null) {
      Purchasely.userLogin(userId);
      return InterceptResult.success;
    }
    return InterceptResult.failed;
  },
);

await Purchasely.interceptAction(
  PresentationActionKind.navigate,
  (info, payload) async {
    if (payload is NavigatePayload) {
      launchUrl(Uri.parse(payload.url));
      return InterceptResult.success;
    }
    return InterceptResult.notHandled;
  },
);

await Purchasely.interceptAction(
  PresentationActionKind.purchase,
  (info, payload) async {
    // In Full mode let Purchasely handle the purchase:
    return InterceptResult.notHandled;
  },
);
```

Action kinds (`PresentationActionKind`): `close`, `closeAll`, `login`, `navigate`, `purchase`, `restore`, `openPresentation`, `openPlacement`, `promoCode`, `webCheckout`. Each kind has a typed payload (`NavigatePayload`, `PurchasePayload`, `ClosePayload`, `CloseAllPayload`, `OpenPresentationPayload`, `OpenPlacementPayload`, `WebCheckoutPayload`); payload-less kinds (`login`, `restore`, `promoCode`) carry no extra fields.

### Removing interceptors

```dart
await Purchasely.removeInterceptor(PresentationActionKind.navigate);
await Purchasely.removeAllInterceptors();
```

## User Management

User identity, attributes, events, subscriptions, programmatic purchases and deeplinks are **unchanged** in 6.0 — same `Purchasely.*` signatures as before.

### Login

```dart
Purchasely.userLogin('user_123');
```

### Logout

```dart
Purchasely.userLogout();
```

## Programmatic Purchases

For app-side purchase buttons in Full mode, use `purchaseWithPlanVendorId` (unchanged). Do not use `Purchasely.purchase(planId: ...)`; that API is not exposed by the Flutter bridge.

```dart
final purchasedPlan = await Purchasely.purchaseWithPlanVendorId(
  vendorId: 'premium_yearly',
  offerId: null,
  contentId: null,
);
```

## User Attributes

Set attributes for audience targeting and personalization (unchanged):

```dart
// String attribute
Purchasely.setUserAttributeWithString('first_name', 'John');

// Number attribute
Purchasely.setUserAttributeWithInt('age', 30);
Purchasely.setUserAttributeWithDouble('score', 4.5);

// Boolean attribute
Purchasely.setUserAttributeWithBoolean('is_premium', true);

// Date attribute
Purchasely.setUserAttributeWithDate('signup_date', DateTime(2024, 1, 15));
```

## Events

Listen for SDK events (unchanged):

```dart
Purchasely.listenToEvents((event) {
  print('Event: ${event.name}');
  print('Properties: ${event.properties}');

  // Forward to your analytics provider
  analytics.track(event.name, event.properties);
});
```

## Subscriptions

Fetch the user's active subscriptions (unchanged):

```dart
final subscriptions = await Purchasely.userSubscriptions();
for (final sub in subscriptions) {
  print('Plan: ${sub.plan.vendorId}');
  print('Store: ${sub.subscriptionSource}');
}
```

> **`presentSubscriptions` is a no-op on Android in 6.0.** The native subscriptions screen was removed from the Android SDK, so `Purchasely.presentSubscriptions()` does nothing on Android. It still works on iOS. Build your own subscriptions screen with `userSubscriptions()` if you need cross-platform parity.

## Pre-fetching Screens

Build a `PresentationRequest`, `preload()` it to fetch the screen from the network, then `display()` the **same** request when you are ready (replaces `fetchPresentation` + `presentPresentation`).

```dart
try {
  final request = PresentationBuilder.placement('ONBOARDING').build();

  // Preload resolves once the screen is loaded
  final presentation = await request.preload();

  if (presentation.type == PresentationType.deactivated) {
    // No paywall to display for this placement — do NOT display
    return;
  }
  if (presentation.type == PresentationType.client) {
    // Display your own paywall (BYOS) — plan summaries are in presentation.plans
    showCustomPaywall(presentation.plans);
    return;
  }

  // Display the preloaded presentation; resolves at dismiss
  final outcome = await request.display(const Transition.fullScreen());

  if (outcome.purchaseResult == PurchaseResult.purchased ||
      outcome.purchaseResult == PurchaseResult.restored) {
    print('User purchased ${outcome.plan}');
  } else {
    print('Dismissed: ${outcome.closeReason}');
  }
} catch (e) {
  print(e);
}
```

`PresentationType` values: `normal` (default paywall), `fallback` (requested one not found), `deactivated` (no paywall), `client` (your own BYOS paywall).

### Presentation lifecycle (display / close / back)

A loaded `Presentation` (from `preload()`, or from `outcome.presentation`) exposes imperative controls:

```dart
final presentation = await PresentationBuilder.placement('ONBOARDING').build().preload();

presentation.display();  // show (resolves at dismiss)
presentation.close();    // dismiss programmatically (was closePresentation())
presentation.back();     // navigate back inside a multi-step (Flow) presentation
```

## Deeplinks

### Handle Incoming Deeplink

```dart
final handled = await Purchasely.isDeeplinkHandled('purchasely://your-deeplink-url');
if (handled) {
  // Purchasely will display the appropriate content
}
```

### Allow Deeplinks

Deeplink display is allowed via the start builder; `Purchasely.readyToOpenDeeplink(true)` still exists to toggle it at runtime.

```dart
await PurchaselyBuilder.apiKey('YOUR_API_KEY')
    .allowDeeplink(true)
    .start();
```

### Default Presentation Result Handler

Retrieve the result of user actions on presentations opened via deeplinks by attaching `onDismissed` to a default-source request (replaces `setDefaultPresentationResultHandler`):

```dart
PresentationBuilder.defaultSource()
    .onDismissed((outcome) {
      print('Deeplink presentation dismissed: ${outcome.purchaseResult} / ${outcome.closeReason}');
    })
    .build()
    .display();
```

## Synchronize Purchases

Force synchronization with Purchasely servers (unchanged):

```dart
await Purchasely.synchronize();
```

## Complete Integration Example

```dart
import 'package:flutter/material.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PurchaselyBuilder.apiKey('YOUR_API_KEY')
      .runningMode(RunningMode.full)
      .logLevel(LogLevel.debug)
      .stores([PLYStore.google])
      .storekitVersion(StorekitVersion.storeKit2)
      .allowDeeplink(true)
      .start();

  // Set up an action interceptor (one handler per kind)
  await Purchasely.interceptAction(
    PresentationActionKind.login,
    (info, payload) async {
      // Handle login, then:
      Purchasely.userLogin('USER_ID');
      return InterceptResult.success;
    },
  );

  // Listen for events
  Purchasely.listenToEvents((event) {
    print('PLY Event: ${event.name}');
  });

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  Future<void> _showPaywall() async {
    final outcome = await PresentationBuilder.placement('ONBOARDING')
        .build()
        .display(const Transition.fullScreen());

    if (outcome.error != null) {
      print('Error: ${outcome.error!.message}');
    } else if (outcome.purchaseResult == PurchaseResult.purchased ||
        outcome.purchaseResult == PurchaseResult.restored) {
      print('Purchased: ${outcome.plan}');
    } else {
      print('Dismissed: ${outcome.closeReason}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My App')),
      body: Center(
        child: ElevatedButton(
          onPressed: _showPaywall,
          child: Text('Show Paywall'),
        ),
      ),
    );
  }
}
```
