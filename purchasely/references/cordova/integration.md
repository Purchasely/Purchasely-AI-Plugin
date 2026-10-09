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
> - [`../sdk-versions.md`](../sdk-versions.md) — latest stable versions (pin to **6.2.0** for Cordova)
> - [`./migration-v6.md`](./migration-v6.md) — full v5 → v6 API mapping if migrating an existing integration

**Cordova is on the v6 builder API** (`Purchasely.builder`, `Purchasely.presentation`, `Purchasely.interceptAction`) as a **stable** release (npm `latest`, not `@next`) — pulling native iOS `Purchasely 6.2.0` / Android `io.purchasely:core 6.2.0` at plugin 6.2.0 (6.1.0 pulled 6.1.0 / 6.1.0, 6.1.1 pulled iOS 6.1.2 / Android 6.1.1).

## Installation

Requirements: iOS 13.4+ (the native xcframework floor), Android minSdk 23, compileSdk 36, targetSdk 35, `cordova >=11.0.0`, `cordova-android >=12.0.0`. The bridge did not change these floors between 6.0.0 and 6.2.0. Pin all packages to **6.2.0** (see [`../sdk-versions.md`](../sdk-versions.md)).

```bash
# Core plugin
cordova plugin add @purchasely/cordova-plugin-purchasely@6.2.0

# Google Play — required if targeting Google Play Store
cordova plugin add @purchasely/cordova-plugin-purchasely-google@6.2.0
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

`display(transition?)` takes an optional `Purchasely.TransitionType` (`fullScreen`, `modal`, `drawer`, `popin`, `push`, `inlinePaywall`) or a full object for drawer/popin sizing. There is no per-request `close()` on Cordova — `request.close()` always dismisses every displayed Purchasely screen (the native bridge’s `closeAllScreens()` action under the hood); `request.back()` navigates back inside a multi-step (Flow) presentation.

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

## What 6.1.0, 6.1.1 and 6.2.0 add

Plugin 6.1.0, 6.1.1 and 6.2.0 are additive. An existing 6.0.0 integration needs no code change, except for one value change (see [SubscriptionSource value change](#subscriptionsource-value-change-610)). Native pins: 6.1.0 = iOS `6.1.0` / Android `6.1.0`, 6.1.1 = iOS `6.1.2` / Android `6.1.1`, 6.2.0 = iOS `6.2.0` / Android `6.2.0`. The plugin has no inline or embedded presentation view in 6.2.0. Do not promise one.

### Web redemption listener (6.1.0)

Set the listener on the builder. The builder subscribes the callback before the native `start()` call, so a redemption that settles during `start()` is not missed. The second argument is `appHandlesRedemptionAlert`. Pass `false` (default) to keep the SDK popin. Pass `true` to show your own result screen.

```javascript
Purchasely.builder('YOUR_API_KEY')
  .webRedemptionListener(function(result) {
    if (result.isSuccess) {
      // replay = a link that was already redeemed. Unlock, but do not thank the user twice.
      unlockContent(result.context && result.context.subscription, result.replay);
    } else {
      showError(result.errorCode, result.errorMessage);
    }
  }, true)
  .start();
```

The result is one flat object on both platforms: `{ isSuccess, context, replay, errorCode, errorMessage }`. `errorCode` is `'EXPIRED_REDEMPTION_TOKEN'`, `'INVALID_REDEMPTION_TOKEN'` or `null`. `context` and `context.subscription` can each be `null`, and both stay a success. A failure reports `replay: false` and `context: null`. For a subscription, `purchaseToken`, `nextRenewalDate` and `cancelledDate` can be absent: Android sends `null`, iOS omits the key. Use a truthiness check, not `!== undefined`.

`Purchasely.addWebRedemptionListener(success, error)` and `Purchasely.removeWebRedemptionListener()` also exist, for an app that changes the listener while the SDK runs. A redemption that settles during `start()` is then missed. Both paths share one native slot: the last caller wins. The `REDEMPTION_CONSUMED` and `REDEMPTION_FAILED` events arrive through `Purchasely.addEventListener`. Rules:

- A redemption deeplink does not obey `allowDeeplink`.
- `errorMessage` for an expired link can contain a masked email address. Show it to the user. Do not send it to analytics, a crash reporter or a log, on any platform.

### Anonymous user id (6.1.0)

The parameter is a **string**, not a native `UUID`. The bridge parses it. A value that is not a canonical UUID is refused with a log, the option is skipped, and `start()` still succeeds. The SDK keeps an id already on the device unless `override` is `true`, and `override: true` splits the user history. The SDK stores the id you pass in uppercase and an id it generates in lowercase, so compare ids case-insensitively.

```javascript
Purchasely.builder('YOUR_API_KEY')
  .anonymousUserId('3f2504e0-4f89-11d3-9a0c-0305e82c3301', false)
  .start();
