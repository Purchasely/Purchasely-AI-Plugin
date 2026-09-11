# Android API Reference

This reference describes the native Android SDK v6 API (Kotlin & Java). Use **Presentation** for SDK runtime objects, **Screen** for Console-authored content, and `screenId` for direct Screen lookup.

## Imports

Presentation types moved from `io.purchasely.ext.*` to `io.purchasely.ext.presentation.*` in v6.

```kotlin
import io.purchasely.ext.Purchasely
import io.purchasely.ext.PLYRunningMode
import io.purchasely.ext.LogLevel
import io.purchasely.ext.PLYError
import io.purchasely.ext.PLYInterceptResult

import io.purchasely.ext.presentation.PLYPresentation
import io.purchasely.ext.presentation.PLYPresentationAction
import io.purchasely.ext.presentation.PLYPresentationState
import io.purchasely.ext.presentation.PLYPresentationType
import io.purchasely.ext.presentation.PLYPresentationOutcome
import io.purchasely.ext.presentation.PLYPurchaseResult
import io.purchasely.ext.presentation.preload
import io.purchasely.ext.presentation.display
import io.purchasely.ext.presentation.buildView
import io.purchasely.ext.presentation.getFragment
// or simply: import io.purchasely.ext.presentation.*

import io.purchasely.views.presentation.PLYThemeMode
```

## Initialization

### Kotlin DSL (recommended)

```kotlin
Purchasely {
    context(application)
    apiKey("YOUR_API_KEY")
    userId("user-123")                 // optional
    stores(listOf(GoogleStore()))
    runningMode(PLYRunningMode.Full)    // default is Observer — set Full for purchase handling/validation
    themeMode(PLYThemeMode.SYSTEM)       // optional, since 6.0.1 — SYSTEM/LIGHT/DARK (parity with iOS)
    logLevel(LogLevel.DEBUG)
    logcatEnabled(true)                 // optional, controls Logcat output independently
    allowDeeplink(true)
    allowCampaigns(true)
    onInitialized { error ->
        if (error == null) {
            // SDK ready
        }
    }
}
```

### Fluent Builder (Java + Kotlin)

```kotlin
Purchasely.Builder(applicationContext)
    .apiKey("YOUR_API_KEY")
    .userId("user-123")
    .stores(listOf(GoogleStore()))
    .runningMode(PLYRunningMode.Full)
    .themeMode(PLYThemeMode.SYSTEM)     // optional, since 6.0.1 — SYSTEM/LIGHT/DARK (parity with iOS)
    .logLevel(LogLevel.DEBUG)
    .logcatEnabled(true)
    .allowDeeplink(true)
    .allowCampaigns(true)
    .handleDeeplink(intent.data)        // optional cold-start deeplink
    .build()
    .start { error ->
        if (error == null) {
            // SDK ready
        }
    }
```

| Method | Description |
|--------|-------------|
| `context(context)` | Required in Kotlin DSL (the fluent Builder takes it as the constructor argument). |
| `apiKey(key)` | Required. Validated at `start()`; null/blank fires the callback with `PLYError.Configuration` and the SDK stays inert. |
| `userId(id)` | Optional anonymous-to-known mapping. |
| `stores(stores)` | Billing store implementations (e.g. `GoogleStore()`). Optional — storeless start is supported. |
| `runningMode(mode)` | `PLYRunningMode.Full` or `PLYRunningMode.Observer`. **Default is `Observer`.** |
| `themeMode(mode)` | Since `6.0.1`, settable on **both** the DSL and the fluent Builder (parity with iOS `themeMode(_:)`). `mode` is a `PLYThemeMode` (`SYSTEM` / `LIGHT` / `DARK`); default `SYSTEM`. |
| `logLevel(level)` | `LogLevel.DEBUG` / `WARN` / `ERROR` / … |
| `logcatEnabled(enabled)` | Controls Logcat output independently of `logLevel` (default `true`). |
| `allowDeeplink(allowed)` | Enables deeplink-driven display. Default `true` in v6 (was `false`). |
| `allowCampaigns(allowed)` | Enables or defers campaign display. Default `true`. |
| `handleDeeplink(uri)` | Optional cold-start deeplink to route at initialization. |
| `onInitialized { error -> }` | Kotlin DSL initialization callback (single nullable `PLYError`). |
| `start { error -> }` | Builder initialization callback (single nullable `PLYError`). |

