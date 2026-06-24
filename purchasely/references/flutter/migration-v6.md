# Flutter — Migrating to the Purchasely 6.0 API

> **Published as a pre-release.** The Flutter v6 API ships in
> `purchasely_flutter: 6.0.0-rc.1` (and the matching `purchasely_google` /
> `purchasely_android_player` packages), live on pub.dev alongside the native
> iOS `Purchasely 6.0.0-rc.1` and Android `io.purchasely:core 6.0.0-rc.1`
> pre-releases. The builder-based API documented below (`Purchasely.apiKey(...)`,
> `PLYPresentationBuilder`, `Purchasely.interceptAction`) is the current published
> surface — the v5 API (`Purchasely.start(...)`, `fetchPresentation` /
> `presentPresentation[ForPlacement]`, `setPaywallActionInterceptorCallback` +
> `onProcessAction`, `closePresentation()`) is gone.

> **In-repo migration guide.** This is the Flutter-specific old→new mapping for the
> Purchasely 6.0 plugin. The companion integration reference is
> [`integration.md`](./integration.md); cross-platform concepts live in
> [`../concepts/`](../concepts/).

This release **adapts the Purchasely Flutter plugin to the Purchasely 6.0 native
SDKs** (iOS `Purchasely 6.0.0-rc.1`, Android `io.purchasely:core 6.0.0-rc.1`).