// Options object form: { anonymousUserId: '...', anonymousUserIdOverride: false }
```

### API proxy (6.1.0)

`proxy(api)` routes the API traffic through your own `https` URL. It works on iOS and Android. The paywall and tracking hosts stay on production. There are three states: a string routes, `null` clears a proxy set earlier, and a key that is absent leaves the setting unchanged. `proxy()` with no argument, or with `undefined`, is refused with a log, because the no-argument native modifiers differ between the platforms.

```javascript
Purchasely.builder('YOUR_API_KEY')
  .proxy('https://api-proxy.example.com')
  .start();
// Options object form: { proxy: 'https://...' } or { proxy: null } to clear
```

### Custom events: `emit` (6.2.0)

`Purchasely.emit(name, properties, success, error)`. The `properties`, `success` and `error` arguments are optional. Declare the event in the Console first: the SDK sends only the declared names, matched exactly, and ignores an undeclared name. Pass a date as an ISO 8601 string. The call works before `start()`. Custom events never reach `addEventListener`. An empty name calls `error` with `name is required`. See [`../concepts/custom-events.md`](../concepts/custom-events.md).

```javascript
Purchasely.emit('recipe_viewed', { recipe_id: 42, title: 'Ratatouille' });
Purchasely.emit('checkout_started');
```

### Promotional offer signing (6.2.0, iOS only)

`signPromotionalOfferWithToken(storeProductId, storeOfferId, purchaseContextToken, success, error)` is for Observer mode on iOS. The purchase must carry the same token: `applicationUsername` with StoreKit 1, or `appAccountToken` with StoreKit 2. Pass `null` to let the SDK make the token. A string that is not a UUID calls `error` with no signing. The success value is the signature object (`planVendorId`, `identifier`, `signature`, `keyIdentifier`, `nonce`, `timestamp`) plus `purchaseContextToken`, a lowercase UUID string. See [`../concepts/promotional-offers.md`](../concepts/promotional-offers.md).

```javascript
Purchasely.signPromotionalOfferWithToken('product_id', 'offer_id', null,
  function(signature) { console.log(signature.purchaseContextToken); },
  function(error) { console.error(error); }
);
```

`signPromotionalOffer(storeProductId, storeOfferId, success, error)` is **deprecated**. It signs over the anonymous user id, so Apple rejects a purchase that carries another value. On Android both methods call `success` with no value and sign nothing, so shared code can call them on both platforms.

### `refundHandling` consent purpose (6.2.0, iOS only)

The value is `Purchasely.DataProcessingPurpose.refundHandling`, which is the string `'REFUND_HANDLING'`. It is not part of `allNonEssentials`. Android ignores it. `revokeDataProcessingConsent` replaces the whole list on each call, so pass every refused purpose together. An empty list `[]` grants every purpose back. The bridge does not add any logic for the empty list: it forwards an empty set to the native SDK. A string that the bridge does not know is ignored. See [`../concepts/privacy-settings.md`](../concepts/privacy-settings.md).

```javascript
Purchasely.revokeDataProcessingConsent([
  Purchasely.DataProcessingPurpose.analytics,
  Purchasely.DataProcessingPurpose.refundHandling
]);
```

### SubscriptionSource value change (6.1.0)

`Purchasely.SubscriptionSource.none` changed from `4` to `5`, and `webCheckoutStripe: 4` is new. The values now equal the native raw values on both platforms (iOS `stripe = 4, none = 5`). Code that uses the constant `Purchasely.SubscriptionSource.none` keeps working. Code that compares the raw number `4`, or stores it, must change. On iOS the wire value did not change. Before 6.1.0, a Stripe subscription matched `none` in JavaScript.

| Subscription source | Android wire before 6.1.0 | Android wire from 6.1.0 | iOS wire (unchanged) |
| --- | --- | --- | --- |
| Web checkout (Stripe) | `4`, named `none` in JS | `4`, named `webCheckoutStripe` | `4` |
| No source | `4` | `5` | `5` |

### Other behavior changes

- 6.1.0: a listener that is removed or replaced now closes its Cordova callback, and all listener handles clear when the WebView reloads (`onReset`).
- 6.1.1: native fixes only (iOS 6.1.2, Android 6.1.1), with no JavaScript change.
- 6.2.0: every purchase is attributed to the paywall, placement, campaign and A/B test that started it. Audience targeting sees active and expired subscriptions, including web subscriptions.

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
