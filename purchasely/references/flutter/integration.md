# Flutter Integration

Purchasely Flutter is on the **v6 API**, the same generation as the native iOS and Android SDKs. The plugin pins the **6.0.0-rc.1** pre-release on every layer: the three Dart packages (`purchasely_flutter`, `purchasely_google`, `purchasely_android_player`) are all `6.0.0-rc.1`, and they pull the published native SDKs (iOS `Purchasely 6.0.0-rc.1` on the CocoaPods trunk, Android `io.purchasely:core 6.0.0-rc.1` on Maven Central). All public Dart types carry the **`PLY` prefix** (`PLYPresentationBuilder`, `PLYPresentationRequest`, `PLYPresentationOutcome`, `PLYTransition`, …), aligning with the iOS/Android naming convention. The one exception is **SDK initialization**: the builder is started via `Purchasely.apiKey(...)` (a static method on `Purchasely` that returns a `PurchaselyBuilder`). This renaming landed on **2026-06-24** and is a **source-breaking change** for any existing v6 code that used unprefixed names.

Three areas changed shape from v5: **starting the SDK** (`Purchasely.apiKey(...)`), **displaying / preloading / closing a presentation** (`PLYPresentationBuilder` + `PLYPresentationRequest`), and the **action interceptor** (`Purchasely.interceptAction`). Everything else on the `Purchasely` class — purchases, restore, identity, catalog, subscriptions data, user attributes, events, dynamic offerings, consent and config — remains source-compatible. See [`migration-v6.md`](./migration-v6.md) for the full v5 → v6 old→new mapping.

> **Cross-platform reference.** This file covers Flutter-specific syntax. Many concepts (Observer-mode post-purchase flow, presentation type guard, presentation cache, programmatic purchases, audience-targeting attributes, GDPR consent, subscription checks) are **universal across iOS / Android / Flutter / RN / Cordova** and live in `../concepts/`. Load:
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
> - [`../sdk-versions.md`](../sdk-versions.md) — latest versions (pin Flutter to **6.0.0-rc.1**)

## Installation

Pin all three packages to the exact same version, `6.0.0-rc.1`:

```bash
# Core SDK
flutter pub add purchasely_flutter:6.0.0-rc.1

# Google Play — required if targeting Google Play Store
flutter pub add purchasely_google:6.0.0-rc.1

# Video Player — optional, for video support in paywalls on Android
flutter pub add purchasely_android_player:6.0.0-rc.1
```

**CRITICAL: All Purchasely packages must be at the exact same version, pinned exactly (never floating).** Check `pubspec.yaml`:

```yaml
dependencies:
  purchasely_flutter: 6.0.0-rc.1
  purchasely_google: 6.0.0-rc.1
  purchasely_android_player: 6.0.0-rc.1
```

> **Native dependency.** `purchasely_flutter 6.0.0-rc.1` pulls the **6.0.0-rc.1** native SDKs transitively — iOS `Purchasely 6.0.0-rc.1` (CocoaPods trunk) and Android `io.purchasely:core 6.0.0-rc.1` (Maven Central). Both are published, so the project builds from the public repositories with no `mavenLocal()` and no development pod. You do not bump the native pods/gradle dependencies yourself; the plugin's pinning is correct.

### iOS Setup

Minimum deployment target **iOS 13.4**. Install the pods:

```bash
cd ios && pod install --repo-update
```

### Android Setup

`compileSdk 36`, `targetSdk 35`, `minSdk 23`. Edit `android/build.gradle`:

```groovy
buildscript {
    ext {
        minSdkVersion = 23
        compileSdkVersion = 36
        targetSdkVersion = 35
    }
}
allprojects {
    repositories {
        mavenCentral()
    }
}
```

## Import and Initialization

Start the SDK with `Purchasely.apiKey(...)`. Only the API key is required; every other option has a sensible default. The builder replaces the old `Purchasely.start({...})` call.

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

