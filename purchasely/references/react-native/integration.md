# React Native Integration

Purchasely React Native is on the **v6 API**, the same generation as the native iOS and Android SDKs. The plugin pins the **6.0.0-rc.1** pre-release on every layer: all five npm packages (`react-native-purchasely`, `@purchasely/react-native-purchasely-google`, `@purchasely/react-native-purchasely-android-player`, `@purchasely/react-native-purchasely-amazon`, `@purchasely/react-native-purchasely-huawei`) are `6.0.0-rc.1`, and they pull the published native SDKs (iOS `Purchasely 6.0.0-rc.1` on the CocoaPods trunk, Android `io.purchasely:core 6.0.0-rc.1` on Maven Central). The public JS/TS symbols keep their plain names (`Purchasely.builder`, `PresentationBuilder`, `PresentationRequest`, `PresentationOutcome`, `Transition`, …) — there are no `v6` / `V6` symbols.

Three areas changed shape from v5: **starting the SDK** (`Purchasely.builder(apiKey)`), **displaying / preloading / closing a presentation** (`Purchasely.presentation` + `PresentationRequest`), and the **action interceptor** (`Purchasely.interceptAction`). Everything else on the `Purchasely` default export — purchases, restore, identity, catalog, subscriptions data, user attributes, events, dynamic offerings, consent and config — remains source-compatible (`isDeeplinkHandled` is **kept**, not renamed). See [`migration-v6.md`](./migration-v6.md) for the full v5 → v6 old→new mapping.

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
> - [`../sdk-versions.md`](../sdk-versions.md) — latest versions (pin React Native to **6.0.0-rc.1**)

## Installation

Pin all packages to the exact same version, `6.0.0-rc.1`. Use `--save-exact` — `6.0.0-rc.1` is a pre-release, so a floating range (`^6.0.0`, `6.x`) will not resolve it.

```bash
# Core SDK
npm install react-native-purchasely@6.0.0-rc.1 --save-exact

# Google Play — required if targeting Google Play Store
npm install @purchasely/react-native-purchasely-google@6.0.0-rc.1 --save-exact

# Video Player — optional, for video support in paywalls on Android
npm install @purchasely/react-native-purchasely-android-player@6.0.0-rc.1 --save-exact

# Amazon Appstore — optional, Android alt store
npm install @purchasely/react-native-purchasely-amazon@6.0.0-rc.1 --save-exact

# Huawei AppGallery — optional, Android alt store
npm install @purchasely/react-native-purchasely-huawei@6.0.0-rc.1 --save-exact
```

**CRITICAL: All Purchasely packages must be at the exact same version, pinned exactly (never floating).** Check `package.json`:

```json
{
  "dependencies": {
    "react-native-purchasely": "6.0.0-rc.1",
    "@purchasely/react-native-purchasely-google": "6.0.0-rc.1",
    "@purchasely/react-native-purchasely-android-player": "6.0.0-rc.1"
  }
}
```

> **Native dependency.** `react-native-purchasely 6.0.0-rc.1` pulls the **6.0.0-rc.1** native SDKs transitively — iOS `Purchasely 6.0.0-rc.1` (CocoaPods trunk) and Android `io.purchasely:core 6.0.0-rc.1` (Maven Central). Both are published, so the project builds from the public repositories. You do not bump the native pods/gradle dependencies yourself; the plugin's pinning is correct.

### iOS Setup

Minimum deployment target **iOS 13.4**. Install the pods:

```bash
cd ios && pod install --repo-update
```

### Android Setup

`minSdkVersion 21` (align `compileSdk` / `targetSdk` with your existing app, e.g. 36). Edit `android/build.gradle`:

```groovy
buildscript {
    ext {
        minSdkVersion = 21
        compileSdkVersion = 36
        targetSdkVersion = 36
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

Start the SDK with the fluent `Purchasely.builder(apiKey)`. Only the API key is required; every other option has a sensible default and is passed as a **string** (not an enum). The builder replaces the old `Purchasely.start({...})` call and returns `Promise<boolean>`.

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
      .stores(['google'])            // Android only: 'google' | 'huawei' | 'amazon'
      .storekitVersion('storeKit2')  // iOS only: 'storeKit1' | 'storeKit2'
      .start();

    console.log('Purchasely started:', started);
  } catch (error) {
    console.error('Purchasely init failed:', error);
  }
}
```

> **Default running mode changed.** With the 6.0 native SDK the default `runningMode` is `'observer'` — the host app keeps control of the purchase flow. Pass `.runningMode('full')` to let Purchasely own the purchase flow (purchase processing + validation, and auto-close after purchase/restore). This is a **silent behavioural change** (no compile error): an app that previously relied on the implicit Full mode will stop owning the purchase flow after upgrading unless it passes `.runningMode('full')` explicitly.

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

