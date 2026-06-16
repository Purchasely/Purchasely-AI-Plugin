# Android SDK v5.x -> v6.0.0-rc.1 Migration

This guide is Android-only. Do not apply it to iOS, React Native, Flutter, or Cordova until their v6 migrations are ready.

To recognize legacy v5 code in a project before rewriting it, see [v5-api-reference.md](v5-api-reference.md) — a compact snapshot of the v5 public API with a `-> v6` pointer for each entry.

## Build And Dependency Changes

Pin every native Android Purchasely artifact to `6.0.0-rc.1`:

```kotlin
implementation("io.purchasely:core:6.0.0-rc.1")
implementation("io.purchasely:google-play:6.0.0-rc.1")      // Google Play
implementation("io.purchasely:player:6.0.0-rc.1")           // optional video support
// alternative stores (only if used):
implementation("io.purchasely:huawei-services:6.0.0-rc.1")  // Huawei AppGallery
implementation("io.purchasely:amazon:6.0.0-rc.1")           // Amazon Appstore
```

There is **no** `presentation-compose` artifact. For Compose embedding, wrap the Android `View` from `buildView(...)` in an `AndroidView`.

If `6.0.0-rc.1` is only installed on the developer machine, add `mavenLocal()` in `dependencyResolutionManagement.repositories` before `google()` and `mavenCentral()`.

SDK v6 uses the modern Android toolchain: Gradle 9.3.0+, AGP 9.x, Kotlin 2.2.x (K2 compiler), JDK 17 to build, minSdk 23, compileSdk 36.

The reified entry points `interceptAction<T> { … }` / `removeActionInterceptor<T>()` are `inline` functions targeting JVM 11. Compile your Kotlin module with `jvmTarget = 11`, or use the `Class`-based overload.

With AGP 9, remove the explicit `org.jetbrains.kotlin.android` plugin; AGP provides Android Kotlin support directly. Keep specialized Kotlin plugins such as Compose or Serialization when the app uses them. Also remove `android { kotlinOptions { ... } }` once `kotlin-android` is gone.

Google Play Billing resolves to v8.3.0 through Purchasely Google Play. If the app directly uses BillingClient, update direct Billing dependencies to `com.android.billingclient:billing:8.3.0` and migrate `queryProductDetailsAsync` to read `queryResult.productDetailsList`.

## Initialization

> **⚠️ The default running mode changed from `Full` (v5) to `Observer` (v6).** This is silent — your code keeps compiling, but the SDK stops validating purchases. If your app relies on Purchasely to process and validate purchases, set `runningMode(PLYRunningMode.Full)` explicitly.
>
> **Behavioral consequence — no auto-close.** In Observer mode, presentations **no longer auto-close** after a purchase or restore. In v5, the implicit `Full` default auto-appended a `close_all` action after `purchase` / `restore`. If your app relied on auto-close, set `runningMode(PLYRunningMode.Full)`, or close the presentation yourself in the outcome callback.
>
> When `Full` is not set, the SDK logs a DEBUG message at `build()` time.

```kotlin
// V5 — running mode was implicitly Full (auto-closed after purchase)
Purchasely.Builder(this).apiKey(apiKey).stores(listOf(GoogleStore())).build().start()

// V6 default is Observer — stays open after purchase, no validation
Purchasely { context(application); apiKey(apiKey); stores(listOf(GoogleStore())) }

// V6 — same behavior as v5 (validation + auto-close)
Purchasely { context(application); apiKey(apiKey); stores(listOf(GoogleStore())); runningMode(PLYRunningMode.Full) }
```

Preferred for Kotlin projects:

```kotlin
Purchasely {
    context(application)
    apiKey(apiKey)
    stores(listOf(GoogleStore()))
    runningMode(PLYRunningMode.Full)  // default is Observer
    logLevel(LogLevel.DEBUG)
    logcatEnabled(true)               // optional, independent of logLevel
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
    .logLevel(LogLevel.DEBUG)
    .logcatEnabled(true)
    .allowDeeplink(true)
    .allowCampaigns(true)
    .handleDeeplink(intent.data)      // optional cold-start deeplink
    .build()
    .start { error -> }
```

