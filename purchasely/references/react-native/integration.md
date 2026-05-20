# React Native Integration

> **Cross-platform reference.** This file covers React Native-specific syntax. Many concepts (Observer-mode post-purchase flow, presentation type guard, presentation cache, programmatic purchases, audience-targeting attributes, GDPR consent, subscription checks) are **universal across iOS / Android / RN / Flutter / Cordova** and live in `../concepts/`. Load:
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
> - [`../sdk-versions.md`](../sdk-versions.md) — latest stable versions (pin to **5.7.3** for React Native)

## Installation

Requirements: iOS 11.0+, Android minSdk 21, compileSdk 33. Pin all packages to **5.7.3** (see [`../sdk-versions.md`](../sdk-versions.md)).

```bash
# Core SDK
npm install react-native-purchasely@5.7.3 --save-exact

# Google Play — required if targeting Google Play Store
npm install @purchasely/react-native-purchasely-google@5.7.3 --save-exact

# Video Player — optional, for video support in paywalls on Android
npm install @purchasely/react-native-purchasely-android-player@5.7.3 --save-exact
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

## Display a Paywall or Flow

Use `fetchPresentation()` and then `presentPresentation()` for standard paywalls and Flows. The bridge calls native `presentation.display()`, which is required for Flow close controls and step transitions.

```typescript
import Purchasely, { PLYPresentationType, ProductResult } from 'react-native-purchasely';

try {
  const presentation = await Purchasely.fetchPresentation({
    placementId: 'ONBOARDING',
    contentId: null,
  });

  switch (presentation.type) {
    case PLYPresentationType.NORMAL:
    case PLYPresentationType.FALLBACK: {
      const result = await Purchasely.presentPresentation({
        presentation,
        isFullscreen: true,
      });

      switch (result.result) {
        case ProductResult.PRODUCT_RESULT_PURCHASED:
          console.log('Purchased plan:', result.plan);
          break;
        case ProductResult.PRODUCT_RESULT_RESTORED:
          console.log('Restored purchases');
          break;
        case ProductResult.PRODUCT_RESULT_CANCELLED:
          console.log('User cancelled');
          break;
      }
      break;
    }
    case PLYPresentationType.DEACTIVATED:
      return; // Do NOT display
    case PLYPresentationType.CLIENT:
      showCustomPaywall(presentation.plans);
      return;
  }
} catch (error) {
  console.error('Presentation error:', error);
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

## Programmatic Purchases

For app-side purchase buttons in Full mode, use `purchaseWithPlanVendorId`. Do not use `Purchasely.purchase({ planId: ... })`; that API is not exposed by the React Native bridge.

```typescript
const purchasedPlan = await Purchasely.purchaseWithPlanVendorId({
  planVendorId: 'premium_yearly',
  offerId: null,
  contentId: null,
});
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
import Purchasely, { PLYPresentationType } from 'react-native-purchasely';

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
    const presentation = await Purchasely.fetchPresentation({
      placementId: 'ONBOARDING',
    });

    switch (presentation.type) {
      case PLYPresentationType.NORMAL:
      case PLYPresentationType.FALLBACK: {
        const result = await Purchasely.presentPresentation({
          presentation,
          isFullscreen: true,
        });
        console.log('Result:', result.result);
        break;
      }
      case PLYPresentationType.DEACTIVATED:
        return;
      case PLYPresentationType.CLIENT:
        return;
    }
  };

  return (
    <View style={{ flex: 1, justifyContent: 'center' }}>
      <Button title="Show Paywall" onPress={showPaywall} />
    </View>
  );
}
```
