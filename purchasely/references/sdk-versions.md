# Purchasely SDK — Latest Versions

> **Single source of truth.** When pinning a Purchasely dependency, pin to these exact versions unless the user explicitly asks otherwise. If you find an outdated version in a project, recommend upgrading to the version below for that platform.

## Current supported versions

_Last updated: 2026-07-23._

| Platform | Latest version | Notes |
|----------|----------------|-------|
| **iOS** (native) | **6.0.0** | Stable GA (tagged 2026-07-20). Fluent init builder, per-action `interceptAction` + `PLYInterceptResult`, `PLYPresentationBuilder`, `swiftUIView`, `closeAllScreens()`, `PLYPresentationOutcome` (with `closeReason`). **Default running mode is `.observer`** — set `.runningMode(.full)` for purchase handling. Install via SPM (primary — `from: "6.0.0"`) or CocoaPods (`~> 6.0`); the SDK's dev repo is now SPM-only, so CocoaPods/binary distribution is published from the separate `Purchasely/Purchasely-iOS` repo. Deployment target **13.4+** — inherited from the 5.x SDK, not a v6 change. |
| **Android** (native) | **6.0.1** | Stable GA (tagged 2026-07-20 — no `6.0.0` tag was ever cut; chronology is `rc.1` → `rc.2` → `rc.3` → `6.0.1`). Presentation builder API, `screenId`, typed action interceptors, `PLYPresentationOutcome`. **Default running mode is `Observer`** — set `PLYRunningMode.Full` for purchase handling. No `presentation-compose` artifact (use `AndroidView { buildView }` for Compose); `google-play` / `huawei-services` / `amazon` / `player` artifacts stay in lockstep at `6.0.1`. |
| **Flutter** | **6.0.0** | Stable (published to pub.dev 2026-07-21). `purchasely_flutter`, `purchasely_google`, `purchasely_android_player` all `6.0.0`; embeds native iOS **6.0.0** + Android **`io.purchasely:core 6.0.1`**. Requires **Dart ≥ 3.0.0**. v6 builder API: `PurchaselyBuilder` fluent init, `PresentationBuilder` / `PresentationRequest`, per-action `interceptAction` + `InterceptResult`, `PresentationOutcome` (with `closeReason`). **Default running mode is `RunningMode.observer`** — set `.runningMode(RunningMode.full)` for purchase handling. All three `purchasely_*` packages MUST be the same version. |
| **React Native** | **6.0.0** | Stable GA (npm `latest` tag). v6 builder API: `Purchasely.builder` fluent init (string options), `Purchasely.presentation` (`PLYPresentationBuilder`) / `PLYPresentationRequest`, per-action `interceptAction` returning `'success' \| 'failed' \| 'notHandled'`, `PLYPresentationOutcome` (with `closeReason` = `button`/`backSystem`/`programmatic`). `isDeeplinkHandled` is **removed** — use `handleDeeplink(uri)`. `presentSubscriptions()` is **removed**. Pulls the **native iOS 6.0.0 / Android 6.0.1 SDKs** (confirmed pinned at the published tags). Requires **`minSdk 23`** and iOS deployment target **15.1** (aligned with RN 0.86). **Default running mode is now `'observer'`** — set `.runningMode('full')` for purchase handling. All five `react-native-purchasely*` packages MUST be the same version, pinned exactly. |
| **Cordova** | **6.0.0** | **Stable GA** (npm `latest` tag, not `@next`). v6 builder API: `Purchasely.builder(apiKey)` fluent init (also keeps the v5-shaped `Purchasely.start({...}, ok, err)` options object, now a single object instead of positional args), `Purchasely.presentation` builder / request lifecycle (`preload()`/`display()`/`close()`/`back()`), per-action `interceptAction(kind, handler)` returning `'success' \| 'failed' \| 'notHandled'`, 5-field outcome (`presentation`, `purchaseResult` string, `plan`, `closeReason`, `error`). The v5 flat paywall API (`fetchPresentation*`, `presentPresentation*`, `setPaywallActionInterceptor` + `onProcessAction`) is **removed**. `isDeeplinkHandled` is **removed** — use `handleDeeplink(uri)`. `presentSubscriptions()` is **removed**. Pulls native iOS `Purchasely 6.0.0` / Android `io.purchasely:core 6.0.1`. All `@purchasely/cordova-plugin-*` packages MUST be the same version, pinned exactly. |

## How to pin

### iOS — Swift Package Manager (primary)

In Xcode → File → Add Packages → enter `https://github.com/Purchasely/Purchasely-iOS` and select **Up to Next Major Version**, `from: "6.0.0"`:

```swift
.package(url: "https://github.com/Purchasely/Purchasely-iOS", from: "6.0.0")
```

### iOS — CocoaPods

```ruby
# Podfile
pod 'Purchasely', '~> 6.0'
```

