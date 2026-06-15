# Android SDK v5.x API — reference for MIGRATION ONLY (replaced in v6)

This is a compact snapshot of the **public Android v5.x** API. It exists so the migrate skill can **recognize legacy v5 code** in a project and rewrite it. Do not use these signatures for new code — every entry below was removed or renamed in v6. For the v6 replacements and full rewrite steps, see [migration-v6.md](migration-v6.md).

Each entry adds a one-line `-> v6` pointer.

## Imports (v5)

```kotlin
import io.purchasely.ext.Purchasely
import io.purchasely.ext.PLYRunningMode
import io.purchasely.ext.PLYPresentation
import io.purchasely.ext.PLYPresentationAction
import io.purchasely.ext.PLYPresentationInfo
import io.purchasely.ext.PLYPresentationActionParameters
import io.purchasely.ext.PLYProductViewResult
import io.purchasely.ext.PLYPresentationProperties
```

`-> v6`: presentation types moved to `io.purchasely.ext.presentation.*`.

## Initialization (v5)

```kotlin
Purchasely.Builder(applicationContext)
    .apiKey("API_KEY")
    .stores(listOf(GoogleStore()))
    .logLevel(LogLevel.DEBUG)
    .runningMode(PLYRunningMode.Full)          // implicit default in v5
    .readyToOpenDeeplink(true)
    .build()
    .start { isConfigured, error -> }
```

- `Purchasely.Builder(...).build().start { isConfigured, error -> }` -> v6: `start { error -> }` (single nullable `PLYError`), or the `Purchasely { … }` Kotlin DSL.
- `PLYRunningMode.PaywallObserver` -> v6: `PLYRunningMode.Observer`. **Default mode flipped from `Full` to `Observer` in v6.**
- `.readyToOpenDeeplink(true)` / `Purchasely.readyToOpenDeeplink` -> v6: `allowDeeplink` (defaults to `true`).

## Action interceptor (v5)

```kotlin
Purchasely.setPaywallActionsInterceptor { info, action, parameters, processAction ->
    when (action) {
        PLYPresentationAction.PURCHASE -> processAction(true)   // let SDK continue
        PLYPresentationAction.LOGIN    -> processAction(false)  // app handled it
        PLYPresentationAction.RESTORE  -> processAction(true)
        PLYPresentationAction.NAVIGATE -> processAction(true)
        PLYPresentationAction.CLOSE,
        PLYPresentationAction.CLOSE_ALL -> processAction(true)
        else -> processAction(true)
    }
}
```

- `setPaywallActionsInterceptor { info, action, parameters, processAction -> }` -> v6: per-action `Purchasely.interceptAction<PLYPresentationAction.X> { info, action -> }` (Kotlin) or `interceptAction(PLYPresentationAction.X.class, (info, action, result) -> result.invoke(...))` (Java).
- `processAction(false)` (app handled) -> v6: `PLYInterceptResult.SUCCESS`.
- `processAction(true)` (let SDK continue) -> v6: `PLYInterceptResult.NOT_HANDLED`. New failure path -> `PLYInterceptResult.FAILED`.
- `PLYPresentationAction` **enum** (`PURCHASE`, `RESTORE`, `LOGIN`, `CLOSE`, `CLOSE_ALL`, `NAVIGATE`, `OPEN_PRESENTATION`, `OPEN_PLACEMENT`, `PROMO_CODE`, `WEB_CHECKOUT`) -> v6: **sealed class** (`Purchase`, `Restore`, `Login`, `Close`, `CloseAll`, `Navigate`, `OpenPresentation`, `OpenPlacement`, `PromoCode`, `WebCheckout`).
- `PLYPresentationActionParameters` (`parameters.plan`, `parameters.subscriptionOffer`, `parameters.url`, …) -> v6: typed fields on each action subclass (`action.plan`, `action.subscriptionOffer`, `action.offer`, `action.url`, …).
- `PLYPresentationInfo` -> v6: `PLYInterceptorInfo`.

## Fetch & display a presentation (v5)

