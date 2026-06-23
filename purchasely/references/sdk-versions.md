# Purchasely SDK — Latest Versions

> **Single source of truth.** When pinning a Purchasely dependency, pin to these exact versions unless the user explicitly asks otherwise. If you find an outdated version in a project, recommend upgrading to the version below for that platform.

## Current supported versions

_Last updated: 2026-06-15._

| Platform | Latest version | Notes |
|----------|----------------|-------|
| **iOS** (native) | **6.0.0-rc.1** | Fluent init builder, per-action `interceptAction` + `PLYInterceptResult`, `PLYPresentationBuilder`, `swiftUIView`, `closeAllScreens()`, `PLYPresentationOutcome` (with `closeReason`). **Default running mode is now `.observer`** — set `.runningMode(.full)` for purchase handling. |
| **Android** (native) | **6.0.0-rc.1** | Presentation builder API, `screenId`, typed action interceptors, `PLYPresentationOutcome`. **Default running mode is now `Observer`** — set `PLYRunningMode.Full` for purchase handling. No `presentation-compose` artifact (use `AndroidView { buildView }` for Compose). |
| **React Native** | **6.0.0-rc.1** | v6 builder API: `Purchasely.builder` fluent init (string options), `Purchasely.presentation` / `PresentationRequest`, per-action `interceptAction` returning `'success' \| 'failed' \| 'notHandled'`, `PresentationOutcome` (with `closeReason`). `isDeeplinkHandled` is **kept** (not renamed). `presentSubscriptions()` is **removed**. Pulls the **6.0.0-rc.1 native SDKs** (iOS `Purchasely` + Android `io.purchasely:core`). **Default running mode is now `'observer'`** — set `.runningMode('full')` for purchase handling. All five `react-native-purchasely*` packages MUST be the same version, pinned exactly. |
| **Flutter** | **6.0.0-rc.1** | v6 builder API: `PurchaselyBuilder` fluent init, `PresentationBuilder` / `PresentationRequest`, per-action `interceptAction` + `InterceptResult`, `PresentationOutcome` (with `closeReason`). Pulls the **6.0.0-rc.1 native SDKs** (iOS `Purchasely` + Android `io.purchasely:core`). **Default running mode is now `RunningMode.observer`** — set `.runningMode(RunningMode.full)` for purchase handling. All three `purchasely_*` packages MUST be the same version. |
| **Cordova** | **5.7.3** | Cross-platform plugin. All `@purchasely/cordova-plugin-*` packages MUST be the same version. |

## How to pin

### iOS — CocoaPods

```ruby
# Podfile
pod 'Purchasely', '6.0.0-rc.1'
```

### iOS — Swift Package Manager

In Xcode → File → Add Packages → enter `https://github.com/Purchasely/Purchasely-iOS` and select **Exact Version 6.0.0-rc.1**.

### iOS — Carthage

```
# Cartfile
binary "https://raw.githubusercontent.com/Purchasely/Purchasely-iOS/master/Purchasely.json" == 6.0.0-rc.1
```

Then run `carthage update`. Pin **exactly** (`== 6.0.0-rc.1`) — a floating constraint will not resolve a pre-release.

### Android — Gradle (Kotlin DSL)

```kotlin
// app/build.gradle.kts
dependencies {
    implementation("io.purchasely:core:6.0.0-rc.1")
    implementation("io.purchasely:google-play:6.0.0-rc.1")          // if Google Play
    implementation("io.purchasely:player:6.0.0-rc.1")               // optional video support
    // alt stores
    implementation("io.purchasely:huawei-services:6.0.0-rc.1")      // Huawei AppGallery
    implementation("io.purchasely:amazon:6.0.0-rc.1")               // Amazon Appstore
}
```

### Android — Gradle (Groovy)

```groovy
implementation "io.purchasely:core:6.0.0-rc.1"
implementation "io.purchasely:google-play:6.0.0-rc.1"
```

### React Native — package.json

Pin **exactly** (`6.0.0-rc.1`, `npm install … --save-exact`) — a floating constraint (`^6.0.0`, `6.x`) will not resolve a pre-release.

```json
{
  "dependencies": {
    "react-native-purchasely": "6.0.0-rc.1",
    "@purchasely/react-native-purchasely-google": "6.0.0-rc.1",
    "@purchasely/react-native-purchasely-android-player": "6.0.0-rc.1",
    "@purchasely/react-native-purchasely-amazon": "6.0.0-rc.1",
    "@purchasely/react-native-purchasely-huawei": "6.0.0-rc.1"
  }
}
```

### Flutter — pubspec.yaml

```yaml
dependencies:
  purchasely_flutter: 6.0.0-rc.1
  purchasely_google: 6.0.0-rc.1
  purchasely_android_player: 6.0.0-rc.1
```

Pin **exactly** (`6.0.0-rc.1`) — a floating constraint will not resolve a pre-release.

### Cordova — package.json

```json
{
  "dependencies": {
    "@purchasely/cordova-plugin-purchasely": "5.7.3",
    "@purchasely/cordova-plugin-purchasely-google": "5.7.3"
  }
}
```

