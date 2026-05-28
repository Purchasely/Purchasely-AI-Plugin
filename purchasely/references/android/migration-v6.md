# Android SDK v5.x -> v6.0.0 Migration

This guide is Android-only. Do not apply it to iOS, React Native, Flutter, or Cordova until their v6 migrations are ready.

## Build And Dependency Changes

Pin every native Android Purchasely artifact to `6.0.0`:

```kotlin
implementation("io.purchasely:core:6.0.0")
implementation("io.purchasely:google-play:6.0.0")
implementation("io.purchasely:player:6.0.0") // optional video support
implementation("io.purchasely:presentation-compose:6.0.0") // optional Compose embedding
```

If `6.0.0` is only installed on the developer machine, add `mavenLocal()` in `dependencyResolutionManagement.repositories` before `google()` and `mavenCentral()`.

SDK v6 uses the modern Android toolchain: Gradle 9.x, AGP 9.x, Kotlin 2.2.x, JDK 11, minSdk 23, compileSdk 35.

With AGP 9, remove the explicit `org.jetbrains.kotlin.android` plugin; AGP provides Android Kotlin support directly. Keep specialized Kotlin plugins such as Compose or Serialization when the app uses them. Also remove `android { kotlinOptions { ... } }` once `kotlin-android` is gone.

Google Play Billing resolves to v8.3.0 through Purchasely Google Play. If the app directly uses BillingClient, update direct Billing dependencies to `com.android.billingclient:billing:8.3.0` and migrate `queryProductDetailsAsync` to read `queryResult.productDetailsList`.

## Initialization

Preferred for Kotlin projects:

```kotlin
Purchasely {
    context(application)
    apiKey(apiKey)
    stores(listOf(GoogleStore()))
    runningMode(PLYRunningMode.Full)
    allowDeeplink(true)
    allowCampaigns(true)
    onInitialized { error ->
        if (error == null) {
            // configured
        }
    }
}
```

Java projects, or Kotlin call sites that must stay fluent:

```kotlin
Purchasely.Builder(applicationContext)
    .apiKey(apiKey)
    .stores(listOf(GoogleStore()))
    .runningMode(PLYRunningMode.Full)
    .allowDeeplink(true)
    .allowCampaigns(true)
    .build()
    .start { error -> }
```

Changes that apply to both init paths:
- `PLYRunningMode.PaywallObserver` -> `PLYRunningMode.Observer`.
- Default running mode is now `Observer`; set `PLYRunningMode.Full` explicitly when Purchasely must validate purchases.
- `readyToOpenDeeplink(...)` -> `allowDeeplink(...)`.
- `Purchasely.readyToOpenDeeplink` -> `Purchasely.allowDeeplink`.
- `Purchasely.isDeeplinkHandled(uri, activity)` -> `Purchasely.handleDeeplink(uri, activity)`.
- Campaign display is controlled separately with `allowCampaigns`.

## Presentation API

Presentation types moved from `io.purchasely.ext` to `io.purchasely.ext.presentation`:

```kotlin
import io.purchasely.ext.presentation.PLYPresentation
import io.purchasely.ext.presentation.PLYPresentationAction
import io.purchasely.ext.presentation.PLYPresentationState
import io.purchasely.ext.presentation.PLYPresentationType
import io.purchasely.ext.presentation.PLYPurchaseResult
import io.purchasely.ext.presentation.preload
```

Replace `Purchasely.fetchPresentation(...)` and `PLYPresentationProperties` with the builder DSL:

```kotlin
val presentation = PLYPresentation {
    placementId("onboarding")
    screenId("screen_abc123")
    contentId("article_42")
    flowId("flow_abc123")
    backgroundColor(0xFF101820.toInt())
    progressColor(0xFFFFC857.toInt())
    displayCloseButton(true)
    displayBackButton(true)
    onPresented { loaded, error -> }
    onCloseRequested { }
    onDismissed { outcome -> }
}.preload()

when (presentation.type) {
    PLYPresentationType.DEACTIVATED -> Unit
    PLYPresentationType.CLIENT -> showClientScreen(presentation)
    else -> presentation.display(activity) { outcome ->
        when (outcome.purchaseResult) {
            PLYPurchaseResult.PURCHASED -> refreshAccess()
            PLYPurchaseResult.RESTORED -> refreshAccess()
            PLYPurchaseResult.CANCELLED, null -> Unit
        }
    }
}
```

Other Presentation changes:
- `PLYPresentation.id` -> `screenId`.
- `screenId` is the canonical Android public name; do not rename Android code to `presentationId`.
- `onClose` -> `onCloseRequested`.
- `display` callbacks now receive `PLYPresentationOutcome`.
- `PLYProductViewResult` is replaced by `PLYPurchaseResult` inside `outcome.purchaseResult`.
- `buildView(context, callback)` also receives `PLYPresentationOutcome`.
- `presentationView(...)` is removed. Use `PLYPresentation { ... }.preload { loaded, error -> loaded?.buildView(context) }`.

