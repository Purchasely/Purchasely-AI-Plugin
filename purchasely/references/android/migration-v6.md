# Android SDK v5.x -> v6.0.0 Migration

This guide is Android-only. Do not apply it to iOS, React Native, Flutter, or Cordova until their v6 migrations are ready.

## Build And Dependency Changes

Pin every native Android Purchasely artifact to `6.0.0`:

```kotlin
implementation("io.purchasely:core:6.0.0")
implementation("io.purchasely:google-play:6.0.0")
implementation("io.purchasely:player:6.0.0") // optional video support
```

If `6.0.0` is only installed on the developer machine, add `mavenLocal()` in `dependencyResolutionManagement.repositories` before `google()` and `mavenCentral()`:

```kotlin
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        mavenLocal()
        google()
        mavenCentral()
    }
}
```

SDK v6 uses the modern Android toolchain. In the Shaker migration, AGP `9.2.1` required Gradle `9.4.1`. With AGP 9, remove the explicit `org.jetbrains.kotlin.android` plugin; AGP provides Android Kotlin support directly. Keep specialized Kotlin plugins such as Compose or Serialization when the app uses them.

Leaving `org.jetbrains.kotlin.android` applied alongside AGP 9 fails the build with `Cannot add extension with name 'kotlin', as there is an extension already registered with that name`. Remove the alias from both the root `build.gradle.kts` (`apply false`) and every module's `plugins { ... }` block, **and drop the alias entry from `libs.versions.toml`** if you use a version catalog.

When the explicit Kotlin plugin is removed, also drop the `android { kotlinOptions { jvmTarget = "..." } }` block — `kotlinOptions` is contributed by `kotlin-android` and is no longer resolvable. The JVM target inferred from `compileOptions.sourceCompatibility` is enough; override with `kotlin { jvmToolchain(11) }` only when you really need to force a different toolchain.

Google Play Billing resolves to v8.3.0 through Purchasely Google Play. If the app directly uses BillingClient, update direct Billing dependencies to `com.android.billingclient:billing:8.3.0` and migrate `queryProductDetailsAsync` to read `queryResult.productDetailsList`.

## Initialization

**Preferred for Kotlin projects — the new DSL entrypoint.** `Purchasely { ... }` configures **and** starts the SDK in a single call. There is no `.build()` or `.start(...)`. The init callback is registered inside the block with `onInitialized { error -> ... }`.

```kotlin
Purchasely {
    context(applicationContext)
    apiKey(apiKey)
    stores(listOf(GoogleStore()))
    runningMode(PLYRunningMode.Full)
    allowDeeplink(true)
    onInitialized { error ->
        if (error == null) {
            // configured
        } else {
            // handle error.message
        }
    }
}
```

`context(...)` and `apiKey(...)` are mandatory inside the block. The DSL is Kotlin-only.

**Java projects (or Kotlin call sites that must stay on the fluent Builder).** Keep the fluent `Purchasely.Builder(...).build().start { ... }` form. `start` now receives a single `PLYError?` parameter (the v5 `(Boolean, PLYError?)` signature is removed):

```kotlin
Purchasely.Builder(applicationContext)
    .apiKey(apiKey)
    .stores(listOf(GoogleStore()))
    .runningMode(PLYRunningMode.Full)
    .allowDeeplink(true)
    .build()
    .start { error ->
        if (error == null) {
            // configured
        } else {
            // handle error.message
        }
    }
```

Changes that apply to **both** init paths:
- `PLYRunningMode.PaywallObserver` -> `PLYRunningMode.Observer`.
- Default running mode is now `Observer`; set `PLYRunningMode.Full` explicitly when Purchasely must validate purchases and auto-close paywalls after purchase/restore.
- `readyToOpenDeeplink(...)` -> `allowDeeplink(...)`.
- `Purchasely.readyToOpenDeeplink` -> `Purchasely.allowDeeplink`.
- `Purchasely.isDeeplinkHandled(uri, activity)` -> `Purchasely.handleDeeplink(uri, activity)`.
- Campaign display is now controlled separately with `allowCampaigns`.

## Presentation API

Presentation types moved from `io.purchasely.ext` to `io.purchasely.ext.presentation`:

```kotlin
import io.purchasely.ext.presentation.PLYPresentation
import io.purchasely.ext.presentation.PLYPresentationAction
import io.purchasely.ext.presentation.PLYPresentationType
import io.purchasely.ext.presentation.PLYPurchaseResult
import io.purchasely.ext.presentation.preload
```

