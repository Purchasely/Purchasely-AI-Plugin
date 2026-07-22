# Cordova — Migrating to the Purchasely 6.0 API

> **In-repo migration guide.** This is the Cordova-specific v5 → v6 mapping for the
> Purchasely plugin. The companion integration reference is
> [`integration.md`](./integration.md); cross-platform concepts live in
> [`../concepts/`](../concepts/). Pin to `6.0.0-rc.3` (see [`../sdk-versions.md`](../sdk-versions.md)).

The Cordova plugin v6 (`6.0.0-rc.3`) wraps the **Purchasely 6.0 native SDKs** (iOS
`Purchasely 6.0.0-rc.3`, Android `io.purchasely:core 6.0.0-rc.3`). Unlike the React Native /
Flutter v6 plugins — which introduced a builder API — the **Cordova JavaScript surface stays
method-based**: the native bridges were rewired to the v6 SDKs behind the existing
`cordova.exec` actions. Most methods keep their name and signature, but there are **three
breaking surfaces** — `start()`, the **action interceptor**, and the presentation
**display mode** — plus several renamed/removed methods.

> There is **no v5 source-compatibility shim**: the renamed methods below were renamed,
> not aliased, and the removed ones no longer resolve.

---

## How to recognize a v5 Cordova integration

Grep the project for any of these legacy tokens — a hit means the integration is on v5:

```
Purchasely.start('              (positional string apiKey — v6 takes an options object)
setPaywallActionInterceptor     onProcessAction          PaywallAction
RunningMode.paywallObserver     RunningMode.transactionOnly
readyToOpenDeeplink             isDeeplinkHandled
setDefaultPresentationResultHandler
presentSubscriptions            presentProductWithIdentifier   presentPlanWithIdentifier
showPresentation                hidePresentation
isFullscreen                    closePaywall
```

> The plugin version itself (`@purchasely/cordova-plugin-purchasely`) is the clearest signal:
> `5.7.x` = v5, `6.0.0-rc.3` = v6.

---

## Summary of breaking changes

| v5                                                    | v6                                                                                  |
|-------------------------------------------------------|-------------------------------------------------------------------------------------|
| `Purchasely.start(apiKey, stores, …)` (positional)    | **`Purchasely.start(options, success, error)`** — single config object ⚠️           |
| Default running mode `Full`                           | Default running mode `Observer` ⚠️                                                  |
| `RunningMode` integer values                          | **name strings** (`'observer'` / `'full'`); `paywallObserver` / `transactionOnly` removed |
| `setPaywallActionInterceptor(cb)` + `onProcessAction` | **`interceptAction(kind, handler)`** returning an `InterceptResult` ⚠️               |
| `PaywallAction`                                        | **`PresentationAction`** (renamed; same string values)                              |
| `isFullscreen` boolean on `present*`                  | **display mode** (`TransitionType` string / boolean / transition object)            |
| `presentSubscriptions()`                              | **removed** (build your own from `userSubscriptions()` / `userSubscriptionsHistory()`) |
| `presentProductWithIdentifier()` / `presentPlanWithIdentifier()` | **removed** (use placement/screen presentation)                          |
| `showPresentation()` / `hidePresentation()`           | **removed** (use `closePresentation()` / new `backPresentation()`)                  |
| `readyToOpenDeeplink(bool)`                           | `allowDeeplink(bool)` (+ new `allowCampaigns(bool)`)                                 |
| `isDeeplinkHandled(url, s, e)`                        | `handleDeeplink(url, s, e)`                                                          |
| `synchronize()` (fire-and-forget)                     | `synchronize(success, error)` (reports completion)                                  |
| `setDefaultPresentationResultHandler(cb)`             | `setDefaultPresentationDismissHandler(cb)` (+ `removeDefaultPresentationDismissHandler()`) |

> **Unchanged** — `fetchPresentation` / `fetchPresentationForPlacement`, `presentPresentation`,
> `presentPresentationForPlacement` / `presentPresentationWithIdentifier` (only their
> `isFullscreen` arg became a display mode), `closePresentation`, `userLogin` / `userLogout`,
> `allProducts`, `purchaseWithPlanVendorId`, `restoreAllProducts`, `silentRestoreAllProducts`,
> `userSubscriptions(History)`, every `setUserAttributeWith*`, `setThemeMode`,
> `revokeDataProcessingConsent`, `addEventsListener`, … keep the **same name and signature**.
> New in v6: `presentPresentationForDefault`, `fetchPresentationForDefault`, `backPresentation`,
> `allowCampaigns`, `removeDefaultPresentationDismissHandler`.