The init callback signature is `{ error -> }` (single nullable `PLYError`) — the v5 `{ isConfigured, error -> }` two-argument form was removed.

> **Default running mode is `Observer`.** In v5 it was `Full`. If your app relies on Purchasely to process and validate purchases, set `runningMode(PLYRunningMode.Full)` explicitly. When Full is not set, the SDK logs a DEBUG message at `build()` time. In Observer mode, presentations also no longer auto-close after a purchase/restore.

### Storeless start

Starting without any store is a first-class path: screens, analytics, campaigns, deeplinks and user attributes all work. In Full mode, purchase APIs return `PLYError.NoStoreConfigured` when no store is configured (was `PLYError.Unknown` with message `"No store found"` in v5).

## Presentation Builder

The sealed base is `PLYPresentationBase`. Kotlin typealiases keep most call sites compiling. Java callers use the concrete nested names (`PLYPresentationBase.Loaded`, `PLYPresentationBase.Builder`, `PLYPresentationBase.Prepared`).

```kotlin
import io.purchasely.ext.presentation.PLYPresentation
import io.purchasely.ext.presentation.preload

val prepared = PLYPresentation {
    placementId("onboarding")          // required unless screenId is set
    screenId("screen_abc123")          // optional, direct Screen lookup
    contentId("article_42")            // optional
    backgroundColor(0xFF101820.toInt()) // optional runtime color override
    progressColor(0xFFFFC857.toInt())   // optional runtime color override
    displayCloseButton(true)            // optional Android UI flag
    displayBackButton(true)             // optional Android UI flag
    onPresented { loaded, error -> }
    onCloseRequested { }
    onDismissed { outcome -> }
}

val presentation = prepared.preload()
```

> `flowId`, `productId` and `planId` are **not** exposed on the public builder. To display a Flow, use its deeplink `app_scheme://ply/flows/FLOW_ID`. `flowId` remains read-only on the loaded `PLYPresentation`.

`screenId` is the canonical Android public name. Do not use `presentationId` in Android code samples.

### Display

`display(context)` / `display(context, transition)` are **non-suspend** (Java-callable, also callable inside a coroutine). Each overload returns a `PLYPresentationSession` you can `await()`.

Callback form:

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

Session / `await()` form (coroutine):

```kotlin
lifecycleScope.launch {
    try {
        val outcome: PLYPresentationOutcome = presentation.display(activity).await()
        // react to outcome.purchaseResult / outcome.plan / outcome.closeReason
    } catch (e: PLYError) {
        // the presentation failed to launch or render
    }
}
```

### Prepared display (atomic fetch-and-display)

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

### Preload early, display later (no extra network call)

```kotlin
var loaded: PLYPresentation? = null

lifecycleScope.launch {
    loaded = PLYPresentation { placementId("onboarding") }.preload()
}

button.setOnClickListener { loaded?.display(this) }
```

### Types

| Typealias (Kotlin) | Underlying type (Java) | Meaning |
|--------------------|------------------------|---------|
| `PLYPresentationBuilder` | `PLYPresentationBase.Builder` | Mutable builder. |
| `PLYPresentationPrepared` | `PLYPresentationBase.Prepared` | Built request intent. |
| `PLYPresentation` | `PLYPresentationBase.Loaded` | Loaded runtime presentation. |

### `PLYPresentation` fields

