---
name: integrate
description: "Use when integrating the Purchasely SDK into a mobile app — guides through installation, initialization, paywall display, purchase handling, and action interceptor setup for iOS, Android, React Native, Flutter, and Cordova."
---

# Purchasely SDK Integration Guide

You are guiding a developer through integrating the Purchasely SDK into their mobile app. You must write actual code into the user's project — not just explain what to do.

Reference documentation is available in the `references/` directory of this plugin. Before integrating, read `references/purchasely-architecture.md` to understand the end-to-end platform (SDK ↔ Purchasely Server ↔ stores ↔ your backend ↔ third-party tools) and the Full-mode purchase flow.

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

**Before installing, ask the user these questions (adapt per platform):**

For **Android, React Native, Flutter, Cordova** — ask:
1. **Which store(s) do you target?** Google Play is the most common. Huawei AppGallery and Amazon Appstore are also supported (Android native only). The store dependency is REQUIRED and separate from the core SDK.
2. **Do you need video support in paywalls?** If yes, an optional video player dependency is needed (not available on Cordova).

For **iOS** — no extra questions needed (App Store is the only store, video is included).

### iOS

Requirements: iOS 11.0+, Xcode 13.0+, Swift 5.0+

**Option A — CocoaPods** (preferred if a `Podfile` exists):

Add to the app's `Podfile`:
```ruby
pod 'Purchasely'
```
Then run:
```bash
pod install
```

**Option B — Swift Package Manager** (if the project uses SPM):

In Xcode: File > Add Packages, then enter the repository URL:
```
https://github.com/Purchasely/Purchasely-iOS
```

**Option C — Carthage**:

Add to `Cartfile`:
```
binary "https://raw.githubusercontent.com/Purchasely/Purchasely-iOS/master/Purchasely.json"
```
Then run:
```bash
carthage update
```

### Android

Requirements: minSdk 23, compileSdk 34, Kotlin 2.+, Gradle 8.+, JDK 11

The Purchasely SDK is published on **Maven Central** — no custom repository needed. Just make sure `mavenCentral()` is present in your `settings.gradle.kts` (it is by default in modern projects).

**Add dependencies** in `app/build.gradle.kts`:
```kotlin
dependencies {
    // Core SDK — Required
    implementation("io.purchasely:core:5.+")

    // Google Play Store — Required if publishing on Google Play
    implementation("io.purchasely:google-play:5.+")

    // Video Player — Optional, for video support in paywalls
    implementation("io.purchasely:player:5.+")
}
```

**Alternative stores** (instead of or in addition to Google Play):
```kotlin
// Huawei AppGallery (also requires Huawei AGConnect plugin and repo)
implementation("io.purchasely:huawei-services:5.+")

// Amazon Appstore
implementation("io.purchasely:amazon:5.+")
```

For **Huawei**, also add to the project-level build.gradle:
```groovy
buildscript {
    repositories {
        maven { url 'https://developer.huawei.com/repo/' }
    }
    dependencies {
        classpath 'com.huawei.agconnect:agcp:1.6.0.300'
    }
}
allprojects {
    repositories {
        maven { url 'https://developer.huawei.com/repo/' }
    }
}
```
And apply the plugin in `app/build.gradle`: `apply plugin: 'com.huawei.agconnect'`

Then sync Gradle.

### React Native

Requirements: iOS 11.0+, Android minSdk 21, compileSdk 33

**1. Install the core SDK:**
```bash
npm install react-native-purchasely --save
```

**2. Install the store dependency (required for Android):**
```bash
# Google Play — required if targeting Google Play Store
npm install @purchasely/react-native-purchasely-google --save
```

**3. Optional — video player for Android:**
```bash
npm install @purchasely/react-native-purchasely-android-player --save
```

**4. iOS pods:**
```bash
cd ios && pod install
```

**5. Android setup** — edit `android/build.gradle`:
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

**CRITICAL: All Purchasely packages must be at the exact same version.** Check `package.json` to ensure version alignment:
```json
"dependencies": {
  "react-native-purchasely": "5.0.0",
  "@purchasely/react-native-purchasely-google": "5.0.0",
  "@purchasely/react-native-purchasely-android-player": "5.0.0"
}
```

### Flutter

Requirements: iOS 11.0+, Android minSdk 21, compileSdk 33

**1. Install the core SDK:**
```bash
flutter pub add purchasely_flutter
```

**2. Install the store dependency (required for Android):**
```bash
# Google Play — required if targeting Google Play Store
flutter pub add purchasely_google
```

**3. Optional — video player for Android:**
```bash
flutter pub add purchasely_android_player
```

**4. iOS pods:**
```bash
cd ios && pod install
```

**5. Android setup** — edit `android/build.gradle`:
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

**CRITICAL: All Purchasely packages must be at the exact same version.** Check `pubspec.yaml`:
```yaml
dependencies:
  purchasely_flutter: ^5.0.0
  purchasely_google: ^5.0.0
  purchasely_android_player: ^5.0.0
```

### Cordova

Requirements: iOS 11.0+, Android minSdk 21, compileSdk 33

**1. Install the core plugin:**
```bash
cordova plugin add @purchasely/cordova-plugin-purchasely
```

