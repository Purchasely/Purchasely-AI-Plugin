# Android Initialization

Native Android SDK v6 uses `PLYRunningMode.Full` or `PLYRunningMode.Observer`, `allowDeeplink`, and `allowCampaigns`.

## Dependencies

```kotlin
dependencies {
    implementation("io.purchasely:core:6.0.0")
    implementation("io.purchasely:google-play:6.0.0")
    implementation("io.purchasely:player:6.0.0") // optional video support
    implementation("io.purchasely:presentation-compose:6.0.0") // optional Compose embedding
}
```

## Kotlin DSL

```kotlin
class App : Application() {
    override fun onCreate() {
        super.onCreate()

        Purchasely {
            context(this@App)
            apiKey("YOUR_API_KEY")
            stores(listOf(GoogleStore()))
            runningMode(PLYRunningMode.Full)
            logLevel(LogLevel.DEBUG)
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

## Fluent Builder

Use this from Java or when a Kotlin call site cannot use the DSL.

```kotlin
Purchasely.Builder(applicationContext)
    .apiKey("YOUR_API_KEY")
    .stores(listOf(GoogleStore()))
    .runningMode(PLYRunningMode.Full)
    .allowDeeplink(true)
    .allowCampaigns(true)
    .build()
    .start { error -> }
```

## Modes

| Mode | Purpose |
|------|---------|
| `PLYRunningMode.Full` | Purchasely runs purchases and validation. |
| `PLYRunningMode.Observer` | App runs purchases; Purchasely observes transactions and displays Screens. |

Default in v6 is `Observer`. Set `Full` explicitly when Purchasely should execute store purchases.

## Deeplinks and campaigns

```kotlin
Purchasely.allowDeeplink = true
Purchasely.allowCampaigns = true
Purchasely.handleDeeplink(uri, activity)
```

Use `allowCampaigns(false)` during startup flows when automated campaign display must wait for the UI to be ready.