| Field | Type |
|-------|------|
| `screenId` | `String?` (was `id`) |
| `placementId` | `String?` |
| `contentId` | `String?` |
| `flowId` | `String?` (read-only output) |
| `language` | `String?` |
| `type` | `PLYPresentationType` |
| `plans` | `List<PLYPresentationPlan>` |
| `metadata` | `PLYPresentationMetadata?` |
| `backgroundColor` | `String?` |
| `height` | `Int` |
| `displayMode` | `PLYTransition?` |
| `connections` | `List<PLYConnection>` |
| `state` | `StateFlow<PLYPresentationState>` |

`PLYPresentation.id` was renamed `screenId`; `toMap()["id"]` is now `toMap()["screenId"]`.

### `PLYTransition` sizing — `heightPercentage` → `height`

The old `heightPercentage: Float` field is **removed** (no alias). Sizing is now a structured `PLYTransitionDimension(type: PLYDimensionType, value: Float)`, supporting pixels **or** a percentage:

```kotlin
val drawerHeight = PLYTransitionDimension(PLYDimensionType.PERCENTAGE, 0.6f)  // 60% of screen height
val popinHeight = PLYTransitionDimension(PLYDimensionType.PIXEL, 480f)        // fixed 480px
```

### `PLYPresentationState`

Builder / prepared / loaded all expose `state: StateFlow<PLYPresentationState>`:

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

`onClose` was renamed `onCloseRequested` (fires when the user requests a close, e.g. taps the X). The actual dismissal with the outcome is delivered by `onDismissed` / the `display()` dismiss callback / `PLYPresentationState.Dismissed`.

### `PLYPresentationOutcome`

Display / dismissal callbacks receive one `PLYPresentationOutcome` (no separate `PLYError` parameter):

```kotlin
data class PLYPresentationOutcome(
    val presentation: PLYPresentation?,
    val purchaseResult: PLYPurchaseResult?,   // PURCHASED / RESTORED / CANCELLED / null
    val plan: PLYPlan?,
    val closeReason: PLYCloseReason? = null,
    val error: PLYError? = null,
)
```

`PLYProductViewResult` is deprecated — use `PLYPurchaseResult`. The `PLYPresentationResultHandler` typealias was renamed `PLYPresentationOutcomeHandler` (carries a single outcome).

## Embedded Presentations

### View

`buildView(context) { outcome -> }` returns a `PLYPresentationView?` — an Android `View` (not a Compose composable).

```kotlin
val view = loaded.buildView(context) { outcome -> }
container.addView(view)
```

### Fragment

```kotlin
val fragment = loaded.getFragment { outcome -> }
```

### Compose

There is **no** `io.purchasely:presentation-compose` artifact and **no** `PLYPresentationView` composable. Wrap the Android `View` returned by `buildView(...)` in an `AndroidView`:

```kotlin
AndroidView(factory = { loaded.buildView(it) { outcome -> } })
```

## Action Interceptor

The global `setPaywallActionsInterceptor` was removed. Each action has its own typed interceptor.
There are three ways to register one — pick by call site:

| Style | Signature | How you return the result |
|-------|-----------|---------------------------|
| Kotlin, coroutine | `interceptAction<T> { info, action -> … }` | **return** a `PLYInterceptResult` (lambda is `suspend`) |
| Kotlin, no coroutine | `interceptAction(T::class.java) { info, action, result -> … }` | call `result(…)` later (callback) |
| Java | `interceptAction(T.class, callback)` | call `result.invoke(…)` later (callback) |

Kotlin — with coroutine (reified, returns `PLYInterceptResult` directly; `suspend` calls allowed):

```kotlin
import io.purchasely.ext.PLYInterceptResult
import io.purchasely.ext.presentation.PLYPresentationAction

Purchasely.interceptAction<PLYPresentationAction.Login> { _, _ ->
    showLogin()
    PLYInterceptResult.SUCCESS
}

Purchasely.interceptAction<PLYPresentationAction.Purchase> { info, purchase ->
    if (observerMode) {
        launchBilling(info?.activity, purchase.plan.store_product_id, purchase.subscriptionOffer?.offerToken)
        PLYInterceptResult.SUCCESS
    } else {
        PLYInterceptResult.NOT_HANDLED
    }
}
```

