# Android Common Patterns

Use these native Android SDK v6 patterns for Screens and Presentations.

## Display a placement from an Activity

```kotlin
class PremiumActivity : AppCompatActivity() {
    fun showPresentation() {
        lifecycleScope.launch {
            val presentation = PLYPresentation {
                placementId("premium_feature")
                onPresented { loaded, error -> }
                onCloseRequested { }
            }.preload()

            when (presentation.type) {
                PLYPresentationType.DEACTIVATED -> Unit
                PLYPresentationType.CLIENT -> showCustomScreen(presentation)
                else -> presentation.display(this@PremiumActivity) { outcome ->
                    if (outcome.purchaseResult == PLYPurchaseResult.PURCHASED) refreshAccess()
                }
            }
        }
    }
}
```

## Display a direct Screen

```kotlin
val presentation = PLYPresentation {
    screenId("screen_abc123")
}.preload()
```

Android public APIs use `screenId`. Do not introduce `presentationId` in Android app code.

## Prepared display helper

```kotlin
PLYPresentation { placementId("onboarding") }.display(
    context = activity,
    presentation = { loaded ->
        // Display triggered.
    },
    callback = { outcome ->
        // Final dismissal.
    }
)
```

## Session and await()

`display(context)` is non-suspend and returns a `PLYPresentationSession` you can `await()` from a coroutine:

```kotlin
lifecycleScope.launch {
    try {
        val outcome = presentation.display(activity).await()
        when (outcome.purchaseResult) {
            PLYPurchaseResult.PURCHASED -> refreshAccess()
            PLYPurchaseResult.RESTORED -> refreshAccess()
            PLYPurchaseResult.CANCELLED, null -> Unit
        }
    } catch (e: PLYError) {
        // the presentation failed to launch or render
    }
}
```

## Preload early, display later (no extra network call)

```kotlin
var cached: PLYPresentation? = null

// Early preload — display reuses it, no second network call.
lifecycleScope.launch {
    cached = PLYPresentation { placementId("premium_feature") }.preload()
}

button.setOnClickListener { cached?.display(this) { outcome -> } }
```

## Observe lifecycle state

```kotlin
val prepared = PLYPresentation { placementId("onboarding") }

lifecycleScope.launch {
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
}
```

## Embed in a Fragment container

```kotlin
class ScreenContainerFragment : Fragment(R.layout.fragment_screen_container) {
    fun embed(presentation: PLYPresentation) {
        childFragmentManager.beginTransaction()
            .replace(R.id.container, presentation.getFragment { outcome -> })
            .commit()
    }
}
```

## Embed in a View hierarchy

```kotlin
val view = presentation.buildView(requireContext()) { outcome -> }
container.addView(view)
```

## Embed in Compose

There is no `presentation-compose` artifact and no `PLYPresentationView` composable. `buildView(...)` returns an Android `View?` — wrap it in an `AndroidView`:

```kotlin
@Composable
fun InlinePresentation(presentation: PLYPresentation) {
    AndroidView(
        modifier = Modifier.fillMaxWidth(),
        factory = { context ->
            presentation.buildView(context) { outcome -> } ?: FrameLayout(context)
        }
    )
}
```

## Observer mode with Google Play Billing

```kotlin
private var pendingResult: ((PLYInterceptResult) -> Unit)? = null

Purchasely.interceptAction<PLYPresentationAction.Purchase> { info, purchase ->
    if (!observerMode) return@interceptAction PLYInterceptResult.NOT_HANDLED

    // Cancel any orphaned previous result before suspending for the new one
    pendingResult?.invoke(PLYInterceptResult.NOT_HANDLED)
    pendingResult = null

    suspendCancellableCoroutine { continuation ->
        pendingResult = { result ->
            if (continuation.isActive) continuation.resume(result)
        }
        continuation.invokeOnCancellation { pendingResult = null }
        startBilling(
            activity = info?.activity,
            productId = purchase.plan.store_product_id,
            offerToken = purchase.subscriptionOffer?.offerToken,
        )
    }
}

fun onBillingSuccess() {
    pendingResult?.invoke(PLYInterceptResult.SUCCESS)   // resolving with SUCCESS auto-synchronizes — do not call Purchasely.synchronize() here
    pendingResult = null
    // Observer mode does not auto-close (the implicit close_all is Full-only). This handler
    // runs after the interceptor has resolved, so dismiss the paywall here — unless a
    // `close` / `close_all` action is configured on the button in the Console.
    Purchasely.closeAllScreens()
}

fun onBillingCancelled() {
    pendingResult?.invoke(PLYInterceptResult.NOT_HANDLED)
    pendingResult = null
}

fun onBillingError() {
    pendingResult?.invoke(PLYInterceptResult.FAILED)
    pendingResult = null
}
```

