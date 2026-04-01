# Android API Reference

## Initialization

### `Purchasely.Builder`

Fluent builder for SDK configuration.

```kotlin
Purchasely.Builder(applicationContext)
    .apiKey("YOUR_API_KEY")                        // required
    .logLevel(LogLevel.DEBUG)                      // optional, default: ERROR
    .stores(listOf(GoogleStore(), HuaweiStore()))   // required, at least one store
    .userId("user_123")                            // optional
    .runningMode(PLYRunningMode.Full)              // optional, default: Full
    .readyToOpenDeeplink(true)                     // optional, default: false
    .build()
    .start { success, error -> }
```

**Builder methods:**

| Method | Type | Description |
|--------|------|-------------|
| `apiKey(key)` | `String` | Your Purchasely API key (required) |
| `logLevel(level)` | `LogLevel` | Logging verbosity |
| `stores(stores)` | `List<Store>` | Billing store implementations |
| `userId(id)` | `String?` | Pre-set user identifier |
| `runningMode(mode)` | `PLYRunningMode` | `.Full` or `.Observer` |
| `readyToOpenDeeplink(ready)` | `Boolean` | Whether app is ready for deeplinks |

## Paywall Presentation

### `Purchasely.fetchPresentation(placementId, contentId, callback)`

Fetch a presentation for a placement. Returns a `PLYPresentation` object with metadata and display capabilities.

```kotlin
Purchasely.fetchPresentation(
    placementId = "ONBOARDING",
    contentId = null,  // optional content targeting
    callback = object : PLYPresentationCallback {
        override fun onPresentationFetched(presentation: PLYPresentation) {
            when (presentation.type) {
                PLYPresentationType.NORMAL,
                PLYPresentationType.FALLBACK -> {
                    // Safe to display
                    presentation.display(context)
                }
                PLYPresentationType.DEACTIVATED -> {
                    // Do NOT display
                }
                PLYPresentationType.CLIENT -> {
                    // Use your own UI with Purchasely plan data
                    val plans = presentation.plans
                }
            }
        }

        override fun onPresentationClosed() {
            // Paywall dismissed
        }

        override fun onPurchaseResult(result: PLYPurchaseResult) {
            // Handle purchase/restore result
        }
    }
)
```

### `PLYPresentation`

Object returned from `fetchPresentation`:

| Property/Method | Type | Description |
|----------------|------|-------------|
| `type` | `PLYPresentationType` | NORMAL, FALLBACK, DEACTIVATED, CLIENT |
| `plans` | `List<PLYPlan>` | Plans associated with the presentation |
| `id` | `String` | Presentation identifier |
| `display(context)` | `void` | Display the paywall as a full-screen activity |
| `getFragment()` | `Fragment` | Get a Fragment for custom embedding |

### `Purchasely.presentationView(placementId, contentId, callback)` -- DEPRECATED

Returns a view for the paywall. Deprecated in favor of `fetchPresentation`.

## Action Interceptor (v5)

### `Purchasely.setPaywallActionsInterceptor`

Set a global interceptor for all paywall actions.

```kotlin
Purchasely.setPaywallActionsInterceptor { info, action, parameters, processAction ->
    when (action) {
        PLYPresentationAction.LOGIN -> {
            // Present login flow
            showLoginScreen { success ->
                if (success) {
                    Purchasely.userLogin("user_id") { }
                }
                processAction(success)
            }
        }
        PLYPresentationAction.PURCHASE -> processAction(true)
        PLYPresentationAction.RESTORE -> processAction(true)
        PLYPresentationAction.CLOSE -> processAction(true)
        PLYPresentationAction.NAVIGATE -> {
            val url = parameters?.url
            // Handle navigation
            processAction(false)
        }
        else -> processAction(true)
    }
}
```

**Important:** You must call `processAction()` in every code path. Failing to do so will freeze the paywall UI.

## Action Interceptor (v6)

### `Purchasely.interceptAction<ActionType>`

Per-action interceptor with typed results. Replaces the global interceptor in v6.

```kotlin
Purchasely.interceptAction<PLYPresentationAction.Login> { info ->
    // info contains presentation context
    val result = showLoginScreen()
    if (result.success) {
        Purchasely.userLogin(result.userId) { }
        PLYInterceptResult.SUCCESS
    } else {
        PLYInterceptResult.NOT_HANDLED
    }
}

Purchasely.interceptAction<PLYPresentationAction.Navigate> { info ->
    // Handle custom navigation
    PLYInterceptResult.SUCCESS
}
```

**PLYInterceptResult values:**

| Value | Description |
|-------|-------------|
| `SUCCESS` | Action was handled successfully |
| `NOT_HANDLED` | Action was not handled, SDK should proceed with default behavior |
| `FAILED` | Action failed |

