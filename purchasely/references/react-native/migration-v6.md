# React Native — Migrating to the Purchasely 6.0 API

> **Published as a pre-release.** The React Native v6 API ships in
> `react-native-purchasely: 6.0.0-rc.1` (and the matching
> `@purchasely/react-native-purchasely-google` / `-android-player` / `-amazon` /
> `-huawei` packages), live on npm alongside the native iOS `Purchasely 6.0.0-rc.1`
> and Android `io.purchasely:core 6.0.0-rc.1` pre-releases. The builder-based API
> documented below (`Purchasely.builder`, `Purchasely.presentation`,
> `Purchasely.interceptAction`) is the current published surface — the v5
> paywall API (`Purchasely.start({...})`, `fetchPresentation` /
> `presentPresentation[ForPlacement]`, `setPaywallActionInterceptorCallback` +
> `onProcessAction`, `closePresentation()`, `readyToOpenDeeplink`) is **removed**
> (not deprecated): calling any removed method fails to compile (TypeScript) and
> the method no longer exists at runtime.

> **In-repo migration guide.** This is the React Native-specific old→new mapping for
> the Purchasely 6.0 plugin. The companion integration reference is
> [`integration.md`](./integration.md); cross-platform concepts live in
> [`../concepts/`](../concepts/).

This release **adapts the Purchasely React Native plugin to the Purchasely 6.0
native SDKs** (iOS `Purchasely 6.0.0-rc.1`, Android `io.purchasely:core 6.0.0-rc.1`).
There is **no "v6" naming in the JS API** — the public symbols keep their plain
names (`Purchasely.builder`, `PresentationBuilder`, `PresentationRequest`,
`PresentationOutcome`, `Transition`, …). No `v6` / `V6` symbols exist.

Only three areas changed: **starting the SDK**, **displaying / preloading /
closing a presentation**, and the **action interceptor**. Everything else on the
`Purchasely` default export — purchases, restore, identity, catalog,
subscriptions, user attributes, events, dynamic offerings, consent and config —
is **unchanged** (including `isDeeplinkHandled`, which is **kept**, not renamed).

A paywall is now called a **Presentation** (or *Screen*).

> **Tip — let the AI help you migrate.** The Purchasely AI plugin and the
> `purchasely-integrate`, `purchasely-review` and `purchasely-debug` skills can
> read your integration and rewrite the v5 paywall calls to the v6 builder API
> for you. Point them at the files that call `Purchasely.start`,
> `presentPresentationForPlacement`, `fetchPresentation`,
> `setPaywallActionInterceptorCallback`, etc.

---

## TL;DR

- Start the SDK with the fluent builder:
  `Purchasely.builder('…').runningMode('full').start()` (returns `Promise<boolean>`).
- Build a presentation with `Purchasely.presentation`
  (`.placement(id)`, `.screen(id)`, `.default()`), then `.build()` to get a
  **`PresentationRequest`** with a lifecycle (`preload()`, `display(transition?)`,
  `close()`, `back()`).
- `display(transition?)` resolves at **dismiss** with a 5-field
  **`PresentationOutcome`** (`presentation`, `purchaseResult`, `plan`,
  `closeReason`, `error`).
- The interceptor is now `Purchasely.interceptAction(kind, handler)`, where
  `handler` returns a **string** (`'success'` / `'failed'` / `'notHandled'`) —
  there is no more `onProcessAction`.
