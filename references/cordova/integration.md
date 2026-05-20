# Cordova Integration

> **Cross-platform reference.** This file covers Cordova-specific syntax. Many concepts (Observer-mode post-purchase flow, presentation type guard, presentation cache, programmatic purchases, audience-targeting attributes, GDPR consent, subscription checks) are **universal across iOS / Android / RN / Flutter / Cordova** and live in `../concepts/`. Load:
>
> - [`../concepts/running-modes.md`](../concepts/running-modes.md) — Full vs Observer + log levels
> - [`../concepts/paywall-actions.md`](../concepts/paywall-actions.md) — `PLYPresentationAction` enum + interceptor rules
> - [`../concepts/presentation-types.md`](../concepts/presentation-types.md) — `NORMAL` / `FALLBACK` / `DEACTIVATED` / `CLIENT` guard
> - [`../concepts/presentation-cache.md`](../concepts/presentation-cache.md) — app-side cache (recommended)
> - [`../concepts/observer-mode-post-purchase.md`](../concepts/observer-mode-post-purchase.md) — `proceed → closePresentation` ordering, chaining follow-up placements
> - [`../concepts/programmatic-purchases.md`](../concepts/programmatic-purchases.md) — exact `purchaseWithPlanVendorId` syntax
> - [`../concepts/user-attributes-targeting.md`](../concepts/user-attributes-targeting.md) — audience targeting + GDPR consent
> - [`../concepts/privacy-settings.md`](../concepts/privacy-settings.md) — `revokeDataProcessingConsent` and privacy purposes
> - [`../concepts/subscription-checks.md`](../concepts/subscription-checks.md) — gating premium content, restore purchases
> - [`../sdk-versions.md`](../sdk-versions.md) — latest stable versions (pin to **5.7.3** for Cordova)

## Installation

Requirements: iOS 11.0+, Android minSdk 21, compileSdk 33. Pin all packages to **5.7.3** (see [`../sdk-versions.md`](../sdk-versions.md)).

```bash
# Core plugin
cordova plugin add @purchasely/cordova-plugin-purchasely@5.7.3

# Google Play — required if targeting Google Play Store
cordova plugin add @purchasely/cordova-plugin-purchasely-google@5.7.3
```

**CRITICAL: All Purchasely packages must be at the exact same version.**

### Android Setup

Edit `android/build.gradle`:
```groovy
buildscript {
    ext {
        minSdkVersion = 21
        compileSdkVersion = 33
        targetSdkVersion = 33
    }
}
allprojects {
    repositories {
        mavenCentral()
    }
}
```

## Initialization

Initialize with callback style in your `deviceready` handler:

```javascript
document.addEventListener('deviceready', function() {
  Purchasely.start(
    'YOUR_API_KEY',           // apiKey
    ['Google'],                // androidStores: 'Google', 'Huawei', 'Amazon'
    false,                     // storeKit1: false = use StoreKit 2 (recommended)
    null,                      // userId (optional)
    Purchasely.LogLevel.DEBUG, // logLevel
    Purchasely.RunningMode.full, // runningMode: full or paywallObserver
    function(success) {
      console.log('Purchasely started:', success);
    },
    function(error) {
      console.error('Purchasely init failed:', error);
    }
  );
}, false);
```

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

Intercept paywall actions to inject custom behavior. Cordova uses `setPaywallActionInterceptor(...)`, not `setPaywallActionInterceptorCallback(...)`.

```javascript
Purchasely.setPaywallActionInterceptor(function(result) {
  var action = result.action;
  var parameters = result.parameters;
  var info = result.info;

  switch (action) {
    case 'LOGIN':
      // Present your login screen
      showLoginScreen(function(userId) {
        if (userId) {
          Purchasely.userLogin(userId);
          Purchasely.onProcessAction(true);
        } else {
          Purchasely.onProcessAction(false);
        }
      });
      break;

    case 'NAVIGATE':
      var url = parameters && parameters.url;
      if (url) {
        window.open(url, '_system');
      }
      Purchasely.onProcessAction(false);
      break;

    case 'PURCHASE':
    case 'RESTORE':
    case 'CLOSE':
    default:
      Purchasely.onProcessAction(true);
      break;
  }
});
```

**Important:** You must call `Purchasely.onProcessAction(true/false)` in every code path. Failing to do so will freeze the paywall UI.

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
      // Unlock premium content
      unlockPremium(result.plan);
      break;
    case Purchasely.PurchaseResult.RESTORED:
      // Restore premium content
      restorePremium();
      break;
    case Purchasely.PurchaseResult.CANCELLED:
      // User cancelled -- do nothing or show message
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
Purchasely.userLogout();
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

Fetch the user's active subscriptions:

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
  }
);
```

## Deeplinks

### Handle Incoming Deeplink

```javascript
Purchasely.isDeeplinkHandled(
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

### Signal Ready for Deeplinks

```javascript
Purchasely.readyToOpenDeeplink(true);
```

## Synchronize Purchases

```javascript
Purchasely.synchronize();
```

Cordova `synchronize()` is fire-and-forget in the public JS bridge; it does not accept success/error callbacks.

## Complete Integration Example

```javascript
var app = {
  initialize: function() {
    document.addEventListener('deviceready', this.onDeviceReady.bind(this), false);
  },

  onDeviceReady: function() {
    // Initialize Purchasely
    Purchasely.start(
      'YOUR_API_KEY',
      ['Google'],
      false,
      null,
      Purchasely.LogLevel.DEBUG,
      Purchasely.RunningMode.full,
      function() {
        console.log('Purchasely ready');

        // Set up action interceptor
        Purchasely.setPaywallActionInterceptor(function(result) {
          if (result.action === 'LOGIN') {
            app.showLogin();
          } else {
            Purchasely.onProcessAction(true);
          }
        });

        // Ready for deeplinks
        Purchasely.readyToOpenDeeplink(true);
      },
      function(error) {
        console.error('Purchasely failed:', error);
      }
    );
  },

  showPaywall: function() {
    Purchasely.fetchPresentationForPlacement(
      'ONBOARDING',
      null,
      function(presentation) {
        if (presentation.type === 'NORMAL' || presentation.type === 'FALLBACK') {
          Purchasely.presentPresentation(
            presentation,
            true,
            null,
            function(result) {
              console.log('Result:', result.result);
            },
            function(error) {
              console.error('Presentation error:', error);
            }
          );
        }
      },
      function(error) {
        console.error('Fetch error:', error);
      }
    );
  },

  showLogin: function() {
    // Your login logic here
    var userId = prompt('Enter user ID:');
    if (userId) {
      Purchasely.userLogin(userId);
      Purchasely.onProcessAction(true);
    } else {
      Purchasely.onProcessAction(false);
    }
  }
};

app.initialize();
```
