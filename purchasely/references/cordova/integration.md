# Cordova Integration

> **Cross-platform reference.** This file covers Cordova-specific syntax for the **v6** SDK (`6.0.0-rc.1`). Many concepts (Observer-mode post-purchase flow, presentation type guard, presentation cache, programmatic purchases, audience-targeting attributes, GDPR consent, subscription checks) are **universal across iOS / Android / RN / Flutter / Cordova** and live in `../concepts/`. Load:
>
> - [`../concepts/running-modes.md`](../concepts/running-modes.md) — Full vs Observer + log levels
> - [`../concepts/paywall-actions.md`](../concepts/paywall-actions.md) — per-action `interceptAction` + `InterceptResult` rules
> - [`../concepts/presentation-types.md`](../concepts/presentation-types.md) — `NORMAL` / `FALLBACK` / `DEACTIVATED` / `CLIENT` guard
> - [`../concepts/presentation-cache.md`](../concepts/presentation-cache.md) — app-side cache (recommended)
> - [`../concepts/observer-mode-post-purchase.md`](../concepts/observer-mode-post-purchase.md) — resolve the interceptor → `closePresentation` ordering, chaining follow-up placements
> - [`../concepts/programmatic-purchases.md`](../concepts/programmatic-purchases.md) — exact `purchaseWithPlanVendorId` syntax
> - [`../concepts/user-attributes-targeting.md`](../concepts/user-attributes-targeting.md) — audience targeting + GDPR consent
> - [`../concepts/privacy-settings.md`](../concepts/privacy-settings.md) — `revokeDataProcessingConsent` and privacy purposes
> - [`../concepts/subscription-checks.md`](../concepts/subscription-checks.md) — gating premium content, restore purchases
> - [`../sdk-versions.md`](../sdk-versions.md) — latest stable versions (pin to **6.0.0-rc.1** for Cordova)
> - [`migration-v6.md`](migration-v6.md) — v5 → v6 migration mapping for Cordova

> **v6 keeps a method-based JS API — but the surface changed.** Unlike native iOS/Android and the React Native / Flutter SDKs, the Cordova plugin does **not** introduce a builder API — the native bridges were rewired to the v6 SDKs behind `cordova.exec` actions. Most methods keep their name and signature, but there are **three breaking surfaces**: `start()` now takes a **single options object** (was positional); the action interceptor is now **per-action** (`interceptAction(kind, handler)` returning an `InterceptResult` — `setPaywallActionInterceptor` + `onProcessAction` were **removed**); and the presentation `isFullscreen` boolean became a **display mode**. Smaller changes: default running mode is now **Observer**, deeplinks use `allowDeeplink` / `handleDeeplink` (+ new `allowCampaigns`), the default dismiss handler is `setDefaultPresentationDismissHandler`, `synchronize` reports completion, and `presentSubscriptions` / `presentProductWithIdentifier` / `presentPlanWithIdentifier` / `showPresentation` / `hidePresentation` were **removed**.

## Installation

Requirements: iOS 13.4+, Android minSdk 23, compileSdk 36. Pin all packages to **6.0.0-rc.1** (see [`../sdk-versions.md`](../sdk-versions.md)). The `6.0.0-rc.1` plugin pulls the **6.0.0-rc.2 native SDKs** (iOS `Purchasely`, Android `io.purchasely:core`).

```bash
# Core plugin
cordova plugin add @purchasely/cordova-plugin-purchasely@6.0.0-rc.1

# Google Play — required if targeting Google Play Store
cordova plugin add @purchasely/cordova-plugin-purchasely-google@6.0.0-rc.1
```

**CRITICAL: All Purchasely packages must be at the exact same version.** A stray `6.0.0` (release) outranks `6.0.0-rc.1` in Gradle and silently upgrades `io.purchasely:core`, causing a runtime `NoSuchMethodError`. There is **no video player plugin on Cordova**.

### Android Setup