**2. Install the store dependency (required for Android):**
```bash
# Google Play — required if targeting Google Play Store
cordova plugin add @purchasely/cordova-plugin-purchasely-google
```

**3. Android setup** — edit `android/build.gradle`:
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

**CRITICAL: All Purchasely packages must be at the exact same version.** Check `package.json`:
```json
"dependencies": {
  "@purchasely/cordova-plugin-purchasely": "5.0.0",
  "@purchasely/cordova-plugin-purchasely-google": "5.0.0"
}
```

**Action:** Actually edit the project files and run the install commands. Do not just show the commands — write the dependency into the appropriate file and execute the install. Ask the user about store choice and video support BEFORE installing.

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
import io.purchasely.ext.LogLevel
import io.purchasely.google.GoogleStore

// In Application.onCreate()
Purchasely.Builder(applicationContext)
    .apiKey("YOUR_API_KEY")
    .logLevel(LogLevel.DEBUG)
    .stores(listOf(GoogleStore()))  // Add HuaweiStore() or AmazonStore() if needed
    .build()
    .start { success, error ->
        Log.d("PLY", "Started: $success")
    }
```

Only include the stores matching the dependencies added in Step 1. For example, if using Huawei: `listOf(GoogleStore(), HuaweiStore())`.

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
let presentation = try await Purchasely.fetchPresentation(for: "PLACEMENT_ID")

switch presentation.type {
case .normal, .fallback:
    // display() handles Flows, transitions, and full-screen presentation automatically
    presentation.display(controller: self) { result, plan in
        switch result {
        case .purchased: print("Purchased: \(plan?.vendorId ?? "")")
        case .restored:  print("Restored")
        case .cancelled: break
        @unknown default: break
        }
    }
case .deactivated:
    // Placement is deactivated — do nothing or show your own UI
    break
case .client:
    // Show your own custom paywall
    let presentationId = presentation.presentationId
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
            // display() handles Flows, transitions, and full-screen presentation automatically
            presentation.display(this)
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

### Advanced: Inline / Embedded Paywall (iOS & Android)

> **Only use this approach if the user explicitly needs to embed a paywall inside an existing container view** (e.g., an inline screen, a tab, or a custom layout). For standard full-screen and Flow presentations, `display()` above is the correct approach.

#### iOS — embed in a container view

```swift
// After fetchPresentation, for .normal or .fallback types only:
guard let paywallVC = presentation.controller else { return }

addChild(paywallVC)
paywallVC.view.translatesAutoresizingMaskIntoConstraints = false
containerView.addSubview(paywallVC.view)
NSLayoutConstraint.activate([
    paywallVC.view.topAnchor.constraint(equalTo: containerView.topAnchor),
    paywallVC.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
    paywallVC.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
    paywallVC.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
])
paywallVC.didMove(toParent: self)
```

#### Android — option A: embed as a View

```kotlin
// buildView() returns a View — add it into an existing ViewGroup
val paywallView = presentation.buildView(this) { result ->
    // Handle result (purchase, restore, cancel...)
}
containerViewGroup.addView(paywallView)
```

#### Android — option B: embed as a Fragment

```kotlin
// getFragment() returns a Fragment — use with FragmentManager
val fragment = presentation.getFragment(
    callback = object : PLYPresentationResultHandler {
        override fun invoke(result: PLYProductViewResult, plan: PLYPlan?) {
            // Handle result (optional — omit the callback parameter if not needed)
        }
    }
)
supportFragmentManager.beginTransaction()
    .replace(R.id.your_container, fragment)
    .commitAllowingStateLoss()
```

> Note: Both options bypass Flow navigation — use only for truly inline use cases where you manage the UI hierarchy yourself.

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

## Step 7: Architecture Choice (Ask the User)

Before finishing, ask the user:

> **How would you like to organize the SDK integration?**
>
> **A) Direct integration** — Call Purchasely SDK methods directly from your app code. Simpler to set up, fine for small projects.
>
> **B) Wrapper pattern (recommended for larger projects)** — Route all Purchasely SDK calls through a single dedicated class. Better for testability and SDK isolation. The class name is up to you (`PurchaselyWrapper`, `PurchaselyService`, `IAPManager`, … any name works). See `references/architecture-patterns.md`.

If the user chooses **B**, help them:
1. Create a single class (e.g. `PurchaselyWrapper`) that owns every call into `Purchasely.*`
2. Move init, interceptor, and events into that class
3. Define type-safe result types (`FetchResult`, `DisplayResult`)
4. If Observer mode: decouple the native billing service with reactive patterns (SharedFlow / Combine) so it has zero SDK imports

If the user chooses **A**, the integration from Steps 1-6 is already complete. Do NOT add a wrapper.

See `references/architecture-patterns.md` for detailed architecture diagrams and implementation guidance.

---

## Important Notes

- In **Full mode**, the SDK handles the entire purchase flow. You do not need to call StoreKit/Play Billing APIs yourself.
- In **Observer mode**, you handle purchases yourself and must call `Purchasely.synchronize()` after each successful purchase so Purchasely can track it.
- Always test with a sandbox/test account before going to production.
- Switch `logLevel` to `ERROR` (or remove the parameter) before releasing to production.
- The SDK supports multiple stores on Android (Google, Huawei, Amazon). Only include the stores your app actually publishes on.
