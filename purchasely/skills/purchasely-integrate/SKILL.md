---
name: purchasely-integrate
description: "Use when integrating the Purchasely SDK into a mobile app — guides through installation, initialization, paywall display, purchase handling, and action interceptor setup for iOS, Android, React Native, Flutter, and Cordova."
---

# Purchasely SDK Integration Guide

You are guiding a developer through integrating the Purchasely SDK into their mobile app. You must write actual code into the user's project — not just explain what to do.

Reference documentation is available in the `../../references/` directory of this plugin. Before integrating, read `../../references/purchasely-architecture.md` to understand the end-to-end platform (SDK ↔ Purchasely Server ↔ stores ↔ your backend ↔ third-party tools) and the Full-mode purchase flow. If the app already sells subscriptions on the web (Stripe, another subscription platform, in-house billing), also read `../../references/cross-platform-subscriptions.md` — Purchasely accepts S2S Stripe receipts and the coexistence model has subtle defaults to know about.

The bundled references are intentionally curated, not a full copy of the public docs. If a required integration detail is missing, looks stale, or depends on an exact SDK signature / current Console behavior, verify it against the official Purchasely documentation at https://docs.purchasely.com/ before writing code.

**Universal SDK concepts** (apply to every platform — iOS, Android, React Native, Flutter, Cordova) are in `../../references/concepts/`. Load them as needed:

- `../../references/concepts/running-modes.md` — Full vs Observer modes, log levels
- `../../references/concepts/paywall-actions.md` — `PLYPresentationAction` enum, interceptor `proceed/processAction` rules
- `../../references/concepts/presentation-types.md` — `PLYPresentationType` guard (NORMAL / FALLBACK / DEACTIVATED / CLIENT)
- `../../references/concepts/presentation-cache.md` — App-side cache + **preload pattern** (fetch ahead, display instantly)
- `../../references/concepts/observer-mode-post-purchase.md` — `proceed/processAction → dismiss` ordering, chaining follow-up placements
- `../../references/concepts/programmatic-purchases.md` — Exact app-side purchase APIs by platform
- `../../references/concepts/user-attributes-targeting.md` — Audience targeting attributes
- `../../references/concepts/privacy-settings.md` — `revokeDataProcessingConsent`, essential/optional processing, GDPR/CMP choices
- `../../references/concepts/user-identity.md` — `userLogin` / `userLogout` timing + anonymous→logged-in merge
- `../../references/concepts/subscription-checks.md` — Gating premium content via `userSubscriptions`, restore purchases
- `../../references/concepts/subscription-management.md` — Opening the native Manage Subscription page (App Store / Play Store)
- `../../references/concepts/promotional-offers.md` — Offer types, Apple promotional offers, Google developer-determined offers, offer codes
- `../../references/concepts/campaigns.md` — No-code automations (trigger/placement-based), `readyToOpenDeeplink` (renamed `allowDeeplink` on native v6), use cases
- `../../references/concepts/lottie-animations.md` — Lottie animations in Screens (iOS / Android weak dependency bridge; cross-platform host projects)
- `../../references/concepts/analytics-integration.md` — Forwarding UI events to Firebase / Amplitude / AppsFlyer + recommended analytics wrapper pattern