`Purchasely.presentation.placement(id).build()` returns a `PresentationRequest`. Call `display([transition])` to show the screen; it resolves at **dismiss** with a `PresentationOutcome`. This replaces the old `fetchPresentation()` + `presentPresentation()` pair and handles Flows (close controls, step transitions) natively.

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
    console.log('User dismissed:', outcome.closeReason); // 'button' | 'backSystem' | 'interactiveDismiss' | 'programmatic'
  }
} catch (error) {
  console.error('Presentation error:', error);
}
```

`purchaseResult` is a **string union** (`'purchased' | 'cancelled' | 'restored' | null`), not the old `ProductResult` ordinal enum.

You can also target a specific screen or product:

```typescript
// A specific presentation by screen id (was presentPresentationWithIdentifier)
await Purchasely.presentation.screen('SCREEN_ID').build().display();

// A specific product (content) inside a screen (was presentProductWithIdentifier)
await Purchasely.presentation.screen('SCREEN_ID').contentId('CONTENT_ID').build().display();
```

### Lifecycle callbacks

Chain optional lifecycle callbacks on the builder before `.build()`:

```typescript
const request = Purchasely.presentation
  .placement('ONBOARDING')
  .contentId('my_content_id')
  .onLoaded((presentation) => console.log('loaded:', presentation?.type))
  .onPresented((presentation) => console.log('presented'))
  .onCloseRequested(() => console.log('close requested'))
  .onDismissed((outcome) => console.log('dismissed:', outcome.purchaseResult))
  .build();
```

You can also tune the look on the builder: `.backgroundColor(hex)`, `.progressColor(hex)`, and (Android) `.displayCloseButton(bool)` / `.displayBackButton(bool)`.

### Transitions

`display([transition])` accepts an optional `Transition` **object** (not a factory):

```typescript
await request.display({ type: 'fullScreen' });           // full-screen
await request.display({ type: 'modal' });                // modal sheet
await request.display({ type: 'modal', dismissible: false });
await request.display({ type: 'push' });                 // pushed onto the navigation stack
```

`type` also accepts `'drawer'`, `'popin'` and `'inlinePaywall'` for advanced layouts, with optional `heightPercentage`, `dismissible`, and `backgroundColors: { light?, dark? }`.

### PresentationOutcome fields

| Field | Type | Description |
|-------|------|-------------|
| `presentation` | `Presentation \| null` | The displayed presentation (or `null` if it never reached display) |
| `purchaseResult` | `'purchased' \| 'restored' \| 'cancelled' \| null` | Purchase outcome |
| `plan` | `PurchaselyPlan \| null` | The purchased plan (when `purchaseResult` is `'purchased'` / `'restored'`) |
| `closeReason` | `'button' \| 'backSystem' \| 'interactiveDismiss' \| 'programmatic' \| null` | Why the screen closed (when no purchase) |
| `error` | `{ message: string } \| null` | Display error |

> **iOS / Android `closeReason` parity.** Both native 6.0 SDKs expose `closeReason` on the outcome. Android reports `backSystem` (system back); iOS reports `interactiveDismiss` (swipe-down / nav pop). `closeReason` is the cross-platform superset of both.

### Inline Paywall with PLYPresentationView

Embed a paywall directly in your component tree with the `PLYPresentationView` component (unchanged from v5). Pass a `placementId` and read the result from `onPresentationClosed`.

```tsx
import { PLYPresentationView } from 'react-native-purchasely';

function InlinePaywallScreen() {
  return (
    <PLYPresentationView
      placementId="INLINE_PAYWALL"
      flex={1}
      onPresentationClosed={(result) => {
        if (result.result === 'purchased' || result.result === 'restored') {
          // Handle purchase
        }
      }}
    />
  );
}
```

## Action Interceptor

Intercept paywall actions to inject custom behavior. Register **one handler per action kind** with `Purchasely.interceptAction(kind, handler)`. The handler returns a **string** telling the SDK how the action was handled:

- `'success'` — you handled the action successfully
- `'failed'` — you tried to handle it but it failed
- `'notHandled'` — let the SDK perform its default behaviour

This replaces the old `setPaywallActionInterceptorCallback` + `Purchasely.onProcessAction(bool)` pair — there is no more `onProcessAction` and no single global callback. The model mirrors the native per-action `interceptAction`.

```typescript
import Purchasely from 'react-native-purchasely';
import { Linking } from 'react-native';

Purchasely.interceptAction('login', async (info, payload) => {
  // Present your login screen
  const userId = await navigateToLogin();
  if (userId) {
    Purchasely.userLogin(userId);
    return 'success';
  }
  return 'failed';
});

Purchasely.interceptAction('navigate', async (info, payload) => {
  if (payload?.kind === 'navigate') {
    Linking.openURL(payload.url);
    return 'success';
  }
  return 'notHandled';
});

