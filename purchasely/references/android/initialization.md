# Android Initialization

Native Android SDK v6 initializes with the Kotlin DSL (`Purchasely { … }`, recommended) or the fluent `Purchasely.Builder` (the only form Java callers can use). Both share one internal initialization and behave identically.

## Dependencies

```kotlin
dependencies {
    implementation("io.purchasely:core:6.0.0-rc1")
    implementation("io.purchasely:google-play:6.0.0-rc1")        // Google Play
    implementation("io.purchasely:player:6.0.0-rc1")             // optional video support
    // alternative stores:
    implementation("io.purchasely:huawei-services:6.0.0-rc1")    // Huawei AppGallery
    implementation("io.purchasely:amazon:6.0.0-rc1")             // Amazon Appstore
}
```

There is **no** `presentation-compose` artifact. For Compose embedding, wrap the Android `View` from `buildView(...)` in an `AndroidView` (see [common-patterns.md](common-patterns.md)).

## Toolchain

| Requirement | Version |
|-------------|---------|
| Gradle | 9.3.0+ |
| AGP | 9.x |
| Kotlin | 2.2.x (K2 compiler) |
| JDK (to build) | 17 |
| `minSdk` | 23 |
| `compileSdk` | 36 |

The reified entry points `interceptAction<T> { … }` / `removeActionInterceptor<T>()` are `inline` functions targeting JVM 11. Compile your Kotlin module with `jvmTarget = 11`, or use the `Class`-based overload. With AGP 9, remove the explicit `org.jetbrains.kotlin.android` plugin and the `android { kotlinOptions { … } }` block (AGP provides Android Kotlin support directly).

## Default running mode is `Observer` ⚠️

> **The default `runningMode` changed from `Full` (v5) to `Observer` (v6).** This change is silent — code keeps compiling, but the SDK stops validating purchases. If your app relies on Purchasely to process and validate purchases, set `runningMode(PLYRunningMode.Full)` explicitly.
>
> **Behavioral consequence — no auto-close.** In Observer mode, presentations **no longer auto-close** after a purchase or restore. In v5, the implicit `Full` default auto-appended a `close_all` action after `purchase` / `restore`. If your app relied on auto-close, set `runningMode(PLYRunningMode.Full)` or close the presentation yourself in the outcome callback.
>
> When `Full` is not set, the SDK logs a DEBUG message at `build()` time reminding you of the change.

## Kotlin DSL (recommended)

```kotlin
class App : Application() {
    override fun onCreate() {
        super.onCreate()

        Purchasely {
            context(this@App)
            apiKey("YOUR_API_KEY")
            userId("user-123")               // optional
            stores(listOf(GoogleStore()))
            runningMode(PLYRunningMode.Full)  // default is Observer
            logLevel(LogLevel.DEBUG)
            logcatEnabled(true)               // optional, independent of logLevel
            allowDeeplink(true)
            allowCampaigns(true)
            onInitialized { error ->
                if (error == null) {
                    // SDK ready
                }
            }
        }
    }
}
```

`context` and `apiKey` are mandatory; every setting is a method-style setter. Custom Lint checks (`PurchaselyMissingContext`, `PurchaselyMissingApiKey`, `PurchaselyFullModeWithoutStores`) flag common mistakes in the editor.

## Fluent Builder (Java + Kotlin)

Use this from Java, or when a Kotlin call site cannot use the DSL.

```kotlin
Purchasely.Builder(applicationContext)
    .apiKey("YOUR_API_KEY")
    .userId("user-123")
    .stores(listOf(GoogleStore()))
    .runningMode(PLYRunningMode.Full)
    .logLevel(LogLevel.DEBUG)
    .logcatEnabled(true)
    .allowDeeplink(true)
    .allowCampaigns(true)
    .handleDeeplink(intent.data)       // optional cold-start deeplink
    .build()
    .start { error ->
        if (error == null) {
            // SDK ready
        }
    }
```

The init callback is now `{ error -> }` (single nullable `PLYError`); the v5 `{ isConfigured, error -> }` two-argument form was removed.

## `apiKey` validation

The SDK validates `apiKey` at `start()`. When null/blank, the callback fires with `PLYError.Configuration` ("API key not set") and the SDK stays inert (no crash). If you source the key dynamically (RemoteConfig, feature flags), make sure it is non-blank before calling `start()`.

## Storeless start

Starting **without any store** is a first-class path: screens, analytics, campaigns, deeplinks and user attributes all work. In Full mode, purchase APIs return `PLYError.NoStoreConfigured` when no store is configured (was `PLYError.Unknown` with message `"No store found"` in v5).

## Modes

| Mode | Purpose |
|------|---------|
| `PLYRunningMode.Full` | Purchasely runs purchases and validation, and auto-closes the presentation after purchase/restore. |
| `PLYRunningMode.Observer` | App runs purchases; Purchasely observes transactions and displays Screens. No auto-close. |

Default in v6 is `Observer`. Set `Full` explicitly when Purchasely should execute store purchases.

## Deeplinks and campaigns

The SDK auto-intercepts its own deeplinks (zero code) by reading the foreground activity's intent on create and resume. `allowDeeplink` and `allowCampaigns` are two independent flags (default `true`).

```kotlin
Purchasely.allowDeeplink = true     // deeplink presentations
Purchasely.allowCampaigns = false   // campaigns stay queued (e.g. during onboarding)
Purchasely.allowCampaigns = true    // queued campaigns display immediately
Purchasely.handleDeeplink(uri, activity) // still works; deduped against auto-interception
```

For a cold start from a deeplink, pass it to the builder with `.handleDeeplink(intent.data)`. Opt out of auto-interception with `.automaticDeeplinkHandling(false)`.

> **Pitfall — `singleTask` / `singleTop` activities.** If the deeplink arrives in `onNewIntent` and you do not call `setIntent(intent)`, the URI is hidden from auto-interception. Call `setIntent(intent)` in `onNewIntent`, or keep a manual `Purchasely.handleDeeplink(intent.data, activity)` call.

```kotlin
override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent) // required for deeplink auto-interception on singleTask/singleTop
}
```

See the full v5→v6 migration in [migration-v6.md](migration-v6.md).