**Platform-specific deep dives** (load the one(s) matching the project's platform — they hold the authoritative install snippets, init signatures, and platform-only patterns):

- `../../references/ios/initialization.md` — iOS install (CocoaPods / SPM / Carthage), `Purchasely.start(...)` signature, App Tracking Transparency hook order, StoreKit 2 setup
- `../../references/ios/api-reference.md` — full iOS API surface with signatures (init, fetch, present, attributes, login, sync, errors)
- `../../references/ios/common-patterns.md` — SwiftUI lifecycle, UIKit container embedding, `@MainActor` rules, presentation cache implementation
- `../../references/android/initialization.md` — Android install (Maven Central, store dependencies, ProGuard/R8 rules), `Purchasely.Builder` setup
- `../../references/android/api-reference.md` — full Android API surface with Kotlin/Java signatures
- `../../references/android/common-patterns.md` — Jetpack Compose embedding, Fragment vs View, lifecycle-aware patterns
- `../../references/react-native/integration.md` — RN-specific install, Metro setup, plugin alignment, store package
- `../../references/flutter/integration.md` — Flutter-specific install, MethodChannel/EventChannel bridge, plugin alignment
- `../../references/cordova/integration.md` — Cordova-specific install, plugin add, store plugin, JS callbacks

**Troubleshooting & ops** (load when needed):

- `../../references/testing/README.md` — Sandbox testing on iOS (Sandbox Apple ID) and Android (License Tester, internal track)
- `../../references/troubleshooting/debug-mode.md` — Enabling SDK debug logs + Purchasely Console-side Debug Mode (preview drafts on device)
- `../../references/troubleshooting/error-codes.md` — `PLYError` reference (iOS + Android), promotional-offer errors, Google Play Billing v8 hang
- `../../references/troubleshooting/screen-issue-report.md` — Template for escalating Screen Composer bugs to Purchasely Support

**Latest SDK versions** — always pin to the versions listed in `../../references/sdk-versions.md` (single source of truth). When this skill mentions installation, pin to exact versions from that doc, not floating versions.

## Expert checkpoint

Before writing integration code, invoke the `Task` tool with `subagent_type: "purchasely:sdk-expert"` and ask it to validate the intended implementation. Pass the detected platform, running mode, target store(s), SDK version, placement/display approach, purchase handling plan, privacy/consent requirements if any, and any uncertainty from the local project. Incorporate the expert's corrections before editing files.

## Completion Build Gate

Before reporting the integration complete, build the user's app with the project's canonical command (prefer the existing CI/build script). If the build fails, fix the error, rerun the build, and run relevant tests again until the app builds successfully. Do not claim completion from code review or lint alone; include the exact build/test commands and outcomes in the final response.

Platform hints: Android `./gradlew assembleDebug`; iOS use `xcodebuild` with the workspace when one exists; React Native / Flutter / Cordova should build the affected native target(s), not just install packages.

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

**Versions to pin** (always read `../../references/sdk-versions.md` for the authoritative list):

| Platform | Latest stable version |
|----------|-----------------------|
| iOS (native) | **6.0.0-rc1** |
| Android (native) | **6.0.0-rc1** |
| React Native | **5.7.3** |
| Flutter | **5.7.3** |
| Cordova | **5.7.3** |

Always pin to the **exact** version above, never floating (`5.+`, `6.+`, `^5.0.0`, `^6.0.0-rc1`). Floating versions break reproducibility and silently pull regressions.

**Before installing, ask the user these questions (adapt per platform):**

For **Android, React Native, Flutter, Cordova** — ask:
1. **Which store(s) do you target?** Google Play is the most common. Huawei AppGallery and Amazon Appstore are also supported (Android native only). The store dependency is REQUIRED and separate from the core SDK.
2. **Do you need video support in Screens?** If yes, an optional video player dependency is needed (not available on Cordova).

For **iOS** — no extra questions needed (App Store is the only store, video is included).

### iOS

Requirements: iOS 11.0+, Xcode 13.0+, Swift 5.0+ (Swift 6 strict concurrency supported)

**Option A — CocoaPods** (preferred if a `Podfile` exists):

Add to the app's `Podfile`:
```ruby
pod 'Purchasely', '~> 6.0'
```
Then run:
```bash
pod install --repo-update
```

**Option B — Swift Package Manager** (if the project uses SPM):

In Xcode: File > Add Packages, then enter the repository URL:
```
https://github.com/Purchasely/Purchasely-iOS
```
Select **Up to Next Major Version 6.0.0-rc1** (Package.swift: `.package(url: "https://github.com/Purchasely/Purchasely-iOS", from: "6.0.0-rc1")`).

**Option C — Carthage**:

Add to `Cartfile`:
```
binary "https://raw.githubusercontent.com/Purchasely/Purchasely-iOS/master/Purchasely.json" ~> 6.0
```
Then run:
```bash
carthage update
```

> **Swift 6 strict concurrency.** When the host app builds with strict concurrency, add `@preconcurrency import Purchasely` at `@MainActor` call sites; test targets may relax to `SWIFT_STRICT_CONCURRENCY = minimal`.

### Android

Requirements: minSdk 23, compileSdk 36, Kotlin 2.2.x, Gradle 9.x, JDK 11

The Purchasely SDK is published on **Maven Central** — no custom repository needed. Just make sure `mavenCentral()` is present in your `settings.gradle.kts` (it is by default in modern projects).

**Add dependencies** in `app/build.gradle.kts` (pin to exact `6.0.0-rc1` — see `../../references/sdk-versions.md`):
```kotlin
dependencies {
    // Core SDK — Required
    implementation("io.purchasely:core:6.0.0-rc1")

    // Google Play Store — Required if publishing on Google Play
    implementation("io.purchasely:google-play:6.0.0-rc1")

    // Video Player — Optional, for video support in Screens
    implementation("io.purchasely:player:6.0.0-rc1")
}
```

**Alternative stores** (instead of or in addition to Google Play):
```kotlin
// Huawei AppGallery (also requires Huawei AGConnect plugin and repo)
implementation("io.purchasely:huawei-services:6.0.0-rc1")

// Amazon Appstore
implementation("io.purchasely:amazon:6.0.0-rc1")
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

**CRITICAL: All Purchasely packages must be at the exact same version.** Pin to `5.7.3` (see `../../references/sdk-versions.md`):
```json
"dependencies": {
  "react-native-purchasely": "5.7.3",
  "@purchasely/react-native-purchasely-google": "5.7.3",
  "@purchasely/react-native-purchasely-android-player": "5.7.3"
}
```

### Flutter

Requirements: iOS 11.0+, Android minSdk 21, compileSdk 33

> **Flutter is on the v5 API** (same generation as React Native / Cordova). `purchasely_flutter 5.7.3` pulls the 5.7.x native SDKs and exposes the v5 Dart surface: `Purchasely.start(...)`, `fetchPresentation` / `presentPresentation[ForPlacement]`, `setPaywallActionInterceptorCallback` + `onProcessAction`. The v6 Flutter builder API ships in the final 2.0.0 release — `../../references/flutter/migration-v6.md` and `../../references/flutter/integration.md` document that upcoming API as a preview. For production today, use the v5 API shown below.

**1. Install the core SDK:**
```bash
flutter pub add purchasely_flutter:5.7.3
```

**2. Install the store dependency (required for Android):**
```bash
# Google Play — required if targeting Google Play Store
flutter pub add purchasely_google:5.7.3
```

**3. Optional — video player for Android:**
```bash
flutter pub add purchasely_android_player:5.7.3
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

**CRITICAL: All Purchasely packages must be at the exact same version.** Pin to `5.7.3` (see `../../references/sdk-versions.md`):
```yaml
dependencies:
  purchasely_flutter: 5.7.3
  purchasely_google: 5.7.3
  purchasely_android_player: 5.7.3
```

> **Native dependency.** The Purchasely 6.0 native SDKs may not be published on CocoaPods / Maven Central yet; local builds resolve them via `mavenLocal()` (Android) and a development pod (iOS).

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

**CRITICAL: All Purchasely packages must be at the exact same version.** Pin to `5.7.3` (see `../../references/sdk-versions.md`):
```json
"dependencies": {
  "@purchasely/cordova-plugin-purchasely": "5.7.3",
  "@purchasely/cordova-plugin-purchasely-google": "5.7.3"
}
```

**Action:** Actually edit the project files and run the install commands. Do not just show the commands — write the dependency into the appropriate file and execute the install. Ask the user about store choice and video support BEFORE installing.

---

## Step 2: Initialize the SDK

Add SDK initialization code to the app's entry point. The API key must come from the **Purchasely Console > App Settings**. Tell the user to replace `YOUR_API_KEY` with their actual key.

Key configuration options to explain to the user:
- **Running mode**: `Full` (Purchasely handles the purchase flow end-to-end) or `Observer` (the app handles purchases, Purchasely only observes). ⚠️ **In SDK v6 the default running mode changed from Full to Observer on BOTH native iOS and Android.** The change is **silent** — existing code keeps compiling, but the SDK stops validating/processing purchases unless you set Full explicitly. If your app relies on Purchasely to process and validate purchases, you MUST call `.runningMode(.full)` (iOS) / `runningMode(PLYRunningMode.Full)` (Android). In Observer mode, presentations also no longer auto-close after purchase/restore.
- **StoreKit version** (iOS only): StoreKit 2 is recommended for new apps
- **Log level**: Use `DEBUG` during development, switch to `ERROR` for production
- **Android stores**: `GoogleStore` (default), `HuaweiStore`, `AmazonStore` — include only the stores relevant to the app

### iOS (Swift, SDK v6)

v6 replaces the single `Purchasely.start(withAPIKey:...)` call with a fluent builder. The recommended form is `async`:

```swift
import Purchasely

// In an async context reached from App.init() / didFinishLaunchingWithOptions
do {
    try await Purchasely
        .apiKey("YOUR_API_KEY")
        .runningMode(.full)            // ⚠️ REQUIRED for purchase handling — default is .observer in v6
        .storekitSettings(.storeKit2)  // StoreKit 2 recommended for new apps
        .logLevel(.debug)
        .start()
    print("Purchasely started")
} catch {
    print("Purchasely start error: \(error)")  // e.g. PLYError.configuration if the API key is empty
}
```

Completion-handler form (also Objective-C-compatible), when you cannot `await`:

```swift
Purchasely
    .apiKey("YOUR_API_KEY")
    .runningMode(.full)
    .start { error in
        if let error = error { print("Purchasely start error: \(error)") }
    }
```

Other chain modifiers: `.appUserId(_)`, `.environment(_)`, `.themeMode(_)`, `.allowDeeplink(_)`, `.allowCampaigns(_)`, `.handleDeeplink(_)` (cold-start deeplink). The old pre-`start` class funcs (`setEnvironment`, `setThemeMode`, `setShowPromotedInAppPurchasePaywall`, …) are deprecated in favor of these modifiers.

### Android (Kotlin, SDK v6)

```kotlin
import io.purchasely.ext.PLYRunningMode
import io.purchasely.ext.Purchasely
import io.purchasely.ext.LogLevel
import io.purchasely.google.GoogleStore

// In Application.onCreate()
Purchasely {
    context(applicationContext)
    apiKey("YOUR_API_KEY")
    logLevel(LogLevel.DEBUG)
    stores(listOf(GoogleStore()))  // Add HuaweiStore() or AmazonStore() if needed
    runningMode(PLYRunningMode.Full)
    allowDeeplink(true)
    allowCampaigns(true)
    onInitialized { error ->
        if (error == null) Log.d("PLY", "Started")
        else Log.e("PLY", "Start error", error)
    }
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

### Flutter (Dart, v5)

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

// In main() or initState()
final started = await Purchasely.start(
  apiKey: 'YOUR_API_KEY',
  androidStores: ['Google'],          // 'Google' | 'Huawei' | 'Amazon' (Android)
  storeKit1: false,                   // iOS: false = StoreKit 2 (recommended), true = StoreKit 1
  logLevel: PLYLogLevel.debug,        // debug | info | warn | error
  runningMode: PLYRunningMode.full,   // full | paywallObserver | observer | transactionOnly
);
print('Purchasely started: $started');
```

`Purchasely.start(...)` returns a `Future<bool>`; check it before using the SDK. The `runningMode` defaults to `PLYRunningMode.full` — pass `PLYRunningMode.paywallObserver` for Observer mode where your app owns the purchase flow.

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

## Step 3: Display a Presentation / Screen

Purchasely uses a **placement-based** approach. Placements are configured in the Purchasely Console and identified by a `placementId` (e.g., `"onboarding"`, `"settings"`, `"home_banner"`). Each placement can be associated with different Screens, audiences, and A/B tests — all managed remotely.

Native iOS and Android are on the v6 builder API. iOS uses `PLYPresentationBuilder` (`.forPlacementId(_)` / `.forScreenId(_)`) → `.build().preload()`. Android uses the `PLYPresentation { ... }.preload()` builder. The legacy `fetchPresentation(...)` / `presentationView(...)` / VC-returning methods are removed in v6 native — do **NOT** use them.

> 💡 **Cross-platform SDKs (React Native / Flutter / Cordova): prefer `fetchPresentation()` + `presentPresentation(presentation)` over `presentPresentationForPlacement(placementId)`.** The pre-fetch path is what the [official docs recommend](https://docs.purchasely.com/docs/general-in-app-experiences-display#how-to-display-an-in-app-experience-associated-to-a-placement) and it's the only one that handles **Flows** correctly on plugin versions ≤ 5.7.x: it branches on `isFlow` / `flowId != null` natively and calls `presentation.display()`, which owns the close affordance and step transitions. The shorthand `presentPresentationForPlacement` is still exposed and remains fine for **simple, non-Flow paywalls** when you don't need to inspect the `PLYPresentationType` (e.g. quick prototypes, a placement guaranteed to never host a Flow), but if a Flow is ever assigned to that placement from the Console the user will get a stuck modal with no way out. When in doubt, use the pre-fetch path.

The fetch returns a presentation with a `type` property. Handle each type:
- **NORMAL**: Display the paywall to the user
- **FALLBACK**: Display the paywall but log a warning (the primary paywall failed to load and this is a fallback)
- **DEACTIVATED**: Do NOT display anything — the placement has been deactivated in the Console
- **CLIENT**: The Console is requesting you show your own custom paywall (use the returned `presentationId` to decide which one)

### iOS (Swift, SDK v6)

```swift
// Build + preload, then display. preload() returns the loaded presentation
// (no extra network call on display).
let presentation = try await PLYPresentationBuilder
    .forPlacementId("PLACEMENT_ID")
    .build()
    .preload()

switch presentation.type {
case .normal, .fallback:
    // display(from:) handles Flows, transitions, and full-screen presentation automatically.
    presentation.display(from: self)
case .deactivated:
    // Placement is deactivated — do nothing or show your own UI
    break
case .client:
    // Show your own custom paywall
    break
@unknown default:
    break
}
```

Convenience shorthand when you don't need to inspect the type: `try await Purchasely.display(for: "PLACEMENT_ID", transition: nil)` (use `transition: .modal` for a modal). To dismiss programmatically later, call `Purchasely.closeAllScreens()`. The dismissal result is a `PLYPresentationOutcome` (`purchaseResult`, `plan`, `closeReason`); attach `.onDismissed { outcome in }` on the builder before `build()` if you need it.

### Android (Kotlin, SDK v6)

```kotlin
val presentation = PLYPresentation {
    placementId("PLACEMENT_ID")
    // Optional direct Console Screen lookup. Android keeps this name public.
    // screenId("SCREEN_ID")
    onPresented { loaded, error -> }
    onCloseRequested { }
}.preload()

when (presentation.type) {
    PLYPresentationType.NORMAL,
    PLYPresentationType.FALLBACK -> {
        presentation.display(activity) { outcome ->
            // Final dismissal result.
        }
    }
    PLYPresentationType.DEACTIVATED -> Unit
    PLYPresentationType.CLIENT -> {
        val screenId = presentation.screenId
        showYourOwnScreen(screenId)
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

### Flutter (Dart, v5)

Fetch the presentation, branch on its `type`, then present it. `presentPresentation(...)` resolves at **dismiss** with a `PresentPresentationResult` (`result` is a `PLYPurchaseResult`, plus the purchased `plan`):

```dart
final presentation = await Purchasely.fetchPresentation('PLACEMENT_ID');

if (presentation == null) return;

switch (presentation.type) {
  case PLYPresentationType.normal:
  case PLYPresentationType.fallback:
    final result = await Purchasely.presentPresentation(
      presentation,
      isFullscreen: true,
    );
    if (result.result == PLYPurchaseResult.purchased ||
        result.result == PLYPurchaseResult.restored) {
      print('User purchased ${result.plan?.name}');
    } else {
      print('Dismissed without purchase');
    }
    break;
  case PLYPresentationType.deactivated:
    // Placement is deactivated — do nothing
    break;
  case PLYPresentationType.client:
    // Show your own custom paywall (BYOS) — plan summaries are in presentation.plans
    break;
}
```

For a simple, non-Flow placement where you don't need to inspect the type, the shorthand `Purchasely.presentPresentationForPlacement('PLACEMENT_ID', isFullscreen: true)` is also available (it returns the same `PresentPresentationResult`).

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

**Action:** Find the appropriate screen/view/component where the Presentation should be displayed (e.g., a premium button, settings screen, or onboarding flow) and add the display code. Ask the user which placement ID to use, or use `"onboarding"` as a sensible default.

### Advanced: Inline / Embedded Paywall (iOS & Android)

> **Only use this approach if the user explicitly needs to embed a paywall inside an existing container view** (e.g., an inline screen, a tab, or a custom layout). For standard full-screen and Flow presentations, `display()` above is the correct approach.

#### iOS — embed in a UIKit container view

```swift
// After build().preload(), for .normal or .fallback types only:
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

#### iOS — embed in SwiftUI

In v6, read `presentation.swiftUIView` (renamed from the v5 `controller.PresentationView`; the name disambiguates from `UIKit.UIView`). It is `nil` for `.deactivated` presentations.

```swift
// `presentation` is the loaded PLYPresentation (.normal / .fallback)
if let view = presentation.swiftUIView {
    view
        .frame(maxWidth: .infinity)
}
```

#### Android — option A: embed as a View

```kotlin
val presentationView = presentation.buildView(this) { outcome ->
    // Handle embedded Presentation result.
}
containerViewGroup.addView(presentationView)
```

#### Android — option B: embed as a Fragment

```kotlin
val fragment = presentation.getFragment { outcome ->
    // Handle embedded Presentation result.
}
supportFragmentManager.beginTransaction()
    .replace(R.id.your_container, fragment)
    .commitAllowingStateLoss()
```

#### Android — option C: embed in Compose

There is no Compose-specific artifact or composable in v6. Wrap the Android View returned by `buildView(...)` with `AndroidView`:

```kotlin
AndroidView(
    modifier = Modifier.fillMaxWidth(),
    factory = { context ->
        presentation.buildView(context) { outcome ->
            // Handle embedded Presentation result.
        }
    }
)
```

> Note: Use embedded APIs only for inline use cases where the app owns the UI hierarchy.

---

## Step 4: Handle Paywall Actions with the Action Interceptor

The **Paywall Actions Interceptor** lets you intercept user actions on the paywall before they are processed. This is essential for:
- **LOGIN**: Prompt the user to log in when they tap a login-required button on the paywall
- **NAVIGATE**: Handle custom navigation actions (e.g., deep links to terms of service)
- **PURCHASE**: Add custom logic before/after a purchase (in Full mode, the SDK handles the purchase itself)
- **RESTORE**: Add custom logic around restoration
- **CLOSE**: Control what happens when the user dismisses the paywall

**On native iOS and Android (v6)**, the interceptor is **per-action**: register one handler per action and return a `PLYInterceptResult` — `.success` (you handled it, the SDK chains the next action), `.failed` (you tried and failed, remaining actions are skipped), or `.notHandled` (the SDK executes the action itself). There is no `proceed`/`processAction` callback in the v6 native interceptors. (The v5→v6 mapping is `processAction(false)` → `.success` and `processAction(true)` → `.notHandled`.) The cross-platform bridges (React Native / Flutter / Cordova) still use the single `setPaywallActionInterceptor` / `setPaywallActionInterceptorCallback` + `onProcessAction(...)` shown below.

### iOS (Swift, SDK v6)

```swift
// async form
Purchasely.interceptAction(.login) { info, params in
    let loggedIn = await self.presentLogin()
    if loggedIn { Purchasely.userLogin(with: "USER_ID") }
    return loggedIn ? .success : .notHandled
}

Purchasely.interceptAction(.navigate) { info, params in
    if let urlString = params?.url, let url = URL(string: urlString) {
        await UIApplication.shared.open(url)
    }
    return .success
}

// In Full mode, let Purchasely run the purchase itself:
Purchasely.interceptAction(.purchase) { info, params in
    return .notHandled
}
```

A completion-based form is also available for Objective-C / non-async call sites:

```swift
Purchasely.interceptAction(.login) { info, params, completion in
    self.presentLogin { loggedIn in
        completion(loggedIn ? .success : .notHandled)
    }
}
```

`info` is a `PLYInterceptorInfo` (renamed from v5 `PLYPresentationInfo`): `info.presentation?.id`, `?.placementId`, `?.audienceId`, `?.abTestId`, `info.contentId`, `info.controller`.

### Android (Kotlin, SDK v6)

```kotlin
Purchasely.interceptAction<PLYPresentationAction.Login> { _, _ ->
    showLoginScreen()
    PLYInterceptResult.SUCCESS
}

Purchasely.interceptAction<PLYPresentationAction.Navigate> { _, navigate ->
    startActivity(Intent(Intent.ACTION_VIEW, navigate.url))
    PLYInterceptResult.SUCCESS
}

Purchasely.interceptAction<PLYPresentationAction.Purchase> { _, _ ->
    PLYInterceptResult.NOT_HANDLED // let Purchasely handle it in Full mode
}
```

Android v6 returns `PLYInterceptResult.SUCCESS`, `FAILED`, or `NOT_HANDLED`; there is no `processAction` callback in the new native Android interceptor.

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

### Flutter (Dart, v5)

Register a single callback with `Purchasely.setPaywallActionInterceptorCallback(...)`, switch on `result.action`, and **always** call `Purchasely.onProcessAction(true/false)` (or intercept with `hidePresentation()` / `closePresentation()`) on every path — otherwise the paywall freezes.

```dart
Purchasely.setPaywallActionInterceptorCallback(
  (PaywallActionInterceptorResult result) {
    switch (result.action) {
      case PLYPaywallAction.login:
        // Navigate to your login screen, then:
        Purchasely.userLogin('USER_ID');
        Purchasely.onProcessAction(true); // MUST call
        break;
      case PLYPaywallAction.navigate:
        final url = result.parameters.url;
        if (url != null) launchUrl(Uri.parse(url));
        Purchasely.onProcessAction(true); // MUST call
        break;
      case PLYPaywallAction.purchase:
        // In Full mode, let Purchasely run the purchase itself:
        Purchasely.onProcessAction(true); // MUST call
        break;
      case PLYPaywallAction.close:
        Purchasely.onProcessAction(true); // MUST call
        break;
      default:
        Purchasely.onProcessAction(true); // MUST call
        break;
    }
  },
);
```

Action values (`PLYPaywallAction`): `close`, `close_all`, `login`, `navigate`, `purchase`, `restore`, `open_presentation`, `open_placement`, `promo_code`, `open_flow_step`, `web_checkout`.

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

> **Ordering matters.** Call `userLogin` **before** any subscription gating or `fetchPresentation` call that depends on audience targeting — otherwise the SDK evaluates audience rules against the anonymous user. Also call `synchronize()` on foreground (`applicationDidBecomeActive` / `onResume` / `AppState 'active'`) to refresh state when renewals or cancellations happened in the background. Full per-platform guidance in `../../references/concepts/user-identity.md` (anonymous→logged-in merge, sign-out caveats, code samples).

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

## Step 5b: Restore Purchases

A user can lose access to their subscription on a new device, after a reinstall, or after switching account on the store. Apple **requires** a "Restore Purchases" entry point for App Store review (Guideline 3.1.1) — Google does not require but strongly recommends one.

> ⚠️ **Check the Purchasely paywall first.** Most Purchasely Screens built with the Screen Composer already include a "Restore" button — the Console operator can toggle it on. If it's already there on every relevant paywall, **do not add a duplicate** in app code; clarify the situation with the customer / Console operator and surface the existing button. Only add an app-side restore button when (a) the Purchasely Screen does **not** have one, **and** (b) you need a Restore action outside the paywall (e.g. in app Settings — recommended for Apple review).

If you do add it, wire it to `Purchasely.restoreAllProducts(...)`. See `../../references/concepts/subscription-checks.md` for the full per-platform code samples and the Observer-mode variant (intercept the `RESTORE` paywall action, run your own restore, call `Purchasely.synchronize()` + `proceed(true)`).

**Action:** Search the project for a Settings screen / Account screen. If one exists and the Purchasely paywalls don't already provide restore, add a "Restore Purchases" button there with the SDK call. If the Purchasely paywalls do provide restore, leave the in-paywall button as the canonical entry point and tell the user.

---

## Step 5c: Manage Subscription Entry Point

App Store and Play Store both require an in-app entry point to **manage the subscription** (cancel, upgrade, downgrade). This is a native OS page — your app only opens the right deeplink. See `../../references/concepts/subscription-management.md` for the per-platform helpers:

- iOS 15+: `AppStore.showManageSubscriptions(in: scene)` (in-app sheet)
- iOS legacy / fallback: open `https://apps.apple.com/account/subscriptions`
- Android: open `https://play.google.com/store/account/subscriptions?sku=<sku>&package=<pkg>` (per-product) or the general subscriptions URL

**Action:** Add a "Manage subscription" link in the Settings / Account screen, visible only to active subscribers (gate on `userSubscriptions`).

---

## Step 6: Verify the Integration

After completing the integration, verify it works:

1. **Run the Completion Build Gate above** — prove there are no compilation errors from the SDK import before moving on
2. **Run the app when a device/simulator is available** — confirm it launches after the build
3. **Check the logs** — look for `"Purchasely SDK initialized"` or similar success message in the debug console
4. **Display a test paywall** — trigger the paywall display and confirm the presentation loads from the Purchasely Console
5. **Verify the action interceptor** — tap buttons on the paywall and confirm your interceptor logs fire
6. **Check the Purchasely Console** — go to Live > Events to see if the SDK is sending events from the device

**Action:** Build the app, fix any build errors, rerun the build and relevant tests, then run the app when possible. Read the console output to confirm successful initialization before reporting success to the user.

---

## Step 7: Architecture Choice (Ask the User)

Before finishing, ask the user:

> **How would you like to organize the SDK integration?**
>
> **A) Direct integration** — Call Purchasely SDK methods directly from your app code. Simpler to set up, fine for small projects.
>
> **B) Wrapper pattern (recommended for larger projects)** — Route all Purchasely SDK calls through a single dedicated class. Better for testability and SDK isolation. The class name is up to you (`PurchaselyWrapper`, `PurchaselyService`, `IAPManager`, … any name works). See `../../references/architecture-patterns.md`.