Changes that apply to both init paths:
- `PLYRunningMode.PaywallObserver` -> `PLYRunningMode.Observer`.
- Default running mode is now `Observer`; set `PLYRunningMode.Full` explicitly when Purchasely must validate purchases.
- `start { isConfigured, error -> }` -> `start { error -> }` (single nullable `PLYError`).
- `readyToOpenDeeplink(...)` -> `allowDeeplink(...)` (now defaults to `true`).
- `Purchasely.readyToOpenDeeplink` -> `Purchasely.allowDeeplink`.
- `Purchasely.isDeeplinkHandled(uri, activity)` -> `Purchasely.handleDeeplink(uri, activity)`.
- Campaign display is controlled separately with `allowCampaigns`.

### apiKey validation

The SDK validates `apiKey` at `start()`. When null/blank, the callback fires with `PLYError.Configuration` ("API key not set") and the SDK stays inert (no crash). Ensure a dynamically sourced key is non-blank before `start()`.

### Storeless start

Starting without any store is a first-class path: screens, analytics, campaigns, deeplinks and user attributes all work. In Full mode, purchase APIs return `PLYError.NoStoreConfigured` when no store is configured.

> If you previously caught `PLYError.Unknown` with message `"No store found"`, switch to matching `PLYError.NoStoreConfigured`.

### Logging

- Custom loggers now receive **all** log messages regardless of `logLevel`.
- New flag `Purchasely.logcatEnabled` controls Logcat output independently; set it at init with `.logcatEnabled(false)`.

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
    placementId("onboarding")          // required unless screenId is set
    screenId("screen_abc123")          // optional, direct Screen lookup
    contentId("article_42")            // optional
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

> `flowId`, `productId` and `planId` are **no longer** exposed on the public builder. Remove any `flowId(...)` / `productId(...)` / `planId(...)` builder calls. To display a Flow, use its deeplink `app_scheme://ply/flows/FLOW_ID`. `flowId` remains read-only on the loaded `PLYPresentation`.

Other Presentation changes:
- `PLYPresentation.id` -> `screenId`. `toMap()["id"]` -> `toMap()["screenId"]`.
- `screenId` is the canonical Android public name; do not rename Android code to `presentationId`.
- `onClose` -> `onCloseRequested` (fires on close *request*; the dismissal outcome arrives via `onDismissed` / the `display` result / `PLYPresentationState.Dismissed`).
- `display` callbacks now receive `PLYPresentationOutcome`.
- `PLYProductViewResult` is replaced by `PLYPurchaseResult` inside `outcome.purchaseResult`.
- `buildView(context, callback)` also receives `PLYPresentationOutcome`.
- `presentationView(...)` is removed. Use `PLYPresentation { ... }.preload { loaded, error -> loaded?.buildView(context) }`.

### `PLYPresentationOutcome` structure

```kotlin
data class PLYPresentationOutcome(
    val presentation: PLYPresentation?,
    val purchaseResult: PLYPurchaseResult?,   // PURCHASED / RESTORED / CANCELLED / null
    val plan: PLYPlan?,
    val closeReason: PLYCloseReason? = null,
    val error: PLYError? = null,
)
```

### `display()` is non-suspend and returns a session

`display(context)` / `display(context, transition)` are **non-suspend** (Java-callable). Each overload returns a `PLYPresentationSession` you can `await()`:

```kotlin
lifecycleScope.launch {
    try {
        val outcome = presentation.display(activity).await()
        // react to outcome.purchaseResult / outcome.plan / outcome.closeReason
    } catch (e: PLYError) {
        // failed to launch or render
    }
}
```

### Preload early, display later (no extra network call)

