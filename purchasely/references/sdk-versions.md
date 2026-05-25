# Purchasely SDK — Latest Versions

> **Single source of truth.** When pinning a Purchasely dependency, pin to these exact versions unless the user explicitly asks otherwise. If you find an outdated version in a project, recommend upgrading to the version below for that platform.

## Current latest stable versions

_Last updated: 2026-05-18._

| Platform | Latest version | Notes |
|----------|----------------|-------|
| **iOS** (native) | **5.7.5** | `closeAllScreens()` available since this version. `@MainActor`-isolated. |
| **Android** (native) | **5.7.4** | `closeAllScreens()` available since this version. No threading constraint. |
| **React Native** | **5.7.3** | Cross-platform plugin. All three `react-native-purchasely*` packages MUST be the same version. |
| **Flutter** | **5.7.3** | Cross-platform plugin. All three `purchasely_*` packages MUST be the same version. |
| **Cordova** | **5.7.3** | Cross-platform plugin. All `@purchasely/cordova-plugin-*` packages MUST be the same version. |

## How to pin

### iOS — CocoaPods

```ruby
# Podfile
pod 'Purchasely', '5.7.5'
```

### iOS — Swift Package Manager

In Xcode → File → Add Packages → enter `https://github.com/Purchasely/Purchasely-iOS` and select **Exact Version 5.7.5**.

### Android — Gradle (Kotlin DSL)

```kotlin
// app/build.gradle.kts
dependencies {
    implementation("io.purchasely:core:5.7.4")
    implementation("io.purchasely:google-play:5.7.4")          // if Google Play
    implementation("io.purchasely:player:5.7.4")               // optional video support
    // alt stores
    implementation("io.purchasely:huawei-services:5.7.4")      // Huawei AppGallery
    implementation("io.purchasely:amazon:5.7.4")               // Amazon Appstore
}
```

### Android — Gradle (Groovy)

```groovy
implementation "io.purchasely:core:5.7.4"
implementation "io.purchasely:google-play:5.7.4"
```

### React Native — package.json

```json
{
  "dependencies": {
    "react-native-purchasely": "5.7.3",
    "@purchasely/react-native-purchasely-google": "5.7.3",
    "@purchasely/react-native-purchasely-android-player": "5.7.3"
  }
}
```

### Flutter — pubspec.yaml

```yaml
dependencies:
  purchasely_flutter: 5.7.3
  purchasely_google: 5.7.3
  purchasely_android_player: 5.7.3
```

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

When you install `react-native-purchasely@5.7.3` (or the Flutter / Cordova equivalent), the cross-platform plugin internally pulls a specific native SDK version:

| Cross-platform plugin | Pulls iOS native | Pulls Android native |
|-----------------------|------------------|----------------------|
| `react-native-purchasely 5.7.3` | iOS SDK 5.7.x | Android SDK 5.7.x |
| `purchasely_flutter 5.7.3` | iOS SDK 5.7.x | Android SDK 5.7.x |
| `@purchasely/cordova-plugin-purchasely 5.7.3` | iOS SDK 5.7.x | Android SDK 5.7.x |

This means a cross-platform 5.7.3 plugin gets the **5.7.x native SDKs** transitively. You do not need to bump the native pods/gradle dependencies yourself; the plugin's pinning is correct. However, the public JS / Dart bridge may expose a different method name than the native SDK — for example current React Native / Flutter / Cordova bridges expose `closePresentation()`, not `closeAllScreens()`.

> If a user is on a cross-platform plugin version older than 5.7.3, recent native behavior may not be bridged. Upgrade the plugin first, then verify the public bridge method name in that platform's integration reference.

## Universal rules

1. **All three plugin packages on the same major.minor.patch.** Mixing `react-native-purchasely 5.7.3` with `@purchasely/react-native-purchasely-google 5.6.0` causes runtime crashes.
2. **Use exact versions (`5.7.5`), not floating versions (`5.+`, `^5.0.0`).** Floating versions silently pull breaking changes on `pod install` / `flutter pub get` / `npm install`.
3. **iOS deployment target: 11.0+.** Older targets break the Pod install.
4. **Android `minSdk` 23 for native, 21 for cross-platform plugins.**
5. **Run a fresh install after pinning** — `pod install --repo-update` (iOS), `./gradlew --refresh-dependencies` (Android), `flutter clean && flutter pub get` (Flutter), `rm -rf node_modules && npm i` (RN / Cordova).

## When to upgrade

Always recommend upgrading to the versions above when:

- The project pins an older version that lacks reliable paywall dismissal (iOS < 5.7.5, Android < 5.7.4, cross-platform < 5.7.3 native bridge).
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