If the user chooses **B**, help them:
1. Create a single class (e.g. `PurchaselyWrapper`) that owns every call into `Purchasely.*`
2. Move init, interceptor, and events into that class
3. Define type-safe result types (`FetchResult`, `DisplayResult`)
4. If Observer mode: decouple the native billing service with reactive patterns (SharedFlow / Combine) so it has zero SDK imports

If the user chooses **A**, the integration from Steps 1-6 is already complete. Do NOT add a wrapper.

See `../../references/architecture-patterns.md` for detailed architecture diagrams and implementation guidance.

---

## Important Notes

- In **Full mode**, the SDK handles the entire purchase flow. You do not need to call StoreKit/Play Billing APIs yourself.
- In **Observer mode**, you handle purchases yourself and must call `Purchasely.synchronize()` after each successful purchase so Purchasely can track it.
- Always test with a sandbox/test account before going to production.
- Switch `logLevel` to `ERROR` (or remove the parameter) before releasing to production.
- The SDK supports multiple stores on Android (Google, Huawei, Amazon). Only include the stores your app actually publishes on.

---

## Step 8: Observer Mode — Post-Purchase Flow (All Platforms)

> **Universal pattern.** Applies to iOS, Android, React Native, Flutter, Cordova. The full cross-platform reference is `../../references/concepts/observer-mode-post-purchase.md` — load it when you need the per-language code samples. The summary below covers the rules and the two native idioms.

