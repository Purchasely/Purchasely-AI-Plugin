---
name: migrate
description: "Use when migrating Purchasely SDK from v5.x to v6.0 — identifies deprecated APIs, applies breaking changes, and validates the migration across iOS, Android, React Native, Flutter, and Cordova."
---

# Purchasely SDK Migration Skill (v5.x to v6.0)

> **Note:** Migration from v5.x to v6.0 is not yet available for React Native, Flutter, and Cordova. These cross-platform SDKs will be updated in a future release. If the project uses one of these platforms, inform the user and skip migration steps for that platform.

## Step 1: Detect Current SDK Version

Identify the platform(s) in use and their current Purchasely SDK version.

**Android** — search for the dependency version:
```bash
rg 'io\.purchasely:purchasely:\d+\.\d+\.\d+' --glob 'build.gradle*' --glob '*.kts'
```

**iOS** — check CocoaPods or SPM:
```bash
# CocoaPods
rg "pod\s+'Purchasely'" --glob 'Podfile*'
# Swift Package Manager
rg 'purchasely' --glob 'Package.swift' --glob 'Package.resolved' -i
```

**React Native** — check package.json:
```bash
rg '"react-native-purchasely"' --glob 'package.json'
```

**Flutter** — check pubspec.yaml:
```bash
rg 'purchasely_flutter' --glob 'pubspec.yaml'
```

**Cordova** — check package.json or config.xml:
```bash
rg 'purchasely' --glob 'package.json' --glob 'config.xml' -i
```

If the detected version is already >= 6.0, inform the user that migration is not needed. If the version is < 5.0, warn the user that this skill covers v5.x to v6.0 only and earlier versions may require additional steps.

## Step 2: Scan for Deprecated and Breaking Patterns

Run the following searches across the codebase. Report every match with `file:line`.

### Android / Kotlin Patterns

| Pattern (regex) | Category | Description |
|---|---|---|
| `Purchasely\.setPaywallActionsInterceptor\s*\{` | BREAKING | Global interceptor removed in v6; use per-action `Purchasely.interceptAction()` |
| `Purchasely\.presentationView\(` | BREAKING | Removed; use `PLYPresentation { }.display()` builder |
| `Purchasely\.presentationViewForPlacement\(` | BREAKING | Removed; use `PLYPresentation { }.display()` builder |
| `isDeeplinkHandled\(` | BREAKING | Renamed to `handleDeeplink()` |
| `readyToOpenDeeplink` | BREAKING | Renamed to `allowDeeplink` |
| `processAction\s*\(\s*(true\|false)\s*\)` | BREAKING | Boolean parameter replaced by `PLYInterceptResult` enum |
| `PLYRunningMode\.PaywallObserver` | BREAKING | Renamed to `PLYRunningMode.Observer` |
| `PLYPresentationActionParameters` | BREAKING | Removed; parameters are now on sealed class variants directly |

### iOS / Swift Patterns

| Pattern (regex) | Category | Description |
|---|---|---|
| `isDeeplinkHandled\(` | DEPRECATED | Renamed to `handleDeeplink()` (deprecated shim exists but update recommended) |
| `readyToOpenDeeplink\(` | DEPRECATED | Renamed to `allowDeeplink()` |
| `info\.presentationId` | DEPRECATED | Use `info.presentation?.id` |
| `info\.placementId` | DEPRECATED | Use `info.presentation?.placementId` |
| `info\.audienceId` | DEPRECATED | Use `info.presentation?.audienceId` |
| `info\.abTestId` | DEPRECATED | Use `info.presentation?.abTestId` |
| `info\.abTestVariantId` | DEPRECATED | Use `info.presentation?.abTestVariantId` |

## Step 3: Generate Migration Report

Present findings to the user in a structured report:

