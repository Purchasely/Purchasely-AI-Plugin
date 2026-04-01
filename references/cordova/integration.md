# Cordova Integration

## Installation

```bash
cordova plugin add @nickvdp/purchasely-cordova
```

## Initialization

Initialize with callback style in your `deviceready` handler:

```javascript
document.addEventListener('deviceready', function() {
  Purchasely.start(
    'YOUR_API_KEY',           // apiKey
    ['Google'],                // androidStores: 'Google', 'Huawei', 'Amazon'
    false,                     // storeKit1: false = use StoreKit 2 (recommended)
    Purchasely.LogLevel.DEBUG, // logLevel
    Purchasely.RunningMode.FULL, // runningMode: FULL or OBSERVER
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

### Full-Screen Presentation

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
Purchasely.fetchPresentation(
  'PREMIUM',  // placementVendorId
  null,       // contentId
  function(presentation) {
    switch (presentation.type) {
      case 'NORMAL':
      case 'FALLBACK':
        // Safe to display
        Purchasely.presentPresentation(presentation);
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

Intercept paywall actions to inject custom behavior:

```javascript
Purchasely.setPaywallActionInterceptorCallback(function(result) {
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
  },
  function(error) {
    console.error('Login failed:', error);
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

// Number attribute
Purchasely.setUserAttributeWithNumber('age', 30);

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
      Purchasely.LogLevel.DEBUG,
      Purchasely.RunningMode.FULL,
      function() {
        console.log('Purchasely ready');

        // Set up action interceptor
        Purchasely.setPaywallActionInterceptorCallback(function(result) {
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
    Purchasely.presentPresentationForPlacement(
      'ONBOARDING',
      null,
      true,
      function(result) {
        console.log('Result:', result.result);
      },
      function(error) {
        console.error('Error:', error);
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
