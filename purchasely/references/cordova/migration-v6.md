# Cordova — Migrating to the Purchasely 6.0 API

> **Published as a stable release.** The Cordova v6 API ships in
> `@purchasely/cordova-plugin-purchasely: 6.0.0` (and the matching
> `@purchasely/cordova-plugin-purchasely-google: 6.0.0`), live on npm under the
> `latest` dist-tag alongside the native iOS `Purchasely 6.0.0` and Android
> `io.purchasely:core 6.0.1`. Unlike React Native / Flutter / native iOS / Android
> (still pre-release at the time of writing), **Cordova 6.0.0 is a stable GA
> release** — no `@next` / release-candidate tag is involved. The builder-based
> API documented below (`Purchasely.builder`, `Purchasely.presentation`,
> `Purchasely.interceptAction`) is the current published surface — the v5 flat
> paywall API (`fetchPresentation*`, `presentPresentation*`,
> `setPaywallActionInterceptor` + `onProcessAction`, `presentSubscriptions`,
> `readyToOpenDeeplink`, `isDeeplinkHandled`) is **removed** (not deprecated):
> calling any removed method throws (no such export exists on the JS bridge).

> **In-repo migration guide.** This is the Cordova-specific old→new mapping for
> the Purchasely 6.0 plugin. The companion integration reference is
> [`integration.md`](./integration.md); cross-platform concepts live in
> [`../concepts/`](../concepts/).