Replace `Purchasely.fetchPresentation(...)` and `PLYPresentationProperties` with the builder DSL:

```kotlin
val presentation = PLYPresentation {
    placementId("onboarding")
    contentId("article_42")
}.preload()

when (presentation.type) {
    PLYPresentationType.DEACTIVATED -> Unit
    PLYPresentationType.CLIENT -> showClientPaywall(presentation)
    else -> presentation.display(activity) { outcome ->
        when (outcome.purchaseResult) {
            PLYPurchaseResult.PURCHASED -> handlePurchase(outcome.plan)
            PLYPurchaseResult.RESTORED -> handleRestore(outcome.plan)
            PLYPurchaseResult.CANCELLED, null -> Unit
        }
    }
}
```

Other presentation changes:
- `PLYPresentation.id` -> `screenId`.
- `onClose` -> `onCloseRequested`.
- `display` callbacks now receive `PLYPresentationOutcome`.
- `PLYProductViewResult` is replaced by `PLYPurchaseResult` inside `outcome.purchaseResult`.
- `buildView(context, callback)` also receives `PLYPresentationOutcome`.
- `presentationView(...)` is removed. Use `PLYPresentation { ... }.preload { loaded, error -> loaded?.buildView(context) }`.

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
        val productId = action.plan?.store_product_id
        val offerToken = action.subscriptionOffer?.offerToken
        if (info.activity != null && productId != null && offerToken != null) {
            launchBilling(info.activity, productId, offerToken)
            PLYInterceptResult.SUCCESS
        } else {
            PLYInterceptResult.FAILED
        }
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

### Observer-mode bridge: callback → suspend

In v5 Observer mode, the host app received `processAction: (Boolean) -> Unit` and called it once the native StoreKit/Billing flow finished. In v6, the interceptor lambda is a **`suspend`** function returning `PLYInterceptResult`. Implement a small bridge so the interceptor suspends until the host purchase flow reports back:

```kotlin
private var pendingResult: ((PLYInterceptResult) -> Unit)? = null

Purchasely.interceptAction<PLYPresentationAction.Purchase> { info, purchase ->
    if (!observerMode) return@interceptAction PLYInterceptResult.NOT_HANDLED
    awaitPendingResult { resolve ->
        pendingResult = resolve
        scope.launch { purchaseRequests.emit(PurchaseRequest(info?.activity, purchase.plan.store_product_id, purchase.subscriptionOffer?.offerToken)) }
    }
}

private suspend fun awaitPendingResult(
    register: ((PLYInterceptResult) -> Unit) -> Unit
): PLYInterceptResult = suspendCancellableCoroutine { continuation ->
    pendingResult?.invoke(PLYInterceptResult.NOT_HANDLED) // cancel any previous wait
    val cb: (PLYInterceptResult) -> Unit = { if (continuation.isActive) continuation.resume(it) }
    register(cb)
    continuation.invokeOnCancellation { if (pendingResult === cb) pendingResult = null }
}

// When the native billing flow returns:
private fun handleTransactionResult(result: TransactionResult) = when (result) {
    is TransactionResult.Success   -> { pendingResult?.invoke(PLYInterceptResult.SUCCESS);     pendingResult = null }
    is TransactionResult.Cancelled -> { pendingResult?.invoke(PLYInterceptResult.NOT_HANDLED); pendingResult = null }
    is TransactionResult.Error     -> { pendingResult?.invoke(PLYInterceptResult.FAILED);      pendingResult = null }
    else -> Unit
}
```

In `close()` / `restart()`, invoke any outstanding `pendingResult` with `NOT_HANDLED` before calling `Purchasely.removeAllActionInterceptors()` so suspended coroutines don't leak.

## User Attributes

User attribute mutation methods now return `Deferred<Boolean>`:

```kotlin
Purchasely.setUserAttribute("favorite_spirit", "gin") // return value may be ignored
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
rg "PaywallObserver|readyToOpenDeeplink|isDeeplinkHandled|setPaywallActionsInterceptor|PLYPresentationProperties|PLYPresentationActionParameters|PLYPresentationInfo|PLYProductViewResult|fetchPresentation" android/app/src
```

Expected remaining warning from SDK 6.0.0 in some builds: Android resource formatting warnings in localized `ply_in_app_partial_restore_partial_with_errors` strings. These come from the SDK artifact, not app code.