```
## Migration Report: Purchasely v5.x -> v6.0

### Platform: [Android / iOS]
### Current version: X.Y.Z

### BREAKING CHANGES (must fix before upgrading)

1. **file.kt:42** — `Purchasely.setPaywallActionsInterceptor {`
   - Old: Global interceptor with `processAction(true/false)`
   - New: Per-action interceptor with `PLYInterceptResult` enum
   - Impact: Compilation failure if not migrated

2. ...

### DEPRECATED (still compiles, should update)

1. **file.swift:17** — `isDeeplinkHandled(`
   - Old: `Purchasely.isDeeplinkHandled(url)`
   - New: `Purchasely.handleDeeplink(url)`
   - Impact: Works via shim but will be removed in future version

2. ...

### Summary
- X breaking changes found
- Y deprecations found
```

## Step 4: Apply Changes (with user confirmation)

Before making any edits, present the migration report from Step 3 and ask the user to confirm. Apply changes only after explicit approval.

### Android Breaking Changes

#### a) Action Interceptor Rewrite

This is the most complex migration. The global `setPaywallActionsInterceptor` is replaced by per-action interceptors.

**OLD:**
```kotlin
Purchasely.setPaywallActionsInterceptor { info, action, parameters, processAction ->
    when(action) {
        PLYPresentationAction.LOGIN -> {
            // handle login
            processAction(true)
        }
        else -> processAction(true)
    }
}
```

**NEW:**
```kotlin
Purchasely.interceptAction<PLYPresentationAction.Login> { info ->
    // handle login
    PLYInterceptResult.SUCCESS
}
```

When migrating multi-branch `when` blocks, create one `interceptAction` call per action type that had custom handling. Actions that simply called `processAction(true)` do not need an interceptor (that is the default behavior in v6).

#### b) Presentation Display

**OLD:**
```kotlin
Purchasely.fetchPresentation("placement_id") { presentation, error ->
    presentation?.display(context)
}
```

**NEW:**
```kotlin
PLYPresentation { placementId("placement_id") }.display(context)
```

#### c) Deeplink Handling

**OLD:**
```kotlin
Purchasely.isDeeplinkHandled(uri, activity)
```

**NEW:**
```kotlin
Purchasely.handleDeeplink(uri, activity)
```

#### d) Ready to Open Deeplink

**OLD:**
```kotlin
Purchasely.readyToOpenDeeplink = true
```

**NEW:**
```kotlin
Purchasely.allowDeeplink = true
```

#### e) Running Mode

**OLD:**
```kotlin
PLYRunningMode.PaywallObserver
```

**NEW:**
```kotlin
PLYRunningMode.Observer
```

### iOS Changes (all have deprecated shims, non-breaking)

#### a) Deeplink Methods

**OLD:**
```swift
Purchasely.isDeeplinkHandled(url)
Purchasely.readyToOpenDeeplink(true)
```

**NEW:**
```swift
Purchasely.handleDeeplink(url)
Purchasely.allowDeeplink(true)
```

#### b) Presentation Info Accessors

**OLD:**
```swift
info.presentationId
info.placementId
info.audienceId
info.abTestId
info.abTestVariantId
```

**NEW:**
```swift
info.presentation?.id
info.presentation?.placementId
info.presentation?.audienceId
info.presentation?.abTestId
info.presentation?.abTestVariantId
```

## Step 5: Suggest New v6 Features (optional)

After migration is complete, present these optional improvements the user may want to adopt:

- **PLYPresentation Builder pattern** — Declarative presentation configuration with built-in preload support for faster display.
- **Per-action interceptors** — More granular control; intercept only the actions you care about instead of a monolithic callback.
- **PLYPresentationState observable** — Subscribe to presentation state changes via `StateFlow` (Android) for reactive UI updates.
- **Campaign display control** — New `allowCampaigns` flag to programmatically enable/disable campaign presentation display.
- **Sequential action execution** — Actions are now executed sequentially, preventing race conditions from rapid user taps.

## Step 6: Validate Migration

After applying changes, run validation:

1. **Search for remaining deprecated patterns** — re-run all regex patterns from Step 2 and confirm zero matches.

2. **Check build tool versions (Android only)**:
   ```bash
   # Gradle version — must be >= 9.3.0
   rg 'distributionUrl' --glob 'gradle-wrapper.properties'
   # Kotlin version — must be >= 2.2.x
   rg 'kotlin' --glob 'build.gradle*' --glob '*.kts' | rg '\d+\.\d+\.\d+'
   ```

3. **Suggest build verification** — ask the user to run a build to catch any remaining compilation errors:
   - Android: `./gradlew assembleDebug`
   - iOS: `xcodebuild build -workspace *.xcworkspace -scheme <scheme> -destination 'generic/platform=iOS Simulator'`

4. **Suggest running the review skill** — recommend `/review` or the code review skill to get a second pass on the migrated code for correctness and style.
