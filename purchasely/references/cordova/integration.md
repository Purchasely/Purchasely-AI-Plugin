# Cordova Integration

> **Cross-platform reference.** This file covers Cordova-specific syntax for the **v6** SDK (`6.0.0-rc.1`). Many concepts (Observer-mode post-purchase flow, presentation type guard, presentation cache, programmatic purchases, audience-targeting attributes, GDPR consent, subscription checks) are **universal across iOS / Android / RN / Flutter / Cordova** and live in `../concepts/`. Load:
>
> - [`../concepts/running-modes.md`](../concepts/running-modes.md) — Full vs Observer + log levels
> - [`../concepts/paywall-actions.md`](../concepts/paywall-actions.md) — `PaywallAction` + interceptor rules
> - [`../concepts/presentation-types.md`](../concepts/presentation-types.md) — `NORMAL` / `FALLBACK` / `DEACTIVATED` / `CLIENT` guard
> - [`../concepts/presentation-cache.md`](../concepts/presentation-cache.md) — app-side cache (recommended)
> - [`../concepts/observer-mode-post-purchase.md`](../concepts/observer-mode-post-purchase.md) — `onProcessAction → closePresentation` ordering, chaining follow-up placements
> - [`../concepts/programmatic-purchases.md`](../concepts/programmatic-purchases.md) — exact `purchaseWithPlanVendorId` syntax
> - [`../concepts/user-attributes-targeting.md`](../concepts/user-attributes-targeting.md) — audience targeting + GDPR consent
> - [`../concepts/privacy-settings.md`](../concepts/privacy-settings.md) — `revokeDataProcessingConsent` and privacy purposes
> - [`../concepts/subscription-checks.md`](../concepts/subscription-checks.md) — gating premium content, restore purchases
> - [`../sdk-versions.md`](../sdk-versions.md) — latest stable versions (pin to **6.0.0-rc.1** for Cordova)
> - [`migration-v6.md`](migration-v6.md) — v5 → v6 migration mapping for Cordova

> **v6 keeps the same method-based JS API.** Unlike native iOS/Android and the React Native / Flutter SDKs, the Cordova plugin does **not** introduce a builder API — the native bridges were rewired to the v6 SDKs behind the same `cordova.exec` actions. Only a few breaking renames apply: default running mode is now **Observer**, deeplinks use `allowDeeplink` / `handleDeeplink`, the default dismiss handler is `setDefaultPresentationDismissHandler`, `synchronize` reports completion, and `presentSubscriptions` is a **no-op**.

## Installation

Requirements: iOS 13.4+, Android minSdk 23, compileSdk 36. Pin all packages to **6.0.0-rc.1** (see [`../sdk-versions.md`](../sdk-versions.md)).

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

Initialize with callback style in your `deviceready` handler. **The v6 default running mode is `Observer`** — pass `Purchasely.RunningMode.full` if Purchasely must own the purchase flow and validate receipts:

```javascript
document.addEventListener('deviceready', function() {
  Purchasely.start(
    'YOUR_API_KEY',              // apiKey
    ['Google'],                  // androidStores: 'Google', 'Huawei', 'Amazon'
    false,                       // storeKit1: false = use StoreKit 2 (recommended)
    null,                        // userId (optional)
    Purchasely.LogLevel.DEBUG,   // logLevel
    Purchasely.RunningMode.full, // ⚠️ v6 default is Observer — set .full to handle purchases
    function(isConfigured) {
      console.log('Purchasely started:', isConfigured);
    },
    function(error) {
      console.error('Purchasely init failed:', error);
    }
  );
}, false);
```

> `Purchasely.RunningMode.paywallObserver` was **removed** in v6 — use `Purchasely.RunningMode.observer` (same value `2`).

## Display a Paywall

### Placement shortcut for simple non-Flow paywalls

`presentPresentationForPlacement(...)` is still available for simple placements guaranteed to host only a non-Flow paywall. For Flow-compatible display, use the fetch + type guard path below.

```javascript
Purchasely.presentPresentationForPlacement(
  'ONBOARDING',  // placementVendorId
  null,           // contentId (optional)
  true,           // isFullscreen
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
          true,  // isFullscreen
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

## Action Interceptor

Intercept paywall actions to inject custom behavior. Cordova uses `setPaywallActionInterceptor(...)`, **not** `setPaywallActionInterceptorCallback(...)`. Action values are the lowercase strings on `Purchasely.PaywallAction`.

```javascript
Purchasely.setPaywallActionInterceptor(function(result) {
  var action = result.action;
  var parameters = result.parameters;
  var info = result.info;

  switch (action) {
    case Purchasely.PaywallAction.login:
      // Present your login screen
      showLoginScreen(function(userId) {
        if (userId) {
          Purchasely.userLogin(userId, function() {});
          Purchasely.onProcessAction(true);
        } else {
          Purchasely.onProcessAction(false);
        }
      });
      break;

    case Purchasely.PaywallAction.navigate:
      var url = parameters && parameters.url;
      if (url) {
        window.open(url, '_system');
      }
      Purchasely.onProcessAction(false);
      break;

    case Purchasely.PaywallAction.purchase:
    case Purchasely.PaywallAction.restore:
    case Purchasely.PaywallAction.close:
    default:
      Purchasely.onProcessAction(true);
      break;
  }
});
```

**Important:** You must call `Purchasely.onProcessAction(true/false)` in every code path. Failing to do so will freeze the paywall UI.

## Observer Mode — Processing Transactions Yourself

In Observer mode (the v6 default), run your own billing, synchronize, then close the screen (Observer mode does not auto-close):

```javascript
Purchasely.setPaywallActionInterceptor(function(result) {
  if (result.action === Purchasely.PaywallAction.purchase) {
    var storeProductId = result.parameters.plan.productId;
    MyPurchaseSystem.purchase(storeProductId, function() {
      Purchasely.synchronize();          // upload the receipt to Purchasely
      Purchasely.onProcessAction(false); // you handled the purchase
      Purchasely.closePresentation();    // Observer mode does not auto-close
    }, function() {
      Purchasely.onProcessAction(false);
    });
  } else {
    Purchasely.onProcessAction(true);
  }
});
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

> **`presentSubscriptions` is a no-op in v6.** The native subscriptions-list UI was removed from both SDKs. `Purchasely.presentSubscriptions()` logs a warning and does nothing — build your own management screen from `userSubscriptions()` / `userSubscriptionsHistory()`.

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
```

> v5's `readyToOpenDeeplink(bool)` and `isDeeplinkHandled(url, ...)` were **removed** — use `allowDeeplink(bool)` and `handleDeeplink(url, success, error)`.

### Default presentation dismiss handler

For presentations opened by the SDK itself (campaigns, deeplinks, promoted in-app purchases), register the default dismiss handler — `setDefaultPresentationDismissHandler` (renamed from v5's `setDefaultPresentationResultHandler`):

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

## Completion Build Gate

Before declaring a Cordova integration complete, build the example app for each target platform and resolve any failure:

```bash
cd purchasely/example
./android.sh   # builds the Android app with the linked plugin
./ios.sh       # builds the iOS app
```

If the build fails, fix the integration and rerun the build until it passes before reporting success.