Kotlin — without coroutine (Class-based overload, selected via `::class.java`; return the result
later through the `result` lambda — call it exactly once, synchronously or after async work):

```kotlin
Purchasely.interceptAction(PLYPresentationAction.Purchase::class.java) { info, action, result ->
    val purchase = action as PLYPresentationAction.Purchase   // not cast for you here
    // ... optionally async (billing, dialog); then:
    result(PLYInterceptResult.NOT_HANDLED)
}
```

Java (Class-based overload — the reified form is not callable from Java):

```java
Purchasely.interceptAction(PLYPresentationAction.Purchase.class, (info, action, result) -> {
    PLYPresentationAction.Purchase purchase = (PLYPresentationAction.Purchase) action;
    // ... handle purchase.getPlan(), purchase.getSubscriptionOffer() ...
    result.invoke(PLYInterceptResult.NOT_HANDLED);
});
```

Remove interceptors:

```kotlin
Purchasely.removeActionInterceptor<PLYPresentationAction.Purchase>() // Kotlin, typed
Purchasely.removeAllActionInterceptors()
```

```java
Purchasely.removeActionInterceptor(PLYPresentationAction.Purchase.class); // Java
Purchasely.removeAllActionInterceptors();
```

> The reified `interceptAction<T>` / `removeActionInterceptor<T>()` are `inline` member functions of `Purchasely` targeting JVM 11 — no separate import beyond `io.purchasely.ext.Purchasely` is needed. Compile your Kotlin module with `jvmTarget = 11`, or use the `Class`-based overload.

| Result | Meaning |
|--------|---------|
| `SUCCESS` | App handled the action — SDK skips its default behavior. |
| `FAILED` | App tried but failed — breaks the action chain. |
| `NOT_HANDLED` | SDK should handle the action itself. |

`processAction(false)` (v5) → `PLYInterceptResult.SUCCESS`; `processAction(true)` (v5) → `PLYInterceptResult.NOT_HANDLED`.

`PLYPresentationAction` is a **sealed class** with typed payloads:

| Variant | Parameters |
|---------|------------|
| `PLYPresentationAction.Purchase` | `plan`, `subscriptionOffer`, `offer` |
| `PLYPresentationAction.Restore` | — |
| `PLYPresentationAction.Login` | — |
| `PLYPresentationAction.Close` | `closeReason` |
| `PLYPresentationAction.CloseAll` | `closeReason` |
| `PLYPresentationAction.Navigate` | `url`, `title` |
| `PLYPresentationAction.OpenPresentation` | `presentationId` |
| `PLYPresentationAction.OpenPlacement` | `placementId` |
| `PLYPresentationAction.PromoCode` | — |
| `PLYPresentationAction.WebCheckout` | `url`, `clientReferenceId`, … |

`PLYPresentationInfo` → `PLYInterceptorInfo`. `PLYPresentationActionParameters` is removed (parameters are now on each action subclass). Also removed: `PLYPaywallActionHandler`, `PLYCompletionHandler`, `PLYPaywallActionListener`, `PLYProcessActionListener`.