```kotlin
var loaded: PLYPresentation? = null

lifecycleScope.launch {
    loaded = PLYPresentation { placementId("onboarding") }.preload()
}

button.setOnClickListener { loaded?.display(context) }
```

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
        is PLYPresentationState.Dismissed -> handle(state.outcome)
        is PLYPresentationState.Error -> showError(state.error)
    }
}
```

### Embedded Compose

There is **no** `presentation-compose` artifact and **no** `PLYPresentationView` composable. `buildView(...)` returns a `PLYPresentationView?` (an Android `View`). Wrap it in an `AndroidView`:

```kotlin
AndroidView(factory = { context ->
    loaded.buildView(context) { outcome -> } ?: FrameLayout(context)
})
```

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

Java callers cannot use the reified `interceptAction<T>`. Use the `Class`-based overload, cast the action, and resolve with `result.invoke(...)`:

```java
Purchasely.interceptAction(PLYPresentationAction.Purchase.class, (info, action, result) -> {
    PLYPresentationAction.Purchase purchase = (PLYPresentationAction.Purchase) action;
    // use purchase.getPlan(), purchase.getSubscriptionOffer(), purchase.getOffer()
    result.invoke(PLYInterceptResult.NOT_HANDLED);
});
```

Java callers must use the concrete nested type names (`PLYPresentationBase.Loaded`, `PLYPresentationBase.Builder`, `PLYPresentationBase.Prepared`) — the Kotlin typealiases (`PLYPresentation`, …) are not visible in Java.

Result mapping:
- Old `processAction(false)` meaning "app handled it" -> `PLYInterceptResult.SUCCESS`.
- Old `processAction(true)` meaning "let SDK continue" -> `PLYInterceptResult.NOT_HANDLED`.
- New failure path -> `PLYInterceptResult.FAILED`.

`PLYPresentationAction` is now a sealed class. Replace enum constants and `PLYPresentationActionParameters` with typed action data:

| v5 (enum) | v6 (sealed) | Parameters |
| --- | --- | --- |
| `PLYPresentationAction.PURCHASE` | `PLYPresentationAction.Purchase` | `plan`, `subscriptionOffer`, `offer` |
| `PLYPresentationAction.RESTORE` | `PLYPresentationAction.Restore` | — |
| `PLYPresentationAction.LOGIN` | `PLYPresentationAction.Login` | — |
| `PLYPresentationAction.CLOSE` | `PLYPresentationAction.Close` | `closeReason` |
| `PLYPresentationAction.CLOSE_ALL` | `PLYPresentationAction.CloseAll` | `closeReason` |
| `PLYPresentationAction.NAVIGATE` | `PLYPresentationAction.Navigate` | `url`, `title` |
| `PLYPresentationAction.OPEN_PRESENTATION` | `PLYPresentationAction.OpenPresentation` | `presentationId` |
| `PLYPresentationAction.OPEN_PLACEMENT` | `PLYPresentationAction.OpenPlacement` | `placementId` |
| `PLYPresentationAction.PROMO_CODE` | `PLYPresentationAction.PromoCode` | — |
| `PLYPresentationAction.WEB_CHECKOUT` | `PLYPresentationAction.WebCheckout` | `url`, `clientReferenceId`, … |

Parameters that were on `PLYPresentationActionParameters` are now fields on each action subclass (e.g. `purchase.plan`, `purchase.subscriptionOffer`, `purchase.offer`).

Remove interceptors by type or all at once:

```kotlin
Purchasely.removeActionInterceptor<PLYPresentationAction.Purchase>() // Kotlin, typed
Purchasely.removeAllActionInterceptors()
```

```java
Purchasely.removeActionInterceptor(PLYPresentationAction.Purchase.class); // Java
Purchasely.removeAllActionInterceptors();
```

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

## Deeplinks

| v5 | v6 |
| --- | --- |
| `isDeeplinkHandled(uri, activity)` | `handleDeeplink(uri, activity)` |
| `readyToOpenDeeplink` | `allowDeeplink` (now defaults to `true`) |
| `Builder().readyToOpenDeeplink(...)` | `Builder().allowDeeplink(...)` |

**Automatic interception (zero code).** The SDK reads the foreground activity's intent on create and resume and routes its own URIs to the deeplink handler. You no longer need to call `handleDeeplink(uri)` yourself — existing manual calls keep working and are deduped. Opt out with `.automaticDeeplinkHandling(false)`.

```kotlin
// V5 — manual call required
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    Purchasely.handleDeeplink(intent.data) // ← no longer needed in v6
}
```

**Cold start.** Pass the launch deeplink to the builder: `.handleDeeplink(intent.data)`.

> **Pitfall — `singleTask` / `singleTop` activities.** When the deeplink arrives in `onNewIntent` and you do not call `setIntent(intent)`, the URI is hidden from auto-interception. Call `setIntent(intent)` or keep the manual `handleDeeplink` call:
>
> ```kotlin
> override fun onNewIntent(intent: Intent) {
>     super.onNewIntent(intent)
>     setIntent(intent) // required for auto-interception
> }
> ```

`allowDeeplink` defaults to `true` in v6 (was `false`). Preview deeplinks (`?preview=1`) always display, bypassing the flag. `allowDeeplink` and `allowCampaigns` are independent (default `true`):

```kotlin
Purchasely.allowDeeplink = true     // deeplink presentations
Purchasely.allowCampaigns = false   // campaigns stay queued (e.g. during onboarding)
Purchasely.allowCampaigns = true    // queued campaigns display immediately
```

## synchronize() now accepts callbacks (Observer mode)

`Purchasely.synchronize()` — called after a purchase completes in your own billing flow — gains optional callbacks and refreshes the subscriptions cache before firing `onSuccess`. Both default to `null`, so existing fire-and-forget calls keep working.

```kotlin
// Fire-and-forget (still valid)
Purchasely.synchronize()