Purchasely.interceptAction('purchase', async (info, payload) => {
  // In Full mode let Purchasely handle the purchase:
  return 'notHandled';
});
```

Action kinds: `'close'`, `'closeAll'`, `'login'`, `'navigate'`, `'purchase'`, `'restore'`, `'openPresentation'`, `'openPlacement'`, `'promoCode'`, `'webCheckout'`. Each kind has a typed payload reachable through `payload?.kind` (e.g. `payload.url` for `'navigate'`, `payload.plan` for `'purchase'`); payload-less kinds (`'login'`, `'restore'`, `'promoCode'`) carry no extra fields.

### Removing interceptors

```typescript
Purchasely.removeActionInterceptor('navigate');
Purchasely.removeAllActionInterceptors();
```

## User Management

User identity, attributes, events, subscriptions and programmatic purchases are **unchanged** in v6 — same `Purchasely.*` signatures as before.

### Login

```typescript
Purchasely.userLogin('user_123');
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

Set attributes for audience targeting and personalization (unchanged):

```typescript
// String attribute
Purchasely.setUserAttributeWithString('first_name', 'John');

// Number attribute
Purchasely.setUserAttributeWithNumber('age', 30);

// Boolean attribute
Purchasely.setUserAttributeWithBoolean('is_premium', true);

// Date attribute
Purchasely.setUserAttributeWithDate('signup_date', new Date());
```

## Events

Listen for SDK events (paywall views, purchases, etc.) — unchanged:

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

Fetch the user's active subscriptions (unchanged):

```typescript
const subscriptions = await Purchasely.userSubscriptions();
subscriptions.forEach((sub) => {
  console.log('Plan:', sub.plan.vendorId);
  console.log('Store:', sub.subscriptionSource);
});
```

> **`presentSubscriptions()` is REMOVED in v6 (BREAKING).** The native subscriptions screen was removed from the 6.0 SDKs on **both** platforms, so `Purchasely.presentSubscriptions()` has been **removed entirely** from the React Native API — it is not a no-op, the method no longer exists. There is no drop-in replacement: build your own subscriptions screen from `userSubscriptions()` / `userSubscriptionsHistory()`.

## Pre-fetching Screens

Build a `PresentationRequest`, `preload()` it to fetch the screen from the network, then `display()` the **same** request when you are ready (replaces `fetchPresentation` + `presentPresentation`).

```typescript
import Purchasely, { PLYPresentationType } from 'react-native-purchasely';

try {
  const request = Purchasely.presentation.placement('ONBOARDING').build();

  // Preload resolves once the screen is loaded
  const presentation = await request.preload();

  if (presentation.type === PLYPresentationType.DEACTIVATED) {
    // No paywall to display for this placement — do NOT display
    return;
  }
  if (presentation.type === PLYPresentationType.CLIENT) {
    // Display your own paywall (BYOS) — plan summaries are in presentation.plans
    showCustomPaywall(presentation.plans);
    return;
  }

  // Display the preloaded presentation; resolves at dismiss
  const outcome = await request.display();

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

A built `PresentationRequest` exposes imperative controls:

```typescript
const request = Purchasely.presentation.placement('ONBOARDING').build();

request.display();  // show (resolves at dismiss)
request.close();    // dismiss programmatically
request.back();     // navigate back inside a multi-step (Flow) presentation
```

> `request.close()` currently dismisses **all** displayed presentations (the native SDK does not yet expose a per-request close). If you stack presentations, closing one dismisses the others.

## Deeplinks

v6 displays deeplinks and campaigns immediately by default. Allow or gate them on the builder with `allowDeeplink`, and feed cold-start / runtime deeplinks with `Purchasely.isDeeplinkHandled` (this name is **kept** in React Native — it is not renamed to `handleDeeplink`).

### Allow Deeplinks

Deeplink display is allowed via the start builder.

```typescript
await Purchasely.builder('YOUR_API_KEY')
  .allowDeeplink(true) // replaces readyToOpenDeeplink(true)
  .start();
```

### Handle Incoming Deeplink

```typescript
const handled = await Purchasely.isDeeplinkHandled('app://ply/presentations/');
if (handled) {
  // Purchasely will display the appropriate content
}
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
    outcome.closeReason     // 'button' | 'backSystem' | 'interactiveDismiss' | 'programmatic' | null
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

> In Observer mode after a host-side purchase, `await Purchasely.synchronize()` before chaining a follow-up placement so the receipt is uploaded first.

## Bridge & version alignment notes

- The JS ↔ native bridge is still **NativeModules** (`Purchasely`) + event emitters. v6 changes the public JS surface, not the bridge transport.
- **All Purchasely npm packages MUST be the exact same version** (`6.0.0-rc.1`). Mixing versions causes runtime crashes. Pin exactly — never floating (`^6.0.0`, `6.x`).
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
      Purchasely.userLogin('USER_ID');
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