This release **adapts the Purchasely Cordova plugin to the Purchasely 6.0 native
SDKs** (iOS `Purchasely 6.0.0`, Android `io.purchasely:core 6.0.1`). The public
JS symbols keep the plain `Purchasely.*` naming (Cordova has never used a `PLY`
type prefix in JS — that's a native/RN/Flutter convention). No `v6` / `V6`
symbols exist.

Only a few areas changed: **starting the SDK**, **displaying / preloading /
closing a presentation**, the **action interceptor**, and the **deeplink API**.
Everything else on the `Purchasely` module — purchases, restore, identity,
catalog, subscriptions, user attributes, events, dynamic offerings, consent and
config — is **unchanged**.

A paywall is now called a **Presentation** (or *Screen*).

> **Tip — let the AI help you migrate.** The Purchasely AI plugin and the
> `purchasely-integrate`, `purchasely-review` and `purchasely-debug` skills can
> read your integration and rewrite the v5 paywall calls to the v6 builder API
> for you. Point them at the files that call `Purchasely.start`,
> `presentPresentationForPlacement`, `fetchPresentation`,
> `setPaywallActionInterceptor`, `isDeeplinkHandled`, etc.

---

## TL;DR

- Start the SDK either with the existing options object —
  `Purchasely.start({ apiKey, ... }, success, error)` — or the new fluent
  builder — `Purchasely.builder('…').runningMode('full').start()` (returns a
  `Promise<boolean>` when called with no callbacks, or accepts
  `.start(success, error)`).
- Build a presentation with `Purchasely.presentation` (a
  `PLYPresentationBuilder`-equivalent object): `.placement(id)`, `.screen(id)`,
  `.defaultSource()` (alias `.default()`), then `.build()` to get a
  **presentation request** with a lifecycle (`preload()`, `display(transition?)`,
  `close()`, `back()`).
- `preload()` resolves a **loaded presentation** (screenId-normalized data plus
  `display`/`close`/`back`); it fires the `onLoaded(presentation, error)`
  callback **only on this path** — a bare `display()` has no separate "loaded"
  event.
- `display(transition?)` resolves at **dismiss** with a 5-field **outcome**
  (`presentation`, `purchaseResult`, `plan`, `closeReason`, `error`) — there is
  **no legacy `result` field**.
- The interceptor is now `Purchasely.interceptAction(kind, handler)`, where
  `handler` returns — or resolves to — a `Purchasely.InterceptResult`
  (`'success'` / `'failed'` / `'notHandled'`) — there is no more
  `onProcessAction`.
- Deeplinks: `readyToOpenDeeplink` / `isDeeplinkHandled` are **removed** — use
  `.allowDeeplink(true)` and `Purchasely.handleDeeplink(uri, ok, err)`.
- There is **no inline/embedded presentation view** on Cordova (WebView plugin,
  no declarative native view) — see [Known limitations](#known-limitations--deferred-to-v61).
- **All other `Purchasely.*` methods are UNCHANGED** — see
  [What's unchanged](#whats-unchanged).

---

## Migration checklist

1. Detect the Cordova project (`config.xml`, `plugin.xml` dependents, `www/`
   call sites) and bump both plugins to **`6.0.0`** exactly
   (`cordova plugin add @purchasely/cordova-plugin-purchasely@6.0.0` and
   `...-google@6.0.0`); never a floating range. Re-run `cordova prepare`.
2. Grep for legacy v5 symbols (the ones removed below):
   `presentPresentationForPlacement`, `presentPresentationWithIdentifier`,
   `fetchPresentation`, `fetchPresentationForPlacement`,
   `fetchPresentationForDefault`, `presentPresentation`, `presentSubscriptions`,
   `setPaywallActionInterceptor`, `onProcessAction`, `readyToOpenDeeplink`,
   `isDeeplinkHandled`, `setDefaultPresentationResultHandler`.
3. Replace `Purchasely.start(apiKey, stores, storeKit1, userId, logLevel,
   runningMode, ok, err)` (v5 positional list — no longer accepted) with either
   the **options object** `Purchasely.start({ apiKey, ... }, ok, err)` or the
   **fluent builder** `Purchasely.builder(apiKey)....start()`. **Add
   `.runningMode(Purchasely.RunningMode.full)` explicitly** if you relied on
   the old implicit Full mode (default is now `observer`).
4. Replace `fetchPresentation*` / `presentPresentation*` /
   `presentProductWithIdentifier` / `presentPlanWithIdentifier` with
   `Purchasely.presentation.placement(id) | .screen(id) | .defaultSource()` →
   `.build()` → `.preload()` / `.display()`.
5. Replace `setPaywallActionInterceptor(callback)` + `onProcessAction(bool)`
   with one `Purchasely.interceptAction(kind, handler)` per kind; return
   `'success' | 'failed' | 'notHandled'` (or a Promise resolving one of them)
   instead of calling `onProcessAction`.
6. Replace `readyToOpenDeeplink(true)` with `.allowDeeplink(true)` on the
   builder/options. **Replace `isDeeplinkHandled(url, ok, err)` with
   `Purchasely.handleDeeplink(url, ok, err)`** — the v5 name is removed with no
   alias.
7. Replace `setDefaultPresentationResultHandler(success, error)` with
   `Purchasely.setDefaultPresentationDismissHandler(success, error)`.
8. Remove every call to `presentSubscriptions()` (and
   `presentProductWithIdentifier` / `presentPlanWithIdentifier`, already
   covered in step 4) — they no longer exist. Build your own subscriptions
   screen from `userSubscriptions()` / `userSubscriptionsHistory()`.
9. Update the outcome-handling code: the old `result.result` int enum
   (`Purchasely.PurchaseResult.PURCHASED` etc.) is replaced by
   `outcome.purchaseResult` — a **string** (`'purchased' | 'cancelled' |
   'restored'`). Compare `outcome.closeReason` against the
   `Purchasely.CloseReason.*` constants, never the raw string.
10. Update tests under the example app / your own test harness to the v6 API
    and run `npx jest` (or the project's JS test command) until green.

---

## Removed v5 paywall API → v6 replacement

These were the paywall-related entry points on the `Purchasely` JS export. They
have been removed in favour of the builder API.

| Removed v5 method | v6 replacement |
|-------------------|----------------|
| `Purchasely.start(apiKey, stores, storeKit1, userId, logLevel, runningMode, ok, err)` (positional) | `Purchasely.start({ apiKey, stores, storeKit1, appUserId, logLevel, runningMode }, ok, err)` **or** `Purchasely.builder(apiKey).stores([...]).runningMode('full').start()` |
| `Purchasely.fetchPresentation(id, contentId, ok, err)` | `Purchasely.presentation.screen(id).contentId(contentId).build().preload()` |
| `Purchasely.fetchPresentationForPlacement(id, contentId, ok, err)` | `Purchasely.presentation.placement(id).contentId(contentId).build().preload()` |
| `Purchasely.fetchPresentationForDefault(contentId, ok, err)` | `Purchasely.presentation.defaultSource().contentId(contentId).build().preload()` |
| `Purchasely.presentPresentationForPlacement(id, contentId, isFullscreen, ok, err)` | `Purchasely.presentation.placement(id).contentId(contentId).build().display({ type: 'fullScreen' })` |
| `Purchasely.presentPresentationWithIdentifier(id, contentId, ok, err)` | `Purchasely.presentation.screen(id).contentId(contentId).build().display()` |
| `Purchasely.presentPresentation(presentation, isFullscreen, backgroundColor, ok, err)` | preload then display the same request: `const req = Purchasely.presentation.placement(id).build(); await req.preload(); await req.display();` |
| `Purchasely.presentProductWithIdentifier(productId, …)` | `Purchasely.presentation.screen(id).contentId(contentId).build().display()` |
| `Purchasely.presentPlanWithIdentifier(planId, …)` | `Purchasely.presentation.screen(id).build().display()` |
| `Purchasely.setPaywallActionInterceptor(cb)` + `Purchasely.onProcessAction(bool)` | `Purchasely.interceptAction(kind, handler)` — handler returns `'success' \| 'failed' \| 'notHandled'` (no more `onProcessAction`) |
| `Purchasely.setDefaultPresentationResultHandler(success, error)` | `Purchasely.setDefaultPresentationDismissHandler(success, error)` |
| `Purchasely.readyToOpenDeeplink(true)` | `.allowDeeplink(true)` on the builder/options (or `Purchasely.allowDeeplink(true)` at runtime) |
| `Purchasely.isDeeplinkHandled(url, ok, err)` | `Purchasely.handleDeeplink(url, ok, err)` — **renamed, no alias.** |
| `Purchasely.presentSubscriptions()` | **REMOVED — no replacement.** Build your own screen from `userSubscriptions()` / `userSubscriptionsHistory()`. |

> **Reminder.** Everything *not* in this table — purchases, restore, login,
> attributes, subscriptions data, products, events, offerings, consent and
> config — keeps the exact same `Purchasely.*` signatures. Only the paywall +
> deeplink surface moved.

---

## Initialization

Cordova v6 supports **two** ways to start the SDK — pick one.

### Before (v5 — positional args, removed)

```javascript
Purchasely.start(
  'YOUR_API_KEY',
  ['Google'],
  false,                        // storeKit1
  null,                         // userId
  Purchasely.LogLevel.DEBUG,
  Purchasely.RunningMode.full,
  function (isConfigured) { /* ... */ },
  function (error) { /* ... */ }
);
```

### After (v6) — options object (same shape, now a single object)

```javascript
Purchasely.start(
  {
    apiKey: 'YOUR_API_KEY',
    appUserId: null,
    logLevel: Purchasely.LogLevel.DEBUG,
    runningMode: Purchasely.RunningMode.full,   // 'observer' (default) | 'full'
    stores: [Purchasely.Store.google],
    storeKit1: false,                           // iOS only
    storekitVersion: Purchasely.StorekitVersion.storeKit2, // iOS only
    allowDeeplink: true,
    allowCampaigns: true,
    deeplink: null,                              // cold-start deeplink URL
  },
  function (isConfigured) { /* ... */ },
  function (error) { /* ... */ }
);
```

### After (v6) — fluent builder (RECOMMENDED, parity with RN/Flutter)

```javascript
// Promise form (no callbacks passed to start())
const isConfigured = await Purchasely.builder('YOUR_API_KEY')
  .appUserId('user_id')                                   // optional
  .runningMode(Purchasely.RunningMode.full)                // observer (default) | full
  .logLevel(Purchasely.LogLevel.DEBUG)
  .allowDeeplink(true)                                     // replaces readyToOpenDeeplink(true)
  .allowCampaigns(true)                                    // optional, default true
  .stores([Purchasely.Store.google])                       // Android: google | huawei | amazon
  .storekitVersion(Purchasely.StorekitVersion.storeKit2)   // iOS: storeKit1 | storeKit2
  .storeKit1(false)                                        // iOS legacy toggle, alt to storekitVersion
  .deeplink(null)                                           // cold-start deeplink URL
  .start();

// Callback form is also supported:
Purchasely.builder('YOUR_API_KEY')
  .runningMode(Purchasely.RunningMode.full)
  .start(
    function (isConfigured) { /* ... */ },
    function (error) { /* ... */ }
  );
```

> **⚠️ Major breaking change — the default `runningMode` is now `'observer'`
> (v5 effectively defaulted to `full`).** This is a **silent behavioural
> change**: it does **not** throw, so an app that previously let Purchasely own
> the purchase flow will **stop doing so** after upgrading unless it explicitly
> passes `runningMode: Purchasely.RunningMode.full` (options object) or
> `.runningMode(Purchasely.RunningMode.full)` (builder). Audit every
> `start()`/`builder()` call site. The change is consistent across platforms
> (iOS, Android, Flutter, React Native, Cordova) — any unknown/unset value now
> resolves to `observer`, never `full`. `Purchasely.RunningMode` has **only
> two** values (`observer`, `full`) — `paywallObserver` / `transactionOnly`
> never existed on the Cordova bridge and remain absent.

---

## Displaying a paywall

### Before (v5 — removed)

```javascript
Purchasely.presentPresentationForPlacement(
  'ONBOARDING',
  null,   // contentId
  true,   // isFullscreen
  function (result) {
    switch (result.result) {
      case Purchasely.PurchaseResult.PURCHASED:
      case Purchasely.PurchaseResult.RESTORED:
        console.log('Purchased', result.plan);
        break;
      case Purchasely.PurchaseResult.CANCELLED:
        break;
    }
  },
  function (error) { console.error(error); }
);
```

### After (v6)

`display()` resolves at **dismiss** with a 5-field outcome:

```javascript
const outcome = await Purchasely.presentation
  .placement('ONBOARDING')
  .contentId('my_content_id')
  .build()
  .display();

// outcome: { presentation, purchaseResult, plan, closeReason, error }
if (outcome.error) {
  console.error(outcome.error.message);
} else if (outcome.purchaseResult === 'purchased' || outcome.purchaseResult === 'restored') {
  console.log('Purchased', outcome.plan && outcome.plan.name);
} else {
  console.log('Dismissed', outcome.closeReason); // compare against Purchasely.CloseReason.*
}
```

`purchaseResult` is a string (`'purchased' | 'cancelled' | 'restored'`, `null`
when no purchase occurred) — the old `result.result` int enum
(`Purchasely.PurchaseResult.*`) is gone from the outcome shape. `closeReason`
is one of `Purchasely.CloseReason.button`, `.backSystem` or `.programmatic` —
**always compare against the constant**, never hardcode the wire string: the
`backSystem` constant's underlying value is `'back_system'` (snake_case), and
iOS reports a swipe/interactive dismiss as `backSystem` too. A close **after a
successful purchase** omits `closeReason` (it is `null`).

### Targeting a specific screen / product / plan

```javascript
// Specific presentation by screen id (was presentPresentationWithIdentifier)
await Purchasely.presentation.screen('SCREEN_ID').build().display();

// Specific product (was presentProductWithIdentifier)
await Purchasely.presentation.screen('SCREEN_ID').contentId('CONTENT_ID').build().display();

// Specific plan (was presentPlanWithIdentifier)
await Purchasely.presentation.screen('SCREEN_ID').build().display();

// Default (audience-targeted) placement (was fetchPresentationForDefault / presentPresentationForDefault)
await Purchasely.presentation.defaultSource().build().display(); // alias: .default()
```

### Transitions

`display(transition?)` takes an optional transition — a
`Purchasely.TransitionType` string, a legacy boolean (`true` → `fullScreen`,
`false` → `modal`), or a full object for drawer/popin sizing:

```javascript
await Purchasely.presentation.placement('ONBOARDING').build().display({
  type: Purchasely.TransitionType.drawer,
  dismissible: true,
  height: { type: Purchasely.DimensionType.percentage, value: 0.6 },
  backgroundColor: '#101010',
});
```

`TransitionType`: `fullScreen`, `modal`, `drawer`, `popin`, `push`,
`inlinePaywall`. `DimensionType`: `pixel`, `percentage`.

> **Platform note.** On **iOS**, only a *percentage* `height` (plus
> `dismissible` and `backgroundColor`) is applied to `drawer`/`popin` — pixel
> sizing and `width` are not exposed to the bridge by the native iOS SDK.
> **Android** honors the full set (`width`, `height`, both dimension types).

---

## Pre-fetching (preload)

### Before (v5 — removed)

```javascript
Purchasely.fetchPresentationForPlacement('ONBOARDING', null, function (presentation) {
  Purchasely.presentPresentation(presentation, true, null, handlePurchaseResult, handleError);
}, handleError);
```

### After (v6)

Build a request, `preload()` it to fetch the screen from the network (it
resolves a **loaded presentation** — screenId-normalized data plus
`display`/`close`/`back` — and fires `onLoaded(presentation, error)` if you
registered one), then `display()` it when you're ready:

```javascript
const request = Purchasely.presentation
  .placement('ONBOARDING')
  .onLoaded((presentation, error) => console.log('loaded', presentation && presentation.screenId))
  .build();

const loaded = await request.preload();
// ...later, when ready to show it:
const outcome = await loaded.display(); // same as request.display()
```

> **`onLoaded` only fires on the `preload()` path.** A bare `display()` (no
> prior `preload()`) has no separate "loaded" event — it goes straight to
> `onPresented`. `onPresented` / `onCloseRequested` fire on **both** the direct
> `display()` path and the `preload()` → `display()` re-display path.

---

## Presentation lifecycle (close / back)

```javascript
const request = Purchasely.presentation.placement('ONBOARDING').build();

request.display();  // show
request.close();    // closeAllScreens() under the hood — closes every displayed screen
request.back();      // navigate back inside a multi-step (Flow) presentation
```

There is no per-request `close()` on Cordova (unlike iOS's request-scoped
close on React Native) — `request.close()` always dismisses every displayed
Purchasely screen, matching `Purchasely.closeAllScreens()`.
`Purchasely.closePresentation()` is kept as a **deprecated alias** of
`closeAllScreens()`.

---

## Action interceptor

`setPaywallActionInterceptor(callback)` + `onProcessAction(bool)` are replaced
by `Purchasely.interceptAction(kind, handler)`. Register **one handler per
action kind**; the handler receives `(info, parameters)` and returns — or
resolves to — a `Purchasely.InterceptResult` (`'success'` / `'failed'` /
`'notHandled'`) instead of calling `onProcessAction(true/false)`.

### Before (v5 — removed)

```javascript
Purchasely.setPaywallActionInterceptor(function (result) {
  switch (result.action) {
    case 'LOGIN':
      showLoginScreen(function (userId) {
        if (userId) {
          Purchasely.userLogin(userId);
          Purchasely.onProcessAction(true);
        } else {
          Purchasely.onProcessAction(false);
        }
      });
      break;
    case 'NAVIGATE':
      window.open(result.parameters && result.parameters.url, '_system');
      Purchasely.onProcessAction(false);
      break;
    default:
      Purchasely.onProcessAction(true);
      break;
  }
});
```

### After (v6)

```javascript
Purchasely.interceptAction(Purchasely.PresentationAction.purchase, function (info, parameters) {
  // let the SDK proceed with the native purchase
  return Purchasely.InterceptResult.notHandled;
});

Purchasely.interceptAction(Purchasely.PresentationAction.login, function (info, parameters) {
  return new Promise(function (resolve) {
    showLoginScreen(function (userId) {
      if (userId) {
        Purchasely.userLogin(userId);
        resolve(Purchasely.InterceptResult.success);
      } else {
        resolve(Purchasely.InterceptResult.failed);
      }
    });
  });
});

Purchasely.interceptAction(Purchasely.PresentationAction.navigate, function (info, parameters) {
  window.open(parameters && parameters.url, '_system');
  return Purchasely.InterceptResult.success;
});

// Cleanup
Purchasely.removeActionInterceptor(Purchasely.PresentationAction.purchase);
Purchasely.removeAllActionInterceptors();
```

`Purchasely.PresentationAction` lists all **10** kinds — keys are **camelCase**
(parity with RN/Flutter); the underlying wire values stay `snake_case`, so
always compare against the constant, never a hardcoded string:

| Constant | Wire value |
|---|---|
| `Purchasely.PresentationAction.close` | `'close'` |
| `Purchasely.PresentationAction.closeAll` | `'close_all'` |
| `Purchasely.PresentationAction.login` | `'login'` |
| `Purchasely.PresentationAction.navigate` | `'navigate'` |
| `Purchasely.PresentationAction.purchase` | `'purchase'` |
| `Purchasely.PresentationAction.restore` | `'restore'` |
| `Purchasely.PresentationAction.openPresentation` | `'open_presentation'` |
| `Purchasely.PresentationAction.openPlacement` | `'open_placement'` |
| `Purchasely.PresentationAction.promoCode` | `'promo_code'` |
| `Purchasely.PresentationAction.webCheckout` | `'web_checkout'` |

Handlers may return a value directly or a `Promise` resolving one — async work
(e.g. showing your own login screen, awaiting a host purchase flow) is
supported. Each intercepted call resolves independently, so concurrent
intercepts never clobber one another.

### Removed: the single global interceptor

`setPaywallActionInterceptor(callback)` + `Purchasely.onProcessAction(bool)`
are **removed** — there is no global interceptor and no `onProcessAction` in
v6. The `PaywallAction` constant is **renamed to `PresentationAction`**.

---

## Deeplinks & the default dismiss handler

```javascript
// Allow deeplinks (replaces readyToOpenDeeplink(true)) — set at start, or at runtime:
Purchasely.allowDeeplink(true);
Purchasely.allowCampaigns(true); // new: gate automatic campaign display

// Handle an incoming deeplink at runtime (replaces isDeeplinkHandled — renamed, no alias):
Purchasely.handleDeeplink(
  'purchasely://your-deeplink-url',
  function (handled) { console.log('Handled by Purchasely:', handled); },
  function (error) { console.error(error); }
);
```

There are **two distinct paywall flows** — don't conflate them:

### 1. Paywalls **you** display

Read the result from that request's own `display()` / `onDismissed(...)`:

```javascript
const outcome = await Purchasely.presentation.placement('ONBOARDING').build().display();
```

### 2. Paywalls the **SDK** opens itself (campaigns, deeplinks, Promoted IAP)

Your app never calls `display()` for these, so there is no request to attach a
callback to. Register the **global default dismiss handler** instead — the v6
replacement for `setDefaultPresentationResultHandler`:

```javascript
Purchasely.setDefaultPresentationDismissHandler(
  function (outcome) {
    // outcome: { presentation, purchaseResult, plan, closeReason, error }
    console.log(
      'SDK paywall dismissed:',
      outcome.presentation && outcome.presentation.screenId,
      outcome.purchaseResult,
      outcome.closeReason
    );
  },
  function (error) { console.error(error); }
);

// Stop receiving these:
Purchasely.removeDefaultPresentationDismissHandler();
```

---

## Removed: `presentSubscriptions()` (BREAKING)

`Purchasely.presentSubscriptions()` is **removed entirely** (the native
subscriptions screen was removed on both platforms) — it is **not** a no-op,
the method no longer exists on the JS bridge. Remove every call and build your
own subscriptions screen from `Purchasely.userSubscriptions()` /
`Purchasely.userSubscriptionsHistory()` (both now accept an
`invalidateCache` boolean).

---

## Synchronize (now reports completion)

`Purchasely.synchronize()` was fire-and-forget in v5. It now accepts
`(success, error)` callbacks and reports completion:

```javascript
Purchasely.synchronize(
  function (ok) { console.log('Synchronized', ok); },
  function (error) { console.error('Synchronize failed', error); }
);
```

Fire-and-forget calls (`Purchasely.synchronize()`, no args) still work. In
Observer mode, synchronize before chaining a follow-up subscriber-targeted
placement so the receipt is uploaded first.

---

## Apple commitment info (iOS 26.4+, Apple only)

Apple's "monthly subscription with 12-month commitment" is surfaced through the
bridge. These fields are **iOS-only** — absent on Android and on plans /
subscriptions without a commitment:

- `Purchasely.BillingPlanType` — `{ unspecified: 0, upFront: 1, monthly: 2 }`.
  Pass it as the 4th argument of
  `setDynamicOffering(reference, planVendorId, offerVendorId, billingPlanType, success, error)`.
- `plan.commitmentInfo` — an array on plans (`allProducts()`,
  `planWithIdentifier()`, a presentation outcome's `plan`, and the
  `interceptAction('purchase')` payload's `parameters.plan`), each entry
  `{ billingPlanType, billingPrice, billingPeriod, totalPrice, totalPeriod, totalDuration }`.
- `subscription.commitmentProgress` — on subscriptions
  (`userSubscriptions()` / `userSubscriptionsHistory()`):
  `{ billingPeriodNumber, totalBillingPeriods, commitmentExpiresDate, commitmentPrice }`.

---

## Other v6 changes

- `Purchasely.closeAllScreens()` is the canonical name; `closePresentation()`
  is kept as a **deprecated alias**.
- `Purchasely.addEventListener` / `removeEventListener` are canonical;
  `addEventsListener` / `removeEventsListener` are kept as **deprecated
  aliases** (the original Cordova-only spelling).
- `Purchasely.userLogout(clearUserAttributes)` gained a boolean parameter
  (default `true`) controlling whether locally cached user attributes are also
  cleared.
- `userSubscriptions(success, error, invalidateCache)` /
  `userSubscriptionsHistory(success, error, invalidateCache)` gained an
  `invalidateCache` parameter to force a fresh fetch.
- New read accessors: `getBuiltInAttribute(key, ok, err)`,
  `getBuiltInAttributes(ok, err)`, `isAnonymous(ok, err)`,
  `userAttributes(ok, err)` (bulk read).
- `incrementUserAttribute(key, value)` / `decrementUserAttribute(key, value)`
  default `value` to `1` when omitted.
- `signPromotionalOffer(...)` is a **no-op on Android** (resolves without
  signing) — it only does real work on iOS.
- `Purchasely.Attribute` gained `ONESIGNAL_USER_ID`.
- `Purchasely.PresentationType` — `{ normal: 0, fallback: 1, deactivated: 2,
  client: 3 }`. `deactivated` means no paywall is configured for that
  placement (do not display); `client` means Build-Your-Own-Screen — render
  your own UI from the presentation's `plans`.
- Exported constants: `LogLevel`, `RunningMode`, `Attribute`, `PurchaseResult`,
  `PlanType`, `SubscriptionSource`, `InterceptResult`, `PresentationType`,
  `CloseReason`, `TransitionType`, `DimensionType`, `Store`,
  `StorekitVersion`, `PresentationAction`, `BillingPlanType`, `ThemeMode`,
  `DataProcessingLegalBasis`, `DataProcessingPurpose`.

---

## Known limitations / deferred to v6.1

Cordova 6.0.0 intentionally does **not** have full API parity with React
Native / Flutter yet. These gaps are tracked in the Linear project
**"Cordova — parité & compléments v6.1"** — do not tell a developer these are
available today:

- **No inline/embedded presentation view.** Cordova is a WebView plugin with
  no declarative native view layer, so there is no equivalent of RN/Flutter's
  `PLYPresentationView` widget/component. If the app needs an embedded
  (non-fullscreen, in-layout) paywall, it is not available on Cordova.
- **Builder style modifiers `progressColor` / `displayCloseButton` /
  `displayBackButton` are not wired.** Only `.backgroundColor(hex)` is exposed
  by the Cordova native layer; no present action accepts the other three.
- **`automaticDeeplinkHandling` (Android start option) is not available** on
  Cordova.
- **BYOS `clientPresentationDisplayed` / `clientPresentationClosed` hooks are
  not available** on Cordova. Use `presentation.type ===
  Purchasely.PresentationType.client` from a `preload()`/`display()` result to
  detect a Build-Your-Own-Screen presentation instead.
- **Event transport.** Cordova uses `cordova.exec` keep-alive callbacks (no
  `NativeEventEmitter`) for listeners — the event payload shapes match
  RN/Flutter even though the transport differs.

---

## What's unchanged

All **core** SDK methods are unchanged in name, signature, and behaviour. Only
the v5 *paywall* surface was removed (plus `synchronize`, which gained
completion callbacks, and the deeplink rename — see above). The following keep
working exactly as in v5:

- **User**: `userLogin`, `userLogout` (now takes an optional
  `clearUserAttributes` bool), `getAnonymousUserId`, `isAnonymous`.
- **Products**: `allProducts`, `productWithIdentifier`, `planWithIdentifier`,
  `purchaseWithPlanVendorId`, `signPromotionalOffer`, `isEligibleForIntroOffer`,
  `setDynamicOffering`, `getDynamicOfferings`, `removeDynamicOffering`,
  `clearDynamicOfferings`.
- **Subscriptions data**: `userSubscriptions`, `userSubscriptionsHistory`
  (both now accept `invalidateCache`), `restoreAllProducts`,
  `silentRestoreAllProducts`, `userDidConsumeSubscriptionContent`.
- **Attributes**: `setUserAttributeWith{String,Boolean,Int,Double,Date,StringArray,IntArray,DoubleArray,BooleanArray}`,
  `incrementUserAttribute`, `decrementUserAttribute`, `userAttribute`,
  `userAttributes`, `clearUserAttribute`, `clearUserAttributes`,
  `clearBuiltInAttributes`, `getBuiltInAttribute(s)`, `setAttribute`. Legal
  basis is `Purchasely.DataProcessingLegalBasis.essential` / `.optional`.
- **Listeners**: `addEventListener` / `removeEventListener` (deprecated
  aliases `addEventsListener` / `removeEventsListener`),
  `addUserAttributeListener` / `removeUserAttributeListener`.
- **Misc**: `setLogLevel`, `setLanguage`, `setThemeMode`, `setDebugMode`,
  `allowDeeplink`, `allowCampaigns`, `revokeDataProcessingConsent`.

> **`presentSubscriptions()` is REMOVED in v6 (BREAKING).** See
> [Removed: `presentSubscriptions()`](#removed-presentsubscriptions-breaking)
> above.

> **Native dependency.** This Cordova release targets the Purchasely v6 native
> SDKs (iOS `Purchasely 6.0.0`, Android `io.purchasely:core 6.0.1`), published
> as **stable** releases on CocoaPods / Maven Central — see
> [`../sdk-versions.md`](../sdk-versions.md) for the canonical pins. Both
> Cordova packages (`@purchasely/cordova-plugin-purchasely` and
> `@purchasely/cordova-plugin-purchasely-google`) are `6.0.0`, pinned exactly.

---

## Need a hand?

Use the Purchasely AI plugin / skills (`purchasely-integrate`,
`purchasely-review`, `purchasely-debug`) to scan your project and apply this
migration automatically.
