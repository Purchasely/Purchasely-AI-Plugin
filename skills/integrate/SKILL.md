---
name: integrate
description: "Use when integrating the Purchasely SDK into a mobile app — guides through installation, initialization, paywall display, purchase handling, and action interceptor setup for iOS, Android, React Native, Flutter, and Cordova."
---

# Purchasely SDK Integration Guide

You are guiding a developer through integrating the Purchasely SDK into their mobile app. You must write actual code into the user's project — not just explain what to do.

Reference documentation is available in the `references/` directory of this plugin.

## Arguments

`$ARGUMENTS` may contain an optional platform override (e.g., `ios`, `android`, `react-native`, `flutter`, `cordova`). If provided, skip platform detection and use the specified platform.

## Step 0: Detect the Platform

If no platform was specified in `$ARGUMENTS`, detect the platform by examining the project files:

| Signal | Platform |
|--------|----------|
| `build.gradle` or `build.gradle.kts` with Kotlin/Android references | **Android** |
| `.xcodeproj`, `.xcworkspace`, or `Package.swift` with iOS targets | **iOS** |
| `package.json` containing `react-native` dependency | **React Native** |
| `pubspec.yaml` containing `purchasely_flutter` or Flutter SDK reference | **Flutter** |
| `config.xml` with `cordova` references | **Cordova** |

If multiple platforms are detected (e.g., a monorepo), ask the user which platform they want to integrate first. If no platform is detected, ask the user to specify.

## Step 1: Install the SDK

Run the appropriate installation commands and modify project files as needed.

### iOS

**Option A — CocoaPods** (preferred if a `Podfile` exists):

Add to the app's `Podfile`:
```ruby
pod 'Purchasely'
```
Then run:
```bash
cd ios && pod install
```

**Option B — Swift Package Manager** (if the project uses SPM):

Add the package URL in Xcode or in `Package.swift`:
```
https://github.com/Purchasely/Purchasely-iOS
```

### Android

Add the Purchasely Maven repository and dependency to the app-level `build.gradle` (or `build.gradle.kts`):

In the **project-level** `build.gradle` (or `settings.gradle.kts`), add the Maven repository:
```groovy
// build.gradle (project) — allprojects block
maven { url "https://sdk.purchasely.com/releases" }
```
or in `settings.gradle.kts`:
```kotlin
dependencyResolutionManagement {
    repositories {
        maven { url = uri("https://sdk.purchasely.com/releases") }
    }
}
```

In the **app-level** `build.gradle`:
```groovy
dependencies {
    implementation 'io.purchasely:purchasely:+'
}
```

Then sync Gradle.

### React Native

```bash
yarn add react-native-purchasely
# or: npm install react-native-purchasely
cd ios && pod install
```

### Flutter

Add to `pubspec.yaml` under `dependencies`:
```yaml
purchasely_flutter: ^5.0.0
```
Then run:
```bash
flutter pub get
```

### Cordova

```bash
cordova plugin add @nickvdp/purchasely-cordova
```

**Action:** Actually edit the project files and run the install commands. Do not just show the commands — write the dependency into the appropriate file and execute the install.

---

## Step 2: Initialize the SDK

Add SDK initialization code to the app's entry point. The API key must come from the **Purchasely Console > App Settings**. Tell the user to replace `YOUR_API_KEY` with their actual key.

Key configuration options to explain to the user:
- **Running mode**: `Full` (default — Purchasely handles the purchase flow end-to-end) or `Observer` / `PaywallObserver` (the app handles purchases, Purchasely only observes)
- **StoreKit version** (iOS only): StoreKit 2 is recommended for new apps
- **Log level**: Use `DEBUG` during development, switch to `ERROR` for production
- **Android stores**: `GoogleStore` (default), `HuaweiStore`, `AmazonStore` — include only the stores relevant to the app

### iOS (Swift)

```swift
import Purchasely

// In AppDelegate.application(_:didFinishLaunchingWithOptions:) or App.init()
Purchasely.start(withAPIKey: "YOUR_API_KEY",
                  appUserId: nil,
                  runningMode: .full,
                  paywallActionsInterceptor: nil,
                  storekitSettings: .storeKit2,
                  logLevel: .debug) { success, error in
    print("Purchasely started: \(success)")
}
```

