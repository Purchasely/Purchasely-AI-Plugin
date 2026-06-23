# Cordova — Migrating to the Purchasely 6.0 API

> **In-repo migration guide.** This is the Cordova-specific v5 → v6 mapping for the
> Purchasely plugin. The companion integration reference is
> [`integration.md`](./integration.md); cross-platform concepts live in
> [`../concepts/`](../concepts/). Pin to `6.0.0-rc.1` (see [`../sdk-versions.md`](../sdk-versions.md)).

The Cordova plugin v6 wraps the **Purchasely 6.0 native SDKs** (iOS `Purchasely 6.0.0-rc.1`,
Android `io.purchasely:core 6.0.0-rc.1`). Unlike the React Native / Flutter v6 plugins —
which introduced a builder API — the **Cordova JavaScript surface stays method-based and
almost unchanged**: the native bridges were rewired to the v6 SDKs behind the existing
`cordova.exec` actions. Only a few breaking renames apply.

> There is **no v5 source-compatibility shim**: the renamed methods below were renamed,
> not aliased.

---

## How to recognize a v5 Cordova integration

Grep the project for any of these legacy tokens — a hit means the integration is on v5:

```
startWithAPIKey            RunningMode.paywallObserver
setPaywallActionInterceptorCallback        setDefaultPresentationResultHandler
readyToOpenDeeplink        isDeeplinkHandled         Purchasely.handle(
closePaywall               PLYPaywallAction.
```

> The plugin version itself (`@purchasely/cordova-plugin-purchasely`) is the clearest signal:
> `5.7.x` = v5, `6.0.0-rc.1` = v6.

---

## Summary of breaking changes

| v5                                                   | v6                                                              |
|------------------------------------------------------|----------------------------------------------------------------|
| Default running mode `Full`                          | Default running mode `Observer` ⚠️                             |
| `Purchasely.RunningMode.paywallObserver`             | `Purchasely.RunningMode.observer`                              |
| `Purchasely.readyToOpenDeeplink(bool)`               | `Purchasely.allowDeeplink(bool)`                               |
| `Purchasely.isDeeplinkHandled(url, s, e)`            | `Purchasely.handleDeeplink(url, s, e)`                         |
| `Purchasely.synchronize()` (fire-and-forget)         | `Purchasely.synchronize(success, error)` (reports completion)  |
| `Purchasely.setDefaultPresentationResultHandler(cb)` | `Purchasely.setDefaultPresentationDismissHandler(cb)`          |
| `Purchasely.presentSubscriptions()`                  | **no-op** (native subscriptions UI removed)                    |

> **Everything else is unchanged** — `Purchasely.start(...)` (positional, **not** an object),
> `fetchPresentation` / `fetchPresentationForPlacement`, `presentPresentation`,
> `presentPresentationForPlacement`, `setPaywallActionInterceptor` + `onProcessAction`,
> `closePresentation`, `userLogin` / `userLogout`, `allProducts`, `purchaseWithPlanVendorId`,
> `restoreAllProducts`, `userSubscriptions(History)`, every `setUserAttributeWith*`,
> `setThemeMode`, `revokeDataProcessingConsent`, … keep the **same name and signature**.

---

## 1. Update the plugins

```bash
cordova plugin add @purchasely/cordova-plugin-purchasely@6.0.0-rc.1
cordova plugin add @purchasely/cordova-plugin-purchasely-google@6.0.0-rc.1
```

Both plugins must be on the **same** version. Minimum OS: **iOS 13.4**, **Android API 23**
(`compileSdk 36`). There is no video player plugin on Cordova.

---

## 2. Running mode — default is now Observer

```javascript
// Before (v5)
Purchasely.start('API_KEY', ['Google'], false, null,
    Purchasely.LogLevel.DEBUG, Purchasely.RunningMode.paywallObserver, // removed
    onConfigured, onError);

// After (v6)
Purchasely.start('API_KEY', ['Google'], false, null,
    Purchasely.LogLevel.DEBUG,
    Purchasely.RunningMode.full,   // .observer (default) | .full — set .full to handle purchases
    function(isConfigured) {},
    function(error) { console.error(error); });
```

`Purchasely.RunningMode.paywallObserver` was **removed** — use `observer` (same value `2`).
In Observer mode, presentations no longer auto-close after a purchase/restore — close them
yourself with `Purchasely.closePresentation()`.

---

## 3. Deeplinks renamed

```javascript
// Before (v5)
Purchasely.readyToOpenDeeplink(true);
Purchasely.isDeeplinkHandled(url, onHandled, onError);

// After (v6)
Purchasely.allowDeeplink(true);
Purchasely.handleDeeplink(url, onHandled, onError);
```

Deeplinks display immediately by default; pass `allowDeeplink(false)` to defer.

---

## 4. Default dismiss handler

`setDefaultPresentationResultHandler` → `setDefaultPresentationDismissHandler`. The callback
now receives a single rich outcome object. The legacy `result` (PurchaseResult code) and
`plan` fields are kept; `purchaseResult` (string), `closeReason` and `presentation` are added.

```javascript
// After (v6)
Purchasely.setDefaultPresentationDismissHandler(function(outcome) {
    console.log(outcome.presentation && outcome.presentation.screenId);
    console.log(outcome.purchaseResult, outcome.closeReason);
    if (outcome.result === Purchasely.PurchaseResult.PURCHASED) {
        console.log('Purchased', outcome.plan.vendorId);
    }
}, function(error) { console.error(error); });
```

---

## 5. `synchronize` reports completion

```javascript
// Before (v5): fire-and-forget
Purchasely.synchronize();

// After (v6): optional success / error callbacks, resolved on completion
Purchasely.synchronize(function() {}, function(error) {});
```

`Purchasely.synchronize()` with no arguments still works.

---

## 6. `presentSubscriptions` is a no-op

The native subscriptions-list UI was removed from both SDKs. `Purchasely.presentSubscriptions()`
now logs a warning and does nothing (it is **not** removed from the JS surface — it is a no-op).
Build your own screen from `userSubscriptions()` / `userSubscriptionsHistory()`.

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