### Prepared display helper

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

`display(context) { outcome }` fires on final dismissal.

### Observable state

Every Builder/Prepared/Loaded Presentation exposes `state: StateFlow<PLYPresentationState>`:

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

### Embedded Compose

```kotlin
import io.purchasely.ext.presentation.compose.PLYPresentationView

PLYPresentationView(
    presentation = presentation,
    modifier = Modifier.fillMaxWidth(),
    callback = { outcome -> }
)
```

Without the optional Compose artifact, use `AndroidView { presentation.buildView(it) }` manually.

## Action Interceptor

The global `setPaywallActionsInterceptor` API was removed. Use typed interceptors:

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

Result mapping:
- Old `processAction(false)` meaning "app handled it" -> `PLYInterceptResult.SUCCESS`.
- Old `processAction(true)` meaning "let SDK continue" -> `PLYInterceptResult.NOT_HANDLED`.
- New failure path -> `PLYInterceptResult.FAILED`.

`PLYPresentationAction` is now a sealed class. Replace enum constants and `PLYPresentationActionParameters` with typed action data:

| v5 | v6 |
| --- | --- |
| `PLYPresentationAction.PURCHASE` + `parameters.plan` | `PLYPresentationAction.Purchase` + `action.plan` |
| `parameters.subscriptionOffer` | `action.subscriptionOffer` |
| `PLYPresentationAction.RESTORE` | `PLYPresentationAction.Restore` |
| `PLYPresentationAction.LOGIN` | `PLYPresentationAction.Login` |
| `PLYPresentationAction.NAVIGATE` + `parameters.url` | `PLYPresentationAction.Navigate` + `action.url` |

Call `Purchasely.removeAllActionInterceptors()` when tearing down or restarting the SDK.

## Observer-mode bridge: callback -> suspend

```kotlin
private var pendingResult: ((PLYInterceptResult) -> Unit)? = null

Purchasely.interceptAction<PLYPresentationAction.Purchase> { info, purchase ->
    if (!observerMode) return@interceptAction PLYInterceptResult.NOT_HANDLED
    awaitPendingResult { resolve ->
        pendingResult = resolve
        scope.launch {
            purchaseRequests.emit(
                PurchaseRequest(info?.activity, purchase.plan.store_product_id, purchase.subscriptionOffer?.offerToken)
            )
        }
    }
}

private suspend fun awaitPendingResult(
    register: ((PLYInterceptResult) -> Unit) -> Unit
): PLYInterceptResult = suspendCancellableCoroutine { continuation ->
    pendingResult?.invoke(PLYInterceptResult.NOT_HANDLED)
    val cb: (PLYInterceptResult) -> Unit = { if (continuation.isActive) continuation.resume(it) }
    register(cb)
    continuation.invokeOnCancellation { if (pendingResult === cb) pendingResult = null }
}
```

Resolve `pendingResult` with `SUCCESS`, `NOT_HANDLED`, or `FAILED` when the native billing flow returns. In `close()` / `restart()`, invoke any outstanding `pendingResult` with `NOT_HANDLED` before calling `Purchasely.removeAllActionInterceptors()`.

## User Attributes

User attribute mutation methods now return `Deferred<Boolean>`:

```kotlin
Purchasely.setUserAttribute("favorite_spirit", "gin")
val success = Purchasely.incrementUserAttribute("cocktails_viewed").await()
```

## Removed APIs

Remove or replace:
- `Purchasely.subscriptionsFragment()`.
- `Purchasely.purchaseHistory()` -> `Purchasely.userSubscriptionsHistory()`.
- `Purchasely.isPastSubscriber()` -> derive from `userSubscriptionsHistory()`.
- `PLYPresentationProperties`.
- `PLYPresentationActionParameters`.
- `PLYPresentationInfo` -> `PLYInterceptorInfo`.
- Intro/trial plan helpers and tags -> offer helpers and `OFFER_*` tags.

## Verification Checklist

Run after each phase:

```bash
./gradlew :app:assembleDebug
./gradlew :app:testDebugUnitTest
```

Search must return no v5-only API usages in app source/tests:

```bash
rg "readyToOpenDeeplink|isDeeplinkHandled|PLYPresentationProperties|PLYPresentationActionParameters|PLYPresentationInfo|PLYProductViewResult|fetchPresentation|presentationView" android/app/src
```

Legacy identifiers such as `setPaywallActionsInterceptor` and `PaywallObserver` may remain in migration notes only because those are the names being replaced.
