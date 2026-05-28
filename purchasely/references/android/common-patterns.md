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

With the optional artifact:

```kotlin
implementation("io.purchasely:presentation-compose:6.0.0")
```

```kotlin
@Composable
fun InlinePresentation(presentation: PLYPresentation) {
    PLYPresentationView(
        presentation = presentation,
        modifier = Modifier.fillMaxWidth(),
        callback = { outcome -> }
    )
}
```

Without the optional artifact:

```kotlin
AndroidView(
    factory = { context -> presentation.buildView(context) ?: FrameLayout(context) }
)
```

## Observer mode with Google Play Billing

```kotlin
private var pendingResult: ((PLYInterceptResult) -> Unit)? = null

Purchasely.interceptAction<PLYPresentationAction.Purchase> { info, purchase ->
    if (!observerMode) return@interceptAction PLYInterceptResult.NOT_HANDLED

    suspendCancellableCoroutine { continuation ->
        pendingResult = { result ->
            if (continuation.isActive) continuation.resume(result)
        }
        startBilling(
            activity = info?.activity,
            productId = purchase.plan.store_product_id,
            offerToken = purchase.subscriptionOffer?.offerToken,
        )
    }
}

fun onBillingSuccess() {
    Purchasely.synchronize()
    pendingResult?.invoke(PLYInterceptResult.SUCCESS)
    pendingResult = null
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

## Cleanup on restart

```kotlin
fun closePurchaselyLayer() {
    pendingResult?.invoke(PLYInterceptResult.NOT_HANDLED)
    pendingResult = null
    Purchasely.removeAllActionInterceptors()
    Purchasely.close()
}
```
