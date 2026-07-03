# React Native — Migrating to the Purchasely 6.0 API

> **Published as a pre-release.** The React Native v6 API ships in
> `react-native-purchasely: 6.0.0-rc.2` (and the matching
> `@purchasely/react-native-purchasely-google` / `-android-player` / `-amazon` /
> `-huawei` packages), live on npm alongside the native iOS `Purchasely 6.0.0-rc.2`
> and Android `io.purchasely:core 6.0.0-rc.2` pre-releases. The builder-based API
> documented below (`Purchasely.builder`, `Purchasely.presentation`,
> `Purchasely.interceptAction`) is the current published surface — the v5
> paywall API (`Purchasely.start({...})`, `fetchPresentation` /
> `presentPresentation[ForPlacement]`, `setPaywallActionInterceptorCallback` +
> `onProcessAction`, `closePresentation()`, `readyToOpenDeeplink`,
> `isDeeplinkHandled`) is **removed** (not deprecated): calling any removed method
> fails to compile (TypeScript) and the method no longer exists at runtime.

> **In-repo migration guide.** This is the React Native-specific old→new mapping for
> the Purchasely 6.0 plugin. The companion integration reference is
> [`integration.md`](./integration.md); cross-platform concepts live in
> [`../concepts/`](../concepts/).

This release **adapts the Purchasely React Native plugin to the Purchasely 6.0
native SDKs** (iOS `Purchasely 6.0.0-rc.2`, Android `io.purchasely:core 6.0.0-rc.2`).
The public paywall symbols are **`PLY`-prefixed** — `Purchasely.builder`,
`PLYPresentationBuilder`, `PLYPresentationRequest`, `PLYLoadedPresentation`,
`PLYPresentationOutcome`, `PLYTransition`, `PLYInterceptResult`, … No `v6` / `V6`
symbols exist.

Only a few areas changed: **starting the SDK**, **displaying / preloading /
closing a presentation**, the **action interceptor**, and the **deeplink API**.
Everything else on the `Purchasely` default export — purchases, restore, identity,
catalog, subscriptions, user attributes, events, dynamic offerings, consent and
config — is **unchanged**.

A paywall is now called a **Presentation** (or *Screen*).

> **Tip — let the AI help you migrate.** The Purchasely AI plugin and the
> `purchasely-integrate`, `purchasely-review` and `purchasely-debug` skills can
> read your integration and rewrite the v5 paywall calls to the v6 builder API
> for you. Point them at the files that call `Purchasely.start`,
> `presentPresentationForPlacement`, `fetchPresentation`,
> `setPaywallActionInterceptorCallback`, `isDeeplinkHandled`, etc.

---

## TL;DR

- Start the SDK with the fluent builder:
  `Purchasely.builder('…').runningMode('full').start()` (returns `Promise<boolean>`).
- Build a presentation with `Purchasely.presentation` (a `PLYPresentationBuilder`):
  `.placement(id)`, `.screen(id)`, `.defaultSource()` (alias `.default()`), then
  `.build()` to get a **`PLYPresentationRequest`** with a lifecycle
  (`preload()`, `display(transition?)`, `close()`, `back()`, `requestId`).
- `preload()` resolves a **`PLYLoadedPresentation`** (data + `display`/`close`/`back`).
- `display(transition?)` resolves at **dismiss** with a 5-field
  **`PLYPresentationOutcome`** (`presentation`, `purchaseResult`, `plan`,
  `closeReason`, `error`).
- The interceptor is now `Purchasely.interceptAction(kind, handler)`, where
  `handler` returns a **`PLYInterceptResult`** (`'success'` / `'failed'` /
  `'notHandled'`) — there is no more `onProcessAction`.
- Deeplinks: `isDeeplinkHandled` / `readyToOpenDeeplink` are **removed** — use
  `Purchasely.handleDeeplink(uri)` and `.allowDeeplink(true)`.
- Inline rendering still uses the **`PLYPresentationView`** component (now also
  accepts a preloaded `request`).