Edit `android/build.gradle`:
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
        google()
        mavenCentral()
    }
}
```

## Initialization

In v6, `Purchasely.start(...)` takes a **single options object** followed by `success` / `error` callbacks (the v5 positional argument list is gone). Only `apiKey` is required. **The v6 default running mode is `Observer`** — pass `runningMode: Purchasely.RunningMode.full` if Purchasely must own the purchase flow and validate receipts:

```javascript
document.addEventListener('deviceready', function() {
  Purchasely.start(
    {
      apiKey: 'YOUR_API_KEY',
      stores: [Purchasely.Store.google],   // Store.google | Store.huawei | Store.amazon
      storeKit1: false,                     // iOS only: false = StoreKit 2 (recommended)
      appUserId: null,                      // optional
      logLevel: Purchasely.LogLevel.DEBUG,
      runningMode: Purchasely.RunningMode.full, // ⚠️ v6 default is Observer — set .full to handle purchases
      allowDeeplink: true,                  // optional
      allowCampaigns: true,                 // optional
    },
    function(isConfigured) {
      console.log('Purchasely started:', isConfigured);
    },
    function(error) {
      console.error('Purchasely init failed:', error);
    }
  );
}, false);
```

Recognised options: `apiKey` (required), `appUserId`, `logLevel`, `runningMode`, `stores`, `storeKit1` / `storekitVersion` (iOS), `allowDeeplink`, `allowCampaigns`, `deeplink` (cold-start URL).

> `Purchasely.RunningMode` values are now **name strings** (`'observer'` / `'full'`), not integers — the native iOS and Android enums use different raw values, so the bridge maps by name. `Purchasely.RunningMode.paywallObserver` and `transactionOnly` were **removed** — use `Purchasely.RunningMode.observer`.

## Display a Paywall

### Placement shortcut for simple non-Flow paywalls

`presentPresentationForPlacement(...)` is still available for simple placements guaranteed to host only a non-Flow paywall. For Flow-compatible display, use the fetch + type guard path below.

The `isFullscreen` boolean was replaced by a **display mode**: pass a `Purchasely.TransitionType` string, a legacy boolean (`true` → `fullScreen`, `false` → `modal`, still accepted), or a full transition object for drawer/popin sizing.

```javascript
Purchasely.presentPresentationForPlacement(
  'ONBOARDING',  // placementVendorId
  null,           // contentId (optional)
  Purchasely.TransitionType.fullScreen,  // display mode (string | boolean | transition object)
  function(result) {
    switch (result.result) {
      case Purchasely.PurchaseResult.PURCHASED:
        console.log('Purchased plan:', result.plan);
        break;
      case Purchasely.PurchaseResult.RESTORED:
        console.log('Restored purchases');
        break;
      case Purchasely.PurchaseResult.CANCELLED:
        console.log('User cancelled');
        break;
    }
  },
  function(error) {
    console.error('Presentation error:', error);
  }
);
```

The result object also carries the richer v6 fields `purchaseResult` (string), `closeReason`, and `presentation` alongside the legacy `result` (code) and `plan`.

An optional final `callbacks` object observes the presentation lifecycle: `{ onPresented(presentation, error), onCloseRequested() }`. `success` still receives the final dismiss outcome.

**Rich transitions** (drawer / popin sizing) pass a transition object instead of a string:

```javascript
Purchasely.presentPresentationForPlacement('ONBOARDING', null, {
  type: Purchasely.TransitionType.drawer,
  dismissible: true,
  height: { type: Purchasely.DimensionType.percentage, value: 0.8 }, // 0.0–1.0
  backgroundColor: '#000000'
}, onResult, onError);
```

`TransitionType`: `fullScreen`, `modal`, `drawer`, `popin`, `push`, `inlinePaywall`. `DimensionType`: `pixel`, `percentage` (`width` is popin-only; `height` drives drawer + popin). On **iOS** only a percentage `height` (plus `dismissible` / `backgroundColor`) is applied to drawer/popin; **Android** honors the full set.

To present the default (audience-targeted) presentation with no placement or presentation id, use `presentPresentationForDefault(contentId, displayMode, success, error, callbacks)`.

### Fetch Presentation (check type before displaying)

```javascript
Purchasely.fetchPresentationForPlacement(
  'PREMIUM',  // placementId
  null,       // contentId
  function(presentation) {
    switch (presentation.type) {
      case 'NORMAL':
      case 'FALLBACK':
        Purchasely.presentPresentation(
          presentation,
          Purchasely.TransitionType.fullScreen,  // display mode
          null,  // backgroundColor
          handlePurchaseResult,
          function(error) { console.error('Presentation error:', error); }
        );
        break;
      case 'DEACTIVATED':
        // Do NOT display
        break;
      case 'CLIENT':
        // Use your own UI with Purchasely plan data
        showCustomPaywall(presentation.plans);
        break;
    }
  },
  function(error) {
    console.error('Fetch error:', error);
  }
);
```

`fetchPresentationForDefault(contentId, success, error)` fetches the default (audience-targeted) presentation.

## Action Interceptor

Purchasely 6.0 intercepts actions **per kind**, matching the native SDK. `setPaywallActionInterceptor(callback)` + `onProcessAction(result)` were **removed**. Register a handler for each action you care about with `interceptAction(kind, handler)`. The handler receives `(info, parameters)` and returns — or resolves to — a `Purchasely.InterceptResult` (`success`, `failed`, `notHandled`). Action kinds are on `Purchasely.PresentationAction` (the v5 `PaywallAction` constant was renamed to `PresentationAction`).

```javascript
Purchasely.interceptAction(Purchasely.PresentationAction.login, function(info, parameters) {
  return new Promise(function(resolve) {
    // Present your login screen
    showLoginScreen(function(userId) {
      if (userId) {
        Purchasely.userLogin(userId, function() {});
        resolve(Purchasely.InterceptResult.success);   // the app fully handled login
      } else {
        resolve(Purchasely.InterceptResult.failed);
      }
    });
  });
});