---

## 1. Update the plugins

```bash
cordova plugin add @purchasely/cordova-plugin-purchasely@6.0.0-rc.3
cordova plugin add @purchasely/cordova-plugin-purchasely-google@6.0.0-rc.3
```

> npm's `latest` dist-tag still resolves to `5.7.3` — `6.0.0-rc.3` is published under the `next`
> dist-tag. Always give an explicit version (as above) or `--tag next`; a bare `cordova plugin add
> @purchasely/cordova-plugin-purchasely` silently installs v5.

Both plugins must be on the **same** version. Minimum OS: **iOS 13.4**, **Android API 23**
(`compileSdk 36`). There is no video player plugin on Cordova.

---

## 2. `start()` now takes an options object (breaking)

The positional argument list is replaced by a single configuration object followed by the
`success` / `error` callbacks. Only `apiKey` is required.

```javascript
// Before (v5) — positional
Purchasely.start('API_KEY', ['Google'], false, null,
    Purchasely.LogLevel.DEBUG, Purchasely.RunningMode.full,
    onConfigured, onError);

// After (v6) — options object
Purchasely.start(
  {
    apiKey: 'API_KEY',
    stores: [Purchasely.Store.google],       // Store.google | Store.huawei | Store.amazon
    storeKit1: false,                         // iOS only
    appUserId: null,
    logLevel: Purchasely.LogLevel.DEBUG,
    runningMode: Purchasely.RunningMode.full, // .observer (default) | .full — set .full for purchases
    allowDeeplink: true,                      // optional
    allowCampaigns: true,                     // optional
  },
  function(isConfigured) {},
  function(error) { console.error(error); }
);
```

Recognised options: `apiKey` (required), `appUserId`, `logLevel`, `runningMode`, `stores`,
`storeKit1` / `storekitVersion` (iOS), `allowDeeplink`, `allowCampaigns`, `deeplink` (cold-start URL).

---

## 3. Running mode — new values, new default

Native 6.0 removed `transactionOnly` and `paywallObserver`; only **`observer`** and **`full`**
remain, and the SDK now **defaults to `observer`** (5.x behaved like `full`).

- `RunningMode` values are now **name strings** (`'observer'` / `'full'`), not integers — the
  native iOS and Android enums use different raw values, so the bridge maps by name.
- `Purchasely.RunningMode.paywallObserver` was **removed** — use `observer`.
- **To keep the 5.x behaviour where Purchasely owns the purchase flow, pass
  `runningMode: Purchasely.RunningMode.full`.** In Observer mode, presentations no longer
  auto-close after a purchase/restore — close them yourself with `Purchasely.closePresentation()`.

---

## 4. Action interceptor — now per-action (breaking)

`setPaywallActionInterceptor(callback)` + `onProcessAction(result)` were **removed**. Purchasely
6.0 intercepts actions **per kind**, matching the native SDK. Register a handler per action with
`interceptAction(kind, handler)`; the handler receives `(info, parameters)` and returns — or
resolves to — an `InterceptResult` (`success`, `failed`, `notHandled`).

```javascript
// Before (v5)
Purchasely.setPaywallActionInterceptor(function(result) {
  if (result.action === Purchasely.PaywallAction.login) {
    showLogin(function(id) { Purchasely.userLogin(id, function(){}); Purchasely.onProcessAction(true); });
  } else {
    Purchasely.onProcessAction(true);
  }
});

// After (v6) — one handler per kind, returns an InterceptResult
Purchasely.interceptAction(Purchasely.PresentationAction.login, function(info, parameters) {
  return new Promise(function(resolve) {
    showLogin(function(id) {
      Purchasely.userLogin(id, function() {});
      resolve(Purchasely.InterceptResult.success);
    });
  });
});

Purchasely.interceptAction(Purchasely.PresentationAction.purchase, function(info, parameters) {
  return Purchasely.InterceptResult.notHandled;   // let the SDK proceed
});

// Stop intercepting one kind, or all:
Purchasely.removeActionInterceptor(Purchasely.PresentationAction.login);
Purchasely.removeAllActionInterceptors();
```