- **All other `Purchasely.*` methods are UNCHANGED** — see
  [What's unchanged](#whats-unchanged).

---

## Migration checklist

1. Bump all five npm packages to **`6.0.0-rc.2`** exactly (`--save-exact`); never
   floating. `rm -rf node_modules && npm install`, then `pod install --repo-update`.
   Bump the Android host `minSdkVersion` to **23** (was 21) and `compileSdk` to 35.
2. Replace `Purchasely.start({...})` / `startWithAPIKey(...)` with the
   `Purchasely.builder(apiKey)…start()` chain. **Add `.runningMode('full')`
   explicitly** if you relied on the old implicit Full mode (default is now
   `'observer'`).
3. Replace `fetchPresentation` / `presentPresentation*` /
   `presentProductWithIdentifier` / `presentPlanWithIdentifier` with
   `Purchasely.presentation.placement(id) | .screen(id) | .defaultSource()` →
   `.build()` → `.preload()` / `.display()`.
4. Replace `setPaywallActionInterceptorCallback` + `onProcessAction` with one
   `Purchasely.interceptAction(kind, handler)` per kind; return
   `'success' | 'failed' | 'notHandled'`.
5. Replace `readyToOpenDeeplink(true)` with `.allowDeeplink(true)` on the builder.
   **Replace `isDeeplinkHandled(uri)` with `Purchasely.handleDeeplink(uri)`** — the
   v5 name is removed with no alias.
6. Replace `setDefaultPresentationResultCallback` /
   `setDefaultPresentationResultHandler` with
   `Purchasely.setDefaultPresentationDismissHandler(outcome => …)`.
7. Remove every call to `presentSubscriptions()`,
   `displaySubscriptionCancellationInstruction()`, `clientPresentationDisplayed` /
   `clientPresentationClosed` — they no longer exist. Build your own screen from
   `userSubscriptions()` / `userSubscriptionsHistory()`.
8. Replace `showPresentation` / `hidePresentation` / `closePresentation` with the
   request lifecycle (`request.display()` / `request.close()` / `request.back()`).
9. Migrate `ProductResult` ordinal checks to the `purchaseResult` string union
   (`'purchased' | 'restored' | 'cancelled'`).
10. `synchronize()` is now awaitable (`Promise<boolean>`) — `await` it before
    chaining a subscriber-targeted placement; old fire-and-forget calls still work.

---

## Removed v5 paywall API → v6 replacement

These were the paywall-related entry points on the `Purchasely` default export.
They have been removed in favour of the builder API.

| Removed v5 method | v6 replacement |
|-------------------|----------------|
| `Purchasely.start({ apiKey, androidStores, storeKit1, userId, logLevel, runningMode })` | `Purchasely.builder(apiKey).appUserId(userId).runningMode('full').logLevel('error').stores(['google']).storekitVersion('storeKit2').start()` |
| `Purchasely.startWithAPIKey(apiKey, stores, userId, logLevel, runningMode)` | `Purchasely.builder(apiKey).appUserId(userId).runningMode('full').start()` |
| `Purchasely.fetchPresentation({ placementId })` | `Purchasely.presentation.placement(id).build().preload()` |
| `Purchasely.presentPresentationForPlacement({ placementVendorId })` | `Purchasely.presentation.placement(id).build().display()` |
| `Purchasely.presentPresentationWithIdentifier({ presentationVendorId })` | `Purchasely.presentation.screen(id).build().display()` |
| `Purchasely.presentPresentation({ presentation })` | preload then display the same request: `const req = Purchasely.presentation.placement(id).build(); await req.preload(); await req.display()` |
| `Purchasely.presentProductWithIdentifier(productId, …)` | `Purchasely.presentation.screen(id).contentId(contentId).build().display()` |
| `Purchasely.presentPlanWithIdentifier(planId, …)` | `Purchasely.presentation.screen(id).build().display()` |
| `Purchasely.showPresentation()` | request lifecycle: `request.display()` |
| `Purchasely.hidePresentation()` / `Purchasely.closePresentation()` | request lifecycle: `request.close()` |
| `Purchasely.setPaywallActionInterceptorCallback(cb)` + `Purchasely.onProcessAction(bool)` | `Purchasely.interceptAction(kind, handler)` — handler returns `'success' \| 'failed' \| 'notHandled'` (no more `onProcessAction`) |
| `Purchasely.setDefaultPresentationResultCallback(cb)` / `setDefaultPresentationResultHandler(cb)` | `Purchasely.setDefaultPresentationDismissHandler(outcome => …)` — global handler for presentations the SDK opens itself (campaigns, deeplinks, Promoted IAP). For paywalls **you** display, use `request.onDismissed(outcome => …)` instead. |
| `Purchasely.readyToOpenDeeplink(true)` | `Purchasely.builder(apiKey).allowDeeplink(true).start()` (or `Purchasely.allowDeeplink(true)`) |
| `Purchasely.isDeeplinkHandled(uri)` | `Purchasely.handleDeeplink(uri)` — **renamed, no alias.** Returns `Promise<boolean>`. |
| `Purchasely.presentSubscriptions()` | **REMOVED — no replacement.** Build your own screen from `userSubscriptions()` / `userSubscriptionsHistory()`. |
| `Purchasely.clientPresentationDisplayed(...)` / `clientPresentationClosed(...)` | **REMOVED — no replacement.** |
| `PLYPaywallAction` / `Purchasely.PaywallAction.*` enum | **REMOVED.** Interceptor kinds are now string literals (`'purchase'`, `'navigate'`, …). |
| `RunningMode.TRANSACTION_ONLY` / `RunningMode.PAYWALL_OBSERVER` | **REMOVED.** Only `'observer'` / `'full'` remain. |

> **Reminder.** Everything *not* in this table — purchases, restore, login,
> attributes, subscriptions data, products, events, offerings, consent and config
> — keeps the exact same `Purchasely.*` signatures. Only the paywall + deeplink
> surface moved.

---

## Initialization

### Before (v5 — removed)

```typescript
import Purchasely, { LogLevels, RunningMode } from 'react-native-purchasely';

await Purchasely.start({
  apiKey: 'YOUR_API_KEY',
  androidStores: ['Google'],
  storeKit1: false,
  userId: 'user_id',
  logLevel: LogLevels.ERROR,
  runningMode: RunningMode.FULL,
});

Purchasely.readyToOpenDeeplink(true);
```

### After (v6)

```typescript
import Purchasely from 'react-native-purchasely';

const configured = await Purchasely.builder('YOUR_API_KEY')
  .appUserId('user_id')         // optional, defaults to anonymous
  .runningMode('full')          // 'observer' (default) | 'full'
  .logLevel('error')            // 'debug' | 'info' | 'warn' | 'error'
  .allowDeeplink(true)          // replaces readyToOpenDeeplink(true)
  .allowCampaigns(true)         // automatic campaigns (default true)
  .stores(['google'])           // Android only: 'google' | 'huawei' | 'amazon'
  .storekitVersion('storeKit2') // iOS only: 'storeKit1' | 'storeKit2'
  .start();
```

> **⚠️ Major breaking change — the default `runningMode` is now `'observer'`
> (v5 effectively defaulted to `full`).** This is a **silent behavioural change**:
> it does **not** produce a compile error, so an app that previously let
> Purchasely own the purchase flow will **stop doing so** after upgrading unless
> it explicitly passes `.runningMode('full')`. Audit every `start()`/`builder()`
> call. The change is consistent across platforms (iOS, Android, Flutter, React
> Native), including the native fallback: any unknown/unset value now resolves to
> `observer`, never `full`.

---

## Displaying a paywall

### Before (v5 — removed)

```typescript
const result = await Purchasely.presentPresentationForPlacement({
  placementVendorId: 'ONBOARDING',
  contentId: 'my_content_id',
  isFullscreen: true,
});

switch (result.result) {
  case ProductResult.PRODUCT_RESULT_PURCHASED:
  case ProductResult.PRODUCT_RESULT_RESTORED:
    console.log('Purchased', result.plan?.name);
    break;
  case ProductResult.PRODUCT_RESULT_CANCELLED:
    break;
}
```

### After (v6)

`display()` resolves at **dismiss** with a `PLYPresentationOutcome`:

```typescript
const outcome = await Purchasely.presentation
  .placement('ONBOARDING')
  .contentId('my_content_id')
  .build()
  .display();

// outcome: { presentation, purchaseResult, plan, closeReason, error }
if (outcome.error) {
  console.error(outcome.error.message);
} else if (outcome.purchaseResult === 'purchased' || outcome.purchaseResult === 'restored') {
  console.log('Purchased', outcome.plan?.name);
} else {
  console.log('Dismissed', outcome.closeReason); // 'button' | 'backSystem' | 'programmatic'
}
```

`purchaseResult` is now a string union (`'purchased' | 'cancelled' | 'restored'`)
instead of the `ProductResult` ordinal enum. `closeReason` is one of `'button'`,
`'backSystem'` (Android system back **and** iOS interactive dismiss both map here)
or `'programmatic'` — there is **no** `interactiveDismiss` value.

### Targeting a specific screen / product / plan

```typescript
// Specific presentation by screen id (was presentPresentationWithIdentifier)
await Purchasely.presentation.screen('SCREEN_ID').build().display();

// Specific product (was presentProductWithIdentifier)
await Purchasely.presentation.screen('SCREEN_ID').contentId('CONTENT_ID').build().display();

// Specific plan (was presentPlanWithIdentifier)
await Purchasely.presentation.screen('SCREEN_ID').build().display();

// Default placement
await Purchasely.presentation.defaultSource().build().display();
```

### Transitions

`display([transition])` takes an optional `PLYTransition` object. Sizing uses
`width` / `height` **dimension objects** (`{ type: 'pixel' | 'percentage', value }`).
The v5 `heightPercentage` field was **removed** — use
`height: { type: 'percentage', value }` instead:

```typescript
await request.display({ type: 'fullScreen' });
await request.display({ type: 'modal', dismissible: false });
await request.display({
  type: 'drawer',
  height: { type: 'percentage', value: 0.6 },
  backgroundColors: { light: '#FFFFFF', dark: '#000000' },
});
```

`type` accepts `'fullScreen'`, `'push'`, `'modal'`, `'drawer'`, `'popin'`,
`'inlinePaywall'`.

---

## Pre-fetching (preload)

### Before (v5 — removed)

```typescript
const presentation = await Purchasely.fetchPresentation({ placementId: 'ONBOARDING' });
const result = await Purchasely.presentPresentation({ presentation });
```

### After (v6)

Build a `PLYPresentationRequest`, `preload()` it to fetch the screen from the
network (it resolves a **`PLYLoadedPresentation`** — data + lifecycle methods),
then `display()` the **same** request when you are ready.

```typescript
const request = Purchasely.presentation.placement('ONBOARDING').build();
const loaded = await request.preload(); // PLYLoadedPresentation
// later, when ready to show it:
const outcome = await loaded.display();  // (same as request.display())
```

---

## Presentation lifecycle (show / hide / close)

The imperative `showPresentation` / `hidePresentation` / `closePresentation`
methods are replaced by the request lifecycle:

```typescript
const request = Purchasely.presentation.placement('ONBOARDING').build();

request.display();  // show
request.close();    // hide / close
request.back();     // navigate back inside a multi-step (Flow) presentation
```

> **`request.close()` platform difference.** On **iOS** it closes the **specific**
> presentation identified by its `requestId` (falling back to closing all
> Purchasely screens when the request is no longer tracked). On **Android** the
> native SDK does not yet expose a per-request close, so it dismisses **all**
> displayed presentations. If you stack presentations, closing one dismisses the
> others on Android.

---

## Action interceptor

`setPaywallActionInterceptorCallback` + `onProcessAction` are replaced by
`Purchasely.interceptAction(kind, handler)`. Register **one handler per action
kind**; the handler returns a `PLYInterceptResult` (`'success' | 'failed' |
'notHandled'`) instead of calling `onProcessAction(true/false)`.

### Before (v5 — removed)

```typescript
Purchasely.setPaywallActionInterceptorCallback((result) => {
  if (result.action === Purchasely.PaywallAction.PURCHASE) {
    MyPurchaseSystem.purchase(result.parameters.plan.productId);
    Purchasely.onProcessAction(false);
  } else {
    Purchasely.onProcessAction(true);
  }
});
```

### After (v6)

```typescript
import { Linking } from 'react-native';

Purchasely.interceptAction('purchase', async (info, payload) => {
  if (payload?.kind === 'purchase') {
    const ok = await MyPurchaseSystem.purchase(payload.plan.productId);
    return ok ? 'success' : 'failed';
  }
  return 'notHandled';
});

Purchasely.interceptAction('navigate', async (info, payload) => {
  if (payload?.kind === 'navigate') {
    Linking.openURL(payload.url);
    return 'success';
  }
  return 'notHandled';
});

// Cleanup
Purchasely.removeActionInterceptor('purchase');
Purchasely.removeAllActionInterceptors();
```

Action kinds (10): `'close'`, `'closeAll'`, `'login'`, `'navigate'`, `'purchase'`,
`'restore'`, `'openPresentation'`, `'openPlacement'`, `'promoCode'`,
`'webCheckout'`. The handler receives a `PLYInterceptorInfo` (`{ contentId?,
presentation? }`) and a **typed payload** discriminated by `payload.kind`:
`PLYPurchasePayload` (`plan`, `subscriptionOffer?`, `offer?`), `PLYNavigatePayload`
(`url`, `title?`), `PLYClosePayload` (`closeReason`), `PLYOpenPresentationPayload`
(`presentationId`), `PLYOpenPlacementPayload` (`placementId`),
`PLYWebCheckoutPayload` (`url`, `clientReferenceId`, `queryParameterKey`,
`webCheckoutProvider`). For `'login'` / `'restore'` / `'promoCode'` the payload is
`null`. If the handler throws it counts as `'failed'`; on iOS a handler that does
not resolve within **30 seconds** falls back to `'notHandled'`.

---

## Deeplinks, campaigns & the default dismiss handler

```typescript
// Allow deeplinks (replaces readyToOpenDeeplink(true)) — set at start:
await Purchasely.builder('YOUR_API_KEY').allowDeeplink(true).start();

// Handle an incoming deeplink at runtime (replaces isDeeplinkHandled — renamed):
const handled = await Purchasely.handleDeeplink('app://ply/presentations/');
```

There are **two distinct paywall flows** — don't conflate them:

### 1. Paywalls **you** display

When your app instantiates the presentation, read the result from that request
(`await display()` or `request.onDismissed(...)`):

```typescript
const outcome = await Purchasely.presentation.placement('ONBOARDING').build().display();
```

### 2. Paywalls the **SDK** opens itself (campaigns, deeplinks, Promoted IAP)

Your app never calls `display()` for these, so there is no request to attach a
callback to. Register the **global default dismiss handler** instead. It is the
v6 replacement for `setDefaultPresentationResultCallback` /
`setDefaultPresentationResultHandler`, and mirrors the native
`Purchasely.setDefaultPresentationDismissHandler`:

```typescript
import Purchasely from 'react-native-purchasely';

const subscription = Purchasely.setDefaultPresentationDismissHandler((outcome) => {
  // outcome: { presentation, purchaseResult, plan, closeReason, error }
  // `presentation` is always populated here — use it to tell which
  // campaign/deeplink screen closed.
  console.log(
    'SDK paywall dismissed:',
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

> **Platform note.** `closeReason` has three values: `button`, `backSystem`
> (Android system back **and** the iOS interactive dismiss — swipe-down / nav pop
> — both map here), and `programmatic`. `error` and `closeReason` are mutually
> exclusive: when `error != null`, `closeReason` is `null`.

---

## Synchronize (now awaitable)

`Purchasely.synchronize()` previously returned `void` (fire-and-forget). The v6
native SDKs expose completion callbacks (iOS `synchronize(success:failure:)`,
Android `synchronize(onSuccess:(PLYPlan?)->Unit, onError:(PLYError?)->Unit)`),
so the bridge now returns a **`Promise<boolean>`** that resolves when the
receipt synchronization completes and rejects on failure.

This is **source-compatible**: existing fire-and-forget callers keep working
(they just ignore the returned promise). New code can await it:

```typescript
try {
  await Purchasely.synchronize(); // resolves when the sync finishes
  console.log('Synchronized');
} catch (e) {
  console.error('Synchronize failed', e); // e.g. PLYError.NoStoreConfigured
}
```

> In Observer mode after a host-side purchase, `await Purchasely.synchronize()`
> before chaining a follow-up placement so the receipt is uploaded first.

---

## What's unchanged

All **core** SDK methods are unchanged in name, signature, and behaviour. Only
the v5 *paywall* surface was removed (plus `synchronize`, which gained an
awaitable result, and the deeplink rename — see above). The following keep working
exactly as in v5:

- **User**: `userLogin`, `userLogout`, `getAnonymousUserId`, `isAnonymous`.
- **Products**: `allProducts`, `productWithIdentifier`, `planWithIdentifier`,
  `purchaseWithPlanVendorId`, `signPromotionalOffer`, `isEligibleForIntroOffer`,
  `setDynamicOffering`, `getDynamicOfferings`, `removeDynamicOffering`,
  `clearDynamicOfferings`.
- **Subscriptions data**: `userSubscriptions` (`{ invalidateCache }`),
  `userSubscriptionsHistory`, `restoreAllProducts`, `silentRestoreAllProducts`,
  `userDidConsumeSubscriptionContent`.
- **Attributes**: `setUserAttributeWith{String,Number,Int,Double,Boolean,Date,StringArray,NumberArray,IntArray,DoubleArray,BooleanArray}`
  (`Int`/`Double` are aliases of `Number`), `incrementUserAttribute`,
  `decrementUserAttribute`, `userAttributes`, `userAttribute`,
  `clearUserAttribute`, `clearUserAttributes`, `clearBuiltInAttributes`,
  `setAttribute`. Legal basis is `PLYDataProcessingLegalBasis.ESSENTIAL` / `.OPTIONAL`.
- **Listeners**: `addEventListener` / `removeEventListener` (aliases
  `listenToEvents` / `stopListeningToEvents`),
  `addPurchasedListener` / `removePurchasedListener` (aliases
  `listenToPurchases` / `stopListeningToPurchases`),
  `addUserAttributeSetListener` / `removeUserAttributeSetListener`,
  `addUserAttributeRemovedListener` / `removeUserAttributeRemovedListener`,
  `setUserAttributeListener` / `clearUserAttributeListener`.
- **Misc**: `setLogLevel`, `setLanguage`, `setThemeMode`, `setDebugMode`,
  `allowDeeplink`, `allowCampaigns`, `revokeDataProcessingConsent`, `getConstants`.
- **Embedded component**: `PLYPresentationView` — now also accepts a preloaded
  `request` prop (see [`integration.md`](./integration.md)).

> **`presentSubscriptions()` is REMOVED in v6 (BREAKING).** The native
> subscriptions screen was removed from **both** the iOS and Android SDKs, so
> `Purchasely.presentSubscriptions()` no longer exists in React Native v6 — it is
> not a no-op, the method is gone entirely. `displaySubscriptionCancellationInstruction()`
> and `clientPresentationDisplayed` / `clientPresentationClosed` are gone too.
> Build your own subscriptions screen from `userSubscriptions()` /
> `userSubscriptionsHistory()`.

> **Native dependency.** This React Native release targets the Purchasely v6 native
> SDKs (iOS `Purchasely 6.0.0-rc.2`, Android `io.purchasely:core 6.0.0-rc.2`),
> published as pre-releases on CocoaPods / Maven Central — see
> [`../sdk-versions.md`](../sdk-versions.md) for the canonical pins. The published
> **React Native** packages are all `6.0.0-rc.2`, pinned exactly to those native
> versions.

---

## Need a hand?

Use the Purchasely AI plugin / skills (`purchasely-integrate`,
`purchasely-review`, `purchasely-debug`) to scan your project and apply this
migration automatically.