### Android (Kotlin)

```kotlin
import io.purchasely.ext.Purchasely
import io.purchasely.google.GoogleStore

// In Application.onCreate() or Activity.onCreate()
Purchasely.Builder(applicationContext)
    .apiKey("YOUR_API_KEY")
    .logLevel(LogLevel.DEBUG)
    .stores(listOf(GoogleStore(), HuaweiStore()))
    .build()
    .start { success, error ->
        Log.d("PLY", "Started: $success")
    }
```

### React Native (TypeScript)

```typescript
import Purchasely from 'react-native-purchasely';

// In your app initialization (e.g., App.tsx useEffect or top-level async)
await Purchasely.start({
  apiKey: 'YOUR_API_KEY',
  storeKit1: false, // false = use StoreKit 2 on iOS
  logLevel: Purchasely.LogLevel.DEBUG,
});
```

### Flutter (Dart)

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

// In main() or initState()
final started = await Purchasely.start(
  apiKey: 'YOUR_API_KEY',
  androidStores: ['Google'],
  storeKit1: false, // false = use StoreKit 2 on iOS
  logLevel: PLYLogLevel.debug,
);
print('Purchasely started: $started');
```

### Cordova (JavaScript)

```javascript
Purchasely.start(
  'YOUR_API_KEY',
  ['Google'],       // stores
  null,             // userId (null for anonymous)
  Purchasely.LogLevel.DEBUG,
  Purchasely.RunningMode.Full,
  (success) => console.log('Purchasely started'),
  (error) => console.error('Purchasely start error:', error)
);
```

**Action:** Find the app's entry point file and write the initialization code into it. Add the necessary import statements at the top of the file.

---

## Step 3: Display a Paywall

Purchasely uses a **placement-based** approach. Placements are configured in the Purchasely Console and identified by a `placementId` (e.g., `"onboarding"`, `"settings"`, `"home_banner"`). Each placement can be associated with different paywalls, audiences, and A/B tests — all managed remotely.

Use the `fetchPresentation()` + display pattern. Do **NOT** use the deprecated `presentationView` or `presentationController` methods.

The fetch returns a presentation with a `type` property. Handle each type:
- **NORMAL**: Display the paywall to the user
- **FALLBACK**: Display the paywall but log a warning (the primary paywall failed to load and this is a fallback)
- **DEACTIVATED**: Do NOT display anything — the placement has been deactivated in the Console
- **CLIENT**: The Console is requesting you show your own custom paywall (use the returned `presentationId` to decide which one)

### iOS (Swift)

```swift
let controller = try await Purchasely.fetchPresentation(for: "PLACEMENT_ID")

switch controller.type {
case .normal, .fallback:
    // Present the paywall
    self.present(controller.controller!, animated: true)
case .deactivated:
    // Placement is deactivated — do nothing or show your own UI
    break
case .client:
    // Show your own custom paywall
    let presentationId = controller.presentationId
    // ... display your custom paywall based on presentationId
    break
@unknown default:
    break
}
```

### Android (Kotlin)

```kotlin
Purchasely.fetchPresentation("PLACEMENT_ID") { presentation, error ->
    if (error != null) {
        Log.e("PLY", "Error fetching presentation", error)
        return@fetchPresentation
    }

    when (presentation?.type) {
        PLYPresentationType.NORMAL,
        PLYPresentationType.FALLBACK -> {
            val fragment = presentation.buildView(this) { result ->
                // Handle presentation result (purchase, restore, close...)
            }
            supportFragmentManager.beginTransaction()
                .addToBackStack(null)
                .replace(R.id.container, fragment, "paywall")
                .commitAllowingStateLoss()
        }
        PLYPresentationType.DEACTIVATED -> {
            // Do nothing
        }
        PLYPresentationType.CLIENT -> {
            val presentationId = presentation.presentationId
            // Show your own custom paywall
        }
        else -> {}
    }
}
```

### React Native (TypeScript)

```typescript
const presentation = await Purchasely.fetchPresentation({
  placementId: 'PLACEMENT_ID',
});

