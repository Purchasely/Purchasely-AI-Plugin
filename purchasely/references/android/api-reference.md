# Android API Reference

This reference describes the native Android SDK v6 API. Use **Presentation** for SDK runtime objects, **Screen** for Console-authored content, and `screenId` for direct Screen lookup.

## Initialization

### Kotlin DSL

```kotlin
Purchasely {
    context(application)
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
```

### Fluent Builder

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

| Method | Description |
|--------|-------------|
| `context(context)` | Required in Kotlin DSL. |
| `apiKey(key)` | Required. |
| `stores(stores)` | Billing store implementations. |
| `runningMode(mode)` | `PLYRunningMode.Full` or `PLYRunningMode.Observer`; default is `Observer`. |
| `allowDeeplink(allowed)` | Enables deeplink-driven display when the app UI is ready. |
| `allowCampaigns(allowed)` | Enables or defers campaign display. |
| `onInitialized { error -> }` | Kotlin DSL initialization callback. |
| `start { error -> }` | Builder initialization callback. |

## Presentation Builder

```kotlin
import io.purchasely.ext.presentation.PLYPresentation
import io.purchasely.ext.presentation.preload

val prepared = PLYPresentation {
    placementId("onboarding")
    screenId("screen_abc123")
    contentId("article_42")
    flowId("flow_abc123")
    backgroundColor(0xFF101820.toInt())
    progressColor(0xFFFFC857.toInt())
    displayCloseButton(true)
    displayBackButton(true)
    onPresented { presentation, error -> }
    onCloseRequested { }
    onDismissed { outcome -> }
}

val presentation = prepared.preload()
```

`screenId` is the canonical Android public name. Do not use `presentationId` in Android code samples.

### Display

```kotlin
presentation.display(activity) { outcome ->
    if (outcome.error != null) return@display
    when (outcome.purchaseResult) {
        PLYPurchaseResult.PURCHASED -> refreshAccess()
        PLYPurchaseResult.RESTORED -> refreshAccess()
        PLYPurchaseResult.CANCELLED, null -> Unit
    }
}
```

The `display` callback fires on final dismissal.

### Prepared display

```kotlin
PLYPresentation { placementId("onboarding") }.display(
    context = activity,
    presentation = { loaded ->
        // Loaded and display triggered.
    },
    callback = { outcome ->
        // Final dismissal.
    }
)
```

### Types

| Typealias | Meaning |
|-----------|---------|
| `PLYPresentationBuilder` | Mutable builder. |
| `PLYPresentationPrepared` | Built request intent. |
| `PLYPresentation` | Loaded runtime presentation. |

### `PLYPresentation` fields

| Field | Type |
|-------|------|
| `screenId` | `String?` |
| `placementId` | `String?` |
| `contentId` | `String?` |
| `flowId` | `String?` |
| `language` | `String?` |
| `type` | `PLYPresentationType` |
| `plans` | `List<PLYPresentationPlan>` |
| `metadata` | `PLYPresentationMetadata?` |
| `backgroundColor` | `String?` |
| `height` | `Int` |
| `displayMode` | `PLYTransition?` |
| `connections` | `List<PLYConnection>` |
| `state` | `StateFlow<PLYPresentationState>` |

### `PLYPresentationState`

```kotlin
prepared.state.collect { state ->
    when (state) {
        PLYPresentationState.Idle -> Unit
        PLYPresentationState.Loading -> showLoading()
        PLYPresentationState.Loaded -> hideLoading()
        PLYPresentationState.Displayed -> Unit
        is PLYPresentationState.Error -> showError(state.error)
    }
}
```

## Embedded Presentations

### View

```kotlin
val view = presentation.buildView(context) { outcome -> }
container.addView(view)
```

### Fragment

```kotlin
val fragment = presentation.getFragment { outcome -> }
```

### Compose

```kotlin
implementation("io.purchasely:presentation-compose:6.0.0")
```

```kotlin
import io.purchasely.ext.presentation.compose.PLYPresentationView

PLYPresentationView(
    presentation = presentation,
    modifier = Modifier.fillMaxWidth(),
    callback = { outcome -> }
)
```

## Action Interceptor

```kotlin
import io.purchasely.ext.PLYInterceptResult
import io.purchasely.ext.interceptAction
import io.purchasely.ext.presentation.PLYPresentationAction

Purchasely.interceptAction<PLYPresentationAction.Login> { _, _ ->
    showLogin()
    PLYInterceptResult.SUCCESS
}

Purchasely.interceptAction<PLYPresentationAction.Purchase> { info, action ->
    if (observerMode) {
        launchBilling(info?.activity, action.plan.store_product_id, action.subscriptionOffer?.offerToken)
        PLYInterceptResult.SUCCESS
    } else {
        PLYInterceptResult.NOT_HANDLED
    }
}
```

| Result | Meaning |
|--------|---------|
| `SUCCESS` | App handled the action. |
| `FAILED` | App tried and failed. |
| `NOT_HANDLED` | SDK should continue. |

`PLYPresentationAction` is a sealed class with typed payloads: `Purchase`, `Restore`, `Login`, `Navigate`, `Close`, `CloseAll`, `OpenPresentation`, `OpenPlacement`, `PromoCode`, and `WebCheckout`.

## Deeplinks and Campaigns

```kotlin
Purchasely.allowDeeplink = true
Purchasely.allowCampaigns = true
Purchasely.handleDeeplink(uri, activity)
```

## User Management

```kotlin
Purchasely.userLogin("user_123") { shouldRefresh -> shouldRefresh }
Purchasely.userLogout()
```

## User Attributes

```kotlin
Purchasely.setUserAttribute("favorite_spirit", "gin")
val success = Purchasely.incrementUserAttribute("cocktails_viewed").await()
```

## Subscriptions

```kotlin
Purchasely.userSubscriptions(false, object : SubscriptionsListener {
    override fun onSuccess(subscriptions: List<PLYSubscriptionData>) {}
    override fun onFailure(error: Throwable) {}
})
```

## Close Screens

```kotlin
Purchasely.closeAllScreens()
presentation.close()
presentation.back()
```

## Synchronize

```kotlin
Purchasely.synchronize()
```

Android `synchronize()` is fire-and-forget.
