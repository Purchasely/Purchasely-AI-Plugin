# React Native Integration

Purchasely React Native is on the **v6 API**, the same generation as the native iOS and Android SDKs. The plugin pins **`6.2.0`** (stable GA) on every layer: all five npm packages (`react-native-purchasely`, `@purchasely/react-native-purchasely-google`, `@purchasely/react-native-purchasely-android-player`, `@purchasely/react-native-purchasely-amazon`, `@purchasely/react-native-purchasely-huawei`) are `6.2.0`, and they pull the published native SDKs (iOS `Purchasely 6.2.0` on the CocoaPods trunk, Android `io.purchasely:core 6.2.0` on Maven Central, both pinned in the `6.2.0` tag). The public JS/TS symbols are **`PLY`-prefixed** (`Purchasely.builder`, `PLYPresentationBuilder`, `PLYPresentationRequest`, `PLYLoadedPresentation`, `PLYPresentationOutcome`, `PLYTransition`, …) — there are no `v6` / `V6` symbols.

Three areas changed shape from v5: **starting the SDK** (`Purchasely.builder(apiKey)`), **displaying / preloading / closing a presentation** (`Purchasely.presentation` + `PLYPresentationRequest`), and the **action interceptor** (`Purchasely.interceptAction`). Everything else on the `Purchasely` default export — purchases, restore, identity, catalog, subscriptions data, user attributes, events, dynamic offerings, consent and config — remains source-compatible. Note the **deeplink API changed**: `isDeeplinkHandled` / `readyToOpenDeeplink` are **removed** (no alias) — use `Purchasely.handleDeeplink(uri)` and `Purchasely.allowDeeplink(bool)`. See [`migration-v6.md`](./migration-v6.md) for the full v5 → v6 old→new mapping.

> **Cross-platform reference.** This file covers React Native-specific syntax. Many concepts (Observer-mode post-purchase flow, presentation type guard, presentation cache, programmatic purchases, audience-targeting attributes, GDPR consent, subscription checks) are **universal across iOS / Android / RN / Flutter / Cordova** and live in `../concepts/`. Load:
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
> - [`../sdk-versions.md`](../sdk-versions.md) — latest versions (pin React Native to **6.2.0**)

## Installation

Pin all packages to the exact same version, `6.2.0`. Use `--save-exact`. `6.2.0` is stable GA, so a floating range (`^6.2.0`, `6.x`) would resolve too, but an exact pin keeps every Purchasely package in lockstep.

```bash
# Core SDK
npm install react-native-purchasely@6.2.0 --save-exact

# Google Play — required if targeting Google Play Store
npm install @purchasely/react-native-purchasely-google@6.2.0 --save-exact

# Video Player — optional, for video support in paywalls on Android
npm install @purchasely/react-native-purchasely-android-player@6.2.0 --save-exact

# Amazon Appstore — optional, Android alt store
npm install @purchasely/react-native-purchasely-amazon@6.2.0 --save-exact

# Huawei AppGallery — optional, Android alt store
npm install @purchasely/react-native-purchasely-huawei@6.2.0 --save-exact
```

**CRITICAL: All Purchasely packages must be at the exact same version, pinned exactly (never floating).** Check `package.json`:

```json
{
  "dependencies": {
    "react-native-purchasely": "6.2.0",
    "@purchasely/react-native-purchasely-google": "6.2.0",
    "@purchasely/react-native-purchasely-android-player": "6.2.0"
  }
}
```

> **Toolchain.** The v6 React Native SDK is built and tested against **React Native 0.86** and **Node 22** (`.nvmrc` → `v22`).

> **Native dependency.** `react-native-purchasely 6.2.0` pulls the native SDKs transitively: iOS `Purchasely 6.2.0` (CocoaPods trunk) and Android `io.purchasely:core 6.2.0` (Maven Central). The toolchain floors (iOS 15.1, `minSdkVersion 23`) did not change since 6.0.0. Both are published stable GA releases, so the project builds from the public repositories. You do not bump the native pods/gradle dependencies yourself; the plugin's pinning is correct.

### iOS Setup

Minimum deployment target **iOS 15.1**. Install the pods:

```bash
cd ios && pod install --repo-update
```

### Android Setup

The v6 native module requires **`minSdkVersion 23`** (bumped from 21) and builds against **`compileSdk 35`**. Align `compileSdk` / `targetSdk` with your existing app (35+). Edit `android/build.gradle`:

```groovy
buildscript {
    ext {
        minSdkVersion = 23
        compileSdkVersion = 35
        targetSdkVersion = 35
    }
}
allprojects {
    repositories {
        mavenCentral()
    }
}
```