- Inline rendering still uses the **`PLYPresentationView`** component (unchanged).
- **All other `Purchasely.*` methods are UNCHANGED** — see
  [What's unchanged](#whats-unchanged).

---

## Migration checklist

1. Bump all five npm packages to **`6.0.0-rc.1`** exactly (`--save-exact`); never
   floating. `rm -rf node_modules && npm install`, then `pod install --repo-update`.
2. Replace `Purchasely.start({...})` / `startWithAPIKey(...)` with the
   `Purchasely.builder(apiKey)…start()` chain. **Add `.runningMode('full')`
   explicitly** if you relied on the old implicit Full mode (default is now
   `'observer'`).
3. Replace `fetchPresentation` / `presentPresentation*` /
   `presentProductWithIdentifier` / `presentPlanWithIdentifier` with
   `Purchasely.presentation.placement(id) | .screen(id)` → `.build()` →
   `.preload()` / `.display()`.
4. Replace `setPaywallActionInterceptorCallback` + `onProcessAction` with one
   `Purchasely.interceptAction(kind, handler)` per kind; return
   `'success' | 'failed' | 'notHandled'`.
5. Replace `readyToOpenDeeplink(true)` with `.allowDeeplink(true)` on the builder.
   **Keep `isDeeplinkHandled(uri)`** — it is unchanged in React Native.
6. Replace `setDefaultPresentationResultCallback` /
   `setDefaultPresentationResultHandler` with
   `Purchasely.setDefaultPresentationDismissHandler(outcome => …)`.
7. Remove every call to `presentSubscriptions()` — it no longer exists. Build
   your own screen from `userSubscriptions()` / `userSubscriptionsHistory()`.
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
| `Purchasely.readyToOpenDeeplink(true)` | `Purchasely.builder(apiKey).allowDeeplink(true).start()` |
| `Purchasely.presentSubscriptions()` | **REMOVED — no replacement.** Build your own screen from `userSubscriptions()` / `userSubscriptionsHistory()`. |

> **Reminder.** Everything *not* in this table — purchases, restore, login,
> attributes, subscriptions data, products, events, offerings, consent and config
> — keeps the exact same `Purchasely.*` signatures. Only the paywall surface moved.

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

`display()` resolves at **dismiss** with a `PresentationOutcome`:

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
  console.log('Dismissed', outcome.closeReason); // 'button' | 'backSystem' | 'interactiveDismiss' | 'programmatic'
}
```

`purchaseResult` is now a string union (`'purchased' | 'cancelled' | 'restored'`)
instead of the `ProductResult` ordinal enum.

### Targeting a specific screen / product / plan

```typescript
// Specific presentation by screen id (was presentPresentationWithIdentifier)
await Purchasely.presentation.screen('SCREEN_ID').build().display();

// Specific product (was presentProductWithIdentifier)
await Purchasely.presentation.screen('SCREEN_ID').contentId('CONTENT_ID').build().display();

// Specific plan (was presentPlanWithIdentifier)
await Purchasely.presentation.screen('SCREEN_ID').build().display();
```

---

## Pre-fetching (preload)

### Before (v5 — removed)

```typescript
const presentation = await Purchasely.fetchPresentation({ placementId: 'ONBOARDING' });
const result = await Purchasely.presentPresentation({ presentation });
```

### After (v6)

Build a `PresentationRequest`, `preload()` it to fetch the screen from the
network, then `display()` the **same** request when you are ready.

```typescript
const request = Purchasely.presentation.placement('ONBOARDING').build();
const presentation = await request.preload(); // resolves when the screen is loaded
// later, when ready to show it:
const outcome = await request.display();
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

> `request.close()` currently dismisses **all** displayed presentations (the
> native SDK does not yet expose a per-request close). If you stack
> presentations, closing one will dismiss the others.

---

## Action interceptor

`setPaywallActionInterceptorCallback` + `onProcessAction` are replaced by
`Purchasely.interceptAction(kind, handler)`. Register **one handler per action
kind**; the handler returns `'success' | 'failed' | 'notHandled'` instead of
calling `onProcessAction(true/false)`.

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

Action kinds: `'close'`, `'closeAll'`, `'login'`, `'navigate'`, `'purchase'`,
`'restore'`, `'openPresentation'`, `'openPlacement'`, `'promoCode'`,
`'webCheckout'`. Each kind exposes a typed payload via `payload?.kind`
(e.g. `payload.url` for `'navigate'`, `payload.plan` for `'purchase'`);
payload-less kinds (`'login'`, `'restore'`, `'promoCode'`) carry no extra fields.

