# Android Common Integration Patterns

> **Platform-specific elaborations.** This file covers Android idioms (Activity / Fragment / Jetpack Compose embedding, `SharedFlow` decoupling, ProGuard rules, multi-store setup). Concepts that apply to **every** Purchasely SDK (Observer-mode post-purchase flow, presentation type guard, presentation cache, audience-targeting attributes, GDPR consent, subscription checks) live in `../concepts/`:
>
> - [`../concepts/running-modes.md`](../concepts/running-modes.md), [`../concepts/paywall-actions.md`](../concepts/paywall-actions.md), [`../concepts/presentation-types.md`](../concepts/presentation-types.md), [`../concepts/presentation-cache.md`](../concepts/presentation-cache.md), [`../concepts/observer-mode-post-purchase.md`](../concepts/observer-mode-post-purchase.md), [`../concepts/user-attributes-targeting.md`](../concepts/user-attributes-targeting.md), [`../concepts/subscription-checks.md`](../concepts/subscription-checks.md), [`../sdk-versions.md`](../sdk-versions.md) (Android pinned at **5.7.4**).

## Display Paywall in an Activity

```kotlin
class PaywallActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Purchasely.fetchPresentation(
            placementId = "ONBOARDING",
            callback = object : PLYPresentationCallback {
                override fun onPresentationFetched(presentation: PLYPresentation) {
                    if (presentation.type == PLYPresentationType.DEACTIVATED) {
                        finish()
                        return
                    }
                    presentation.display(this@PaywallActivity)
                }

                override fun onPresentationClosed() {
                    finish()
                }

                override fun onPurchaseResult(result: PLYPurchaseResult) {
                    when (result) {
                        PLYPurchaseResult.PURCHASED -> {
                            // Unlock content
                        }
                        PLYPurchaseResult.RESTORED -> {
                            // Restore content
                        }
                        PLYPurchaseResult.CANCELLED -> {
                            // User cancelled
                        }
                    }
                }
            }
        )
    }
}
```

## Display Paywall in a Fragment

Embed a paywall as a Fragment within your layout:

```kotlin
class PaywallContainerFragment : Fragment(R.layout.fragment_paywall_container) {

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        Purchasely.fetchPresentation(
            placementId = "SETTINGS_PAYWALL",
            callback = object : PLYPresentationCallback {
                override fun onPresentationFetched(presentation: PLYPresentation) {
                    if (presentation.type == PLYPresentationType.DEACTIVATED) return

                    val fragment = presentation.getFragment()
                    childFragmentManager.beginTransaction()
                        .replace(R.id.paywall_container, fragment)
                        .commit()
                }

                override fun onPresentationClosed() {
                    parentFragmentManager.popBackStack()
                }

                override fun onPurchaseResult(result: PLYPurchaseResult) {
                    // Handle result
                }
            }
        )
    }
}
```

## Display Paywall in Jetpack Compose

Use `AndroidView` or `AndroidViewBinding` to embed the paywall Fragment:

```kotlin
@Composable
fun PaywallScreen(
    placementId: String,
    onDismiss: () -> Unit,
    onPurchased: () -> Unit
) {
    val context = LocalContext.current

    DisposableEffect(placementId) {
        Purchasely.fetchPresentation(
            placementId = placementId,
            callback = object : PLYPresentationCallback {
                override fun onPresentationFetched(presentation: PLYPresentation) {
                    if (presentation.type == PLYPresentationType.DEACTIVATED) {
                        onDismiss()
                        return
                    }
                    presentation.display(context as Activity)
                }

                override fun onPresentationClosed() {
                    onDismiss()
                }

                override fun onPurchaseResult(result: PLYPurchaseResult) {
                    if (result == PLYPurchaseResult.PURCHASED) {
                        onPurchased()
                    }
                }
            }
        )
        onDispose { }
    }
}

// Usage in a NavHost:
composable("paywall") {
    PaywallScreen(
        placementId = "PREMIUM",
        onDismiss = { navController.popBackStack() },
        onPurchased = { navController.navigate("premium_content") }
    )
}
```

### Inline Paywall in Compose (Fragment-based)

```kotlin
@Composable
fun InlinePaywall(placementId: String) {
    var fragment by remember { mutableStateOf<Fragment?>(null) }

    LaunchedEffect(placementId) {
        Purchasely.fetchPresentation(
            placementId = placementId,
            callback = object : PLYPresentationCallback {
                override fun onPresentationFetched(presentation: PLYPresentation) {
                    if (presentation.type != PLYPresentationType.DEACTIVATED) {
                        fragment = presentation.getFragment()
                    }
                }
                override fun onPresentationClosed() {}
                override fun onPurchaseResult(result: PLYPurchaseResult) {}
            }
        )
    }

    fragment?.let { paywallFragment ->
        AndroidView(
            factory = { ctx ->
                FragmentContainerView(ctx).apply {
                    id = View.generateViewId()
                }
            },
            update = { container ->
                val activity = container.context as FragmentActivity
                activity.supportFragmentManager.beginTransaction()
                    .replace(container.id, paywallFragment)
                    .commit()
            }
        )
    }
}
```