## PLYPresentation Builder (v6)

New builder pattern for presentation display:

```kotlin
PLYPresentation {
    placementId("ONBOARDING")
    contentId("content_123")  // optional
}.preload { presentation ->
    // Presentation preloaded, ready to display
}.display(context)
```

## Deeplinks

### `Purchasely.handleDeeplink(uri, activity)`

Handle incoming deeplinks. Replaces the deprecated `isDeeplinkHandled`.

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    intent?.data?.let { uri ->
        Purchasely.handleDeeplink(uri, this)
    }
}
```

### `Purchasely.allowDeeplink`

Property to indicate when the app is ready to display deeplinked content. Replaces the deprecated `readyToOpenDeeplink`.

```kotlin
// Set when your main activity is ready
Purchasely.allowDeeplink = true
```

## User Management

### `Purchasely.userLogin(userId, callback)`

Identify the user after authentication.

```kotlin
Purchasely.userLogin("user_123") { shouldRefresh ->
    // Return true to refresh the current paywall
    true
}
```

### `Purchasely.userLogout()`

Clear the current user identity.

```kotlin
Purchasely.userLogout()
```

## User Attributes

### `Purchasely.setUserAttribute(key, value)`

Set user attributes for audience targeting. In v6, these methods return `Deferred<Boolean>`.

```kotlin
// Built-in attributes
Purchasely.setUserAttribute("first_name", "John")
Purchasely.setUserAttribute("last_name", "Doe")
Purchasely.setUserAttribute("age", 30)

// Custom attributes for targeting
Purchasely.setUserAttribute("loyalty_tier", "gold")
Purchasely.setUserAttribute("articles_read", 42)
```

## Subscriptions

### `Purchasely.userSubscriptions`

Fetch the user's active subscriptions.

```kotlin
Purchasely.userSubscriptions { subscriptions ->
    subscriptions?.forEach { subscription ->
        Log.d("PLY", "Plan: ${subscription.plan.vendorId}")
        Log.d("PLY", "Store: ${subscription.subscriptionSource}")
    }
}
```

## Synchronize

### `Purchasely.synchronize()`

Force a synchronization of the user's purchases with Purchasely servers.

```kotlin
Purchasely.synchronize()
```

## Events

### `Purchasely.setEventListener(listener)`

Set a listener to receive SDK events.

```kotlin
Purchasely.setEventListener { event ->
    Log.d("PLY", "Event: ${event.name}")
    // Forward to your analytics provider
}
```

## PLYPresentationAction

### v5 (Enum)

| Action | Description |
|--------|-------------|
| `PURCHASE` | User tapped a purchase button |
| `RESTORE` | User tapped the restore button |
| `LOGIN` | User tapped the login button |
| `CLOSE` | User tapped the close button |
| `NAVIGATE` | User tapped a custom navigation link |
| `OPEN_PRESENTATION` | User tapped a link to another presentation |
| `PROMO_CODE` | User tapped the promo code button |

### v6 (Sealed Class)

In v6, `PLYPresentationAction` becomes a sealed class with parameters on each variant:

| Action | v5 Name | v6 Class |
|--------|---------|----------|
| Purchase | `PURCHASE` | `PLYPresentationAction.Purchase` |
| Restore | `RESTORE` | `PLYPresentationAction.Restore` |
| Login | `LOGIN` | `PLYPresentationAction.Login` |
| Close | `CLOSE` | `PLYPresentationAction.Close` |
| Navigate | `NAVIGATE` | `PLYPresentationAction.Navigate` |
| Open Presentation | `OPEN_PRESENTATION` | `PLYPresentationAction.OpenPresentation` |
| Promo Code | `PROMO_CODE` | `PLYPresentationAction.PromoCode` |

## PLYPresentationType

| Type | Description |
|------|-------------|
| `NORMAL` | Standard presentation, ready to display |
| `FALLBACK` | Fallback presentation (network issue, original not found) |
| `DEACTIVATED` | Presentation has been deactivated in the dashboard -- do not display |
| `CLIENT` | Client-side presentation (use your own paywall with Purchasely data) |

## Additional v6 APIs

### `allowCampaigns`

Control whether the SDK displays campaigns (win-back, retention, etc.):

```kotlin
Purchasely.allowCampaigns = true  // enable campaign display
Purchasely.allowCampaigns = false // disable campaign display
```

### Custom Logging (v6)

In v6, custom loggers receive ALL messages. Use the `logcatEnabled` flag to control Logcat output:

```kotlin
Purchasely.Builder(applicationContext)
    .logLevel(LogLevel.DEBUG)
    .logcatEnabled(false) // disable Logcat, use custom logger only
    .build()
```
