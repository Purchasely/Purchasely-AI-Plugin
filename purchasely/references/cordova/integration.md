# Cordova Integration

> **Cross-platform reference.** This file covers Cordova-specific syntax. Many concepts (Observer-mode post-purchase flow, presentation type guard, presentation cache, programmatic purchases, audience-targeting attributes, GDPR consent, subscription checks) are **universal across iOS / Android / RN / Flutter / Cordova** and live in `../concepts/`. Load:
>
> - [`../concepts/running-modes.md`](../concepts/running-modes.md) — Full vs Observer + log levels
> - [`../concepts/paywall-actions.md`](../concepts/paywall-actions.md) — `PLYPresentationAction` enum + interceptor rules
> - [`../concepts/presentation-types.md`](../concepts/presentation-types.md) — `NORMAL` / `FALLBACK` / `DEACTIVATED` / `CLIENT` guard
> - [`../concepts/presentation-cache.md`](../concepts/presentation-cache.md) — app-side cache (recommended)
> - [`../concepts/observer-mode-post-purchase.md`](../concepts/observer-mode-post-purchase.md) — `synchronize → dismiss` ordering, chaining follow-up placements
> - [`../concepts/programmatic-purchases.md`](../concepts/programmatic-purchases.md) — exact `purchaseWithPlanVendorId` syntax
> - [`../concepts/user-attributes-targeting.md`](../concepts/user-attributes-targeting.md) — audience targeting + GDPR consent
> - [`../concepts/privacy-settings.md`](../concepts/privacy-settings.md) — `revokeDataProcessingConsent` and privacy purposes
> - [`../concepts/subscription-checks.md`](../concepts/subscription-checks.md) — gating premium content, restore purchases
> - [`../sdk-versions.md`](../sdk-versions.md) — latest stable versions (pin to **6.0.0** for Cordova)
> - [`./migration-v6.md`](./migration-v6.md) — full v5 → v6 API mapping if migrating an existing integration

**Cordova is on the v6 builder API** (`Purchasely.builder`, `Purchasely.presentation`, `Purchasely.interceptAction`) as a **stable** release (npm `latest`, not `@next`) — pulling native iOS `Purchasely 6.0.0` / Android `io.purchasely:core 6.0.1`.

## Installation

Requirements: iOS 11.0+, Android minSdk 23, compileSdk 36, targetSdk 35. Pin all packages to **6.0.0** (see [`../sdk-versions.md`](../sdk-versions.md)).

```bash
# Core plugin
cordova plugin add @purchasely/cordova-plugin-purchasely@6.0.0

# Google Play — required if targeting Google Play Store
cordova plugin add @purchasely/cordova-plugin-purchasely-google@6.0.0
```

**CRITICAL: All Purchasely packages must be at the exact same version.**

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
        mavenCentral()
    }
}
```

## Initialization

Cordova v6 supports **two** ways to start the SDK. The fluent builder is recommended (parity with RN/Flutter); the options-object form is also accepted.

**Fluent builder (recommended):**

```javascript
document.addEventListener('deviceready', function() {
  Purchasely.builder('YOUR_API_KEY')
    .runningMode(Purchasely.RunningMode.full)                 // ⚠️ default is 'observer' in v6 — set 'full' explicitly if Purchasely should own the purchase flow
    .logLevel(Purchasely.LogLevel.DEBUG)
    .stores([Purchasely.Store.google])                        // Android: google | huawei | amazon
    .storekitVersion(Purchasely.StorekitVersion.storeKit2)     // iOS only
    .allowDeeplink(true)
    .allowCampaigns(true)
    .start(
      function(success) { console.log('Purchasely started:', success); },
      function(error) { console.error('Purchasely init failed:', error); }
    );
}, false);
```

**Options object (also supported):**

```javascript
Purchasely.start(
  {
    apiKey: 'YOUR_API_KEY',
    stores: [Purchasely.Store.google],
    storeKit1: false,                       // iOS only
    appUserId: null,
    logLevel: Purchasely.LogLevel.DEBUG,
    runningMode: Purchasely.RunningMode.full, // ⚠️ default is 'observer' in v6
    allowDeeplink: true,
  },
  function(success) { console.log('Purchasely started:', success); },
  function(error) { console.error('Purchasely init failed:', error); }
);
```

> **⚠️ Breaking change vs v5.** The default `runningMode` is now `Purchasely.RunningMode.observer` (v5 effectively defaulted to Full). If the app expects Purchasely to process and validate purchases, set `.runningMode(Purchasely.RunningMode.full)` explicitly.

## Display a Paywall

Build a request with `Purchasely.presentation`, then `.preload()` it to inspect the `type` and/or `.display()` it. The v5 `fetchPresentation*` / `presentPresentation*` / `presentPresentationForPlacement` methods are **removed**.

```javascript
var request = Purchasely.presentation
  .placement('PREMIUM')  // or .screen('SCREEN_ID') / .defaultSource()
  .build();