**All public Dart types now carry the `PLY` prefix** (`PLYPresentationBuilder`,
`PLYPresentationRequest`, `PLYPresentation`, `PLYTransition`, …), aligning with the iOS/Android naming convention. This
renaming landed on **2026-06-24** and is a **source-breaking change** — update all
imports and usages. See the [full rename table](#type-renames-ply-prefix) below.

Only three areas changed beyond the prefix: **starting the SDK**, **displaying /
preloading / closing a presentation**, and the **action interceptor**. Everything
else on the `Purchasely` class — purchases, restore, identity, catalog,
subscriptions, user attributes, events, dynamic offerings, consent and config —
is **unchanged**.

A paywall is now called a **Presentation** (or *Screen*).

---

## TL;DR

- Start the SDK via `Purchasely.apiKey('…').runningMode(PLYRunningMode.full).start()`.
- Build a presentation with `PLYPresentationBuilder`
  (`.placement(id)`, `.screen(id)`, `.defaultSource()`), then `.build()` to get
  a **`PLYPresentationRequest`** with a lifecycle (`preload()`,
  `display([PLYTransition])`).
- `display([PLYTransition])` resolves at **dismiss** with a 5-field
  **`PLYPresentationOutcome`** (`presentation`, `purchaseResult`, `plan`,
  `closeReason`, `error`).
- A loaded `PLYPresentation` exposes `display()`, `close()` and `back()` for
  programmatic control.
- The interceptor is now `Purchasely.interceptAction(kind, handler)`, where
  `handler` returns a `PLYInterceptResult` (`success` / `failed` / `notHandled`).
- Inline rendering uses the `PLYPresentationView` widget.
- **All other `Purchasely.*` methods are UNCHANGED** — see
  [What's unchanged](#whats-unchanged).

---

## Type renames (PLY prefix)

Every public Dart type now carries the `PLY` prefix. This is a **source-breaking
rename** — update all imports and usages.

> **Context.** These are v6-internal types that did not exist in v5. If you are
> migrating directly from v5, just use the `PLY*` names from the start — you
> never had the old names. This table is mainly useful for code that was already
> on an early v6 build (before 2026-06-24).

> **SDK init is not in this table.** `PurchaselyBuilder` (the fluent init
> builder) was not given the PLY prefix. It is accessed via
> `Purchasely.apiKey(...)` — see [Initialization](#initialization) below.

| Old early-v6 name | Final v6 name (PLY prefix) |
|---|---|
| `PresentationBuilder` | `PLYPresentationBuilder` |
| `PresentationRequest` | `PLYPresentationRequest` |
| `Presentation` | `PLYPresentation` |
| `PresentationType` | `PLYPresentationType` |
| `PresentationPlan` | `PLYPresentationPlan` |
| `PresentationError` | `PLYPresentationError` |
| `PresentationSource` | `PLYPresentationSource` |
| `PresentationSourceKind` | `PLYPresentationSourceKind` |
| `PresentationActionKind` | `PLYPresentationActionKind` |
| `PurchaseResult` | `PLYPurchaseResult` |
| `CloseReason` | `PLYCloseReason` |
| `RunningMode` | `PLYRunningMode` |
| `LogLevel` | `PLYLogLevel` |
| `StorekitVersion` | `PLYStorekitVersion` |
| `Transition` | `PLYTransition` |
| `TransitionType` | `PLYTransitionType` |
| `TransitionColors` | `PLYTransitionColors` |
| `InterceptResult` | `PLYInterceptResult` |
| `InterceptorInfo` | `PLYInterceptorInfo` |
| `ActionPayload` | `PLYActionPayload` |
| `ActionInterceptorHandler` | `PLYActionInterceptorHandler` |
| `NavigatePayload` | `PLYNavigatePayload` |
| `PurchasePayload` | `PLYPurchasePayload` |
| `ClosePayload` | `PLYClosePayload` |
| `CloseAllPayload` | `PLYCloseAllPayload` |
| `OpenPresentationPayload` | `PLYOpenPresentationPayload` |
| `OpenPlacementPayload` | `PLYOpenPlacementPayload` |
| `WebCheckoutPayload` | `PLYWebCheckoutPayload` |

**`PLYRunningMode` values changed.** The old (v5-era) `PLYRunningMode` had four
values: `transactionOnly`, `observer`, `paywallObserver`, `full`. The new enum
only has `observer` (index 0, default) and `full` (index 1). Any reference to
`PLYRunningMode.transactionOnly` or `PLYRunningMode.paywallObserver` must be
removed.

---

## Removed / changed API → new equivalent

These were the paywall-related entry points on the `Purchasely` class. They have
been removed in favour of the builder API.

| Old (`Purchasely.*`, removed) | New |
|-------------------------------|-----|
| `Purchasely.start(apiKey: …, androidStores: …, storeKit1: …, logLevel: …, runningMode: …, userId: …)` | `await Purchasely.apiKey('…').appUserId(userId).runningMode(PLYRunningMode.full).logLevel(PLYLogLevel.error).stores([PLYStore.google]).storekitVersion(PLYStorekitVersion.storeKit2).start()` |
| `Purchasely.fetchPresentation(placementId: id)` | `PLYPresentationBuilder.placement(id).build().preload()` |
| `Purchasely.presentPresentationForPlacement(id, isFullscreen: …)` | `PLYPresentationBuilder.placement(id).build().display(const PLYTransition.fullScreen())` |
| `Purchasely.presentPresentationWithIdentifier(presentationId, …)` | `PLYPresentationBuilder.screen(id).build().display(const PLYTransition.modal())` |
| `Purchasely.presentPresentation(presentation)` | preload then display: `final req = PLYPresentationBuilder.placement(id).build(); final p = await req.preload(); await p.display();` |
| `Purchasely.presentProductWithIdentifier(productId, …)` | `PLYPresentationBuilder.screen(id).contentId(contentId).build().display()` |
| `Purchasely.presentPlanWithIdentifier(planId, …)` | `PLYPresentationBuilder.screen(id).build().display()` |
| `Purchasely.getPresentationView(...)` | the `PLYPresentationView(request: …)` widget |
| `Purchasely.closePresentation()` / `hidePresentation()` / `close()` | `presentation.close()` (on the loaded `PLYPresentation`) |
| `Purchasely.showPresentation()` | `presentation.display()` (on the loaded `PLYPresentation`) |
| `Purchasely.clientPresentationDisplayed(...)` / `clientPresentationClosed(...)` | handled via the `PLYPresentationRequest` lifecycle (`preload` → inspect `PLYPresentationType.client` → render your own UI) |
| `Purchasely.setDefaultPresentationResultHandler(cb)` / `setDefaultPresentationResultCallback(cb)` | `Purchasely.setDefaultPresentationDismissHandler((outcome) => …)` — receives `PLYPresentationOutcome` |
| `Purchasely.setPaywallActionInterceptorCallback(cb)` + `Purchasely.onProcessAction(bool)` | `Purchasely.interceptAction(kind, handler)` — handler returns `PLYInterceptResult.success` / `.failed` / `.notHandled` (no more `onProcessAction`) |

> **Reminder.** Everything *not* in this table — purchases, restore, login,
> attributes, subscriptions, products, events, offerings, consent and config —
> keeps the exact same `Purchasely.*` signatures. Only the paywall surface moved.

---

## Initialization

### Before (v5)

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

bool configured = await Purchasely.start(
  apiKey: '<YOUR_API_KEY>',
  androidStores: ['Google'],
  storeKit1: false,
  logLevel: PLYLogLevel.error,
  runningMode: PLYRunningMode.full,
  userId: 'user_id',
);

Purchasely.readyToOpenDeeplink(true); // removed in v6; use allowDeeplink
```

### After (6.0)

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

final bool configured = await Purchasely.apiKey('<YOUR_API_KEY>')
    .appUserId('user_id')                          // optional, defaults to anonymous
    .runningMode(PLYRunningMode.full)              // PLYRunningMode.observer (default) | full
    .logLevel(PLYLogLevel.error)                   // debug | info | warn | error
    .allowDeeplink(true)                           // allow the SDK to open deeplinks
    .allowCampaigns(true)                          // optional campaign display gate
    .stores([PLYStore.google])                     // Android only: google | huawei | amazon
    .storekitVersion(PLYStorekitVersion.storeKit2) // iOS only: storeKit2 (default) | storeKit1
    .start();
```

> **Default running mode changed.** With the 6.0 native SDK the default
> `PLYRunningMode` is `PLYRunningMode.observer` — the host app keeps control of the
> purchase flow unless it opts into `PLYRunningMode.full`. Pass
> `.runningMode(PLYRunningMode.full)` to keep the previous behaviour where Purchasely
> owns the purchase flow.

> **`PLYRunningMode` values.** The v6 enum has exactly **two** values: `PLYRunningMode.observer` (index 0, default) and `PLYRunningMode.full` (index 1). Remove any reference to `transactionOnly` or `paywallObserver`.

> **`allowDeeplink` replaces `readyToOpenDeeplink`.** Allowing deeplinks is now part
> of the builder. `readyToOpenDeeplink` was **removed** in v6.

---

## Displaying a presentation

### Before (v5)

```dart
final result = await Purchasely.presentPresentationForPlacement(
  '<YOUR_PLACEMENT_ID>',
  contentId: 'my_content_id',
  isFullscreen: true,
);

switch (result.result) {
  case PLYPurchaseResult.purchased:
  case PLYPurchaseResult.restored:
    print('Purchased ${result.plan?.name}');
    break;
  case PLYPurchaseResult.cancelled:
    break;
}
```

### After (6.0)

`PLYPresentationBuilder.placement(id).build()` returns a `PLYPresentationRequest`.
Calling `display([PLYTransition])` shows the screen and resolves at **dismiss** with
a `PLYPresentationOutcome`.

```dart
final outcome = await PLYPresentationBuilder.placement('<YOUR_PLACEMENT_ID>')
    .contentId('my_content_id')
    .build()
    .display(const PLYTransition.fullScreen());

// outcome: presentation, purchaseResult, plan, closeReason, error
if (outcome.error != null) {
  print('Display error: ${outcome.error!.message}');
} else if (outcome.purchaseResult == PLYPurchaseResult.purchased ||
    outcome.purchaseResult == PLYPurchaseResult.restored) {
  print('Purchased ${outcome.plan?.name}');
} else {
  print('Dismissed: ${outcome.closeReason}'); // button | backSystem | programmatic
}
```

`purchaseResult` is the `PLYPurchaseResult` enum
(`purchased` / `cancelled` / `restored`) and is `null` when the user dismissed the
screen without a purchase action.

`plan` is a fully-typed **`PLYPlan?`** — the same model returned by
`planWithIdentifier`. Access fields directly (`outcome.plan?.vendorId`,
`outcome.plan?.name`, `outcome.plan?.amount`).

### Targeting a specific screen / product

```dart
// A specific presentation by screen id (was presentPresentationWithIdentifier)
await PLYPresentationBuilder.screen('SCREEN_ID').build().display(const PLYTransition.modal());

// A specific product / content inside a screen (was presentProductWithIdentifier)
await PLYPresentationBuilder.screen('SCREEN_ID').contentId('CONTENT_ID').build().display();
```

---

## Sized transitions (`drawer` / `popin`)

`Transition.heightPercentage` was **removed**. Use the named factory constructors
with `PLYTransitionDimension`, mirroring Android's `PLYTransitionDimension`:

```dart
// Before (v5 / removed):
// Transition(type: TransitionType.drawer, heightPercentage: 0.5);

// After — factory constructors:
const PLYTransition.drawer(height: PLYTransitionDimension.percentage(0.5));
const PLYTransition.drawer(height: PLYTransitionDimension.pixel(300));

const PLYTransition.popin(
  width: PLYTransitionDimension.pixel(320),
  height: PLYTransitionDimension.percentage(0.6),
  dismissible: false,
);
```

`PLYTransitionDimension` is either `.percentage(value)` (0.0–1.0) or `.pixel(value)`. Leave a dimension `null` to size to content ("hug").

Available factory constructors on `PLYTransition`:

| Constructor | Description |
|---|---|
| `PLYTransition.fullScreen()` | Full-screen (default) |
| `PLYTransition.modal({bool? dismissible})` | Modal sheet |
| `PLYTransition.push()` | Push / navigation |
| `PLYTransition.drawer({PLYTransitionDimension? height, bool? dismissible, PLYTransitionColors? backgroundColors})` | Bottom drawer with optional height |
| `PLYTransition.popin({PLYTransitionDimension? width, PLYTransitionDimension? height, bool? dismissible, PLYTransitionColors? backgroundColors})` | Floating pop-in with optional dimensions |

---

## Preloading (pre-fetch)

### Before (v5)

```dart
final presentation = await Purchasely.fetchPresentation(placementId: '<YOUR_PLACEMENT_ID>');
final result = await Purchasely.presentPresentation(presentation);
```

### After (6.0)

Build a `PLYPresentationRequest`, `preload()` it to fetch the screen from the
network, then `display()` the loaded `PLYPresentation` when you are ready.

**Pattern A — separate preload and display** (preload early, display later):

```dart
final request = PLYPresentationBuilder.placement('<YOUR_PLACEMENT_ID>').build();

final presentation = await request.preload(); // resolves when the screen is loaded

if (presentation.type == PLYPresentationType.deactivated) {
  return; // No paywall to display for this placement
}
if (presentation.type == PLYPresentationType.client) {
  return; // Display your own paywall (BYOS) — plan summaries are in presentation.plans
}

// Later, when ready to show it; resolves at dismiss
final outcome = await presentation.display(const PLYTransition.fullScreen());
```

**Pattern B — chained preload and display** (preload + display in one expression):

```dart
final outcome = await PLYPresentationBuilder.placement('<YOUR_PLACEMENT_ID>')
    .build()
    .preload()
    .display(const PLYTransition.drawer(height: PLYTransitionDimension.percentage(0.5)));
```

> `preload()` on `PLYPresentationRequest` returns `Future<PLYPresentation>`. The
> `display([PLYTransition?])` method is available both on `PLYPresentation`
> directly (Pattern A) and via a `Future<PLYPresentation>` extension (Pattern B).

---

## Presentation lifecycle (display / close / back)

The imperative `showPresentation` / `hidePresentation` / `closePresentation`
methods are replaced by methods on the loaded `PLYPresentation` handle (the one you
get from `preload()`, or from `outcome.presentation`):

```dart
final presentation = await PLYPresentationBuilder.placement('ONBOARDING').build().preload();

presentation.display();  // show (returns a future that resolves at dismiss)
presentation.close();    // dismiss programmatically
presentation.back();     // navigate back inside a multi-step (Flow) presentation
```

---

## Action interceptor

`setPaywallActionInterceptorCallback` + `onProcessAction` are replaced by
`Purchasely.interceptAction(kind, handler)`. Register **one handler per action
kind**; the handler returns a `PLYInterceptResult` (`success` / `failed` /
`notHandled`) instead of calling `onProcessAction(true/false)`.

### Before (v5)

```dart
Purchasely.setPaywallActionInterceptorCallback((info, action, parameters, processAction) {
  if (action == PLYPaywallAction.purchase) {
    MyPurchaseSystem.purchase(parameters.plan.productId);
    Purchasely.onProcessAction(false);
  } else {
    Purchasely.onProcessAction(true);
  }
});
```

### After (6.0)

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

await Purchasely.interceptAction(
  PLYPresentationActionKind.purchase,
  (info, payload) async {
    if (payload is PLYPurchasePayload) {
      final ok = await MyPurchaseSystem.purchase(payload.plan.productId);
      return ok ? PLYInterceptResult.success : PLYInterceptResult.failed;
    }
    return PLYInterceptResult.notHandled;
  },
);

await Purchasely.interceptAction(
  PLYPresentationActionKind.navigate,
  (info, payload) async {
    if (payload is PLYNavigatePayload) {
      // open payload.url with your router / url_launcher
      return PLYInterceptResult.success;
    }
    return PLYInterceptResult.notHandled;
  },
);

// Cleanup
await Purchasely.removeActionInterceptor(PLYPresentationActionKind.purchase);
await Purchasely.removeAllActionInterceptors();
```

Action kinds (`PLYPresentationActionKind`): `close`, `closeAll`, `login`,
`navigate`, `purchase`, `restore`, `openPresentation`, `openPlacement`,
`promoCode`, `webCheckout`. Each kind has a typed payload
(`PLYNavigatePayload`, `PLYPurchasePayload`, `PLYClosePayload`,
`PLYCloseAllPayload`, `PLYOpenPresentationPayload`, `PLYOpenPlacementPayload`,
`PLYWebCheckoutPayload`); payload-less kinds (`login`, `restore`, `promoCode`)
carry no extra fields.

---

## Deeplinks & default dismiss handler

```dart
// Allow deeplinks and campaigns at start:
await Purchasely.apiKey('<YOUR_API_KEY>')
    .allowDeeplink(true)
    .allowCampaigns(true)
    .start();

// These runtime gates are independent.
await Purchasely.allowDeeplink(true);
await Purchasely.allowCampaigns(false);

// Default dismiss handler (replaces setDefaultPresentationResultHandler).
// Receives results for presentations opened by the SDK: campaigns, deeplinks,
// promoted in-app purchases.
await Purchasely.setDefaultPresentationDismissHandler((outcome) {
  print('SDK presentation dismissed: ${outcome.presentation?.screenId} / '
      '${outcome.purchaseResult} / ${outcome.closeReason}');
});

// v6 deeplink handler:
final handled = await Purchasely.handleDeeplink('app://ply/presentations/');
```

> **`readyToOpenDeeplink` and `isDeeplinkHandled` were removed in v6.** Use `allowDeeplink` / `handleDeeplink` instead.

---

## Inline (embedded) presentations

To render a presentation inline inside your widget tree, use the
`PLYPresentationView` widget with a `PLYPresentationRequest`. The widget preloads
the request and hands the result to the native inline view.

```dart
import 'package:purchasely_flutter/native_view_widget.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

final request = PLYPresentationBuilder.placement('onboarding')
    .onDismissed((outcome) => print('inline dismissed: ${outcome.purchaseResult}'))
    .build();

// In your build():
PLYPresentationView(request: request);
```

---

## What's unchanged

Only the **paywall surface** (start, display / preload / close / back, and the
action interceptor) changed. Every other `Purchasely.*` method keeps the same
name, signature and behaviour:

- **Purchases**: `purchaseWithPlanVendorId`, `signPromotionalOffer`.
- **Restore**: `restoreAllProducts`, `silentRestoreAllProducts`,
  `userDidConsumeSubscriptionContent`.
- **Identity**: `userLogin`, `userLogout`, `isAnonymous`, `anonymousUserId`.
- **Catalog**: `allProducts`, `productWithIdentifier`, `planWithIdentifier`,
  `isEligibleForIntroOffer`.
- **Subscriptions data**: `userSubscriptions`, `userSubscriptionsHistory`,
  `displaySubscriptionCancellationInstruction` (see callout below).
- **User attributes**: `setUserAttributeWithString` / `WithInt` / `WithDouble` /
  `WithBoolean` / `WithDate` / `WithStringArray` / `WithIntArray` /
  `WithDoubleArray` / `WithBooleanArray`, `incrementUserAttribute`,
  `decrementUserAttribute`, `userAttribute`, `userAttributes`,
  `clearUserAttribute`, `clearUserAttributes`, `clearBuiltInAttributes`,
  `setAttribute`, `setUserAttributeListener` / `clearUserAttributeListener`.
- **Events**: `listenToEvents` / `stopListeningToEvents`, `listenToPurchases` /
  `stopListeningToPurchases`.
- **Dynamic offerings**: `setDynamicOffering`, `getDynamicOfferings`,
  `removeDynamicOffering`, `clearDynamicOfferings`.
- **Consent**: `revokeDataProcessingConsent`.
- **Config / misc**: `setLanguage`, `setThemeMode`, `setLogLevel`, `setDebugMode`,
  `allowDeeplink`, `allowCampaigns`, `handleDeeplink`.

> **`synchronize()` now reports completion (BREAKING signature).** The 6.0
> native SDKs expose success/error callbacks on `synchronize()`.
> `Purchasely.synchronize()` now returns **`Future<bool>`** (was `Future<void>`):
> it **resolves with `true` when synchronization actually completes** and
> **throws a `PlatformException` on failure**, instead of the previous
> fire-and-forget behaviour. `await` it (and optionally `try/catch`) before
> chaining a follow-up presentation that targets subscribers.

> **Removed `presentSubscriptions()` (BREAKING).** The native subscriptions
> screen was removed from the 6.0 SDKs on both platforms.
> `Purchasely.presentSubscriptions()` has therefore been **removed entirely**
> from the Flutter API — it is no longer a no-op, the method no longer exists.
> Build your own subscriptions screen with `userSubscriptions()` /
> `userSubscriptionsHistory()`.
>
> `Purchasely.displaySubscriptionCancellationInstruction()` is kept for source
> compatibility but is a **no-op on both Android and iOS**.

> **Removed deeplink helpers.** `readyToOpenDeeplink` and `isDeeplinkHandled`
> were **removed** in v6. Use `allowDeeplink` / `handleDeeplink` instead.

> **Native dependency.** This Flutter release targets the Purchasely v6 native SDKs
> (iOS `Purchasely 6.0.0-rc.1`, Android `io.purchasely:core 6.0.0-rc.1`), published as pre-releases
> on CocoaPods / Maven Central — see [`../sdk-versions.md`](../sdk-versions.md) for the canonical
> pins. The published **Flutter** package is `purchasely_flutter: 6.0.0-rc.1`, pinned exactly
> to those native versions.