```kotlin
Purchasely.fetchPresentation(placementId = "onboarding") { presentation, error ->
    if (error != null) return@fetchPresentation
    presentation?.display(context) { result, plan ->
        when (result) {
            PLYProductViewResult.PURCHASED -> {}
            PLYProductViewResult.RESTORED  -> {}
            PLYProductViewResult.CANCELLED -> {}
        }
    }
}
```

- `Purchasely.fetchPresentation(...)` -> v6: `PLYPresentation { placementId("…") }.preload()`.
- `display(context) { result, plan -> }` -> v6: `display(context) { outcome -> }` (single `PLYPresentationOutcome`); also `.display(context).await()`.
- `PLYProductViewResult` (`PURCHASED` / `RESTORED` / `CANCELLED`) -> v6: `PLYPurchaseResult` (`PURCHASED` / `RESTORED` / `CANCELLED` / `null`) inside `outcome.purchaseResult`.
- `PLYPresentation.id` -> v6: `PLYPresentation.screenId`; `toMap()["id"]` -> `toMap()["screenId"]`.
- `onClose` -> v6: `onCloseRequested`.

## Embedded view (v5)

```kotlin
val view = Purchasely.presentationView(
    context = this,
    placementId = "onboarding",
    properties = PLYPresentationProperties(),
) { result, plan -> }
container.addView(view)
```

- `Purchasely.presentationView(...)` -> v6: `loaded.buildView(context) { outcome -> }`.
- `PLYPresentationProperties` -> v6: removed (configure on the `PLYPresentation { … }` builder).
- Fragment: v6 uses `loaded.getFragment { outcome -> }`.

## Deeplinks (v5)

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    Purchasely.isDeeplinkHandled(intent.data, this)
}
Purchasely.readyToOpenDeeplink = true
```

- `Purchasely.isDeeplinkHandled(uri, activity)` -> v6: `Purchasely.handleDeeplink(uri, activity)` (now **auto-intercepted**, so the manual call is usually unnecessary).
- `Purchasely.readyToOpenDeeplink` -> v6: `Purchasely.allowDeeplink`.

## Subscription UI & history (v5)

```kotlin
val fragment = Purchasely.subscriptionsFragment()
Purchasely.purchaseHistory { history -> }
val past = Purchasely.isPastSubscriber()
```

- `Purchasely.subscriptionsFragment()` and all `PLYSubscriptions*` / `PLYSubscriptionDetail*` / `PLYSubscriptionCancellation*` UI -> v6: removed; build your own UI from `Purchasely.userSubscriptions { }` / `Purchasely.userSubscriptionsHistory { }`.
- `Purchasely.purchaseHistory()` -> v6: `Purchasely.userSubscriptionsHistory()` (suspend, backend).
- `Purchasely.isPastSubscriber()` -> v6: derive from `userSubscriptionsHistory()`.
- Deeplinks `ply/subscriptions`, `ply/cancellation_survey[/PRODUCT_VENDOR_ID]` -> v6: removed.

## Plan intro/trial helpers & tags (v5)

```kotlin
plan.hasIntroductoryPrice()
plan.isEligibleToIntroOffer()
plan.localizedIntroductoryPrice()
PLYPlanTags.INTRO_PRICE
PLYPlanTags.TRIAL_PRICE
```

- `hasIntroductoryPrice()` -> v6: `hasOfferPrice()`.
- `isEligibleToIntroOffer()` -> v6: `isEligibleToOffer()`.
- `localizedIntroductoryPrice()` -> v6: `localizedOfferPrice()`.
- `PLYPlanTags.INTRO_PRICE` / `PLYPlanTags.TRIAL_PRICE` -> v6: `PLYPlanTags.OFFER_PRICE`.
- All other `intro*` / `introductory*` methods and `INTRO_*` / `TRIAL_*` tags -> v6: unified `offer*` / `OFFER_*`.

## See also

- [migration-v6.md](migration-v6.md) — full v5 -> v6 migration steps and v6 replacements.
- [api-reference.md](api-reference.md) — the v6 API surface.
