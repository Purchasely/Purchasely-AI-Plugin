# React Native Integration

## Installation

Requirements: iOS 11.0+, Android minSdk 21, compileSdk 33

```bash
# Core SDK
npm install react-native-purchasely --save

# Google Play — required if targeting Google Play Store
npm install @purchasely/react-native-purchasely-google --save

# Video Player — optional, for video support in paywalls on Android
npm install @purchasely/react-native-purchasely-android-player --save
```

**CRITICAL: All Purchasely packages must be at the exact same version.**

### iOS Setup

```bash
cd ios && pod install
```

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

## Import and Initialization

```typescript
import Purchasely from 'react-native-purchasely';

// Initialize in your app entry point (App.tsx or similar)
async function initializePurchasely() {
  try {
    const started = await Purchasely.start({
      apiKey: 'YOUR_API_KEY',
      storeKit1: false,  // false = use StoreKit 2 (recommended)
      logLevel: Purchasely.LogLevel.DEBUG,
      userId: null,      // optional, set if user is already known
      runningMode: Purchasely.RunningMode.FULL,
    });
    console.log('Purchasely started:', started);
  } catch (error) {
    console.error('Purchasely init failed:', error);
  }
}
```

## Display a Paywall

### Full-Screen Presentation

```typescript
try {
  const result = await Purchasely.presentPresentationForPlacement({
    placementVendorId: 'ONBOARDING',
    isFullscreen: true,
    contentId: null,  // optional content targeting
  });

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
} catch (error) {
  console.error('Presentation error:', error);
}
```

### Fetch Presentation (check type before displaying)

```typescript
const presentation = await Purchasely.fetchPresentation({
  placementVendorId: 'PREMIUM',
});

switch (presentation.type) {
  case Purchasely.PresentationType.NORMAL:
  case Purchasely.PresentationType.FALLBACK:
    // Safe to display
    Purchasely.presentPresentation({ presentation });
    break;
  case Purchasely.PresentationType.DEACTIVATED:
    // Do NOT display
    break;
  case Purchasely.PresentationType.CLIENT:
    // Use your own UI with Purchasely plan data
    showCustomPaywall(presentation.plans);
    break;
}
```

## Action Interceptor

Intercept paywall actions (login, navigate, etc.) to inject custom behavior:

```typescript
Purchasely.setPaywallActionInterceptorCallback((result) => {
  const { action, parameters, info } = result;

  switch (action) {
    case Purchasely.PaywallAction.LOGIN:
      // Present your login screen
      navigation.navigate('Login', {
        onComplete: (userId: string | null) => {
          if (userId) {
            Purchasely.userLogin(userId);
            Purchasely.onProcessAction(true);
          } else {
            Purchasely.onProcessAction(false);
          }
        },
      });
      break;

    case Purchasely.PaywallAction.NAVIGATE:
      const url = parameters?.url;
      if (url) {
        Linking.openURL(url);
      }
      Purchasely.onProcessAction(false);
      break;

    case Purchasely.PaywallAction.PURCHASE:
    case Purchasely.PaywallAction.RESTORE:
    case Purchasely.PaywallAction.CLOSE:
    default:
      Purchasely.onProcessAction(true);
      break;
  }
});
```

**Important:** You must call `Purchasely.onProcessAction(true/false)` in every code path. Failing to do so will freeze the paywall UI.

## User Management

### Login

```typescript
Purchasely.userLogin('user_123');
```

### Logout

```typescript
Purchasely.userLogout();
```

## User Attributes

Set attributes for audience targeting and personalization:

```typescript
// String attribute
Purchasely.setUserAttributeWithString('first_name', 'John');

// Number attribute
Purchasely.setUserAttributeWithNumber('age', 30);

// Boolean attribute
Purchasely.setUserAttributeWithBoolean('is_premium', true);

// Date attribute
Purchasely.setUserAttributeWithDate('signup_date', '2024-01-15T00:00:00Z');
```

## Events

Listen for SDK events (paywall views, purchases, etc.):

```typescript
const subscription = Purchasely.addEventListener((event) => {
  console.log('Event:', event.name);
  console.log('Properties:', event.properties);

  // Forward to your analytics provider
  analytics.track(event.name, event.properties);
});

// Remove listener when no longer needed
subscription.remove();
```

## Subscriptions

Fetch the user's active subscriptions:

```typescript
const subscriptions = await Purchasely.userSubscriptions();
subscriptions.forEach((sub) => {
  console.log('Plan:', sub.plan.vendorId);
  console.log('Store:', sub.subscriptionSource);
});
```

## Deeplinks

### Handle Incoming Deeplink

```typescript
const handled = await Purchasely.isDeeplinkHandled('purchasely://your-deeplink-url');
if (handled) {
  // Purchasely will display the appropriate content
}
```

### Signal Ready for Deeplinks

Call when your app's root navigation is ready:

```typescript
Purchasely.readyToOpenDeeplink(true);
```

## Synchronize Purchases

Force synchronization with Purchasely servers:

```typescript
Purchasely.synchronize();
```

## Complete Integration Example

```typescript
import React, { useEffect } from 'react';
import { Button, View } from 'react-native';
import Purchasely from 'react-native-purchasely';

export default function App() {
  useEffect(() => {
    // Initialize SDK
    Purchasely.start({
      apiKey: 'YOUR_API_KEY',
      storeKit1: false,
      logLevel: Purchasely.LogLevel.DEBUG,
    });

    // Set up action interceptor
    Purchasely.setPaywallActionInterceptorCallback((result) => {
      if (result.action === Purchasely.PaywallAction.LOGIN) {
        // Handle login
        Purchasely.onProcessAction(false);
      } else {
        Purchasely.onProcessAction(true);
      }
    });

    // Listen for events
    const subscription = Purchasely.addEventListener((event) => {
      console.log('PLY Event:', event.name);
    });

    // Ready for deeplinks
    Purchasely.readyToOpenDeeplink(true);

    return () => {
      subscription.remove();
    };
  }, []);

  const showPaywall = async () => {
    const result = await Purchasely.presentPresentationForPlacement({
      placementVendorId: 'ONBOARDING',
      isFullscreen: true,
    });
    console.log('Result:', result.result);
  };

  return (
    <View style={{ flex: 1, justifyContent: 'center' }}>
      <Button title="Show Paywall" onPress={showPaywall} />
    </View>
  );
}
```