---

## Deeplinks, campaigns & the default dismiss handler

```typescript
// Allow deeplinks (replaces readyToOpenDeeplink(true)) — set at start:
await Purchasely.builder('YOUR_API_KEY').allowDeeplink(true).start();
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
    outcome.closeReason     // 'button' | 'backSystem' | 'interactiveDismiss' | 'programmatic' | null
  );
});

// Only one handler is active at a time — calling again replaces it.
// Remove it (e.g. on unmount) with either:
subscription.remove();
// …or:
Purchasely.removeDefaultPresentationDismissHandler();
```

> **Platform note.** `closeReason` is the cross-platform superset: Android
> reports `backSystem` (system back), iOS reports `interactiveDismiss`
> (swipe-down / nav pop). `error` is reserved (always `null` in 6.0).

```typescript
// isDeeplinkHandled is UNCHANGED in React Native (NOT renamed to handleDeeplink):
const handled = await Purchasely.isDeeplinkHandled('app://ply/presentations/');
```

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
awaitable result — see above). The following keep working exactly as in v5:

- **User**: `userLogin`, `userLogout`, `getAnonymousUserId`, `isAnonymous`.
- **Products**: `allProducts`, `productWithIdentifier`, `planWithIdentifier`,
  `purchaseWithPlanVendorId`, `signPromotionalOffer`, `isEligibleForIntroOffer`,
  `setDynamicOffering`, `getDynamicOfferings`, `removeDynamicOffering`,
  `clearDynamicOfferings`.
- **Subscriptions data**: `userSubscriptions`, `userSubscriptionsHistory`,
  `restoreAllProducts`, `silentRestoreAllProducts`,
  `userDidConsumeSubscriptionContent`.
- **Attributes**: `setUserAttributeWith{String,Number,Boolean,Date,StringArray,NumberArray,BooleanArray}`,
  `incrementUserAttribute`, `decrementUserAttribute`, `userAttributes`,
  `userAttribute`, `clearUserAttribute`, `clearUserAttributes`,
  `clearBuiltInAttributes`, `setAttribute`.
- **Listeners**: `addEventListener` / `removeEventListener`,
  `addPurchasedListener` / `removePurchasedListener`,
  `addUserAttributeSetListener` / `removeUserAttributeSetListener`,
  `addUserAttributeRemovedListener` / `removeUserAttributeRemovedListener`.
- **Client (BYOS) presentations**: `clientPresentationDisplayed`,
  `clientPresentationClosed` — unchanged.
- **Misc**: `setLogLevel`, `setLanguage`, `setThemeMode`, `setDebugMode`,
  `isDeeplinkHandled`, `revokeDataProcessingConsent`, `getConstants`, `close`.
- **Embedded component**: `PLYPresentationView` — unchanged.

> **`presentSubscriptions()` is REMOVED in v6 (BREAKING).** The native
> subscriptions screen was removed from **both** the iOS and Android SDKs, so
> `Purchasely.presentSubscriptions()` no longer exists in React Native v6 — it is
> not a no-op, the method is gone entirely. Build your own subscriptions screen
> from `userSubscriptions()` / `userSubscriptionsHistory()`.

> **Native dependency.** This React Native release targets the Purchasely v6 native
> SDKs (iOS `Purchasely 6.0.0-rc.1`, Android `io.purchasely:core 6.0.0-rc.1`),
> published as pre-releases on CocoaPods / Maven Central — see
> [`../sdk-versions.md`](../sdk-versions.md) for the canonical pins. The published
> **React Native** packages are all `6.0.0-rc.1`, pinned exactly to those native
> versions.

---

## Need a hand?

Use the Purchasely AI plugin / skills (`purchasely-integrate`,
`purchasely-review`, `purchasely-debug`) to scan your project and apply this
migration automatically.