CocoaPods and binary distribution are published from the `Purchasely/Purchasely-iOS` repo (the SDK's own dev repo went SPM-only).

### iOS — Carthage

```
# Cartfile
binary "https://raw.githubusercontent.com/Purchasely/Purchasely-iOS/master/Purchasely.json" ~> 6.0
```

Then run `carthage update`.

### Android — Gradle (Kotlin DSL)

```kotlin
// app/build.gradle.kts
dependencies {
    implementation("io.purchasely:core:6.0.1")
    implementation("io.purchasely:google-play:6.0.1")          // if Google Play
    implementation("io.purchasely:player:6.0.1")               // optional video support
    // alt stores
    implementation("io.purchasely:huawei-services:6.0.1")      // Huawei AppGallery
    implementation("io.purchasely:amazon:6.0.1")               // Amazon Appstore
}
```

### Android — Gradle (Groovy)

```groovy
implementation "io.purchasely:core:6.0.1"
implementation "io.purchasely:google-play:6.0.1"
```

### React Native — package.json

Stable GA — pin **exactly** (`6.0.0`, `npm install … --save-exact`) for alignment across all five packages; a floating constraint (`^6.0.0`, `6.x`) now resolves fine, but exact pins keep every package in lockstep.

```json
{
  "dependencies": {
    "react-native-purchasely": "6.0.0",
    "@purchasely/react-native-purchasely-google": "6.0.0",
    "@purchasely/react-native-purchasely-android-player": "6.0.0",
    "@purchasely/react-native-purchasely-amazon": "6.0.0",
    "@purchasely/react-native-purchasely-huawei": "6.0.0"
  }
}
```

### Flutter — pubspec.yaml

```yaml
dependencies:
  purchasely_flutter: ^6.0.0
  purchasely_google: ^6.0.0
  purchasely_android_player: ^6.0.0
```

Now stable — a caret range is fine for reproducible builds; pin exactly (`6.0.0`) if you prefer to control upgrades manually.

### Cordova — package.json

Stable GA — pin **exactly** (`6.0.0`) for alignment across both packages:

```json
{
  "dependencies": {
    "@purchasely/cordova-plugin-purchasely": "6.0.0",
    "@purchasely/cordova-plugin-purchasely-google": "6.0.0"
  }
}
```

Or via the Cordova CLI:

```bash
cordova plugin add @purchasely/cordova-plugin-purchasely@6.0.0
cordova plugin add @purchasely/cordova-plugin-purchasely-google@6.0.0
```

## Cross-platform plugin → native dependency mapping

When you install a cross-platform plugin, it internally pulls a specific native SDK version. React Native, Flutter, and Cordova are all stable GA:

| Cross-platform plugin | Pulls iOS native | Pulls Android native |
|-----------------------|------------------|----------------------|
| `react-native-purchasely 6.0.0` | iOS SDK 6.0.0 | Android SDK 6.0.1 |
| `purchasely_flutter 6.0.0` | iOS SDK 6.0.0 | Android SDK 6.0.1 |
| `@purchasely/cordova-plugin-purchasely 6.0.0` | iOS SDK 6.0.0 | Android SDK 6.0.1 |

This means a cross-platform plugin gets its pinned native SDKs transitively (React Native → iOS `6.0.0` / Android `6.0.1`, Flutter → iOS `6.0.0` / Android `6.0.1`, Cordova → iOS `6.0.0` / Android `6.0.1`). You do not need to bump the native pods/gradle dependencies yourself; the plugin's pinning is correct.

> If a user is on a Cordova plugin version older than `6.0.0`, the v5 flat paywall API (`fetchPresentation*`, `presentPresentation*`, `setPaywallActionInterceptor` + `onProcessAction`) is what's bridged, not the v6 builder. Upgrade the plugin first, then verify the public bridge method name in that platform's integration reference.

> **React Native is on the v6 API** (same generation as native iOS / Android) and is now **stable GA**. All five `react-native-purchasely*` packages at `6.0.0` pull the **native iOS 6.0.0 / Android 6.0.1 SDKs** and expose the v6 JS surface: `Purchasely.builder` fluent init with string options (replacing `Purchasely.start({...})`), `Purchasely.presentation` (`PLYPresentationBuilder`) / `PLYPresentationRequest` (replacing `fetchPresentation` / `presentPresentation[ForPlacement]`), per-action `Purchasely.interceptAction` returning `'success' \| 'failed' \| 'notHandled'` (replacing `setPaywallActionInterceptorCallback` + `onProcessAction`), and `request.close()` to dismiss. `isDeeplinkHandled(uri)` / `readyToOpenDeeplink(bool)` are **removed** — use `Purchasely.handleDeeplink(uri)` and `.allowDeeplink(true)`. `Purchasely.presentSubscriptions()` is **removed** (breaking) — build your own screen from `userSubscriptions()` / `userSubscriptionsHistory()`. Requires Android `minSdk 23` and iOS deployment target **15.1**. See [`react-native/migration-v6.md`](react-native/migration-v6.md) and [`react-native/integration.md`](react-native/integration.md). Pin all packages to `6.0.0` exactly (`--save-exact`) for cross-package alignment.

> **Flutter is on the v6 API** (same generation as native iOS / Android) and is now **stable**. `purchasely_flutter 6.0.0` pulls native iOS **`6.0.0`** + Android **`io.purchasely:core 6.0.1`** and exposes the v6 Dart surface: `PurchaselyBuilder` fluent init, `PresentationBuilder` / `PresentationRequest` (replacing `fetchPresentation` / `presentPresentation[ForPlacement]`), per-action `interceptAction` + `InterceptResult` (replacing `setPaywallActionInterceptorCallback` + `onProcessAction`), and `presentation.close()` to dismiss (there is no `closePresentation()` / `closeAllScreens()` in Flutter v6). `Purchasely.presentSubscriptions()` is **removed** (breaking) — build your own screen from `userSubscriptions()` / `userSubscriptionsHistory()`. Requires **Dart ≥ 3.0.0**. See [`flutter/migration-v6.md`](flutter/migration-v6.md) and [`flutter/integration.md`](flutter/integration.md). Pin `purchasely_flutter: 6.0.0` (or `^6.0.0`).

> **Cordova is on the v6 API** — and, unlike React Native / Flutter, as a **stable** release (npm `latest`, not `@next`). `@purchasely/cordova-plugin-purchasely 6.0.0` pulls native iOS `Purchasely 6.0.0` / Android `io.purchasely:core 6.0.1` and exposes the v6 JS surface: `Purchasely.builder(apiKey)` fluent init (the v5-shaped `Purchasely.start({...}, ok, err)` options object is also still accepted, now as a single object instead of positional args), `Purchasely.presentation` builder / request lifecycle (`preload()` / `display()`) (replacing `fetchPresentation*` / `presentPresentation*`), per-action `interceptAction(kind, handler)` returning `'success' \| 'failed' \| 'notHandled'` (replacing `setPaywallActionInterceptor` + `onProcessAction`), and `request.close()` (→ `closeAllScreens()`) to dismiss. `isDeeplinkHandled` / `readyToOpenDeeplink` are **removed** — use `handleDeeplink(uri)` and `.allowDeeplink(true)`. `Purchasely.presentSubscriptions()` is **removed** (breaking) — build your own screen from `userSubscriptions()` / `userSubscriptionsHistory()`. There is **no inline/embedded presentation view** on Cordova (deferred to v6.1 — tracked in Linear "Cordova — parité & compléments v6.1"). See [`cordova/migration-v6.md`](cordova/migration-v6.md) and [`cordova/integration.md`](cordova/integration.md). Pin both `@purchasely/cordova-plugin-*` packages to `6.0.0` exactly.

## Universal rules

1. **All plugin packages on the same version.** Mixing `react-native-purchasely 6.0.0` with `@purchasely/react-native-purchasely-google 5.7.3`, or `@purchasely/cordova-plugin-purchasely 6.0.0` with `@purchasely/cordova-plugin-purchasely-google 5.7.3`, causes runtime crashes.
2. **Use exact versions, not floating ranges, until you've verified compatibility.** iOS native `6.0.0`, Android native `6.0.1`, Flutter `6.0.0`, React Native `6.0.0`, and Cordova `6.0.0` are all **stable GA** and can safely use a semver-compatible range (`~> 6.0`, `from: "6.0.0"`, `^6.0.0`) so patch fixes flow automatically; pin exactly instead if you prefer to control upgrades manually (recommended for React Native and Cordova, to keep every package in lockstep).
3. **iOS deployment target: 13.4+** for native, Flutter, and Cordova — this floor is inherited from the 5.x SDK, not a v6-specific change. Older targets break the Pod install. **React Native requires 15.1** (set by the `react-native-purchasely` podspec, aligned with RN 0.86) — higher than the universal floor.
4. **Android toolchain (native 6.0.1, and the AGP/Kotlin floor for React Native v6 / Cordova v6 host apps):** Gradle **≥ 9.3** (the SDK's own dev wrapper runs 9.6.1), AGP **9.0.1**, **Kotlin 2.3.21** (fixes issues present in the 2.2.x line used by early v6 release candidates), JDK 17 to build, `minSdk 23`, `compileSdk 36`, `targetSdk 35`, Google Play Billing **8.3.0**.
5. **Run a fresh install after pinning** — `pod install --repo-update` (iOS), `./gradlew --refresh-dependencies` (Android), `flutter clean && flutter pub get` (Flutter), `rm -rf node_modules && npm i` (RN / Cordova).

## When to upgrade

Always recommend upgrading to the versions above when:

- The native Android project pins a v6 release candidate (`rc.1` / `rc.2` / `rc.3`) — jump straight to the stable `6.0.1` (no `6.0.0` tag was ever cut for Android).
- The native iOS project pins a pre-`6.0.0` release candidate — move to the stable `6.0.0` tag.
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