- `InterceptResult`: `success` / `failed` / `notHandled`.
- The `PaywallAction` constant was **renamed to `PresentationAction`** (same string values); the old name was removed.
- Handlers may return a value or a `Promise`; async work is supported.

---

## 5. Presentation display mode (breaking)

The `isFullscreen` boolean on the `present*` methods is replaced by a **display mode**. Pass a
`Purchasely.TransitionType` string, a legacy boolean (`true` → `fullScreen`, `false` → `modal`,
still accepted), or a full transition object for drawer/popin sizing.

```javascript
// Before (v5)
Purchasely.presentPresentationForPlacement('ONBOARDING', null, true, ok, err);

// After (v6) — display-mode string
Purchasely.presentPresentationForPlacement('ONBOARDING', null, Purchasely.TransitionType.fullScreen, ok, err);

// After (v6) — transition object (drawer/popin sizing)
Purchasely.presentPresentationForPlacement('ONBOARDING', null, {
  type: Purchasely.TransitionType.drawer,
  dismissible: true,
  height: { type: Purchasely.DimensionType.percentage, value: 0.8 },
  backgroundColor: '#000000'
}, ok, err);
```

`present*` methods also gained an optional final `callbacks` object:
`{ onPresented(presentation, error), onCloseRequested() }`. New sources:
`presentPresentationForDefault(...)` / `fetchPresentationForDefault(...)` (audience-targeted,
no placement id), and `backPresentation()` to navigate back within a displayed presentation.

**Removed present methods:** `presentSubscriptions()`, `presentProductWithIdentifier()`,
`presentPlanWithIdentifier()`, `showPresentation()`, `hidePresentation()`. Build subscription UI
from `userSubscriptions()` / `userSubscriptionsHistory()`; use placement/screen presentation for
products/plans.

---

## 6. Deeplinks renamed

```javascript
// Before (v5)
Purchasely.readyToOpenDeeplink(true);
Purchasely.isDeeplinkHandled(url, onHandled, onError);

// After (v6)
Purchasely.allowDeeplink(true);
Purchasely.handleDeeplink(url, onHandled, onError);
Purchasely.allowCampaigns(true);   // new — allow/defer campaign deeplinks independently
```

The old names were **removed** (not aliased). Deeplinks display immediately by default; pass
`allowDeeplink(false)` to defer.

---

## 7. Default dismiss handler

`setDefaultPresentationResultHandler` → `setDefaultPresentationDismissHandler` (old name removed).
Stop receiving these with `removeDefaultPresentationDismissHandler()`. The callback receives a
single rich outcome object: `result` (PurchaseResult code) and `plan` are kept; `purchaseResult`
(string), `closeReason` (`button` / `back_system` / `programmatic`), `presentation` and `error`
are added.

```javascript
Purchasely.setDefaultPresentationDismissHandler(function(outcome) {
    console.log(outcome.presentation && outcome.presentation.screenId);
    console.log(outcome.purchaseResult, outcome.closeReason);
    if (outcome.result === Purchasely.PurchaseResult.PURCHASED) {
        console.log('Purchased', outcome.plan.vendorId);
    }
}, function(error) { console.error(error); });
```

---

## 8. `synchronize` reports completion

```javascript
// Before (v5): fire-and-forget
Purchasely.synchronize();

// After (v6): optional success / error callbacks, resolved on completion
Purchasely.synchronize(function(ok) {}, function(error) {});
```

`Purchasely.synchronize()` with no arguments still works.

> **Interceptor guidance.** Resolving a `.purchase` / `.restore` interceptor with `success`
> already **auto-synchronizes** the receipt — do not call `Purchasely.synchronize()` from inside
> that handler (see "Observer Mode — Processing Transactions Yourself" in
> [`integration.md`](./integration.md)). Reserve manual `synchronize()` calls for purchases
> processed **outside** the interceptor flow (a "Restore Purchases" button, a client-side/BYOS
> presentation).

---

## 9. New exported constants

`InterceptResult`, `PresentationAction` (was `PaywallAction`), `PresentationType`, `CloseReason`,
`TransitionType`, `DimensionType`, `Store`, `StorekitVersion`.

---

## Verification

Build the example app for both platforms and resolve any failure before declaring the
migration complete:

```bash
cd purchasely/example
./android.sh
./ios.sh
```

If the build fails, fix the integration and rerun the build until it passes.
