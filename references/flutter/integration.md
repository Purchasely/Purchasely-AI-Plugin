# Flutter Integration

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  purchasely_flutter: ^5.0.0
  purchasely_google: ^5.0.0   # optional, for Google Play
```

Then run:

```bash
flutter pub get
```

### iOS Setup

Ensure your `ios/Podfile` has the correct platform and run pod install:

```bash
cd ios && pod install
```

## Import and Initialization

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

Future<void> initializePurchasely() async {
  bool started = await Purchasely.start(
    apiKey: 'YOUR_API_KEY',
    androidStores: ['Google'],          // 'Google', 'Huawei', 'Amazon'
    storeKit1: false,                    // false = use StoreKit 2 (recommended)
    logLevel: PLYLogLevel.debug,
    runningMode: PLYRunningMode.full,    // .full or .observer
    userId: null,                        // optional, set if user is already known
  );

  if (started) {
    print('Purchasely SDK started');
  } else {
    print('Purchasely SDK failed to start');
  }
}
```

Call this in your `main()` or root widget's `initState()`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializePurchasely();
  runApp(MyApp());
}
```

## Display a Paywall

### Full-Screen Presentation

```dart
try {
  final result = await Purchasely.presentPresentationForPlacement(
    placementVendorId: 'ONBOARDING',
    isFullscreen: true,
    contentId: null,  // optional content targeting
  );

  switch (result.result) {
    case PLYPurchaseResult.purchased:
      print('Purchased plan: ${result.plan?.vendorId}');
      break;
    case PLYPurchaseResult.restored:
      print('Restored purchases');
      break;
    case PLYPurchaseResult.cancelled:
      print('User cancelled');
      break;
  }
} catch (e) {
  print('Presentation error: $e');
}
```

### Fetch Presentation (check type before displaying)

```dart
final presentation = await Purchasely.fetchPresentation(
  placementVendorId: 'PREMIUM',
);

switch (presentation.type) {
  case PLYPresentationType.normal:
  case PLYPresentationType.fallback:
    // Safe to display
    Purchasely.presentPresentation(presentation: presentation);
    break;
  case PLYPresentationType.deactivated:
    // Do NOT display
    break;
  case PLYPresentationType.client:
    // Use your own UI with Purchasely plan data
    showCustomPaywall(presentation.plans);
    break;
}
```

### Inline Paywall with PurchaselyNativeView

Embed a paywall directly in your widget tree:

```dart
class InlinePaywallScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Premium')),
      body: PurchaselyNativeView(
        placementId: 'INLINE_PAYWALL',
        contentId: null,
        onPresentationLoaded: (presentation) {
          print('Paywall loaded: ${presentation.id}');
        },
        onPresentationClosed: () {
          Navigator.of(context).pop();
        },
        onPurchaseResult: (result) {
          if (result.result == PLYPurchaseResult.purchased) {
            // Handle purchase
          }
        },
      ),
    );
  }
}
```

## Action Interceptor

Intercept paywall actions to inject custom behavior:

```dart
Purchasely.setPaywallActionInterceptorCallback((result) {
  switch (result.action) {
    case PLYPaywallAction.login:
      // Present your login screen
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LoginScreen()),
      ).then((userId) {
        if (userId != null) {
          Purchasely.userLogin(userId);
          Purchasely.onProcessAction(true);
        } else {
          Purchasely.onProcessAction(false);
        }
      });
      break;

    case PLYPaywallAction.navigate:
      final url = result.parameters?['url'];
      if (url != null) {
        launchUrl(Uri.parse(url));
      }
      Purchasely.onProcessAction(false);
      break;

    case PLYPaywallAction.purchase:
    case PLYPaywallAction.restore:
    case PLYPaywallAction.close:
    default:
      Purchasely.onProcessAction(true);
      break;
  }
});
```

**Important:** You must call `Purchasely.onProcessAction(true/false)` in every code path. Failing to do so will freeze the paywall UI.

## User Management

### Login

```dart
Purchasely.userLogin('user_123');
```

### Logout

```dart
Purchasely.userLogout();
```

## User Attributes

Set attributes for audience targeting and personalization:

```dart
// String attribute
Purchasely.setUserAttributeWithString('first_name', 'John');

// Number attribute
Purchasely.setUserAttributeWithInt('age', 30);
Purchasely.setUserAttributeWithDouble('score', 4.5);

// Boolean attribute
Purchasely.setUserAttributeWithBoolean('is_premium', true);

// Date attribute
Purchasely.setUserAttributeWithDate('signup_date', DateTime(2024, 1, 15));
```

## Events

Listen for SDK events:

```dart
Purchasely.listenToEvents((event) {
  print('Event: ${event.name}');
  print('Properties: ${event.properties}');

  // Forward to your analytics provider
  analytics.track(event.name, event.properties);
});
```

## Subscriptions

Fetch the user's active subscriptions:

```dart
final subscriptions = await Purchasely.userSubscriptions();
for (final sub in subscriptions) {
  print('Plan: ${sub.plan.vendorId}');
  print('Store: ${sub.subscriptionSource}');
}
```

## Deeplinks

### Handle Incoming Deeplink

```dart
final handled = await Purchasely.isDeeplinkHandled('purchasely://your-deeplink-url');
if (handled) {
  // Purchasely will display the appropriate content
}
```

### Signal Ready for Deeplinks

Call when your app's root navigation is ready:

```dart
Purchasely.readyToOpenDeeplink(true);
```

## Synchronize Purchases

Force synchronization with Purchasely servers:

```dart
Purchasely.synchronize();
```

## Complete Integration Example

```dart
import 'package:flutter/material.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Purchasely.start(
    apiKey: 'YOUR_API_KEY',
    androidStores: ['Google'],
    storeKit1: false,
    logLevel: PLYLogLevel.debug,
  );

  // Set up action interceptor
  Purchasely.setPaywallActionInterceptorCallback((result) {
    if (result.action == PLYPaywallAction.login) {
      // Handle login
      Purchasely.onProcessAction(false);
    } else {
      Purchasely.onProcessAction(true);
    }
  });

  // Listen for events
  Purchasely.listenToEvents((event) {
    print('PLY Event: ${event.name}');
  });

  // Ready for deeplinks
  Purchasely.readyToOpenDeeplink(true);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  Future<void> _showPaywall() async {
    final result = await Purchasely.presentPresentationForPlacement(
      placementVendorId: 'ONBOARDING',
      isFullscreen: true,
    );
    print('Result: ${result.result}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My App')),
      body: Center(
        child: ElevatedButton(
          onPressed: _showPaywall,
          child: Text('Show Paywall'),
        ),
      ),
    );
  }
}
```