Purchasely.interceptAction(Purchasely.PresentationAction.navigate, function(info, parameters) {
  var url = parameters && parameters.url;
  if (url) {
    window.open(url, '_system');
    return Purchasely.InterceptResult.success;     // the app handled navigation
  }
  return Purchasely.InterceptResult.notHandled;    // let the SDK handle it
});

Purchasely.interceptAction(Purchasely.PresentationAction.purchase, function(info, parameters) {
  // let the SDK run its own purchase flow
  return Purchasely.InterceptResult.notHandled;
});

// Stop intercepting one kind, or all of them:
Purchasely.removeActionInterceptor(Purchasely.PresentationAction.purchase);
Purchasely.removeAllActionInterceptors();
```

- `InterceptResult`: `success` (you handled it), `failed` (you tried and failed), `notHandled` (let the SDK proceed).
- Handlers may return a value **or a `Promise`** — async work (showing your own login screen) is supported; report the result once it resolves.
- Each intercept resolves independently, so concurrent intercepts never clobber one another.
- Registering the same kind again **replaces** its handler.

## Observer Mode — Processing Transactions Yourself

In Observer mode (the v6 default), run your own billing, synchronize, then close the screen (Observer mode does not auto-close). Intercept the `purchase` action, do your work asynchronously, resolve the handler, then dismiss:

```javascript
Purchasely.interceptAction(Purchasely.PresentationAction.purchase, function(info, parameters) {
  var storeProductId = parameters.plan.productId;

  return MyPurchaseSystem.purchase(storeProductId).then(function(ok) {
    if (!ok) return Purchasely.InterceptResult.failed;

    return new Promise(function(resolve) {
      Purchasely.synchronize(
        function() { resolve(Purchasely.InterceptResult.success); },
        function() { resolve(Purchasely.InterceptResult.failed); }
      );
    });
  });
});