> `OpenPresentation.presentationId` is the **target presentation** the action wants to open (`PLYPresentationAction.OpenPresentation(presentationId = …)` in source) — it is a parameter on the action, not a renamed field. It is distinct from `PLYPresentation.screenId` (the loaded presentation's own id, renamed from `id` in v6). The "don't use `presentationId`" guidance above applies to the loaded `PLYPresentation`, not to this action parameter.

## UI Handler — Alerts

In Full mode the SDK displays its own `AlertDialog` at the end of a paywall action (purchase success, purchase error, restore result, plan change). `PLYUIHandler.onAlert` lets the app display its own dialog instead.

```kotlin
Purchasely.uiHandler = object : PLYUIHandler {
    override fun onAlert(
        alert: PLYAlertMessage,
        purchaselyView: View,
        activity: Activity?,
        proceed: () -> Unit
    ) { … }
}
// Java: Purchasely.setUIHandler(new CustomUIHandler());
```

**Every branch of `onAlert` must end with exactly one of `proceed()` or `alert.onDismiss()`.**

| Call | Effect |
|------|--------|
| `proceed()` | The SDK displays its own dialog and dismisses the alert when the user taps its button. |
| `alert.onDismiss()` | Dismisses the alert with no SDK dialog. Use it when you display your own. |

The alert is the last step of the paywall action that produced it, and the SDK keeps that action open until the alert is dismissed — only then does it resume the Screen (closing it after a successful purchase, accepting taps again after an error). A branch that calls neither leaves the action pending: **the Screen stays displayed and stops reacting to taps, close button included**, and later actions are never processed. Early v5 releases did not wait for the dismissal, so a missing call went unnoticed.

`onDismiss()` is declared on the `PLYAlertMessage` base class, so it is available on every alert type without a `when` branch. The base class also exposes the strings the SDK would have displayed — `getTitleContent()`, `getContentMessage()`, `getButtonContent()` — so a custom dialog can reuse them.

```kotlin
Purchasely.uiHandler = object : PLYUIHandler {
    override fun onAlert(alert: PLYAlertMessage, purchaselyView: View, activity: Activity?, proceed: () -> Unit) {
        val context = activity ?: return proceed() // no activity: let the SDK display the alert
        when (alert) {
            is PLYAlertMessage.InAppSuccess,
            is PLYAlertMessage.InAppSuccessUnauthentified ->
                // dismiss once your dialog is closed, so the SDK resumes the Screen
                showMyDialog(context, alert.getTitleContent(), alert.getContentMessage()) { alert.onDismiss() }
            else -> proceed()
        }
    }
}
```

Two rules:

- Call `alert.onDismiss()` **after** your dialog is dismissed, not before — on a success alert the SDK resumes the flow and closes the Screen.
- Never call both `proceed()` and `alert.onDismiss()` for the same alert, or the SDK dialog is displayed on top of yours.

`PLYAlertMessage` is a sealed class; the error is carried by the types that have one (`PLYAlertMessage.InAppError`, `PLYAlertMessage.InAppRestorationError`, …). Inside a `when` branch read it with `alert.error`; its localized message is also what `alert.getContentMessage()` returns.

## Deeplinks and Campaigns

The SDK **auto-intercepts** its own deeplinks (zero code): it reads the foreground activity's intent on create and resume. Manual calls still work and are deduped.

```kotlin
Purchasely.allowDeeplink = true     // default true in v6 (was false)
Purchasely.allowCampaigns = true    // separate flag, default true
Purchasely.handleDeeplink(uri, activity) // still works; deduped against auto-interception
```

- Opt out of auto-interception with `.automaticDeeplinkHandling(false)` at init.
- Cold start: pass the deeplink at init with `.handleDeeplink(intent.data)`.
- Preview deeplinks (`?preview=1`) always display, bypassing `allowDeeplink`.

> **Pitfall — `singleTask` / `singleTop` activities.** If the deeplink arrives in `onNewIntent` and you do **not** call `setIntent(intent)`, the URI is hidden from auto-interception. Call `setIntent(intent)` in `onNewIntent`, or keep a manual `Purchasely.handleDeeplink(intent.data, activity)` call.

`readyToOpenDeeplink` → `allowDeeplink`; `isDeeplinkHandled(uri, activity)` → `handleDeeplink(uri, activity)`.

## Presentation Dismiss Handler

### `Purchasely.setDefaultPresentationDismissHandler(handler)`

A default handler for paywalls you do **not** instantiate yourself — chiefly deeplink- and campaign-opened screens, where no `onDismissed` callback was supplied. The handler receives a single `PLYPresentationOutcome`.

```kotlin
Purchasely.setDefaultPresentationDismissHandler { outcome ->
    when (outcome.purchaseResult) {
        PLYPurchaseResult.PURCHASED -> refreshAccess()
        PLYPurchaseResult.RESTORED -> refreshAccess()
        PLYPurchaseResult.CANCELLED, null -> Unit
    }
}
```

Since `6.0.1` the `handler` parameter is **nullable** — pass `null` to unregister the default handler (equivalent to a dedicated `remove...` call). It is mutually exclusive with per-presentation callbacks (`onDismissed`, the `display()` completion, `PLYPresentationState.Dismissed`).

> `setDefaultPresentationResultHandler` never existed on Android as a name — `setDefaultPresentationDismissHandler` is, and always was, the correct Android name (unlike iOS, which renamed *from* `setDefaultPresentationResultHandler`).

## User Management

```kotlin
Purchasely.userLogin("user_123") { shouldRefresh -> shouldRefresh }
Purchasely.userLogout()
```

## User Attributes

Mutation methods return `Deferred<Boolean>` (the result can be ignored — they still work fire-and-forget):

```kotlin
Purchasely.setUserAttribute("favorite_spirit", "gin")
val success = Purchasely.incrementUserAttribute("cocktails_viewed").await()
```

Affected: `setUserAttribute(s)`, `clearUserAttribute(s)`, `incrementUserAttribute`, `decrementUserAttribute`. The internal `PLYUserAttributeManager` was removed (managed by `PLYUserDataStorage`).

## Subscriptions

```kotlin
Purchasely.userSubscriptions { subscriptions -> /* active subs */ }
Purchasely.userSubscriptionsHistory { subscriptions -> /* history */ }
```

The built-in subscription list and cancellation survey UI (`subscriptionsFragment()`, all `PLYSubscriptions*` / `PLYSubscriptionDetail*` / `PLYSubscriptionCancellation*`) were removed — build your own UI from the data APIs above. `purchaseHistory()` → `userSubscriptionsHistory()` (suspend, backend); `isPastSubscriber()` → derive from history.

> `Purchasely.displaySubscriptionCancellationInstruction()` is also **removed** (dropped between `6.0.0-rc.2` and `6.0.0-rc.3`) — it is not mentioned in the upstream `MIGRATION_V6.md`, so this plugin is currently the only place documenting the removal. There is no Android API named `presentSubscriptions()` — if you see that name applied to Android, it's a cross-platform mix-up (RN/Cordova use that name, native Android does not).

## Close Screens

```kotlin
Purchasely.closeAllScreens()
presentation.close()
presentation.back()
```

> `presentation.close()` **delegates to `Purchasely.closeAllScreens()`** — it closes every screen currently displayed, not just this presentation instance. There is no instance-scoped close API on Android (an upstream design choice); if a paywall is stacked over another Purchasely screen, calling `close()` on either one dismisses both.

## Synchronize

`synchronize()` refreshes the subscriptions cache before firing `onSuccess`. Both callbacks are optional (default `null`), so fire-and-forget still works.

```kotlin
// Fire-and-forget
Purchasely.synchronize()

// With callbacks (Observer mode — call after your own billing flow completes)
Purchasely.synchronize(
    onSuccess = { plan -> /* plan is the validated PLYPlan or null; refresh UI */ },
    onError = { error -> /* surface failure */ }
)
```

Java:

```java
Purchasely.synchronize(
    plan -> { /* onSuccess */ return Unit.INSTANCE; },
    error -> { /* onError */ return Unit.INSTANCE; }
);
```

## Plan offers — intro/trial helpers renamed

| Removed (v5) | Replacement (v6) |
|--------------|------------------|
| `hasIntroductoryPrice()` | `hasOfferPrice()` |
| `isEligibleToIntroOffer()` | `isEligibleToOffer()` |
| `localizedIntroductoryPrice()` | `localizedOfferPrice()` |
| `PLYPlanTags.INTRO_PRICE` / `PLYPlanTags.TRIAL_PRICE` | `PLYPlanTags.OFFER_PRICE` |

All `intro*` / `introductory*` methods and `INTRO_*` / `TRIAL_*` tags were removed in favor of unified `offer*` / `OFFER_*` equivalents.