// With callbacks (new in v6)
Purchasely.synchronize(
    onSuccess = { plan -> /* plan is the validated PLYPlan or null; refresh UI */ },
    onError = { error -> /* surface failure */ }
)
```

## User Attributes

User attribute mutation methods now return `Deferred<Boolean>`:

```kotlin
Purchasely.setUserAttribute("favorite_spirit", "gin")
val success = Purchasely.incrementUserAttribute("cocktails_viewed").await()
```

Affected: `setUserAttribute(s)`, `clearUserAttribute(s)`, `incrementUserAttribute`, `decrementUserAttribute`. The internal `PLYUserAttributeManager` was removed (managed by `PLYUserDataStorage`).

## Removed APIs

Remove or replace:
- `Purchasely.setPaywallActionsInterceptor(...)` -> per-action `interceptAction<T>` / `interceptAction(Class, …)`.
- `PLYPresentationInfo` -> `PLYInterceptorInfo`.
- `PLYPresentationActionParameters` -> parameters on each action subclass.
- `PLYPaywallActionHandler`, `PLYCompletionHandler`, `PLYPaywallActionListener`, `PLYProcessActionListener`.
- `Purchasely.fetchPresentation(...)` -> `PLYPresentation { … }.preload()`.
- `Purchasely.presentationView(...)` -> `loaded.buildView(context) { outcome -> }`.
- `PLYPresentationProperties`.
- `PLYProductViewResult` -> `PLYPurchaseResult` (inside `PLYPresentationOutcome`).
- `Purchasely.purchaseHistory()` -> `Purchasely.userSubscriptionsHistory()` (suspend, backend).
- `Purchasely.isPastSubscriber()` -> derive from `userSubscriptionsHistory()`.

### Subscription list & cancellation survey UI removed

`Purchasely.subscriptionsFragment()`, all `PLYSubscriptions*` / `PLYSubscriptionDetail*` / `PLYSubscriptionCancellation*` fragments/views, the deeplinks `ply/subscriptions` and `ply/cancellation_survey[/PRODUCT_VENDOR_ID]`, and their `PLYEvent` subclasses (`SubscriptionListViewed`, `SubscriptionDetailsViewed`, `SubscriptionPlanTapped`, `SubscriptionCancelTapped`, `CancellationReasonPublished`) were removed. Build your own UI from `Purchasely.userSubscriptions { … }` / `Purchasely.userSubscriptionsHistory { … }`.

### Plan offers — `intro*` / `INTRO_*` / `TRIAL_*` removed

All `intro*` / `introductory*` methods and `INTRO_*` / `TRIAL_*` tags were removed in favor of unified `offer*` / `OFFER_*` equivalents (direct renames, identical behavior):

| Removed (v5) | Replacement (v6) |
| --- | --- |
| `hasIntroductoryPrice()` | `hasOfferPrice()` |
| `isEligibleToIntroOffer()` | `isEligibleToOffer()` |
| `localizedIntroductoryPrice()` | `localizedOfferPrice()` |
| `PLYPlanTags.INTRO_PRICE` / `PLYPlanTags.TRIAL_PRICE` | `PLYPlanTags.OFFER_PRICE` |

## Verification Checklist

Mechanical, in order:

1. **Dependencies** pinned to `6.0.0-rc.1`; no `presentation-compose` artifact; alt-store artifacts use `huawei-services` / `amazon`.
2. **Toolchain**: Gradle 9.3.0+, AGP 9.x, Kotlin 2.2.x, JDK 17 to build, `minSdk 23`, `compileSdk 36`; `org.jetbrains.kotlin.android` plugin and `kotlinOptions {}` removed under AGP 9; Kotlin module on `jvmTarget = 11` (or interceptors use the `Class`-based overload).
3. **Init**: `runningMode(PLYRunningMode.Full)` set if the app needs purchase validation / auto-close; `PaywallObserver` -> `Observer`; init callback is `start { error -> }`.
4. **Imports** moved to `io.purchasely.ext.presentation.*`.
5. **Builder** has no `flowId(...)` / `productId(...)` / `planId(...)`; Flows shown via `app_scheme://ply/flows/FLOW_ID`.
6. **Interceptor**: `setPaywallActionsInterceptor` replaced by typed `interceptAction` (Kotlin reified or Java `Class`-based); `PLYPresentationAction` enum constants -> sealed subclasses; `PLYPresentationInfo` -> `PLYInterceptorInfo`.
7. **Outcome**: callbacks read `PLYPresentationOutcome`; `PLYProductViewResult` -> `PLYPurchaseResult`; StateFlow handles `is PLYPresentationState.Dismissed`.
8. **Deeplinks**: redundant `handleDeeplink(intent.data)` removed (auto-intercepted) unless on `singleTask`/`singleTop` without `setIntent(intent)`.
9. **Offers**: `intro*` / `INTRO_*` / `TRIAL_*` -> `offer*` / `OFFER_*`.
10. **Removed UI**: `subscriptionsFragment()`, `purchaseHistory()`, `isPastSubscriber()` replaced.