function onPurchaseSuccess() {
  Purchasely.closePresentation(); // after the interceptor promise resolved
}
```

`Purchasely.synchronize(success, error)` now reports completion (the v5 fire-and-forget behavior is gone); calling `Purchasely.synchronize()` with no arguments still works.

## Programmatic Purchases

For an app-side purchase button in Full mode, use the Cordova positional API:

```javascript
Purchasely.purchaseWithPlanVendorId(
  'premium_yearly',
  null, // offerId
  null, // contentId
  function(plan) {
    console.log('Purchased plan:', plan);
  },
  function(error) {
    console.error('Purchase failed:', error);
  }
);
```

Do not use `Purchasely.purchase(...)` on Cordova; it is not exposed by the public JS bridge.

## Purchase Result Handling

The result callback receives an object with a `result` property:

| Result | Value | Description |
|--------|-------|-------------|
| `PURCHASED` | `Purchasely.PurchaseResult.PURCHASED` | User successfully purchased a plan |
| `CANCELLED` | `Purchasely.PurchaseResult.CANCELLED` | User cancelled the purchase flow |
| `RESTORED` | `Purchasely.PurchaseResult.RESTORED` | User restored previous purchases |

```javascript
function handlePurchaseResult(result) {
  switch (result.result) {
    case Purchasely.PurchaseResult.PURCHASED:
      unlockPremium(result.plan);
      break;
    case Purchasely.PurchaseResult.RESTORED:
      restorePremium();
      break;
    case Purchasely.PurchaseResult.CANCELLED:
      break;
  }
}
```

## User Management

### Login

```javascript
Purchasely.userLogin(
  'user_123',
  function(shouldRefresh) {
    if (shouldRefresh) {
      // Call your backend to refresh user entitlements
    }
  }
);
```

### Logout

```javascript
Purchasely.userLogout(); // clears the user id and custom attributes
```

## Subscriptions

```javascript
Purchasely.userSubscriptions(function(subscriptions) {
  subscriptions.forEach(function(sub) {
    console.log('Plan:', sub.plan.vendorId, 'Source:', sub.subscriptionSource);
  });
}, function(error) { console.error(error); });
```

> **`presentSubscriptions` was removed in v6.** The native subscriptions-list UI was removed from both SDKs, so there is no `Purchasely.presentSubscriptions()` on the JS surface anymore (calling it throws `TypeError: not a function`). Build your own management screen from `userSubscriptions()` / `userSubscriptionsHistory()`. `presentProductWithIdentifier()`, `presentPlanWithIdentifier()`, `showPresentation()` and `hidePresentation()` were removed too — use placement/screen-based presentation, and `closePresentation()` / `backPresentation()` to control the displayed presentation.

## Deeplinks

```javascript
// Pass an incoming deeplink to the SDK
Purchasely.handleDeeplink('app_scheme://ply/presentations/', function(handled) {
  console.log('Handled by Purchasely?', handled);
});

// Deeplinks display immediately by default. Defer them during a splash/onboarding:
Purchasely.allowDeeplink(false);
// ...later, when ready:
Purchasely.allowDeeplink(true);

// Independently allow/defer campaign deeplinks (new in v6):
Purchasely.allowCampaigns(true);
```

> v5's `readyToOpenDeeplink(bool)` and `isDeeplinkHandled(url, ...)` were **removed** (renamed, not aliased) — use `allowDeeplink(bool)` and `handleDeeplink(url, success, error)`. `allowCampaigns(bool)` is new.

### Default presentation dismiss handler

For presentations opened by the SDK itself (campaigns, deeplinks, promoted in-app purchases), register the default dismiss handler — `setDefaultPresentationDismissHandler` (renamed from v5's `setDefaultPresentationResultHandler`). Stop receiving them with `removeDefaultPresentationDismissHandler()`:

```javascript
Purchasely.setDefaultPresentationDismissHandler(function(outcome) {
  // `presentation` identifies which campaign/deeplink closed
  console.log('Dismissed:', outcome.presentation && outcome.presentation.screenId);
  console.log('Purchase:', outcome.purchaseResult, '/ close:', outcome.closeReason);
  if (outcome.result === Purchasely.PurchaseResult.PURCHASED && outcome.plan) {
    console.log('Purchased', outcome.plan.vendorId);
  }
}, function(error) { console.error(error); });
```

## Custom User Attributes

```javascript
Purchasely.setUserAttributeWithString('favorite_spirit', 'gin');
Purchasely.setUserAttributeWithBoolean('newsletter', true);
Purchasely.setUserAttributeWithInt('viewed_articles', 7);
Purchasely.setUserAttributeWithDouble('avg_session', 4.5);

Purchasely.userAttribute('favorite_spirit', function(value) {
  console.log('favorite_spirit =', value);
});

Purchasely.clearUserAttribute('favorite_spirit');
Purchasely.clearUserAttributes();
```

There is no native increment/decrement on Cordova — read then set with `setUserAttributeWithInt`.

## New v6 constants

The plugin exports these v6 constants (in addition to `LogLevel`, `PurchaseResult`, `RunningMode`, `Attribute`, …):

`PresentationAction` (action kinds for `interceptAction`), `InterceptResult` (`success` / `failed` / `notHandled`), `TransitionType`, `DimensionType`, `Store` (`google` / `huawei` / `amazon`), `StorekitVersion` (`storeKit1` / `storeKit2`), `CloseReason` (`button` / `back_system` / `programmatic`), `PresentationType`.

## Completion Build Gate

Before declaring a Cordova integration complete, build the example app for each target platform and resolve any failure:

```bash
cd purchasely/example
./android.sh   # builds the Android app with the linked plugin
./ios.sh       # builds the iOS app
```

If the build fails, fix the integration and rerun the build until it passes before reporting success.
