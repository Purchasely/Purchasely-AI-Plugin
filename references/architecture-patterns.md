# Purchasely SDK — Architecture Patterns

Recommended architecture patterns for production-grade Purchasely SDK integrations.

---

## 1. PurchaselyWrapper Pattern

**Rule: Never call the Purchasely SDK directly. All calls go through a dedicated `PurchaselyWrapper`.**

### Why

- Single point of control for all SDK interactions — easy to swap with a stub for removal
- Screens/Views have zero `io.purchasely` / `import Purchasely` imports — clean separation
- Easier to test (mock the wrapper, not the SDK)
- Consistent error handling and result mapping
- Type-safe result types (`FetchResult`, `DisplayResult`) instead of raw SDK enums

### Wrapper Responsibilities

| Category | Methods |
|----------|---------|
| **Init & Lifecycle** | `initialize()`, `restart()`, `close()`, `closeDisplayedPresentation()` |
| **Interceptor** | Internal paywall actions interceptor (LOGIN, NAVIGATE, PURCHASE, RESTORE) |
| **Events** | Internal event listener/delegate |
| **Presentations** | `loadPresentation()`, `display()`, `getView()` (Android) / `getController()` (iOS) |
| **User Attributes** | `setUserAttribute()`, `incrementUserAttribute()` |
| **User Management** | `userLogin()`, `userLogout()`, `anonymousUserId` |
| **Purchases** | `restoreAllProducts()`, `synchronize()`, `signPromotionalOffer()` (iOS) |
| **Consent** | `revokeDataProcessingConsent()` |
| **Info** | `sdkVersion`, `isDeeplinkHandled()` |

### Tolerated SDK type imports

`PLYRunningMode`, `PLYDataProcessingPurpose`, `PLYPresentationAction`, `PLYPresentationInfo`, `PLYPresentationActionParameters`, `PLYPresentationViewController`, `EventListener` / `PLYEventDelegate`, `PLYOfferSignature`, `LogLevel` / `PLYLogger.PLYLogLevel` — these are enums/types needed for configuration, interceptor logic, and presentation handling. They are not SDK call points.

> **Android note:** Wrap `PLYPresentation` in an opaque `PresentationHandle` value class (`@JvmInline value class`). ViewModels and Screens never import `PLYPresentation` directly — they use `PresentationHandle` exclusively.

### Platform Implementations

**Android (Kotlin):**
- Singleton via DI (Koin/Hilt) with constructor: `PurchaselyWrapper(runningModeRepo, purchaseRequests, restoreRequests, transactionResult, scope)`
- ViewModels receive it via constructor injection
- App entry point calls `wrapper.initialize(application, apiKey, logLevel, onConfigured)`

**iOS (Swift):**
- Singleton: `PurchaselyWrapper.shared` conforming to `PurchaselyWrapping` protocol
- ViewModels accept `PurchaselyWrapping` via init with default `.shared`
- App entry point calls `wrapper.initialize(apiKey:, appUserId:, logLevel:, onReady:)`
- `MockPurchaselyWrapper` in tests implements the protocol

---

## 2. Observer Mode: Reactive Purchase Flow

**Rule: In Observer mode, purchases and restores are decoupled from the SDK via reactive flows. The native `PurchaseManager` has zero Purchasely imports.**

### Architecture

```
PurchaselyWrapper                          PurchaseManager
    │                                           │
    │ PURCHASE (observer) ──────────────────►   │
    │   emit PurchaseRequest                     │
    │                                           │ Native billing
    │                                           │ (Play Billing / StoreKit 2)
    │   ◄────────────────────────────────────   │
    │   TransactionResult                        │
    │                                           │
    │ synchronize()                              │
    │ processAction(false)                       │
    │ onTransactionCompleted?.invoke()           │
```

### Communication Channels

**Android (Kotlin):**
- `SharedFlow<PurchaseRequest>` — wrapper emits, PurchaseManager collects
- `SharedFlow<RestoreRequest>` — wrapper emits, PurchaseManager collects
- `SharedFlow<TransactionResult>` — PurchaseManager emits, wrapper collects
- PurchaseManager takes a `billingClientFactory` lambda (testable, no hardcoded BillingClient)

**iOS (Swift):**
- `PassthroughSubject<PurchaseRequest, Never>` — wrapper sends, PurchaseManager sinks
- `PassthroughSubject<Void, Never>` — wrapper sends restore trigger
- `PassthroughSubject<TransactionResult, Never>` — PurchaseManager sends, wrapper sinks
- PurchaseManager uses injected closures for `anonymousUserId` and `signPromotionalOffer` (no wrapper reference)