**Only relevant if you initialized in `Observer` / `.observer` / `PAYWALL_OBSERVER` mode.** In Full mode, the SDK handles dismissal automatically.

When the interceptor receives a `PURCHASE` action in Observer mode, you run the native billing flow yourself. After it succeeds:

- **Native iOS/Android (v6):** intercept the `.purchase` action, run your billing flow, call **`Purchasely.synchronize()`** to upload the receipt, then **return `PLYInterceptResult.SUCCESS`** (`.success` on iOS) from the interceptor. In v6 Observer mode the presentation does **not** auto-close, so dismiss it yourself with **`Purchasely.closeAllScreens()`**. (There is no `proceed`/`processAction` callback in the v6 native interceptor; returning `.success` is the v6 equivalent of the old `processAction(false)`.)
- **React Native / Flutter / Cordova bridges:** still call `Purchasely.synchronize()` → `Purchasely.onProcessAction(false)` → `Purchasely.closePresentation()`, in that order.

**The order matters:** the SDK must learn the action was handled BEFORE the paywall tears down. Reversing it leaves the paywall in an inconsistent state.

### SDK version requirements for dismissal

| Platform | Minimum version |
|----------|-----------------|
| iOS (native) | **6.0.0-rc1** — `closeAllScreens()` is `@MainActor`-isolated. Wrap in `Task { @MainActor in Purchasely.closeAllScreens() }` when called from a non-isolated synchronous context. |
| Android (native) | **6.0.0-rc1** — `closeAllScreens()`, no threading constraint. |
| React Native | Use `Purchasely.closePresentation()` in the public JS bridge. |
| Flutter | **5.7.3** — use `Purchasely.closePresentation()` in the public Dart bridge (also `hidePresentation()` / `showPresentation()`). |
| Cordova | Use `Purchasely.closePresentation()` in the public JS bridge. |