switch (presentation.type) {
  case PresentationType.NORMAL:
  case PresentationType.FALLBACK:
    Purchasely.presentPresentation({ presentation });
    break;
  case PresentationType.DEACTIVATED:
    // Placement is deactivated — do nothing
    break;
  case PresentationType.CLIENT:
    // Show your own custom paywall
    const presentationId = presentation.presentationId;
    break;
}
```

### Flutter (Dart)

```dart
final presentation = await Purchasely.fetchPresentation('PLACEMENT_ID');

switch (presentation.type) {
  case PLYPresentationType.normal:
  case PLYPresentationType.fallback:
    Purchasely.presentPresentation(presentation);
    break;
  case PLYPresentationType.deactivated:
    // Do nothing
    break;
  case PLYPresentationType.client:
    final presentationId = presentation.presentationId;
    // Show your own custom paywall
    break;
}
```

### Cordova (JavaScript)

```javascript
Purchasely.fetchPresentation(
  'PLACEMENT_ID',
  null, // contentId (optional)
  (presentation) => {
    switch (presentation.type) {
      case Purchasely.PresentationType.NORMAL:
      case Purchasely.PresentationType.FALLBACK:
        Purchasely.presentPresentation(presentation);
        break;
      case Purchasely.PresentationType.DEACTIVATED:
        // Do nothing
        break;
      case Purchasely.PresentationType.CLIENT:
        // Show your own custom paywall
        break;
    }
  },
  (error) => console.error(error)
);
```

**Action:** Find the appropriate screen/view/component where the paywall should be displayed (e.g., a "Premium" button, settings screen, or onboarding flow) and add the paywall display code. Ask the user which placement ID to use, or use `"onboarding"` as a sensible default.

---

## Step 4: Handle Paywall Actions with the Action Interceptor

The **Paywall Actions Interceptor** lets you intercept user actions on the paywall before they are processed. This is essential for:
- **LOGIN**: Prompt the user to log in when they tap a login-required button on the paywall
- **NAVIGATE**: Handle custom navigation actions (e.g., deep links to terms of service)
- **PURCHASE**: Add custom logic before/after a purchase (in Full mode, the SDK handles the purchase itself)
- **RESTORE**: Add custom logic around restoration
- **CLOSE**: Control what happens when the user dismisses the paywall

**CRITICAL**: You MUST always call `processAction` (or `proceed`) at the end of your interceptor logic, or the paywall UI will freeze. Even if you handle the action yourself, call proceed to let the SDK continue its flow.

### iOS (Swift)

```swift
Purchasely.setPaywallActionsInterceptor { [weak self] action, parameters, presentationInfo, proceed in
    switch action {
    case .login:
        // Present your login screen
        self?.presentLogin { loggedIn in
            if loggedIn {
                Purchasely.userLogin(with: "USER_ID")
            }
            proceed(loggedIn) // MUST call proceed
        }
    case .navigate:
        if let urlString = parameters?.url, let url = URL(string: urlString) {
            // Handle navigation (e.g., open terms of service)
            UIApplication.shared.open(url)
        }
        proceed(true) // MUST call proceed
    case .close:
        proceed(true) // MUST call proceed — lets the SDK dismiss the paywall
    default:
        proceed(true) // MUST call proceed for all unhandled actions
    }
}
```

### Android (Kotlin)

```kotlin
Purchasely.setPaywallActionsInterceptor { info, action, parameters, processAction ->
    when (action) {
        PLYPresentationAction.LOGIN -> {
            // Present your login screen
            // After login:
            Purchasely.userLogin("USER_ID")
            processAction(true) // MUST call processAction
        }
        PLYPresentationAction.NAVIGATE -> {
            parameters.url?.let { url ->
                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            }
            processAction(true) // MUST call processAction
        }
        PLYPresentationAction.CLOSE -> {
            processAction(true) // MUST call processAction
        }
        else -> {
            processAction(true) // MUST call processAction for all unhandled actions
        }
    }
}
```

### React Native (TypeScript)

```typescript
Purchasely.setPaywallActionInterceptor((result) => {
  switch (result.action) {
    case PaywallAction.LOGIN:
      // Navigate to your login screen
      // After login:
      Purchasely.userLogin('USER_ID');
      Purchasely.onProcessAction(true); // MUST call
      break;
    case PaywallAction.NAVIGATE:
      if (result.parameters?.url) {
        Linking.openURL(result.parameters.url);
      }
      Purchasely.onProcessAction(true); // MUST call
      break;
    case PaywallAction.CLOSE:
      Purchasely.onProcessAction(true); // MUST call
      break;
    default:
      Purchasely.onProcessAction(true); // MUST call
      break;
  }
});
```

### Flutter (Dart)

```dart
Purchasely.setPaywallActionInterceptor((result) {
  switch (result.action) {
    case PLYPaywallAction.login:
      // Navigate to your login screen
      // After login:
      Purchasely.userLogin('USER_ID');
      Purchasely.onProcessAction(true); // MUST call
      break;
    case PLYPaywallAction.navigate:
      if (result.parameters?.url != null) {
        launchUrl(Uri.parse(result.parameters!.url!));
      }
      Purchasely.onProcessAction(true); // MUST call
      break;
    case PLYPaywallAction.close:
      Purchasely.onProcessAction(true); // MUST call
      break;
    default:
      Purchasely.onProcessAction(true); // MUST call
      break;
  }
});
```

### Cordova (JavaScript)

```javascript
Purchasely.setPaywallActionInterceptor(function(result) {
  switch (result.action) {
    case Purchasely.PaywallAction.LOGIN:
      // Handle login
      Purchasely.userLogin('USER_ID');
      Purchasely.onProcessAction(true); // MUST call
      break;
    case Purchasely.PaywallAction.NAVIGATE:
      if (result.parameters && result.parameters.url) {
        window.open(result.parameters.url, '_system');
      }
      Purchasely.onProcessAction(true); // MUST call
      break;
    default:
      Purchasely.onProcessAction(true); // MUST call
      break;
  }
});
```

**Action:** Add the action interceptor to the app, ideally right after SDK initialization. At minimum, handle the `LOGIN` and `CLOSE` actions. Wire the LOGIN action to the app's existing authentication flow if one exists.

---

## Step 5: User Management

After the user authenticates in the app, call `userLogin` so Purchasely can associate purchases with the user. On sign out, call `userLogout`.

### iOS
```swift
Purchasely.userLogin(with: "USER_ID")
Purchasely.userLogout()
```

### Android
```kotlin
Purchasely.userLogin("USER_ID")
Purchasely.userLogout()
```

### React Native
```typescript
Purchasely.userLogin('USER_ID');
Purchasely.userLogout();
```

### Flutter
```dart
Purchasely.userLogin('USER_ID');
Purchasely.userLogout();
```

### Cordova
```javascript
Purchasely.userLogin('USER_ID');
Purchasely.userLogout();
```

Optionally, set **user attributes** for audience segmentation:
```
Purchasely.setUserAttribute("age", 28)
Purchasely.setUserAttribute("gender", "male")
```

**Action:** Find the app's authentication flow (login/signup success handler and logout handler) and add the `userLogin`/`userLogout` calls. If no auth flow exists, add a TODO comment where it should go.

---

## Step 6: Verify the Integration

After completing the integration, verify it works:

1. **Build and run the app** — ensure there are no compilation errors from the SDK import
2. **Check the logs** — look for `"Purchasely SDK initialized"` or similar success message in the debug console
3. **Display a test paywall** — trigger the paywall display and confirm the presentation loads from the Purchasely Console
4. **Verify the action interceptor** — tap buttons on the paywall and confirm your interceptor logs fire
5. **Check the Purchasely Console** — go to Live > Events to see if the SDK is sending events from the device

**Action:** Build and run the app. Read the console output to confirm successful initialization. If there are errors, debug and fix them before reporting success to the user.

---

## Important Notes

- In **Full mode**, the SDK handles the entire purchase flow. You do not need to call StoreKit/Play Billing APIs yourself.
- In **Observer mode**, you handle purchases yourself and must call `Purchasely.synchronize()` after each successful purchase so Purchasely can track it.
- Always test with a sandbox/test account before going to production.
- Switch `logLevel` to `ERROR` (or remove the parameter) before releasing to production.
- The SDK supports multiple stores on Android (Google, Huawei, Amazon). Only include the stores your app actually publishes on.