## Handle LOGIN Action with startActivityForResult

```kotlin
// In your Application or main Activity setup:
Purchasely.setPaywallActionsInterceptor { info, action, parameters, processAction ->
    when (action) {
        PLYPresentationAction.LOGIN -> {
            val activity = info?.activity ?: return@setPaywallActionsInterceptor processAction(false)

            val loginIntent = Intent(activity, LoginActivity::class.java)
            activity.startActivityForResult(loginIntent, LOGIN_REQUEST_CODE)

            // Store processAction for later use in onActivityResult
            pendingProcessAction = processAction
        }
        else -> processAction(true)
    }
}

// In the Activity hosting the paywall:
override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    super.onActivityResult(requestCode, resultCode, data)
    if (requestCode == LOGIN_REQUEST_CODE) {
        val userId = data?.getStringExtra("user_id")
        if (resultCode == RESULT_OK && userId != null) {
            Purchasely.userLogin(userId) { true }
            pendingProcessAction?.invoke(true)
        } else {
            pendingProcessAction?.invoke(false)
        }
        pendingProcessAction = null
    }
}
```

### Modern Approach with Activity Result API

```kotlin
private val loginLauncher = registerForActivityResult(
    ActivityResultContracts.StartActivityForResult()
) { result ->
    if (result.resultCode == RESULT_OK) {
        val userId = result.data?.getStringExtra("user_id")
        userId?.let { Purchasely.userLogin(it) { true } }
        pendingProcessAction?.invoke(result.resultCode == RESULT_OK)
    } else {
        pendingProcessAction?.invoke(false)
    }
    pendingProcessAction = null
}
```

## PaywallObserver Mode with Google Play Billing

Use Purchasely for paywalls while managing purchases yourself:

```kotlin
// Initialize in Observer mode
Purchasely.Builder(applicationContext)
    .apiKey("YOUR_API_KEY")
    .stores(listOf(GoogleStore()))
    .runningMode(PLYRunningMode.PaywallObserver)
    .build()
    .start { _, _ -> }

// Intercept purchase actions
Purchasely.setPaywallActionsInterceptor { info, action, parameters, processAction ->
    when (action) {
        PLYPresentationAction.PURCHASE -> {
            val productId = parameters?.plan?.googleProductId ?: return@setPaywallActionsInterceptor processAction(false)
            // Launch your own billing flow
            launchBillingFlow(productId) { success ->
                if (success) Purchasely.synchronize()
                processAction(success)
            }
        }
        PLYPresentationAction.RESTORE -> {
            restorePurchases { success ->
                if (success) Purchasely.synchronize()
                processAction(success)
            }
        }
        else -> processAction(true)
    }
}
```

## Observer Mode — Recommended Post-Purchase Flow

After a successful Observer-mode purchase, the recommended sequence is:

1. **`Purchasely.synchronize()`** — fire-and-forget (no callback on Android)
2. **`processAction(false)`** — tell the SDK we handled the purchase (skip its own flow)
3. **`Purchasely.closeAllScreens()`** — force-dismiss the paywall

The order **processAction → closeAllScreens** matters: the interceptor must learn the action was handled BEFORE the paywall tears down.

```kotlin
private fun onPurchaseSuccess(processAction: (Boolean) -> Unit) {
    Purchasely.synchronize()       // fire-and-forget
    processAction(false)           // tell interceptor we handled it
    Purchasely.closeAllScreens()   // dismiss
}
```

> `closeAllScreens()` requires Purchasely Android SDK **5.7.4+**.

### Chaining a Follow-up Placement After Purchase (optional)

Some apps display a follow-up paywall after a successful purchase — a thank-you screen, a premium feature tour, a one-tap upsell. This is **not part of the SDK contract**: it's just `fetchPresentation` called again with whatever placement ID you've configured on the Console (e.g. `"post_purchase"`, `"thank_you"`, `"premium_welcome"` — pick your own).

Because Android's `synchronize()` is fire-and-forget (no callback to await), the follow-up fetch may briefly resolve against stale subscription state if its audience targets subscribers. Android's cache refresh is usually fast enough in practice, but worth knowing if you see fallback presentations.

```kotlin
private fun showPostPurchaseScreen(activity: Activity) {
    Purchasely.fetchPresentation("YOUR_POST_PURCHASE_PLACEMENT_ID") { presentation, error ->
        if (error != null || presentation == null) return@fetchPresentation
        when (presentation.type) {
            PLYPresentationType.NORMAL,
            PLYPresentationType.FALLBACK -> presentation.display(activity)
            else -> {}
        }
    }
}
```

**Naming gotcha:** the placement ID string must match the Console exactly — typos silently return a deactivated presentation.

## Decoupling the Purchase Manager with SharedFlow

In Observer mode, keep the native billing logic isolated from the Purchasely SDK. The wrapper communicates with `PurchaseManager` via `SharedFlow` — `PurchaseManager` has zero Purchasely imports.