Future<void> initializePurchasely() async {
  final bool started = await Purchasely.apiKey('YOUR_API_KEY')
      .appUserId(null)                                // optional, set if user is already known
      .runningMode(PLYRunningMode.full)               // PLYRunningMode.observer (default) | full
      .logLevel(PLYLogLevel.error)                    // debug | info | warn | error
      .stores([PLYStore.google])                      // Android: google | huawei | amazon
      .storekitVersion(PLYStorekitVersion.storeKit2)  // iOS: storeKit2 (recommended) | storeKit1
      .allowDeeplink(true)                            // allow the SDK to open deeplinks
      .allowCampaigns(true)                           // optional campaign display gate
      .start();

  if (started) {
    print('Purchasely SDK started');
  } else {
    print('Purchasely SDK failed to start');
  }
}
```

> **Default running mode changed.** With the 6.0 native SDK the default `PLYRunningMode` is `PLYRunningMode.observer` — the host app keeps control of the purchase flow. Pass `.runningMode(PLYRunningMode.full)` to let Purchasely own the purchase flow (purchase processing + validation, and auto-close after purchase/restore).

> **`PLYRunningMode` values.** The v6 enum has exactly **two** values: `PLYRunningMode.observer` (index 0, default) and `PLYRunningMode.full` (index 1). The v5 values `transactionOnly` and `paywallObserver` no longer exist — remove any reference to them.

Call this in your `main()` or root widget's `initState()`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializePurchasely();
  runApp(MyApp());
}
```

## Display a Paywall or Flow

`PLYPresentationBuilder.placement(id).build()` returns a `PLYPresentationRequest`. Call `display([PLYTransition])` to show the screen; it resolves at **dismiss** with a `PLYPresentationOutcome`. This replaces the old `fetchPresentation()` + `presentPresentation()` pair and handles Flows (close controls, step transitions) natively.

```dart
try {
  final outcome = await PLYPresentationBuilder.placement('ONBOARDING')
      .contentId('my_content_id') // optional: associate content with the purchase
      .build()
      .display(const PLYTransition.fullScreen());

  // outcome: presentation, purchaseResult, plan, closeReason, error
  if (outcome.error != null) {
    print('Display error: ${outcome.error!.message}');
  } else if (outcome.purchaseResult == PLYPurchaseResult.purchased ||
      outcome.purchaseResult == PLYPurchaseResult.restored) {
    print('User purchased ${outcome.plan?.name}');
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
await PLYPresentationBuilder.screen('SCREEN_ID').build().display(const PLYTransition.modal());

// A specific product (content) inside a screen (was presentProductWithIdentifier)
await PLYPresentationBuilder.screen('SCREEN_ID').contentId('CONTENT_ID').build().display();
```

### Lifecycle callbacks

Chain optional lifecycle callbacks on the builder before `.build()`:

```dart
final request = PLYPresentationBuilder.placement('ONBOARDING')
    .contentId('my_content_id')
    .onLoaded((presentation) => print('loaded: ${presentation.type}'))
    .onPresented((presentation) => print('presented'))
    .onCloseRequested(() => print('close requested'))
    .onDismissed((outcome) => print('dismissed: ${outcome.purchaseResult}'))
    .build();
```

### Transitions

`display([PLYTransition])` accepts an optional `PLYTransition`. Named factory constructors:

```dart
const PLYTransition.fullScreen();                   // full-screen (default)
const PLYTransition.modal();                        // modal sheet
const PLYTransition.modal(dismissible: false);
const PLYTransition.push();                         // pushed onto the navigation stack

// Sized transitions — use PLYTransitionDimension (replaces the old heightPercentage field):
const PLYTransition.drawer(height: PLYTransitionDimension.percentage(0.5));
const PLYTransition.drawer(height: PLYTransitionDimension.pixel(300));
const PLYTransition.popin(
  width: PLYTransitionDimension.pixel(320),
  height: PLYTransitionDimension.percentage(0.6),
  dismissible: false,
);
```

`PLYTransitionDimension` is either `.percentage(value)` (0.0–1.0) or `.pixel(value)`. Leave a dimension `null` to size to content ("hug"). The old `heightPercentage` field on `Transition` was **removed** — use the factory constructors above.

### PLYPresentationOutcome fields