request.preload().then(function(loaded) {
  switch (loaded.type) {
    case Purchasely.PresentationType.normal:
    case Purchasely.PresentationType.fallback:
      request.display().then(handlePurchaseResult).catch(function(error) {
        console.error('Presentation error:', error);
      });
      break;
    case Purchasely.PresentationType.deactivated:
      // Do NOT display
      break;
    case Purchasely.PresentationType.client:
      // Use your own UI with Purchasely plan data
      showCustomPaywall(loaded.plans);
      break;
  }
}).catch(function(error) {
  console.error('Fetch error:', error);
});
```

If you don't need to inspect the type first, build and display in one chain:

```javascript
Purchasely.presentation.placement('ONBOARDING').build().display()
  .then(handlePurchaseResult)
  .catch(function(error) { console.error('Presentation error:', error); });
```

`display(transition?)` takes an optional `Purchasely.TransitionType` (`fullScreen`, `modal`, `drawer`, `popin`, `push`, `inlinePaywall`) or a full object for drawer/popin sizing. There is no per-request `close()` on Cordova — `request.close()` always dismisses every displayed Purchasely screen (`closeAllScreens()` under the hood); `request.back()` navigates back inside a multi-step (Flow) presentation.

## Action Interceptor

Register **one handler per action kind** with `Purchasely.interceptAction(kind, handler)`. The handler returns — or resolves to — a `Purchasely.InterceptResult` (`success` / `failed` / `notHandled`) instead of calling `onProcessAction`. The v5 `setPaywallActionInterceptor` + `onProcessAction` are **removed**.

```javascript
Purchasely.interceptAction(Purchasely.PresentationAction.login, function(info, parameters) {
  return new Promise(function(resolve) {
    showLoginScreen(function(userId) {
      if (userId) {
        Purchasely.userLogin(userId);
        resolve(Purchasely.InterceptResult.success);
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
  }
  return Purchasely.InterceptResult.success;
});

// In Full mode, let Purchasely run the purchase itself:
Purchasely.interceptAction(Purchasely.PresentationAction.purchase, function(info, parameters) {
  return Purchasely.InterceptResult.notHandled;
});
```

`Purchasely.PresentationAction` (camelCase keys, `snake_case` wire values): `close`, `closeAll`, `login`, `navigate`, `purchase`, `restore`, `openPresentation`, `openPlacement`, `promoCode`, `webCheckout`. Handlers may return a value directly or a `Promise` resolving one — each intercepted call resolves independently.

**Important:** Every registered handler must resolve to a `Purchasely.InterceptResult` on every code path (success, error, cancellation). A path that never resolves freezes the paywall.

## Programmatic Purchases

Unchanged from v5. For an app-side purchase button in Full mode:

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

`display()` resolves at **dismiss** with a 5-field **outcome** — there is no legacy `result` field:

| Field | Description |
|-------|--------------|
| `presentation` | The presentation that was displayed |
| `purchaseResult` | `'purchased'` \| `'cancelled'` \| `'restored'` \| `null` (string, not the old int enum) |
| `plan` | The purchased/restored plan, if any |
| `closeReason` | `Purchasely.CloseReason.button` \| `.backSystem` \| `.programmatic` \| `null` (always compare against the constant) |
| `error` | Populated on failure |

```javascript
function handlePurchaseResult(outcome) {
  if (outcome.error) {
    console.error(outcome.error.message);
    return;
  }
  switch (outcome.purchaseResult) {
    case 'purchased':
      unlockPremium(outcome.plan);
      break;
    case 'restored':
      restorePremium();
      break;
    default:
      // Dismissed without purchase — check outcome.closeReason if needed
      break;
  }
}
```

## User Management

### Login

```javascript
Purchasely.userLogin(
  'user_123',
  function(success) {
    console.log('User logged in:', success);
  }
);
```

### Logout

```javascript
Purchasely.userLogout(); // optional bool: clearUserAttributes (default true)
```

## User Attributes

```javascript
// String attribute
Purchasely.setUserAttributeWithString('first_name', 'John');

// Numeric attributes
Purchasely.setUserAttributeWithInt('age', 30, Purchasely.DataProcessingLegalBasis.optional);
Purchasely.setUserAttributeWithDouble('score', 4.5, Purchasely.DataProcessingLegalBasis.optional);

// Boolean attribute
Purchasely.setUserAttributeWithBoolean('is_premium', true);
```

## Subscriptions

Fetch the user's active subscriptions (now accepts an optional `invalidateCache` boolean to force a fresh fetch):

```javascript
Purchasely.userSubscriptions(
  function(subscriptions) {
    subscriptions.forEach(function(sub) {
      console.log('Plan:', sub.plan.vendorId);
      console.log('Store:', sub.subscriptionSource);
    });
  },
  function(error) {
    console.error('Failed to fetch subscriptions:', error);
  },
  false // invalidateCache
);
```

`Purchasely.presentSubscriptions()` is **removed entirely** in v6 (not a no-op) — build your own subscriptions screen from `userSubscriptions()` / `userSubscriptionsHistory()`.

## Deeplinks

### Allow Deeplinks (replaces `readyToOpenDeeplink`)

```javascript
Purchasely.allowDeeplink(true);
Purchasely.allowCampaigns(true); // gate automatic campaign display
```

### Handle Incoming Deeplink (replaces `isDeeplinkHandled` — renamed, no alias)

```javascript
Purchasely.handleDeeplink(
  'purchasely://your-deeplink-url',
  function(handled) {
    if (handled) {
      console.log('Deeplink handled by Purchasely');
    }
  },
  function(error) {
    console.error('Deeplink error:', error);
  }
);
```

### Default Presentation Dismiss Handler

For paywalls the SDK opens itself (campaigns, deeplinks, Promoted IAP) — your app never calls `display()` for these, so register the global handler instead:

```javascript
Purchasely.setDefaultPresentationDismissHandler(
  function(outcome) { console.log('SDK paywall dismissed:', outcome.purchaseResult, outcome.closeReason); },
  function(error) { console.error(error); }
);
```

## Synchronize Purchases

`synchronize()` now reports completion (v5 was fire-and-forget):

```javascript
Purchasely.synchronize(
  function(ok) { console.log('Synchronized', ok); },
  function(error) { console.error('Synchronize failed', error); }
);
```

Fire-and-forget calls (`Purchasely.synchronize()`, no args) still work.

## Complete Integration Example

```javascript
var app = {
  initialize: function() {
    document.addEventListener('deviceready', this.onDeviceReady.bind(this), false);
  },

  onDeviceReady: function() {
    Purchasely.builder('YOUR_API_KEY')
      .runningMode(Purchasely.RunningMode.full)
      .logLevel(Purchasely.LogLevel.DEBUG)
      .stores([Purchasely.Store.google])
      .allowDeeplink(true)
      .start(function() {
        console.log('Purchasely ready');

        // Set up action interceptors (one per kind)
        Purchasely.interceptAction(Purchasely.PresentationAction.login, function(info, parameters) {
          return new Promise(function(resolve) {
            app.showLogin(function(userId) {
              if (userId) {
                Purchasely.userLogin(userId);
                resolve(Purchasely.InterceptResult.success);
              } else {
                resolve(Purchasely.InterceptResult.failed);
              }
            });
          });
        });
      }, function(error) {
        console.error('Purchasely failed:', error);
      });
  },

  showPaywall: function() {
    Purchasely.presentation.placement('ONBOARDING').build().display()
      .then(function(outcome) {
        console.log('Result:', outcome.purchaseResult);
      })
      .catch(function(error) {
        console.error('Presentation error:', error);
      });
  },

  showLogin: function(callback) {
    // Your login logic here
    var userId = prompt('Enter user ID:');
    callback(userId);
  }
};

app.initialize();
```