Full version list: `../../references/sdk-versions.md`.

> On native iOS/Android, use `closeAllScreens()` (not `closeDisplayedPresentation()`) — it correctly tears down Flow paywalls with multiple steps. On React Native / Flutter / Cordova, use the public bridge `closePresentation()` unless the app added its own native `closeAllScreens()` bridge.

### iOS Observer-mode post-purchase (v6)

In v6 the `.purchase` interceptor returns a `PLYInterceptResult`. Run your billing flow, `synchronize()`, return `.success`, then dismiss explicitly (Observer mode no longer auto-closes):

```swift
Purchasely.interceptAction(.purchase) { info, params in
    let bought = await self.runMyBillingFlow()
    guard bought else { return .failed }
    await self.synchronizeReceipt()       // upload receipt; await if you chain a follow-up placement
    Purchasely.closeAllScreens()          // dismiss — Observer mode does not auto-close in v6
    return .success                        // v6 equivalent of the old processAction(false)
}

@MainActor
private func synchronizeReceipt() async {
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
        Purchasely.synchronize(
            success: { cont.resume() },
            failure: { _ in cont.resume() }
        )
    }
}
```

### Android Observer-mode post-purchase (v6)

```kotlin
Purchasely.interceptAction<PLYPresentationAction.Purchase> { _, purchase ->
    val bought = runMyBillingFlow(purchase.plan)
    if (!bought) return@interceptAction PLYInterceptResult.FAILED
    Purchasely.synchronize()         // refresh subscriptions cache (onSuccess/onError optional)
    Purchasely.closeAllScreens()     // dismiss — Observer mode does not auto-close in v6
    PLYInterceptResult.SUCCESS       // v6 equivalent of the old processAction(false)
}
```