### Types

```kotlin
// Android
data class PurchaseRequest(val activity: Activity, val productId: String, val offerToken: String)
data object RestoreRequest
sealed class TransactionResult { Success, Cancelled, Error(message), Idle }
```

```swift
// iOS
struct PurchaseRequest { let productId: String }
enum TransactionResult { case success, cancelled, error(String?), idle }
```

### processAction callback

The wrapper stores a single `pendingProcessAction: ((Boolean) -> Unit)?` when emitting a purchase/restore request. When `TransactionResult` arrives, it invokes the callback and nullifies it.

**Race guard:** Before storing a new `pendingProcessAction`, the wrapper cancels any existing one by calling `pendingProcessAction?.invoke(false)` — this prevents a second interceptor action from silently overwriting and orphaning the first callback.

### Interceptor Rules

| Action | Observer mode | Full mode |
|--------|---------------|-----------|
| PURCHASE | Store processAction, emit PurchaseRequest | proceed(true) |
| RESTORE | Store processAction, emit RestoreRequest | proceed(true) |
| LOGIN | proceed(false) | proceed(false) |
| NAVIGATE | Open URL, proceed(false) | Open URL, proceed(false) |
| Other | proceed(true) | proceed(true) |

### TransactionResult Handling

| Result | Wrapper actions |
|--------|-----------------|
| Success | synchronize() → processAction(false) → onTransactionCompleted?.invoke() |
| Cancelled | processAction(false) |
| Error | processAction(false) |
| Idle | ignore |

### PurchaseManager Rules

- **Zero Purchasely/SDK imports** — pure native billing service
- Observes purchase/restore requests from reactive channels
- Emits `TransactionResult` back through reactive channels
- Android: takes `billingClientFactory` lambda for testability
- iOS: takes injected closures for `anonymousUserId` and `signPromotionalOffer`

---

## 3. SDK Initialization

**Rule: `PurchaselyWrapper.initialize()` is the single entry point for SDK setup. The app entry point only calls `wrapper.initialize()` and handles the ready callback.**

**Android:** `Application.onCreate()` calls `wrapper.initialize(application, apiKey, logLevel)`
**iOS:** `AppViewModel.init()` calls `wrapper.initialize(apiKey:, appUserId:, logLevel:, onReady:)`

The wrapper internally configures:
1. SDK start with API key, running mode, StoreKit settings
2. Event listener/delegate
3. Paywall actions interceptor
4. Deeplink readiness
5. Combine/Flow subscriptions for Observer purchase flow

### Restart on mode change

When the SDK mode changes (Full ↔ Observer), `wrapper.restart()` is called:

- **Android:** Settings layer calls `purchaselyWrapper.restart()` directly. `restart()` → `close()` → `initialize()`. `close()` cancels the transaction result collection job, clears any pending process action, then stops the SDK. `initialize()` restarts the collection.
- **iOS:** Settings layer posts a `.purchaselySdkModeDidChange` notification, the wrapper observes it and calls `restart()` internally.

---

## 4. Presentation Loading: Always fetch then build/display

**Rule: Always use `Purchasely.fetchPresentation()` followed by `presentation.buildView()` or `presentation.display()`. Never use `Purchasely.presentationView()`.**

### Why

- `fetchPresentation` + `buildView` / `display` gives full control over the presentation lifecycle
- You can inspect `presentation.type` before deciding what to do (NORMAL, CLIENT, DEACTIVATED)
- You can handle errors from the fetch step separately from display errors
- `presentationView()` is a convenience shortcut that hides these steps — unsuitable for production code

### Pattern

```kotlin
// In PurchaselyWrapper
suspend fun loadPresentation(placementId: String): FetchResult {
    // Uses suspend Purchasely.fetchPresentation() internally
    // Maps result to FetchResult sealed class
    // Catches exceptions and returns FetchResult.Error
}

// For modal display
suspend fun display(handle: PresentationHandle, activity: Activity): DisplayResult  // Android
func display(presentation: PLYPresentation, from viewController: UIViewController?) // iOS

// For inline/embedded display
fun getView(handle: PresentationHandle, context: Context, onResult): View?          // Android
func getController(presentation: PLYPresentation) -> PLYPresentationViewController? // iOS
```

---

## 5. MVVM Pattern: ViewModel Owns Paywall Logic