| Field | Type | Description |
|-------|------|-------------|
| `presentation` | `PLYPresentation?` | The displayed presentation (or `null` if it never reached display) |
| `purchaseResult` | `PLYPurchaseResult?` | `purchased` \| `restored` \| `cancelled` \| `null` |
| `plan` | `PLYPlan?` | The purchased plan (when `purchaseResult` is `purchased` / `restored`) |
| `closeReason` | `PLYCloseReason?` | `button` \| `backSystem` \| `programmatic` (when no purchase) |
| `error` | `PLYPresentationError?` | Display error; mutually exclusive with `closeReason` |

> **iOS / Android `closeReason` parity.** Both native 6.0 SDKs expose `closeReason` on the outcome, and Flutter surfaces it on both platforms. iOS maps its interactive dismiss (swipe-down / nav-pop) to `backSystem` to stay aligned with Android's `BACK_SYSTEM`.

> **`PLYPlan` fields.** `outcome.plan` is a fully-typed `PLYPlan?` — the same model returned by `planWithIdentifier`. Access fields directly: `outcome.plan?.vendorId`, `outcome.plan?.name`, `outcome.plan?.amount`. The v6 SDK also exposes offer-price fields: `hasOfferPrice`, `offerPrice`, `offerAmount`, `offerDuration`, `offerPeriod` (the old `intro*` fields remain as deprecated aliases).

### Inline Paywall with PLYPresentationView

Embed a paywall directly in your widget tree with the `PLYPresentationView` widget and a `PLYPresentationRequest`. The widget preloads the request and hands the result to the native inline view (replaces the old `PurchaselyNativeView` / `getPresentationView`).

```dart
import 'package:purchasely_flutter/native_view_widget.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

class InlinePaywallScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final request = PLYPresentationBuilder.placement('INLINE_PAYWALL')
        .onDismissed((outcome) {
          if (outcome.purchaseResult == PLYPurchaseResult.purchased) {
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

Intercept paywall actions to inject custom behavior. Register **one handler per action kind** with `Purchasely.interceptAction(kind, handler)`. The handler returns a `PLYInterceptResult` that tells the SDK how the action was handled:

- `PLYInterceptResult.success` — you handled the action successfully
- `PLYInterceptResult.failed` — you tried to handle it but it failed
- `PLYInterceptResult.notHandled` — let the SDK perform its default behaviour

This replaces the old `setPaywallActionInterceptorCallback` + `Purchasely.onProcessAction(bool)` pair — there is no more `onProcessAction` and no single global callback. The model mirrors the native per-action `interceptAction`.

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

await Purchasely.interceptAction(
  PLYPresentationActionKind.login,
  (info, payload) async {
    // Present your login screen
    final userId = await navigateToLogin();
    if (userId != null) {
      Purchasely.userLogin(userId);
      return PLYInterceptResult.success;
    }
    return PLYInterceptResult.failed;
  },
);

await Purchasely.interceptAction(
  PLYPresentationActionKind.navigate,
  (info, payload) async {
    if (payload is PLYNavigatePayload) {
      launchUrl(Uri.parse(payload.url));
      return PLYInterceptResult.success;
    }
    return PLYInterceptResult.notHandled;
  },
);

await Purchasely.interceptAction(
  PLYPresentationActionKind.purchase,
  (info, payload) async {
    // In Full mode let Purchasely handle the purchase:
    return PLYInterceptResult.notHandled;
  },
);
```

Action kinds (`PLYPresentationActionKind`): `close`, `closeAll`, `login`, `navigate`, `purchase`, `restore`, `openPresentation`, `openPlacement`, `promoCode`, `webCheckout`. Each kind has a typed payload (`PLYNavigatePayload`, `PLYPurchasePayload`, `PLYClosePayload`, `PLYCloseAllPayload`, `PLYOpenPresentationPayload`, `PLYOpenPlacementPayload`, `PLYWebCheckoutPayload`); payload-less kinds (`login`, `restore`, `promoCode`) carry no extra fields.

### Removing interceptors

```dart
await Purchasely.removeActionInterceptor(PLYPresentationActionKind.navigate);
await Purchasely.removeAllActionInterceptors();
```