> On Android, `Purchasely.synchronize(onSuccess = { plan -> }, onError = { error -> })` accepts optional callbacks and refreshes the subscriptions cache before `onSuccess`. To bridge a blocking billing flow inside a suspend interceptor, use `suspendCancellableCoroutine { ... }`.

### React Native / Flutter / Cordova Observer-mode post-purchase

All three cross-platform bridges follow the same v5 pattern: handle the `purchase` action in the interceptor, run your own billing flow, then call `synchronize()` → `onProcessAction(false)` → `closePresentation()` in that order. (React Native and Cordova `synchronize()` are fire-and-forget; Flutter's `Purchasely.synchronize()` returns an awaitable `Future<void>`.)

**React Native (TypeScript)**

```ts
Purchasely.synchronize();
Purchasely.onProcessAction(false);
Purchasely.closePresentation();
```

**Flutter (Dart, v5)**

Handle the `purchase` action in the interceptor callback, run your own billing flow, then `synchronize()` → `onProcessAction(false)` → `closePresentation()`. `Purchasely.synchronize()` is awaitable so you can sequence the receipt upload before dismissing.

```dart
Purchasely.setPaywallActionInterceptorCallback(
  (PaywallActionInterceptorResult result) async {
    if (result.action == PLYPaywallAction.purchase) {
      final plan = result.parameters.plan;
      final ok = await MyPurchaseSystem.purchase(plan?.vendorId);
      if (ok) {
        await Purchasely.synchronize();  // upload the receipt to Purchasely
        Purchasely.onProcessAction(false);
        Purchasely.closePresentation();
      } else {
        Purchasely.onProcessAction(false);
      }
    } else {
      Purchasely.onProcessAction(true);
    }
  },
);
```

**Cordova (JavaScript)**

```js
Purchasely.synchronize();
Purchasely.onProcessAction(false);
Purchasely.closePresentation();
```

For chained follow-up placements on cross-platform SDKs, see `../../references/concepts/observer-mode-post-purchase.md`.

### Optional: Chain a Follow-up Placement After Purchase

Some apps display a follow-up paywall after a successful purchase — a thank-you screen, a premium feature tour, a one-tap upsell. This is **not part of the SDK contract**: it's just another presentation built for whatever placement ID you've configured on the Console (pick your own, e.g. `"post_purchase"`, `"thank_you"`, `"premium_welcome"`).

If the chained placement's audience targets subscribers, **`synchronize()` must complete first** — otherwise the build resolves against stale state and may return a deactivated/fallback presentation. On iOS, that's why the `synchronizeReceipt()` await above matters; on Android, fire-and-forget `synchronize()` is usually fast enough.

```swift
// iOS — after closeAllScreens() above
@MainActor
private func showPostPurchaseScreen() async {
    guard let presentation = try? await PLYPresentationBuilder
        .forPlacementId("YOUR_POST_PURCHASE_PLACEMENT_ID")
        .build()
        .preload(),
        presentation.type == .normal || presentation.type == .fallback,
        let topVC = UIApplication.shared.topViewController()
    else { return }
    presentation.display(from: topVC)
}
```

```kotlin
// Android — after closeAllScreens() above
private fun showPostPurchaseScreen(activity: Activity) {
    PLYPresentation {
        placementId("YOUR_POST_PURCHASE_PLACEMENT_ID")
    }.preload { loaded, error ->
        if (error != null || loaded == null) return@preload
        when (loaded.type) {
            PLYPresentationType.NORMAL,
            PLYPresentationType.FALLBACK -> loaded.display(activity)
            else -> {}
        }
    }
}
```

**Naming gotcha:** the placement ID string must match the Console exactly — a typo silently returns a deactivated presentation.

**For ALL platforms** — see `../../references/concepts/observer-mode-post-purchase.md` for the canonical multi-platform reference.

For platform-specific elaborations (SwiftUI structured-concurrency guard on iOS, `SharedFlow`-based decoupling on Android), see `../../references/ios/common-patterns.md` and `../../references/android/common-patterns.md`.

---

## Step 9: Beyond the Basics — Recommended Next Steps

Once Steps 1-8 are in place and verified, walk the user through the **optional but high-value** add-ons. Each is documented in a dedicated concept reference so you can load only what's relevant.

| Feature | When to suggest | Reference |
|---------|-----------------|-----------|
| **Preload paywalls** — call `fetchPresentation` ahead of the display (e.g. on app launch, on screen mount) and keep the result for instant display. Avoids the FlowsManager step accumulation on every re-fetch. | Any production integration — significant perceived-perf win | `../../references/concepts/presentation-cache.md` |
| **Campaigns** — schedule paywalls (Black Friday, anniversary), centralise display rules across placements, trigger paywalls on events. Requires SDK ≥ 5.1.0 and `allowDeeplink(true)` (native v6 rename of `readyToOpenDeeplink`; default is `true` on native v6, and Android auto-intercepts deeplinks with zero code). | Any team running marketing operations | `../../references/concepts/campaigns.md` |
| **Promotional offers & promo codes** — retain / win back subscribers with Apple promotional offers, Google developer-determined offers, App Store / Play Store offer codes. Requires SDK ≥ 4.0.0. | Apps with churn, seasonal promos, win-back funnels | `../../references/concepts/promotional-offers.md` |
| **Analytics integration** — forward Purchasely UI events to Firebase / Amplitude / AppsFlyer (client-side) and subscription lifecycle events via 3rd-party integrations / webhooks (server-side, recommended). | Any team with an analytics stack — recommend a single analytics wrapper / manager to centralise the routing | `../../references/concepts/analytics-integration.md` |
| **Subscription gating + restore** — gate premium content via `userSubscriptions`, restore purchases from Settings | Any app with premium features | `../../references/concepts/subscription-checks.md` |
| **Audience attributes + GDPR consent** — target users with `setUserAttribute`, gate event flow on consent | Apps with marketing audiences or EU users | `../../references/concepts/user-attributes-targeting.md` |
| **Bring Your Own Screen (BYOS)** — embed a native screen (login, custom form, legacy paywall A/B variant) inside a Purchasely Flow with its own connections / `executeConnection(...)` chaining. **iOS + Android only, SDK ≥ 5.6.0.** | Teams that need a native login step in a Flow, or want to A/B their existing paywall against a Composer version | `../../references/concepts/byos.md` |
| **Lottie animations** — render Composer Lottie blocks by adding Airbnb Lottie plus the Purchasely bridge/interface in native host projects. | Any Screen uses Lottie JSON animations, including React Native / Flutter / Cordova apps through their iOS/Android hosts | `../../references/concepts/lottie-animations.md` |
| **Chain multiple actions on a single button** — configure `purchase + open_screen` / `purchase + open_placement` / `purchase + deeplink` in the Screen Composer. Without a second action, the default is *close in Full mode, stay open in Observer mode*. | Any team wiring post-purchase upsells, thank-you screens, or onboarding completion | `../../references/concepts/paywall-actions.md` § Chaining multiple actions |

Pick the ones the user's roadmap actually needs — don't push all six on day one.

---

## Step 10: Diagnostic Markers

Add app-side log markers around the key Purchasely decision points — they make every future bug 10× faster to diagnose. The SDK already emits `[Purchasely]` lines; add an app-side prefix (e.g. `[YourApp]`) at:

- After `synchronize()` completes (success or failure)
- Before each platform dismiss call (`closeAllScreens()` on native iOS/Android v6, `closePresentation()` on React Native / Cordova)
- When a presentation finishes loading (native v6: in the builder `onPresented` / `.preload` result — placement, type, error; cross-platform: in the `fetchPresentation` completion)
- When chaining a follow-up placement (and what it resolves to)

Mirror the SDK's analytics events via `PLYEventDelegate` (iOS) / `EventListener` (Android) with the full property bag — that way, a single `grep -E "\[Purchasely\]|\[YourApp\]"` over the failing run reveals exactly what the SDK did and why. See `../../references/troubleshooting/common-issues.md` §0 for the full event taxonomy and annotated traces.