Build and test:

```bash
./gradlew :app:assembleDebug
./gradlew :app:testDebugUnitTest
```

Search must return no v5-only API usages in app source/tests:

```bash
rg "readyToOpenDeeplink|isDeeplinkHandled|PLYPresentationProperties|PLYPresentationActionParameters|PLYPresentationInfo|PLYProductViewResult|fetchPresentation|presentationView|setPaywallActionsInterceptor|PaywallObserver|presentation-compose|PLYPresentationView|subscriptionsFragment|purchaseHistory|isPastSubscriber|hasIntroductoryPrice|isEligibleToIntroOffer|localizedIntroductoryPrice|INTRO_PRICE|TRIAL_PRICE" android/app/src
```

Also confirm the builder DSL contains no `flowId(`, `productId(`, or `planId(` calls. Legacy identifiers such as `setPaywallActionsInterceptor` and `PaywallObserver` may remain in migration notes only because those are the names being replaced.

Then manually verify:

1. The init callback receives `null` error.
2. A placement-based presentation displays; a direct `screenId` presentation displays.
3. `onPresented`, `onCloseRequested` and the final `display` / `onDismissed` outcome fire in the expected order.
4. In Observer mode, purchase and restore paths resolve `PLYInterceptResult` exactly once.
5. In Full mode, purchases validate and screens auto-close after purchase.