## Action interceptor in Java

Java cannot call the reified `interceptAction<T>`. Use the `Class`-based overload with `result.invoke(...)`:

```java
Purchasely.interceptAction(PLYPresentationAction.Purchase.class, (info, action, result) -> {
    PLYPresentationAction.Purchase purchase = (PLYPresentationAction.Purchase) action;
    startBilling(
        info != null ? info.getActivity() : null,
        purchase.getPlan().getStore_product_id(),
        purchase.getSubscriptionOffer() != null ? purchase.getSubscriptionOffer().getOfferToken() : null,
        billingResult -> {
            result.invoke(PLYInterceptResult.SUCCESS);   // resolving with SUCCESS auto-synchronizes — do not call Purchasely.synchronize() here
        }
    );
});
```

Embedded view in Java (`buildView` returns an Android `View`):

```java
PLYPresentationBase.Loaded loaded = /* preloaded presentation */;
View view = loaded.buildView(getApplicationContext(), outcome -> { /* handle */ return Unit.INSTANCE; });
container.addView(view);
```

## Synchronize for a purchase processed outside the interceptor

Resolving a `.purchase` / `.restore` interceptor with `PLYInterceptResult.SUCCESS` already **auto-synchronizes** the receipt — do not also call `Purchasely.synchronize()` from inside the interceptor. Call it manually only for transactions your app processes **outside** the interceptor flow, e.g. a "Restore Purchases" button on a settings screen, or a client-side (`PLYPresentationType.CLIENT`) presentation with its own purchase button:

```kotlin
Purchasely.synchronize(
    onSuccess = { validatedPlan -> if (validatedPlan != null) refreshAccess() },
    onError = { error -> showError(error) }
)
```

## Deeplink auto-interception on singleTask/singleTop activities

Auto-interception reads the activity intent. With `singleTask` / `singleTop` launch modes the deeplink arrives in `onNewIntent`; call `setIntent(intent)` or the URI is hidden from the SDK.

```kotlin
override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent) // required for auto-interception (or call Purchasely.handleDeeplink manually)
}
```

## Follow-up Screen after purchase

```kotlin
presentation.display(activity) { outcome ->
    if (outcome.purchaseResult == PLYPurchaseResult.PURCHASED) {
        lifecycleScope.launch {
            PLYPresentation { placementId("success_payment") }
                .preload()
                .display(activity) { refreshAccess() }
        }
    }
}
```

## Custom alert dialogs (`PLYUIHandler`)

Every branch must end with `proceed()` or `alert.onDismiss()` — the paywall action that raised the alert stays open until one of them is called.

```kotlin
Purchasely.uiHandler = object : PLYUIHandler {
    override fun onAlert(alert: PLYAlertMessage, purchaselyView: View, activity: Activity?, proceed: () -> Unit) {
        val context = activity ?: return proceed() // no activity: let the SDK display the alert
        when (alert) {
            is PLYAlertMessage.InAppSuccess,
            is PLYAlertMessage.InAppSuccessUnauthentified ->
                MaterialAlertDialogBuilder(context)
                    .setTitle(alert.getTitleContent())
                    .setMessage(alert.getContentMessage())
                    .setPositiveButton(alert.getButtonContent()) { d, _ -> d.dismiss() }
                    .setOnDismissListener { alert.onDismiss() } // after the dialog closes
                    .show()
            else -> proceed() // SDK dialog, dismissal handled for you
        }
    }
}
```

## Cleanup on restart

```kotlin
fun closePurchaselyLayer() {
    pendingResult?.invoke(PLYInterceptResult.NOT_HANDLED)
    pendingResult = null
    Purchasely.removeAllActionInterceptors()
    Purchasely.close()
}
```