Android stores are picked via the `stores([...])` builder call (Google by default); the optional `@purchasely/react-native-purchasely-amazon` / `-huawei` packages add the Amazon and Huawei store bindings.

## Import and Initialization

Start the SDK with the fluent `Purchasely.builder(apiKey)` (aliased as `Purchasely.apiKey(apiKey)`). Only the API key is required; every other option has a sensible default and is passed as a **string** (not an enum). The builder replaces the old `Purchasely.start({...})` call and returns `Promise<boolean>`.

```typescript
import Purchasely from 'react-native-purchasely';

async function initializePurchasely() {
  try {
    const started = await Purchasely.builder('YOUR_API_KEY')
      .appUserId('user_id')          // optional, defaults to anonymous
      .runningMode('full')           // 'observer' (default) | 'full'
      .logLevel('error')             // 'debug' | 'info' | 'warn' | 'error'
      .allowDeeplink(true)           // replaces readyToOpenDeeplink(true)
      .allowCampaigns(true)          // automatic campaigns (default true)
      .handleDeeplink(coldStartUri)  // optional: replay a cold-start deeplink after start()
      .stores(['google'])            // Android only: 'google' | 'huawei' | 'amazon'
      .storekitVersion('storeKit2')  // iOS only: 'storeKit1' | 'storeKit2' (default storeKit2)
      .start();

    console.log('Purchasely started:', started);
  } catch (error) {
    console.error('Purchasely init failed:', error);
  }
}
```

> **Default running mode changed.** With the 6.0 native SDK the default `runningMode` is `'observer'` — the host app keeps control of the purchase flow. Pass `.runningMode('full')` to let Purchasely own the purchase flow (purchase processing + validation, and auto-close after purchase/restore). This is a **silent behavioural change** (no compile error): an app that previously relied on the implicit Full mode will stop owning the purchase flow after upgrading unless it passes `.runningMode('full')` explicitly.