**Rule: ViewModels decide when and what to show. Screens only provide the Activity/ViewController and render the UI.**

### Prefetch pattern

All presentations must be prefetched by the ViewModel on init (if not premium). This ensures paywalls are ready to display instantly when the user interacts.

```kotlin
init {
    prefetchPresentations()
}

private fun prefetchPresentations() {
    if (isPremium.value) return
    viewModelScope.launch {
        _filtersPresentation.value = purchaselyWrapper.loadPresentation("filters")
    }
    viewModelScope.launch {
        _inlinePresentation.value = purchaselyWrapper.loadPresentation("inline")
    }
}
```

### Modal paywall flow (Android)

1. ViewModel prefetches the presentation on init, exposes `placementPresentation: StateFlow<FetchResult?>` and `isLoading: StateFlow<Boolean>`
2. Screen shows a loader on the trigger element while loading, the regular UI once ready
3. User taps trigger → ViewModel checks if presentation is ready (`FetchResult.Success`)
4. If ready, ViewModel emits the `PresentationHandle` via `SharedFlow<PresentationHandle>`
5. Screen collects the handle, resolves `Activity` from `LocalContext`, calls `wrapper.display(handle, activity)` directly
6. Screen reports the result back to the ViewModel via `viewModel.onPaywallDismissed()`
7. If presentation is still loading or failed, the tap is ignored (loader is visible)

**Why the Screen handles display (not the ViewModel):**
- The SDK requires an `Activity` to display modal paywalls — a framework concern
- The ViewModel cannot hold an Activity reference (lifecycle leak)
- The ViewModel emits a `PresentationHandle` (opaque, SDK-free) via `SharedFlow`
- The Screen — which already has `LocalContext` — resolves the Activity and calls `wrapper.display()`
- `PurchaselyWrapper` is injected in the Screen via DI for this purpose

### Embedded paywall flow

1. ViewModel prefetches the presentation on init, exposes `inlinePresentation: StateFlow<FetchResult?>`
2. Screen observes the state — when `FetchResult.Success`, passes it to an embedded banner component
3. If fetch failed or is still loading, nothing is displayed (no crash, no empty space)
4. Use `FetchResult.Success.height` (pixels on Android — convert to dp; points on iOS — use as `CGFloat`) for the view height

### Prefetch cache (iOS)

`PurchaselyWrapper.loadPresentation` should consult an in-memory `PresentationCache`, keyed by `placementId[/contentId]`. First call fetches over the network, subsequent calls return the cached `FetchResult` instantly. This prevents:

- Duplicate network calls when SwiftUI `.onAppear` fires repeatedly (nav back, sheet dismiss, etc.)
- Accumulation of stale `flowSteps` entries in the SDK's `FlowsManager` for flow placements — a known SDK issue where each fetch appends a new entry and dismissing the only visible step leaves a stuck `PLYWindow`.

**Cache invalidation triggers (iOS):**
- `PLYUserAttributeDelegate.onUserAttributeSet` / `onUserAttributeRemoved` — any attribute change can alter audience targeting
- Successful `Purchasely.synchronize()` — subscription state may have changed
- `wrapper.restart()` — SDK mode change (Full ↔ Observer) resets the session

> **Note:** Invalidation is coarse-grained (`invalidateAll`) because the SDK doesn't expose attribute → audience dependencies. This is the simplest correct approach; native placement-level caching is expected in Purchasely SDK 6.x and the app-side cache should be removed then.

> **Note on `onResult` binding:** The `onResult` closure is captured by the SDK at first fetch. On cache hits, the original binding is reused — subsequent callers' `onResult` closures are ignored. This is safe when all closures perform the same work (e.g., refresh premium on purchased/restored).

**Android:** Same cache concept applies. The Android SDK doesn't (yet) expose a user-attribute delegate as public API — invalidation is currently tied to explicit `wrapper.synchronize()` and `wrapper.restart()` calls only. When Android gets a delegate (SDK 6.x), wire it up the same way.

---

## 6. Embedded Paywalls: Reusable Inline Component

**Rule: Use a reusable `EmbeddedScreenBanner` component for any inline/embedded paywall display. The presentation must be prefetched by the ViewModel.**

```kotlin
// Android — only render when prefetch succeeded
val inlineResult by viewModel.inlinePresentation.collectAsStateWithLifecycle()
if (inlineResult is FetchResult.Success) {
    val heightModifier = if (inlineResult.height > 0) {
        Modifier.height(inlineResult.height.dp)
    } else {
        Modifier.heightIn(max = 200.dp)
    }
    EmbeddedScreenBanner(
        fetchResult = inlineResult as FetchResult.Success,
        onResult = { viewModel.onPaywallDismissed() },
        modifier = Modifier.fillMaxWidth().then(heightModifier)
    )
}
```