```kotlin
// Types (no SDK imports needed)
data class PurchaseRequest(val activity: Activity, val productId: String, val offerToken: String)
data object RestoreRequest
sealed class TransactionResult {
    data object Success : TransactionResult()
    data object Cancelled : TransactionResult()
    data class Error(val message: String?) : TransactionResult()
    data object Idle : TransactionResult()
}

// In the wrapper (owns SDK)
class PurchaselyWrapper(
    private val purchaseRequests: MutableSharedFlow<PurchaseRequest>,
    private val restoreRequests: MutableSharedFlow<RestoreRequest>,
    private val transactionResult: SharedFlow<TransactionResult>,
    private val scope: CoroutineScope,
) {
    private var pendingProcessAction: ((Boolean) -> Unit)? = null

    fun setupInterceptor(activity: Activity) {
        Purchasely.setPaywallActionsInterceptor { _, action, parameters, processAction ->
            when (action) {
                PLYPresentationAction.PURCHASE -> {
                    val plan = parameters?.plan ?: return@setPaywallActionsInterceptor processAction(false)
                    // Race guard: cancel any orphaned previous callback
                    pendingProcessAction?.invoke(false)
                    pendingProcessAction = processAction
                    scope.launch {
                        purchaseRequests.emit(
                            PurchaseRequest(activity, plan.store_product_id, plan.offerToken.orEmpty())
                        )
                    }
                }
                // … same for RESTORE
                else -> processAction(true)
            }
        }
        // Collect transaction results from PurchaseManager
        scope.launch {
            transactionResult.collect { result ->
                when (result) {
                    is TransactionResult.Success -> {
                        Purchasely.synchronize()
                        pendingProcessAction?.invoke(false)
                        Purchasely.closeAllScreens()
                    }
                    is TransactionResult.Cancelled,
                    is TransactionResult.Error -> pendingProcessAction?.invoke(false)
                    is TransactionResult.Idle -> {}
                }
                pendingProcessAction = null
            }
        }
    }
}
```

## Presentation Cache (Audience Invalidation)

The Android SDK doesn't (yet) expose a user-attribute delegate as public API. If you maintain an app-side presentation cache, invalidate it on explicit triggers:

- `wrapper.synchronize()` — subscription state may have changed
- `wrapper.restart()` — SDK mode change (Full ↔ Observer) resets the session

When the Android SDK adds a user-attribute delegate (expected in 6.x), wire cache invalidation to attribute changes the same way iOS does.

## Handle Presentation Types (DEACTIVATED Guard)

Always check the presentation type before displaying:

```kotlin
fun showPaywall(placementId: String) {
    Purchasely.fetchPresentation(
        placementId = placementId,
        callback = object : PLYPresentationCallback {
            override fun onPresentationFetched(presentation: PLYPresentation) {
                when (presentation.type) {
                    PLYPresentationType.NORMAL,
                    PLYPresentationType.FALLBACK -> {
                        presentation.display(this@MainActivity)
                    }
                    PLYPresentationType.DEACTIVATED -> {
                        // Presentation disabled in dashboard -- skip
                        Log.w("PLY", "Presentation $placementId is deactivated")
                    }
                    PLYPresentationType.CLIENT -> {
                        // Use your own paywall UI with Purchasely plan data
                        showCustomPaywall(presentation.plans)
                    }
                }
            }

            override fun onPresentationClosed() { }
            override fun onPurchaseResult(result: PLYPurchaseResult) { }
        }
    )
}
```

## ProGuard Configuration

Add to `proguard-rules.pro`:

```proguard
# Purchasely SDK
-keep class io.purchasely.** { *; }
-keep class io.purchasely.ext.** { *; }

# Google Play Billing (if using Google Store)
-keep class com.android.vending.billing.** { *; }

# Huawei IAP (if using Huawei Store)
-keep class com.huawei.hms.iap.** { *; }
```

## Multi-Store Setup (Google + Huawei + Amazon)

```kotlin
class MyApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        val stores = mutableListOf<Store>()

        // Add stores based on availability
        try {
            stores.add(GoogleStore())
        } catch (e: Exception) {
            Log.d("PLY", "Google Play not available")
        }

        try {
            stores.add(HuaweiStore())
        } catch (e: Exception) {
            Log.d("PLY", "Huawei HMS not available")
        }

        try {
            stores.add(AmazonStore())
        } catch (e: Exception) {
            Log.d("PLY", "Amazon Appstore not available")
        }

        Purchasely.Builder(applicationContext)
            .apiKey("YOUR_API_KEY")
            .logLevel(LogLevel.DEBUG)
            .stores(stores)
            .build()
            .start { success, error ->
                Log.d("PLY", "SDK started: $success, store: ${Purchasely.currentStore}")
            }
    }
}
```

The SDK automatically detects which store installed the app and uses the appropriate billing library. You can check `Purchasely.currentStore` after initialization to see which store is active.