> **`.handleDeeplink(uri)` on the builder** is for a **cold-start** deeplink captured at launch (Android intent / iOS scene connection options): the SDK replays it automatically once `start()` completes. For deeplinks that arrive at runtime, call `Purchasely.handleDeeplink(uri)` directly (see [Deeplinks](#deeplinks)).

Call it from your app entry point (`App.tsx` / root `useEffect`):

```typescript
import React, { useEffect } from 'react';

export default function App() {
  useEffect(() => {
    initializePurchasely();
  }, []);
  // …
}
```

## Display a Paywall or Flow

`Purchasely.presentation` is the **`PLYPresentationBuilder`**. `Purchasely.presentation.placement(id).build()` returns a **`PLYPresentationRequest`**. Call `display([transition])` to show the screen; it resolves at **dismiss** with a `PLYPresentationOutcome`. This replaces the old `fetchPresentation()` + `presentPresentation()` pair and handles Flows (close controls, step transitions) natively.

```typescript
import Purchasely from 'react-native-purchasely';

try {
  const outcome = await Purchasely.presentation
    .placement('ONBOARDING')
    .contentId('my_content_id') // optional: associate content with the purchase
    .build()
    .display();

  // outcome: { presentation, purchaseResult, plan, closeReason, error }
  if (outcome.error) {
    console.error('Display error:', outcome.error.message);
  } else if (
    outcome.purchaseResult === 'purchased' ||
    outcome.purchaseResult === 'restored'
  ) {
    console.log('User purchased', outcome.plan?.name);
    // Update entitlements to unlock content
  } else {
    console.log('User dismissed:', outcome.closeReason); // 'button' | 'backSystem' | 'programmatic'
  }
} catch (error) {
  console.error('Presentation error:', error);
}
```

`purchaseResult` is a **string union** (`'purchased' | 'cancelled' | 'restored' | null`), not the old `ProductResult` ordinal enum.

The builder exposes three factories: `.placement(id)`, `.screen(id)`, and `.defaultSource()` (canonical) / `.default()` (alias, kept for parity with the iOS native API):

```typescript
// A specific presentation by screen id (was presentPresentationWithIdentifier)
await Purchasely.presentation.screen('SCREEN_ID').build().display();

// A specific product (content) inside a screen (was presentProductWithIdentifier)
await Purchasely.presentation.screen('SCREEN_ID').contentId('CONTENT_ID').build().display();

// The SDK's default placement
await Purchasely.presentation.defaultSource().build().display();
```

### Lifecycle callbacks

Chain optional lifecycle callbacks on the builder before `.build()`:

```typescript
const request = Purchasely.presentation
  .placement('ONBOARDING')
  .contentId('my_content_id')
  .onLoaded((presentation, error) => console.log('loaded:', presentation?.type))
  .onPresented((presentation) => console.log('presented'))
  .onCloseRequested(() => console.log('close requested'))
  .onDismissed((outcome) => console.log('dismissed:', outcome.purchaseResult))
  .build();
```

You can also tune the look on the builder: `.backgroundColor(hex)`, `.progressColor(hex)`, `.displayCloseButton(bool)` and `.displayBackButton(bool)`.

> **`displayCloseButton` / `displayBackButton` platform semantics.** Both are wired on **both** platforms.
> - **Android** — full toggle: `true` shows the button, `false` hides it.
> - **iOS** — removal only: only `false` has an effect (it hides the button). Passing `true` is a no-op — the button follows the paywall's own configuration.

### Transitions

`display([transition])` accepts an optional `PLYTransition` **object** (not a factory):

```typescript
await request.display({ type: 'fullScreen' });           // full-screen
await request.display({ type: 'modal' });                // modal sheet
await request.display({ type: 'modal', dismissible: false });
await request.display({ type: 'push' });                 // pushed onto the navigation stack
```

`type` accepts `'fullScreen'`, `'push'`, `'modal'`, `'drawer'`, `'popin'` and `'inlinePaywall'`. Sizing uses `width` / `height` **dimension objects** — `{ type: 'pixel' | 'percentage', value }` (a `'percentage'` value is a 0–1 fraction). The old v5 `heightPercentage` field was **removed** — use `height: { type: 'percentage', value }` instead. You can also pass `dismissible` and `backgroundColors: { light?, dark? }`:

```typescript
await request.display({
  type: 'drawer',
  height: { type: 'percentage', value: 0.6 },
  dismissible: true,
  backgroundColors: { light: '#FFFFFF', dark: '#000000' },
});
```

> `'inlinePaywall'` is not rendered by the standalone `display()` path — for embedded rendering use the [`PLYPresentationView`](#inline-paywall-with-plypresentationview) component.

### PLYPresentationOutcome fields

| Field | Type | Description |
|-------|------|-------------|
| `presentation` | `PLYPresentation \| null` | The displayed presentation (or `null` if it never reached display) |
| `purchaseResult` | `'purchased' \| 'restored' \| 'cancelled' \| null` | Purchase outcome |
| `plan` | `PLYPlan \| null` | The purchased plan (when `purchaseResult` is `'purchased'` / `'restored'`) |
| `closeReason` | `'button' \| 'backSystem' \| 'programmatic' \| null` | Why the screen closed (when no purchase) |
| `error` | `{ message: string, code?, domain? } \| null` | Display error |

> **`closeReason` values (three).** `button` (tapped a close button), `backSystem` (Android system back **and** the iOS interactive dismiss — swipe-down / nav pop both map here), `programmatic` (`request.close()`). There is **no** `interactiveDismiss` value. `error` and `closeReason` are mutually exclusive: when `error != null`, `closeReason` is `null`.

### Inline Paywall with PLYPresentationView

Embed a paywall directly in your component tree with the `PLYPresentationView` component. The v6-preferred form passes a **preloaded** `request` so the native view resolves the loaded presentation by its `requestId` (no second network fetch). It falls back to `placementId` / `presentation` when no `request` is given.

```tsx
import Purchasely, { PLYPresentationView } from 'react-native-purchasely';
import { useEffect, useState } from 'react';
import type { PLYPresentationRequest } from 'react-native-purchasely';

function InlinePaywallScreen() {
  const [request, setRequest] = useState<PLYPresentationRequest | null>(null);

  useEffect(() => {
    const req = Purchasely.presentation.placement('INLINE_PAYWALL').build();
    // Preload before rendering so `requestId` is populated.
    req.preload().then(() => setRequest(req));
  }, []);

  if (!request) return null;

  return (
    <PLYPresentationView
      request={request}
      flex={1}
      onPresentationClosed={(outcome) => {
        // outcome: PLYPresentationOutcome = { presentation, purchaseResult, plan, closeReason, error }
        if (outcome.purchaseResult === 'purchased' || outcome.purchaseResult === 'restored') {
          // Handle purchase
        }
      }}
    />
  );
}
```

You can still use the simpler `placementId` form when you do not preload:

```tsx
<PLYPresentationView placementId="INLINE_PAYWALL" flex={1} onPresentationClosed={/* … */} />
```

> **The embedded view emits the same 5-field outcome as `display()`.** `onPresentationClosed` receives the same `PLYPresentationOutcome` — `{ presentation, purchaseResult, plan, closeReason, error }` — as `request.display()` / `request.onDismissed(...)`. The `flex` prop defaults to `1`.

> **Unmounting a `<PLYPresentationView request={…}>` without dismissing it evicts the preloaded request natively** (iOS/Android parity) — remounting the same `request` then shows a blank view until you call `request.preload()` again. Re-preload before reusing a request in a new mount.

## Action Interceptor

Intercept paywall actions to inject custom behavior. Register **one handler per action kind** with `Purchasely.interceptAction(kind, handler)`. The handler returns a **`PLYInterceptResult`** string telling the SDK how the action was handled:

- `'success'` — you handled the action successfully
- `'failed'` — you tried to handle it but it failed
- `'notHandled'` — let the SDK perform its default behaviour

This replaces the old `setPaywallActionInterceptorCallback` + `Purchasely.onProcessAction(bool)` pair — there is no more `onProcessAction` and no single global callback. The model mirrors the native per-action `interceptAction`.

```typescript
import Purchasely from 'react-native-purchasely';
import { Linking } from 'react-native';

Purchasely.interceptAction('login', async (info, payload) => {
  // 'login' carries no payload (payload is null)
  const userId = await navigateToLogin();
  if (userId) {
    await Purchasely.userLogin(userId);
    return 'success';
  }
  return 'failed';
});

Purchasely.interceptAction('navigate', async (info, payload) => {
  if (payload?.kind === 'navigate') {
    Linking.openURL(payload.url); // PLYNavigatePayload: { url, title? }
    return 'success';
  }
  return 'notHandled';
});

Purchasely.interceptAction('purchase', async (info, payload) => {
  // payload?.kind === 'purchase' → PLYPurchasePayload: { plan, subscriptionOffer?, offer? }
  // In Full mode let Purchasely handle the purchase:
  return 'notHandled';
});
```

Action kinds (10): `'close'`, `'closeAll'`, `'login'`, `'navigate'`, `'purchase'`, `'restore'`, `'openPresentation'`, `'openPlacement'`, `'promoCode'`, `'webCheckout'`. The second argument is a **typed payload** discriminated by `payload.kind`:

| Kind | Payload | Fields |
|------|---------|--------|
| `purchase` | `PLYPurchasePayload` | `plan`, `subscriptionOffer?`, `offer?` |
| `navigate` | `PLYNavigatePayload` | `url`, `title?` |
| `close` / `closeAll` | `PLYClosePayload` | `closeReason` |
| `openPresentation` | `PLYOpenPresentationPayload` | `presentationId` |
| `openPlacement` | `PLYOpenPlacementPayload` | `placementId` |
| `webCheckout` | `PLYWebCheckoutPayload` | `url`, `clientReferenceId`, `queryParameterKey`, `webCheckoutProvider` |
| `login` / `restore` / `promoCode` | — | `payload` is `null` |

The first argument is a **`PLYInterceptorInfo`** — `{ contentId?, presentation? }`.

> **Error handling & timeout.** If your handler throws, the SDK treats it as `'failed'`. On iOS the interceptor has a **30-second timeout**: if the handler does not resolve in time, the SDK falls back to `'notHandled'`. Keep handlers fast and resolve promptly.

### Removing interceptors

```typescript
Purchasely.removeActionInterceptor('navigate');
Purchasely.removeAllActionInterceptors();
```

## User Management

User identity, attributes, events, subscriptions and programmatic purchases are **unchanged** in v6 — same `Purchasely.*` signatures as before.

### Login

```typescript
await Purchasely.userLogin('user_123'); // returns Promise<boolean>
```

### Logout

```typescript
Purchasely.userLogout();
```

## Programmatic Purchases

For app-side purchase buttons in Full mode, use `purchaseWithPlanVendorId` (unchanged). Do not use `Purchasely.purchase({ planId: ... })`; that API is not exposed by the React Native bridge.

```typescript
const purchasedPlan = await Purchasely.purchaseWithPlanVendorId({
  planVendorId: 'premium_yearly',
  offerId: null,
  contentId: null,
});
```

## User Attributes

Set attributes for audience targeting and personalization (unchanged). Each setter takes an optional GDPR legal basis (`PLYDataProcessingLegalBasis.ESSENTIAL` / `.OPTIONAL`):

```typescript
import { PLYDataProcessingLegalBasis } from 'react-native-purchasely';

// String attribute (with optional legal basis)
Purchasely.setUserAttributeWithString('first_name', 'John', PLYDataProcessingLegalBasis.OPTIONAL);

// Number attribute — setUserAttributeWithInt / setUserAttributeWithDouble are distinct
// native overloads (not aliases); setUserAttributeWithNumber infers Int vs Double from the JS value
Purchasely.setUserAttributeWithNumber('age', 30);

// Boolean attribute
Purchasely.setUserAttributeWithBoolean('is_premium', true);

// Date attribute
Purchasely.setUserAttributeWithDate('signup_date', new Date());
```

## Events

Listen for SDK events (paywall views, purchases, etc.) — unchanged (`addEventListener` has the alias `listenToEvents`):

```typescript
const subscription = Purchasely.addEventListener((event) => {
  console.log('Event:', event.name);
  console.log('Properties:', event.properties);

  // Forward to your analytics provider
  analytics.track(event.name, event.properties);
});

// Remove listener when no longer needed
subscription.remove();
```

## Subscriptions

Fetch the user's active subscriptions (unchanged; `userSubscriptions({ invalidateCache })` accepts an optional cache-bypass flag):

```typescript
const subscriptions = await Purchasely.userSubscriptions();
subscriptions.forEach((sub) => {
  console.log('Plan:', sub.plan.vendorId);
  console.log('Store:', sub.subscriptionSource);
});

// Force a fresh fetch (bypass the cache):
const fresh = await Purchasely.userSubscriptions({ invalidateCache: true });
```

> **`presentSubscriptions()` is REMOVED in v6 (BREAKING).** The native subscriptions screen was removed from the 6.0 SDKs on **both** platforms, so `Purchasely.presentSubscriptions()` has been **removed entirely** from the React Native API — it is not a no-op, the method no longer exists. There is no drop-in replacement: build your own subscriptions screen from `userSubscriptions()` / `userSubscriptionsHistory()`. `displaySubscriptionCancellationInstruction()` is also gone. `clientPresentationDisplayed` / `clientPresentationClosed` are **kept** (BYOS) — pass the presentation you got from `preload()`.

## Pre-fetching Screens

Build a `PLYPresentationRequest`, `preload()` it to fetch the screen from the network, then `display()` it when you are ready (replaces `fetchPresentation` + `presentPresentation`). `preload()` resolves a **`PLYLoadedPresentation`** — the presentation data (`screenId`, `placementId`, `contentId`, `type`, `plans`, `metadata`, …) **plus** the `display(transition?)`, `close()` and `back()` lifecycle methods delegated to the originating request.

```typescript
import Purchasely, { PLYPresentationType } from 'react-native-purchasely';

try {
  const request = Purchasely.presentation.placement('ONBOARDING').build();

  // Preload resolves once the screen is loaded, as a PLYLoadedPresentation
  const loaded = await request.preload();

  if (loaded.type === PLYPresentationType.DEACTIVATED) {
    // No paywall to display for this placement — do NOT display
    return;
  }
  if (loaded.type === PLYPresentationType.CLIENT) {
    // Display your own paywall (BYOS) — plan summaries are in loaded.plans
    showCustomPaywall(loaded.plans);
    return;
  }

  // Display the preloaded presentation; resolves at dismiss.
  // Either call loaded.display() or request.display() — same request.
  const outcome = await loaded.display();

  if (outcome.purchaseResult === 'purchased' || outcome.purchaseResult === 'restored') {
    console.log('User purchased', outcome.plan?.name);
  } else {
    console.log('Dismissed:', outcome.closeReason);
  }
} catch (error) {
  console.error(error);
}
```

`PLYPresentationType` values: `NORMAL` (default paywall), `FALLBACK` (requested one not found), `DEACTIVATED` (no paywall), `CLIENT` (your own BYOS paywall).

### Presentation lifecycle (display / close / back)

A built `PLYPresentationRequest` exposes imperative controls plus a public `requestId` getter (populated after the first `preload()` / `display()`, otherwise `null`):

```typescript
const request = Purchasely.presentation.placement('ONBOARDING').build();

request.display();     // show (resolves at dismiss)
request.close();       // dismiss programmatically
request.back();        // navigate back inside a multi-step (Flow) presentation
console.log(request.requestId); // string | null — used to correlate the embedded view
```

> **`request.close()` platform difference.** On **iOS** it closes the **specific** presentation identified by its `requestId` (falling back to closing all Purchasely screens when the request is no longer tracked). On **Android** the native SDK does not yet expose a per-request close, so it dismisses **all** displayed presentations. If you stack presentations, closing one dismisses the others on Android.

## Deeplinks

v6 displays deeplinks and campaigns immediately by default. Allow or gate them on the builder with `allowDeeplink` (or the standalone `Purchasely.allowDeeplink(bool)`), and feed runtime deeplinks with **`Purchasely.handleDeeplink(uri)`**.

> **`.allowDeeplink()` is an optional chain modifier, not a required one.** If you omit it from the builder chain, the flag is simply never sent to the native side, and the **native default (`true`)** applies — the same as iOS, Android, and Flutter. There is no RN-specific default of `false`; only call `.allowDeeplink(false)` if you actually want to defer deeplink display (e.g. during onboarding).

> **API change from v5.** `Purchasely.isDeeplinkHandled(uri)` and `Purchasely.readyToOpenDeeplink(bool)` are **removed** in React Native v6 — there is **no alias**. Use `Purchasely.handleDeeplink(uri)` (returns `Promise<boolean>`) and `.allowDeeplink(true)` on the builder (or `Purchasely.allowDeeplink(true)`).

### Allow Deeplinks

Deeplink display is allowed via the start builder:

```typescript
await Purchasely.builder('YOUR_API_KEY')
  .allowDeeplink(true) // replaces readyToOpenDeeplink(true)
  .start();
```

### Handle Incoming Deeplink

```typescript
const handled = await Purchasely.handleDeeplink('app://ply/presentations/');
if (handled) {
  // Purchasely recognized and will display the appropriate content
}
```

For a deeplink captured at **cold start**, pass it to the builder instead so it is replayed after `start()`:

```typescript
await Purchasely.builder('YOUR_API_KEY').handleDeeplink(coldStartUri).start();
```

### Default Presentation Dismiss Handler

For presentations the **SDK** opens itself (campaigns, deeplinks, Promoted IAP) your app never calls `display()`, so there is no request to read the result from. Register the **global default dismiss handler** instead (replaces `setDefaultPresentationResultCallback` / `setDefaultPresentationResultHandler`):

```typescript
const subscription = Purchasely.setDefaultPresentationDismissHandler((outcome) => {
  // outcome: { presentation, purchaseResult, plan, closeReason, error }
  // `presentation` is always populated here — use it to tell which
  // campaign/deeplink screen closed.
  console.log(
    outcome.presentation?.screenId,
    outcome.purchaseResult, // 'purchased' | 'restored' | 'cancelled' | null
    outcome.closeReason     // 'button' | 'backSystem' | 'programmatic' | null
  );
});

// Only one handler is active at a time — calling again replaces it.
// Remove it (e.g. on unmount) with either:
subscription.remove();
// …or:
Purchasely.removeDefaultPresentationDismissHandler();
```

## Synchronize Purchases

Force synchronization with Purchasely servers. In v6 `synchronize()` returns a **`Promise<boolean>`** that resolves when the receipt synchronization completes and rejects on failure (the v5 fire-and-forget behaviour is gone). This is **source-compatible** — existing fire-and-forget callers keep working. New code can `await` it before chaining a follow-up presentation that targets subscribers:

```typescript
try {
  await Purchasely.synchronize(); // resolves when the sync finishes
  console.log('Synchronized');
} catch (e) {
  console.error('Synchronize failed', e); // e.g. PLYError.NoStoreConfigured
}
```

> **Resolving a `.purchase` / `.restore` interceptor with `'success'` already auto-synchronizes the receipt** — do not also call `Purchasely.synchronize()` from inside that handler. Reserve manual `synchronize()` calls for purchases processed **outside** the interceptor flow (e.g. a "Restore Purchases" button, or a client-side/BYOS presentation). If you need to chain a follow-up placement that targets users by subscription state, `await Purchasely.synchronize()` yourself first so the receipt is guaranteed to have landed before the fetch.

## After 6.0.0: what 6.1.0, 6.1.1 and 6.2.0 add

All three releases are additive. No code change is required in an existing integration, with one TypeScript exception (see [`PLYSubscription` nullable fields](#plysubscription-nullable-fields)).

| Bridge | Native iOS | Native Android | Content |
|--------|------------|----------------|---------|
| `6.1.0` | `6.1.0` | `6.1.0` | Web redemption listener, `anonymousUserId`, `proxy`, `WEB_CHECKOUT_STRIPE`, `REDEMPTION_*` events |
| `6.1.1` | `6.1.2` | `6.1.1` | Native fixes only, no API change |
| `6.2.0` | `6.2.0` | `6.2.0` | `emit`, `signPromotionalOfferWithToken`, `REFUND_HANDLING`, empty-list consent change |

### Web redemption listener (6.1.0)

Set the listener on the builder. A redemption can settle during `start()`, and the builder subscribes your callback before the native `start()` call. The second argument is `appHandlesRedemptionAlert`: `false` (default) keeps the SDK popin and calls the listener when the user closes it. `true` shows no popin and calls the listener as soon as the redemption settles.

```typescript
await Purchasely.builder('YOUR_API_KEY')
  .webRedemptionListener((result) => {
    if (result.isSuccess) {
      // result.replay is true when the link was already redeemed
      unlockContent(result.context?.subscription, result.replay);
    } else {
      showError(result.errorCode, result.errorMessage);
    }
  }, false)
  .start();
```

The result is one flat object on both platforms: `{ isSuccess, context, replay, errorCode, errorMessage }`. `context` and `context.subscription` are separately nullable, and a success can carry neither. A failure reports `replay: false` and `context: null`. The callback runs on the main thread, once per settled redemption.

`Purchasely.addWebRedemptionListener(cb)` and `Purchasely.removeWebRedemptionListener()` exist for an app that adds or replaces the listener after `start()`. A redemption that settles during `start()` is then missed. `removeWebRedemptionListener()` removes every listener on the event.

- A redemption deeplink does not obey `allowDeeplink`.
- For an expired link, `errorMessage` can contain a masked email address. Show it to the user. Do not send it to analytics or a crash reporter, on either platform. The `REDEMPTION_FAILED` event drops it.
- `PLYEventName` adds `REDEMPTION_CONSUMED` and `REDEMPTION_FAILED`. `PLYEventProperties.redemption` types their payload. A replayed link also sends `REDEMPTION_CONSUMED`: read `properties.redemption.purchase_context.replay`.
- `SubscriptionSource.WEB_CHECKOUT_STRIPE` is a new value. A web checkout subscription now reports it on both platforms (Android reported `null` before).

See [`../concepts/web-checkout.md`](../concepts/web-checkout.md) for the behavior of the redemption flow.

### Anonymous user id and proxy (6.1.0)

```typescript
await Purchasely.builder('YOUR_API_KEY')
  .anonymousUserId('3f2504e0-4f89-11d3-9a0c-0305e82c3301', false) // string, not a UUID type
  .proxy('https://your-proxy.example.com')                        // proxy(null) clears a proxy
  .start();
```

- `anonymousUserId(id: string, override: boolean = false)`: JavaScript has no UUID type, so the bridge parses the string. A value that is not a canonical UUID is refused with a log, the option is skipped and `start()` still succeeds. The SDK keeps an id already on the device unless `override` is `true`. `override: true` splits the user history. The SDK stores the id in uppercase on both platforms, so compare it case-insensitively. See [`../concepts/user-identity.md`](../concepts/user-identity.md).
- `proxy(api: string | null)`: routes the API traffic only through your `https` URL, for a region where `api.purchasely.io` is not reachable. The paywall and tracking hosts stay on production. It works on iOS and Android. It is a start-time option. A chain that never calls `proxy` leaves the current setting untouched.

### Custom events: `emit` (6.2.0)

```typescript
Purchasely.emit('recipe_viewed', { recipe_id: 42, title: 'Ratatouille' });
Purchasely.emit('checkout_started');
```

`emit(name: string, properties: Record<string, unknown> = {}): void` returns nothing. Declare the event in the Console first: the SDK sends only names declared there, matched exactly, and ignores an undeclared name. Pass a date as an ISO 8601 string. Custom events never reach `addEventListener`, and you can call `emit` before `start()`. See [`../concepts/custom-events.md`](../concepts/custom-events.md).

### Promotional offers: `signPromotionalOfferWithToken` (6.2.0, iOS only)

For Observer mode. The method signs a promotional offer over a purchase context token and returns the signature with that token:

```typescript
const result = await Purchasely.signPromotionalOfferWithToken({
  storeProductId: productId,
  storeOfferId: offerId,
  // purchaseContextToken: optional canonical UUID string. Omit it or pass null to let the SDK create one.
});
const token = result?.purchaseContextToken; // lowercase UUID
```

- The purchase must carry this exact token: `applicationUsername` with StoreKit 1, or `appAccountToken` (the UUID) with StoreKit 2. Apple rejects the offer when the purchase carries another value.
- A `purchaseContextToken` that is not a canonical UUID rejects the promise.
- `signPromotionalOffer` is **deprecated**. It still works, but it signs over the anonymous user id, so a purchase that carries another value is rejected by Apple. Use `signPromotionalOfferWithToken`.
- On Android, both methods resolve `null`. They do not reject.

See [`../concepts/promotional-offers.md`](../concepts/promotional-offers.md).

### Consent: `REFUND_HANDLING` and the empty list (6.2.0)

```typescript
import { PLYDataProcessingPurpose } from 'react-native-purchasely';

// Replaces the whole list: pass every refused purpose in the same call
Purchasely.revokeDataProcessingConsent([
  PLYDataProcessingPurpose.ANALYTICS,
  PLYDataProcessingPurpose.REFUND_HANDLING, // 'refund-handling'
]);

Purchasely.revokeDataProcessingConsent([]); // grants every purpose back
```

- `PLYDataProcessingPurpose.REFUND_HANDLING` (string value `'refund-handling'`) records that the user refused to share consumption data with Apple for refund requests. It is not part of `ALL_NON_ESSENTIALS`: add it explicitly.
- Android ignores this purpose. On Android, `[REFUND_HANDLING]` alone is an empty list and grants every purpose back.
- **Behavior change.** Native iOS and Android replace the stored set on each call. In 6.0.0 to 6.1.1 the bridge dropped an empty list (it logged a warning and did nothing). From 6.2.0 the bridge forwards it, so `[]` grants every purpose back on iOS and Android. A list that holds only unknown strings now does the same.

See [`../concepts/privacy-settings.md`](../concepts/privacy-settings.md).

### `PLYSubscription` nullable fields

In 6.1.0, `purchaseToken`, `nextRenewalDate` and `cancelledDate` on `PLYSubscription` are typed `?: string | null`. iOS omits the key (you read `undefined`). Android sends an explicit `null`. Typed code that reads `subscription.purchaseToken` without a guard fails to compile: use `subscription.purchaseToken ?? null`. The runtime behavior did not change.

### Native fixes inherited in 6.1.1

No API change. Native iOS 6.1.2 and Android 6.1.1 fix these points:

- iOS: closing a drawer, popin or modal no longer leaves a transparent window over the app, and `PRESENTATION_CLOSED` is sent again.
- iOS: all purchases of one StoreKit update are processed together, and a regional language such as `de-CH` falls back to the base language `de`.
- iOS: durations and periods no longer show a raw translation key.
- Android: TalkBack reads the rendered text of a button or label, not internal action metadata. A UI test that finds a paywall control by `content-desc` must use the visible text.

## Bridge & version alignment notes

- The JS ↔ native bridge is still **NativeModules** (`Purchasely`) + event emitters. v6 changes the public JS surface, not the bridge transport.
- **All Purchasely npm packages MUST be the exact same version** (`6.2.0`). Mixing versions causes runtime crashes. Pin exactly, never floating (`^6.2.0`, `6.x`).
- Run a fresh install after pinning: `rm -rf node_modules && npm install`, then `pod install --repo-update` (iOS) and `./gradlew --refresh-dependencies` (Android) as needed.
- See [`../sdk-versions.md`](../sdk-versions.md) for the canonical version table and [`./migration-v6.md`](./migration-v6.md) for the full v5 → v6 old→new mapping.

## Complete Integration Example

```typescript
import React, { useEffect } from 'react';
import { Button, View, Linking } from 'react-native';
import Purchasely, { PLYPresentationType } from 'react-native-purchasely';

export default function App() {
  useEffect(() => {
    // Initialize SDK
    Purchasely.builder('YOUR_API_KEY')
      .runningMode('full')
      .logLevel('error')
      .stores(['google'])
      .storekitVersion('storeKit2')
      .allowDeeplink(true)
      .allowCampaigns(true)
      .start();

    // Set up an action interceptor (one handler per kind)
    Purchasely.interceptAction('login', async (info, payload) => {
      // Handle login, then:
      await Purchasely.userLogin('USER_ID');
      return 'success';
    });

    Purchasely.interceptAction('navigate', async (info, payload) => {
      if (payload?.kind === 'navigate') {
        Linking.openURL(payload.url);
        return 'success';
      }
      return 'notHandled';
    });

    // Listen for events
    const subscription = Purchasely.addEventListener((event) => {
      console.log('PLY Event:', event.name);
    });

    return () => {
      subscription.remove();
    };
  }, []);

  const showPaywall = async () => {
    const outcome = await Purchasely.presentation
      .placement('ONBOARDING')
      .build()
      .display();

    if (outcome.error) {
      console.error('Error:', outcome.error.message);
    } else if (
      outcome.purchaseResult === 'purchased' ||
      outcome.purchaseResult === 'restored'
    ) {
      console.log('Purchased:', outcome.plan?.name);
    } else {
      console.log('Dismissed:', outcome.closeReason);
    }
  };

  return (
    <View style={{ flex: 1, justifyContent: 'center' }}>
      <Button title="Show Paywall" onPress={showPaywall} />
    </View>
  );
}
```