### Behavior

- Accepts a prefetched `FetchResult.Success` (ViewModel owns the fetch)
- Builds the view via `PurchaselyWrapper.getView()` / `getController()` using `remember` (Android) or `UIViewControllerRepresentable` (iOS)
- Renders via `AndroidView` (Android) / `UIViewControllerRepresentable` (iOS)
- Uses `presentation.height` for view height (dp on Android, points on iOS)
- If height is 0, falls back to a sensible max (e.g., 200.dp / 200pt)
- `onResult` forwards purchase events to the ViewModel
- If fetch failed, the banner is simply not shown (Screen checks for `FetchResult.Success`)

---

## 7. User Attributes

**Rule: Set user attributes through `PurchaselyWrapper`, always from the ViewModel layer.**

```kotlin
// In ViewModel
purchaselyWrapper.setUserAttribute("has_used_search", true)
purchaselyWrapper.incrementUserAttribute("cocktails_viewed")
purchaselyWrapper.setUserAttribute("favorite_spirit", "gin")
```

### When to set attributes

- On meaningful user actions (search, view detail, add favorite)
- On preference changes (theme, user ID)
- Never on every recomposition — only on actual state changes

**Typed overloads:** The wrapper should provide `String`, `Boolean`, `Int`, and `Float` / `Double` overloads matching the SDK.

---

## 8. Handling Presentation Types

Always handle all `FetchResult` variants:

| Type | Action |
|------|--------|
| `Success` | Display or build view normally |
| `Client` | App must build its own paywall UI using plan data from the presentation |
| `Deactivated` | Do nothing — placement is disabled in the Purchasely console |
| `Error` | Log the error, fail gracefully (no crash, no empty screen) |

---

## 9. Error Handling

- **Never crash on SDK errors.** Log and degrade gracefully.
- **Never block the UI** waiting for a presentation. Use coroutines / async-await and show content immediately.
- **Embedded views:** If fetch fails, the banner simply doesn't appear.
- **Modal paywalls:** If fetch fails, the user action is silently ignored (with a log).

---

## 10. Async: Native Async Patterns

**Rule: Use the platform's native async pattern. Only use callbacks when the SDK doesn't provide an alternative.**

### Android (Kotlin)

- `loadPresentation()` — uses the native suspend `Purchasely.fetchPresentation()`
- `display()` — wraps the callback-based `display(activity)` with `suspendCoroutine`
- `getView()` — keeps callbacks because `buildView()` returns a `View?` synchronously; the callback fires later on purchase events

### iOS (Swift)

- `loadPresentation()` — uses `async/await` with `withCheckedContinuation` to bridge `fetchPresentation(for:, fetchCompletion:, completion:)`; the `onResult` callback is bound at fetch time via the `completion` closure
- `display()` — synchronous, calls `presentation.display(from:)` on main thread; result delivered through the `onResult` callback from fetch
- `getController()` — returns the presentation's `UIViewController` for embedding

---

## 11. Testability

**Rule: All Purchasely integration code must be testable. ViewModels use dependency injection for the wrapper.**

### Protocol-based mocking (iOS)

`PurchaselyWrapping` protocol abstracts the wrapper. ViewModels accept `PurchaselyWrapping` via init with default `PurchaselyWrapper.shared`. Tests inject `MockPurchaselyWrapper`.

### DI-based mocking (Android)

`PurchaselyWrapper` is injected via Koin/Hilt constructor. Tests use MockK to mock it with `mockk<PurchaselyWrapper>(relaxed = true)`.

### PurchaseManager testability

- **Android:** Constructor takes `billingClientFactory: (PurchasesUpdatedListener) -> BillingClient` — tests inject a mock BillingClient
- **iOS:** Uses injected closures (`anonymousUserIdProvider`, `signPromotionalOfferProvider`) instead of direct wrapper access

### Repository testability (Android)

Repositories that need persistent storage (`FavoritesRepository`, `OnboardingRepository`, `RunningModeRepository`, `SettingsRepository`) accept a `KeyValueStore` interface instead of `Context` / `SharedPreferences`. Tests use `InMemoryKeyValueStore` — no Android framework needed.

### Repository testability (iOS)