## User Management

User identity, attributes, events, subscriptions and programmatic purchases are **unchanged** in v6 — same `Purchasely.*` signatures as before.

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

> **`presentSubscriptions()` is REMOVED in v6 (BREAKING).** The native subscriptions screen was removed from the 6.0 SDKs on **both** platforms, so `Purchasely.presentSubscriptions()` has been **removed entirely** from the Flutter API — it is not a no-op, the method no longer exists. There is no drop-in replacement: build your own subscriptions screen from `userSubscriptions()` / `userSubscriptionsHistory()`.
>
> The cancellation survey UI was likewise removed, so `Purchasely.displaySubscriptionCancellationInstruction()` is kept for source compatibility but is a **no-op on both Android and iOS**.

## Pre-fetching Screens

Build a `PLYPresentationRequest`, `preload()` it to fetch the screen from the network, then `display()` the loaded `PLYPresentation` when you are ready (replaces `fetchPresentation` + `presentPresentation`).

**Pattern A — separate preload and display** (preload early, display later):

```dart
try {
  final request = PLYPresentationBuilder.placement('ONBOARDING').build();

  // Preload resolves once the screen is loaded
  final presentation = await request.preload();

  if (presentation.type == PLYPresentationType.deactivated) {
    // No paywall to display for this placement — do NOT display
    return;
  }
  if (presentation.type == PLYPresentationType.client) {
    // Display your own paywall (BYOS) — plan summaries are in presentation.plans
    showCustomPaywall(presentation.plans);
    return;
  }

  // Display the preloaded presentation; resolves at dismiss
  final outcome = await presentation.display(const PLYTransition.fullScreen());

  if (outcome.purchaseResult == PLYPurchaseResult.purchased ||
      outcome.purchaseResult == PLYPurchaseResult.restored) {
    print('User purchased ${outcome.plan?.name}');
  } else {
    print('Dismissed: ${outcome.closeReason}');
  }
} catch (e) {
  print(e);
}
```

**Pattern B — chained preload + display** (one expression):

```dart
final outcome = await PLYPresentationBuilder.placement('ONBOARDING')
    .build()
    .preload()
    .display(const PLYTransition.drawer(height: PLYTransitionDimension.percentage(0.5)));
```

`PLYPresentationType` values: `normal` (default paywall), `fallback` (requested one not found), `deactivated` (no paywall), `client` (your own BYOS paywall).

### Presentation lifecycle (display / close / back)

A loaded `PLYPresentation` (from `preload()`, or from `outcome.presentation`) exposes imperative controls:

```dart
final presentation = await PLYPresentationBuilder.placement('ONBOARDING').build().preload();

presentation.display();  // show (resolves at dismiss)
presentation.close();    // dismiss programmatically (was closePresentation())
presentation.back();     // navigate back inside a multi-step (Flow) presentation
```

## Deeplinks

v6 displays deeplinks and campaigns immediately by default. Allow or gate them on the builder, feed a **cold-start** deeplink via the builder's `handleDeeplink(...)`, and feed **runtime** deeplinks via `Purchasely.handleDeeplink(...)`.

### Allow Deeplinks

Deeplink display is allowed via the start builder; `Purchasely.allowDeeplink(bool)` toggles it at runtime.

```dart
await Purchasely.apiKey('YOUR_API_KEY')
    .allowDeeplink(true)
    .start();

// Toggle later at runtime:
await Purchasely.allowDeeplink(true);
```

### Cold-Start Deeplink (deeplink that launched the app)

When the app is **launched from** a deeplink, pass the captured URL to the start
builder's `handleDeeplink(String?)` modifier. The SDK resolves it automatically
once configured — **no separate `Purchasely.handleDeeplink(...)` call is needed**.

```dart
await Purchasely.apiKey('YOUR_API_KEY')
    .allowDeeplink(true)
    .handleDeeplink(launchDeeplink) // null when not launched from a deeplink
    .start();
```