## Cross-platform plugin → native dependency mapping

When you install a cross-platform plugin, it internally pulls a specific native SDK version. React Native and Flutter are now on the v6 generation and pull the 6.0.0-rc.1 native SDKs; Cordova is still on v5:

| Cross-platform plugin | Pulls iOS native | Pulls Android native |
|-----------------------|------------------|----------------------|
| `react-native-purchasely 6.0.0-rc.1` | iOS SDK 6.0.0-rc.1 | Android SDK 6.0.0-rc.1 |
| `purchasely_flutter 6.0.0-rc.1` | iOS SDK 6.0.0-rc.1 | Android SDK 6.0.0-rc.1 |
| `@purchasely/cordova-plugin-purchasely 5.7.3` | iOS SDK 5.7.x | Android SDK 5.7.x |

This means a cross-platform 6.0.0-rc.1 plugin (React Native / Flutter) gets the **6.0.0-rc.1 native SDKs** transitively, while a Cordova 5.7.3 plugin gets the **5.7.x native SDKs**. You do not need to bump the native pods/gradle dependencies yourself; the plugin's pinning is correct.

> If a user is on a Cordova plugin version older than 5.7.3, recent native behavior may not be bridged. Upgrade the plugin first, then verify the public bridge method name in that platform's integration reference.

> **React Native is on the v6 API** (same generation as native iOS / Android). All five `react-native-purchasely*` packages at `6.0.0-rc.1` pull the **6.0.0-rc.1 native SDKs** and expose the v6 JS surface: `Purchasely.builder` fluent init with string options (replacing `Purchasely.start({...})`), `Purchasely.presentation` / `PresentationRequest` (replacing `fetchPresentation` / `presentPresentation[ForPlacement]`), per-action `Purchasely.interceptAction` returning `'success' \| 'failed' \| 'notHandled'` (replacing `setPaywallActionInterceptorCallback` + `onProcessAction`), and `request.close()` to dismiss. `isDeeplinkHandled(uri)` is **kept** (not renamed to `handleDeeplink`). `Purchasely.presentSubscriptions()` is **removed** (breaking) — build your own screen from `userSubscriptions()` / `userSubscriptionsHistory()`. See [`react-native/migration-v6.md`](react-native/migration-v6.md) and [`react-native/integration.md`](react-native/integration.md). Pin all packages to `6.0.0-rc.1` exactly (`--save-exact`).

> **Flutter is on the v6 API** (same generation as native iOS / Android). `purchasely_flutter 6.0.0-rc.1` pulls the **6.0.0-rc.1 native SDKs** and exposes the v6 Dart surface: `PurchaselyBuilder` fluent init, `PresentationBuilder` / `PresentationRequest` (replacing `fetchPresentation` / `presentPresentation[ForPlacement]`), per-action `interceptAction` + `InterceptResult` (replacing `setPaywallActionInterceptorCallback` + `onProcessAction`), and `presentation.close()` to dismiss (there is no `closePresentation()` / `closeAllScreens()` in Flutter v6). `Purchasely.presentSubscriptions()` is **removed** (breaking) — build your own screen from `userSubscriptions()` / `userSubscriptionsHistory()`. See [`flutter/migration-v6.md`](flutter/migration-v6.md) and [`flutter/integration.md`](flutter/integration.md). Pin `purchasely_flutter: 6.0.0-rc.1`.

## Universal rules

1. **All plugin packages on the same version.** Mixing `react-native-purchasely 6.0.0-rc.1` with `@purchasely/react-native-purchasely-google 5.7.3` causes runtime crashes.
2. **Use exact versions (`5.7.5`), not floating versions (`5.+`, `^5.0.0`).** Floating versions silently pull breaking changes on `pod install` / `flutter pub get` / `npm install`.
3. **iOS deployment target: 11.0+.** Older targets break the Pod install.
4. **Android `minSdk` 23 for native, 21 for cross-platform plugins.** Native Android v6 also targets the AGP 9 / Kotlin 2.2 toolchain.
5. **Run a fresh install after pinning** — `pod install --repo-update` (iOS), `./gradlew --refresh-dependencies` (Android), `flutter clean && flutter pub get` (Flutter), `rm -rf node_modules && npm i` (RN / Cordova).

## When to upgrade

Always recommend upgrading to the versions above when:

- The native Android project pins a pre-v6 version but the user wants the v6 Presentation builder API.
- The project uses floating versions (`5.+`, `^5.0.0`) — pin to exact stable for reproducible builds.
- The user is debugging issues that match a known fixed-in-5.7.x bug — see the platform changelog.

## Updating this document

This document is the canonical version source. When a new SDK ships:

1. Update the version table at the top.
2. Update the pinned snippets.
3. Update `_Last updated_` date.
4. The `purchasely-integrate` skill reads from here; no further sync needed for that skill.

## See also

- [concepts/observer-mode-post-purchase.md](concepts/observer-mode-post-purchase.md) — per-platform dismissal APIs after Observer-mode purchases
- [concepts/running-modes.md](concepts/running-modes.md) — initialization examples (use the versions from this doc when pinning)