Repositories that need persistent storage accept custom `UserDefaults` for test isolation. Data repositories accept the data array directly for test data.

---

## 12. Platform-Specific Notes

### Android (Kotlin / Jetpack Compose)

- `PurchaselyWrapper` is a Koin/Hilt singleton with DI constructor: `PurchaselyWrapper(runningModeRepo, purchaseRequests, restoreRequests, transactionResult, scope)`
- `Application.onCreate()` calls `wrapper.initialize(application, apiKey, logLevel, onConfigured)` — nothing else. `onConfigured` triggers `premiumRepository.refreshPremiumStatus()`.
- `PremiumManagerImpl` implements a `PremiumRepository` interface and injects `PurchaselyWrapper` (no direct SDK calls). Wired via `onTransactionCompleted` callback in DI module.
- `PLYPresentation` is wrapped in `PresentationHandle` (`@JvmInline value class`). ViewModels emit `SharedFlow<PresentationHandle>` for modal paywalls; Screens resolve Activity and call `wrapper.display(handle, activity)`.
- Repositories accept `KeyValueStore` interface — no `Context` dependency. DI injects `SharedPreferencesKeyValueStore` in production, `InMemoryKeyValueStore` in tests.
- Domain layer (`domain/repository/`) defines interfaces; `data/` contains `*Impl` implementations.
- ViewModels inject repository interfaces, not concrete classes.
- Embedded banner Composables use `koinInject()` (or equivalent) for DI in Composables
- `buildView()` returns `PLYPresentationView?` (extends `FrameLayout`)

### iOS (SwiftUI)

- `PurchaselyWrapper` is a Swift singleton (`PurchaselyWrapper.shared`) conforming to `PurchaselyWrapping`
- `AppViewModel.init()` calls `wrapper.initialize(apiKey:, appUserId:, logLevel:, onReady:)` — nothing else
- ViewModels accept `PurchaselyWrapping` via init with default `.shared`
- Async operations use Swift `async/await` (`withCheckedContinuation` to bridge callbacks)
- `loadPresentation()` is `async` and takes an `onResult` callback for purchase/dismiss events
- `display()` is synchronous — calls `presentation.display(from: viewController)` on main thread
- `getController()` returns `PLYPresentationViewController?` for embedding via `UIViewControllerRepresentable`
- Embedded banner is a `UIViewControllerRepresentable` wrapping the presentation's controller
- Screen resolves a `UIViewController` via a `ViewControllerResolver` for modal display
- `presentation.height` is in points (use as `CGFloat` directly in `.frame(height:)`)
- Prefetch is triggered from `onAppear` since `@StateObject` init doesn't have access to `@EnvironmentObject`

---

## Checklist for New Purchasely Integrations

- [ ] All SDK calls go through `PurchaselyWrapper`
- [ ] Screens/Views have zero `io.purchasely` / `import Purchasely` imports
- [ ] Uses `loadPresentation()` + `display()` / `getView()` / `getController()`, never `presentationView()` or `presentationController()`
- [ ] Presentations are prefetched by the ViewModel (Android: `init`, iOS: `onAppear`)
- [ ] Handles all `FetchResult` variants (success, client, deactivated, error)
- [ ] User attributes set from ViewModel, not Screen
- [ ] Modal paywalls (Android): ViewModel prefetches, emits `SharedFlow<PresentationHandle>`, Screen resolves Activity and calls `wrapper.display(handle, activity)`
- [ ] Modal paywalls (iOS): ViewModel prefetches, shows loader while loading, Screen provides ViewController on display
- [ ] Embedded paywalls: ViewModel prefetches, Screen uses an embedded banner component with the prefetched result/controller
- [ ] Uses `presentation.height` (dp / points) for embedded view sizing
- [ ] No crashes on SDK errors — nothing shown if fetch fails
- [ ] SDK init and interceptor are in `PurchaselyWrapper.initialize()` — NOT in App class
- [ ] Observer mode purchases flow through `PurchaseManager` via reactive subjects (not direct wrapper calls)
- [ ] `PurchaseManager` has zero Purchasely / SDK imports
- [ ] Login/logout, restore, consent, synchronize go through wrapper in ViewModels
- [ ] SDK types (`PLYRunningMode`, `PLYDataProcessingPurpose`, etc.) are tolerated as direct imports
- [ ] Android Screens use `collectAsStateWithLifecycle()` (not `collectAsState()`) for lifecycle-aware collection
- [ ] Tests use `MockPurchaselyWrapper` (iOS) or MockK (Android) — never the real SDK