`handleDeeplink(null)` (or omitting it) is a no-op. Mirrors native
`PurchaselyBuilder.handleDeeplink(_:)` (iOS) / `Purchasely.Builder.handleDeeplink(uri)` (Android).

### Handle Incoming Deeplink (runtime)

For a deeplink received while the app is already running, forward it at runtime:

```dart
final handled = await Purchasely.handleDeeplink('purchasely://your-deeplink-url');
if (handled) {
  // Purchasely will display the appropriate content
}
```

> **Events on a deeplink open:** `DEEPLINK_OPENED` → `PRESENTATION_LOADED` → `PRESENTATION_VIEWED`. `PRESENTATION_OPENED` is **not** emitted for a deeplink (only for in-paywall action opens).

> **`readyToOpenDeeplink` and `isDeeplinkHandled` were removed in v6.** Use `allowDeeplink` / `handleDeeplink` instead.

### Default Presentation Dismiss Handler

Receive results of presentations opened by the SDK itself (campaigns, deeplinks, promoted in-app purchases) via `Purchasely.setDefaultPresentationDismissHandler` (replaces `setDefaultPresentationResultHandler` / `setDefaultPresentationResultCallback`):

```dart
await Purchasely.setDefaultPresentationDismissHandler((outcome) {
  print('SDK presentation dismissed: ${outcome.presentation?.screenId} / '
      '${outcome.purchaseResult} / ${outcome.closeReason}');
});
```

## Synchronize Purchases

Force synchronization with Purchasely servers. In v6 `synchronize()` returns `Future<bool>` — it **resolves with `true` when synchronization completes** and **throws a `PlatformException` on failure** (the v5 fire-and-forget behaviour is gone). `await` it (and optionally `try/catch`) before chaining a follow-up presentation that targets subscribers:

```dart
try {
  final ok = await Purchasely.synchronize();
  // ok == true when synchronization completed successfully
} on PlatformException catch (e) {
  print('Synchronize failed: ${e.message}');
}
```

## Bridge & version alignment notes

- The Dart ↔ native bridge is still **MethodChannel** (`purchasely`) + **EventChannels** (`purchasely-events`, `purchasely-purchases`, `purchasely-user-attributes`). v6 changes the public Dart surface, not the bridge transport.
- **All three `purchasely_*` packages MUST be the exact same version** (`6.0.0-rc.1`). Mixing versions causes runtime crashes. Pin exactly — never floating (`^6.0.0`, `6.+`).
- Run a fresh install after pinning: `flutter clean && flutter pub get`, then `pod install --repo-update` (iOS) and `./gradlew --refresh-dependencies` (Android) as needed.
- See [`../sdk-versions.md`](../sdk-versions.md) for the canonical version table and [`./migration-v6.md`](./migration-v6.md) for the full v5 → v6 old→new mapping.

## Complete Integration Example

```dart
import 'package:flutter/material.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Purchasely.apiKey('YOUR_API_KEY')
      .runningMode(PLYRunningMode.full)
      .logLevel(PLYLogLevel.error)
      .stores([PLYStore.google])
      .storekitVersion(PLYStorekitVersion.storeKit2)
      .allowDeeplink(true)
      .allowCampaigns(true)
      .start();

  // Handle results for SDK-opened presentations (campaigns, deeplinks, promoted IAP)
  await Purchasely.setDefaultPresentationDismissHandler((outcome) {
    print('SDK presentation: ${outcome.purchaseResult} / ${outcome.closeReason}');
  });

  // Set up an action interceptor (one handler per kind)
  await Purchasely.interceptAction(
    PLYPresentationActionKind.login,
    (info, payload) async {
      // Handle login, then:
      Purchasely.userLogin('USER_ID');
      return PLYInterceptResult.success;
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
    final outcome = await PLYPresentationBuilder.placement('ONBOARDING')
        .build()
        .display(const PLYTransition.fullScreen());

    if (outcome.error != null) {
      print('Error: ${outcome.error!.message}');
    } else if (outcome.purchaseResult == PLYPurchaseResult.purchased ||
        outcome.purchaseResult == PLYPurchaseResult.restored) {
      print('Purchased: ${outcome.plan?.name}');
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
