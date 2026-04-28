# Purchasely SDK — Architecture Patterns

Recommended architecture patterns for production-grade Purchasely SDK integrations.

> **None of the patterns below are required.** The Purchasely SDK works perfectly when called directly from ViewModels or UI code — that is a fully supported integration. Suggest these patterns only when the team explicitly asks about testability, SDK isolation, or production-grade architecture; do not flag a direct integration as "wrong".

---

## 1. Wrapper Pattern (recommended)

**Recommendation: For larger codebases or teams that value testability and SDK isolation, route all SDK calls through a single dedicated class — commonly called `PurchaselyWrapper`. This is a best practice, not a requirement — direct SDK use is fully supported.**

> The class name is up to you. `PurchaselyWrapper`, `PurchaselyService`, `PurchaselyGateway`, `IAPManager`, `BillingService`, … any name works. What matters is the **concept**: one place that owns all calls into the Purchasely SDK. The rest of this document does **not** assume any specific wrapper name and refers to Purchasely SDK APIs directly.

### Why

- Single point of control for all SDK interactions — easy to swap with a stub for removal
- Screens / Views have zero `io.purchasely` / `import Purchasely` imports — clean separation
- Easier to test (mock the wrapper, not the SDK)
- Consistent error handling and result mapping
- Type-safe app-side result types instead of raw SDK enums

### What the wrapper typically owns

| Category | Purchasely APIs it encapsulates |
|----------|--------------------------------|
| **Init & Lifecycle** | `Purchasely.start(...)`, `Purchasely.stop()`, `Purchasely.close()`, `Purchasely.closeDisplayedPresentation()` |
| **Interceptor** | `Purchasely.setPaywallActionsInterceptor { ... }` (LOGIN, NAVIGATE, PURCHASE, RESTORE) |
| **Events** | `Purchasely.setEventListener(...)` / `PLYEventDelegate` |
| **Presentations** | `Purchasely.fetchPresentation(...)`, `PLYPresentation.display(...)`, `PLYPresentation.buildView(...)` (Android) / `PLYPresentation.controller` (iOS) |
| **User Attributes** | `Purchasely.setUserAttribute(...)`, `Purchasely.incrementUserAttribute(...)` |
| **User Management** | `Purchasely.userLogin(...)`, `Purchasely.userLogout()`, `Purchasely.anonymousUserId` |
| **Purchases** | `Purchasely.restoreAllProducts(...)`, `Purchasely.synchronize(...)`, `Purchasely.signPromotionalOffer(...)` (iOS) |
| **Consent** | `Purchasely.setUserAttribute(forDataProcessingPurposes:...)` (iOS) / equivalent on Android |
| **Info** | `Purchasely.sdkVersion`, `Purchasely.isDeeplinkHandled(...)` |

### SDK types you can keep visible to the rest of the app

`PLYRunningMode`, `PLYDataProcessingPurpose`, `PLYPresentationAction`, `PLYPresentationInfo`, `PLYPresentationActionParameters`, `PLYPresentationViewController`, `EventListener` / `PLYEventDelegate`, `PLYOfferSignature`, `LogLevel` / `PLYLogger.PLYLogLevel` — these are enums / types needed for configuration, interceptor logic, and presentation handling. They are not SDK call points so leaking them outside the wrapper is fine.

> **Android tip:** If you want to keep `PLYPresentation` itself out of ViewModels / Screens, wrap it in an opaque value class (e.g. `@JvmInline value class PresentationHandle(...)`). Optional.

### Platform implementation hints

**Android (Kotlin):**
- Singleton via DI (Koin / Hilt / manual) so ViewModels receive it via constructor injection
- App entry point calls a single `initialize(application, apiKey, logLevel)` that wraps `Purchasely.start(...)`

**iOS (Swift):**
- Singleton + protocol (`PurchaselyWrapping` or any name) so ViewModels accept the protocol type and tests inject a mock implementation
- App entry point calls a single `initialize(apiKey:, appUserId:, logLevel:, onReady:)` that wraps `Purchasely.start(...)`

---

## 2. Observer Mode: Reactive Purchase Flow (optional)

**Recommendation: In Observer mode you can decouple the native billing service from the Purchasely SDK using reactive flows. This pattern works well alongside the wrapper above. Teams that prefer to call `Purchasely.synchronize()` directly from their billing client also have a fully valid Observer integration.**

### Architecture

```
Purchasely interceptor                     Native billing service
    │                                           │
    │ PURCHASE (observer) ──────────────────►   │
    │   emit PurchaseRequest                     │
    │                                           │ Native billing
    │                                           │ (Play Billing / StoreKit 2)
    │   ◄────────────────────────────────────   │
    │   TransactionResult                        │
    │                                           │
    │ Purchasely.synchronize()                   │
    │ proceed(false)                             │
    │ refresh entitlement state                  │
```

### Communication channels

**Android (Kotlin):** `SharedFlow<PurchaseRequest>` / `SharedFlow<RestoreRequest>` from the interceptor side, `SharedFlow<TransactionResult>` from the billing side. The billing service takes a `billingClientFactory` lambda for testability — no hardcoded `BillingClient`.

**iOS (Swift):** `PassthroughSubject<PurchaseRequest, Never>` and `PassthroughSubject<TransactionResult, Never>`. The billing service takes injected closures for `Purchasely.anonymousUserId` and `Purchasely.signPromotionalOffer(...)` — it never references the wrapper directly.

### Suggested types

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

### `proceed` callback handling

When the interceptor receives `PURCHASE` / `RESTORE` (in Observer mode), store the `proceed: (Boolean) -> Unit` closure once and emit a `PurchaseRequest` / `RestoreRequest`. When the matching `TransactionResult` arrives, invoke the stored `proceed` and clear it.

**Race guard:** Before storing a new `proceed`, cancel any existing one with `proceed?.invoke(false)` — this prevents a second interceptor action from silently overwriting and orphaning the first callback.

### Interceptor rules

| Action | Observer mode | Full mode |
|--------|---------------|-----------|
| PURCHASE | Store `proceed`, emit PurchaseRequest | proceed(true) |
| RESTORE | Store `proceed`, emit RestoreRequest | proceed(true) |
| LOGIN | proceed(false) | proceed(false) |
| NAVIGATE | Open URL, proceed(false) | Open URL, proceed(false) |
| Other | proceed(true) | proceed(true) |

### TransactionResult handling

| Result | Actions |
|--------|---------|
| Success | `Purchasely.synchronize(...)` → `proceed(false)` → refresh entitlements |
| Cancelled | `proceed(false)` |
| Error | `proceed(false)` |
| Idle | ignore |

### Native billing service rules

- **Zero Purchasely / SDK imports** — pure native billing service
- Observes purchase / restore requests from reactive channels
- Emits `TransactionResult` back through reactive channels
- Android: takes `billingClientFactory` lambda for testability
- iOS: takes injected closures for `anonymousUserId` and `signPromotionalOffer`

---

## 3. SDK Initialization

**Rule: `Purchasely.start(...)` is the only entry point that brings the SDK up. Call it once at app launch, then configure the event listener / delegate and the paywall actions interceptor right after.**

**Android:** `Application.onCreate()` calls `Purchasely.start(...)` then sets the event listener and the interceptor.
**iOS:** App start (e.g., `App.init` / `AppDelegate`) calls `Purchasely.start(...)` then sets the event delegate and the interceptor.

What needs to happen at init:
1. `Purchasely.start(...)` with API key, running mode, StoreKit settings
2. Event listener / delegate
3. Paywall actions interceptor
4. Deeplink readiness flag
5. (Observer mode only) Reactive subscriptions for the purchase flow

### Restart on running-mode change

When the SDK running mode changes (Full ↔ Observer), call `Purchasely.close()` then `Purchasely.start(...)` again — the SDK does not let you toggle the running mode in place. Cancel any pending purchase / restore callbacks before closing so they do not orphan.

---

## 4. Presentation Loading: Always fetch, then build / display

**Rule: Always use `Purchasely.fetchPresentation(...)` followed by `presentation.display(...)` (modal) or `presentation.buildView(...)` / `presentation.controller` (embedded). Avoid `Purchasely.presentationView(...)` / `presentationController(...)`.**

### Why

- `fetchPresentation` + `display` / `buildView` gives full control over the presentation lifecycle
- You can inspect `presentation.type` before deciding what to do (`NORMAL`, `CLIENT`, `DEACTIVATED`)
- You can handle errors from the fetch step separately from display errors
- `presentationView()` / `presentationController()` are convenience shortcuts that hide these steps — unsuitable when you need fine-grained control

### Pattern

```kotlin
// Android — suspend fetch, then display or buildView
val result = Purchasely.fetchPresentation(context, placementId)
result.presentation?.display(activity) { displayResult, plan -> /* ... */ }
// or for embedded:
val view = result.presentation?.buildView(context) { displayResult, plan -> /* ... */ }
```

```swift
// iOS — async/await bridge then display or controller
let presentation = try await fetchPresentation(for: placementId)
presentation.display(from: viewController)
// or for embedded:
let controller = presentation.controller
```

> Map fetch outcomes to a small app-side sealed type (e.g. `FetchResult.Success(presentation, height)` / `Client(...)` / `Deactivated` / `Error(message)`) so the rest of the app does not depend on raw SDK error types.

---

## 5. MVVM Pattern: ViewModel Owns Paywall Logic

**Rule: ViewModels decide when and what to show. Screens only provide the Activity / ViewController and render the UI.**

### Prefetch pattern

Prefetch presentations in the ViewModel on init (skip if already premium). This ensures paywalls are ready to display instantly when the user interacts.

```kotlin
init {
    if (!isPremium.value) {
        viewModelScope.launch {
            _filtersPresentation.value = fetchPresentationSafely("filters")
        }
        viewModelScope.launch {
            _inlinePresentation.value = fetchPresentationSafely("inline")
        }
    }
}

private suspend fun fetchPresentationSafely(placementId: String): FetchResult =
    runCatching { Purchasely.fetchPresentation(context, placementId).toFetchResult() }
        .getOrElse { FetchResult.Error(it.message) }
```

### Modal paywall flow

1. ViewModel prefetches, exposes `placementPresentation: StateFlow<FetchResult?>` and `isLoading: StateFlow<Boolean>`
2. Screen shows a loader on the trigger while loading, the regular UI once ready
3. User taps trigger → ViewModel checks if presentation is ready (`FetchResult.Success`)
4. If ready, ViewModel emits the presentation reference (or an opaque handle) via `SharedFlow`
5. Screen collects, resolves the `Activity` / `ViewController`, calls `presentation.display(...)` directly
6. Screen reports the result back to the ViewModel (e.g. `viewModel.onPaywallDismissed()`)
7. If presentation is still loading or failed, the tap is ignored (loader is visible)

**Why the Screen handles display:** the SDK requires an `Activity` / `ViewController` to display modal paywalls, which the ViewModel cannot hold without leaking. The ViewModel emits the data, the Screen owns the framework concern.

### Embedded paywall flow

1. ViewModel prefetches, exposes the `FetchResult` as state
2. Screen observes — when `FetchResult.Success`, passes it to the embedded banner component
3. If fetch failed or is still loading, nothing is displayed (no crash, no empty space)
4. Use `presentation.height` (pixels on Android — convert to dp; points on iOS — use as `CGFloat`) for the view height

### Prefetch cache (optional, recommended on iOS for flow placements)

Caching `Purchasely.fetchPresentation(...)` results in memory (keyed by `placementId[/contentId]`) is a useful optimization, **not a requirement**. First call fetches over the network, subsequent calls return the cached result instantly. It prevents:

- Duplicate network calls when SwiftUI `.onAppear` fires repeatedly (nav back, sheet dismiss, etc.)
- Accumulation of stale `flowSteps` entries in the SDK's `FlowsManager` for **flow** placements — a known SDK issue where each fetch appends a new entry and dismissing the only visible step leaves a stuck `PLYWindow`. Caching avoids re-fetching the same flow.

**Cache invalidation triggers (when you adopt this cache):**
- `PLYUserAttributeDelegate.onUserAttributeSet` / `onUserAttributeRemoved` (iOS) — any attribute change can alter audience targeting
- Successful `Purchasely.synchronize()` — subscription state may have changed
- Running-mode change (Full ↔ Observer) — the session is reset

> **Note:** Invalidation is coarse-grained (clear all) because the SDK does not expose attribute → audience dependencies. This is the simplest correct approach; native placement-level caching is expected in Purchasely SDK 6.x and the app-side cache should be removed then.

> **Note on `onResult` binding:** The `onResult` closure is captured by the SDK at first fetch. On cache hits, the original binding is reused — subsequent callers' `onResult` closures are ignored. This is safe when all closures perform the same work (e.g., refresh entitlements on purchased / restored).

> **Android:** the same cache concept applies. The Android SDK does not (yet) expose a public user-attribute delegate, so invalidation is currently limited to explicit `Purchasely.synchronize()` and running-mode changes. When Android exposes the delegate (SDK 6.x), wire it up the same way.

---

## 6. Embedded Paywalls: Reusable Inline Component

**Rule: Wrap inline / embedded paywalls in a reusable component. The presentation should be prefetched by the ViewModel.**

```kotlin
// Android — only render when prefetch succeeded
val inlineResult by viewModel.inlinePresentation.collectAsStateWithLifecycle()
if (inlineResult is FetchResult.Success) {
    val height = (inlineResult as FetchResult.Success).height
    val heightModifier = if (height > 0) Modifier.height(height.dp) else Modifier.heightIn(max = 200.dp)
    EmbeddedScreenBanner(
        fetchResult = inlineResult as FetchResult.Success,
        onResult = { viewModel.onPaywallDismissed() },
        modifier = Modifier.fillMaxWidth().then(heightModifier)
    )
}
```

### Behavior

- Accepts a prefetched `FetchResult.Success` (ViewModel owns the fetch)
- Builds the view via `PLYPresentation.buildView(...)` (Android) or wraps `PLYPresentation.controller` (iOS) in `UIViewControllerRepresentable`
- Renders via `AndroidView` (Android) / `UIViewControllerRepresentable` (iOS)
- Uses `presentation.height` for view height (dp on Android, points on iOS)
- If height is 0, falls back to a sensible max (e.g., 200.dp / 200pt)
- `onResult` forwards purchase events to the ViewModel
- If fetch failed, the banner is simply not shown

---

## 7. User Attributes

**Rule: Set user attributes from the ViewModel layer (not the Screen). The SDK call is `Purchasely.setUserAttribute(...)` / `Purchasely.incrementUserAttribute(...)`.**

```kotlin
// In ViewModel
Purchasely.setUserAttribute("has_used_search", true)
Purchasely.incrementUserAttribute("cocktails_viewed")
Purchasely.setUserAttribute("favorite_spirit", "gin")
```

### When to set attributes

- On meaningful user actions (search, view detail, add favorite)
- On preference changes (theme, user ID)
- Never on every recomposition / re-render — only on actual state changes

**Typed APIs:** the SDK provides typed overloads (`String`, `Boolean`, `Int`, `Float` / `Double`, `Date`). Pick the typed call rather than stringifying values.

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
- **Embedded views:** if fetch fails, the banner simply does not appear.
- **Modal paywalls:** if fetch fails, the user action is silently ignored (with a log).

---

## 10. Async: Native Async Patterns

**Rule: Use the platform's native async pattern. Only use callbacks when the SDK does not provide an alternative.**

### Android (Kotlin)

- `Purchasely.fetchPresentation(...)` — `suspend` API, call directly from a coroutine
- `presentation.display(activity)` — callback-based; bridge with `suspendCoroutine` if you want a `suspend` API
- `presentation.buildView(context)` — synchronous (returns `View?`); the `onResult` callback fires later on purchase events

### iOS (Swift)

- `Purchasely.fetchPresentation(for:, fetchCompletion:, completion:)` — bridge to `async/await` with `withCheckedContinuation`; the `onResult` callback is bound at fetch time via the `completion` closure
- `presentation.display(from:)` — synchronous, must be called on main thread; result delivered through the `onResult` callback from fetch
- `presentation.controller` — returns `PLYPresentationViewController?` for embedding

---

## 11. Testability

**Rule: Make Purchasely integration code testable by injecting a seam between your code and `Purchasely`.**

### Protocol-based mocking (iOS)

Define a protocol (e.g. `PurchaselyWrapping`) that mirrors the SDK calls your app uses. ViewModels accept the protocol type via init with a default real implementation. Tests inject a mock implementation.

### DI-based mocking (Android)

Inject the wrapper class via Koin / Hilt constructor. Tests use MockK: `mockk<MyPurchaselyWrapper>(relaxed = true)`.

### Native billing service testability

- **Android:** constructor takes `billingClientFactory: (PurchasesUpdatedListener) -> BillingClient` — tests inject a mock `BillingClient`
- **iOS:** uses injected closures (`anonymousUserIdProvider`, `signPromotionalOfferProvider`) instead of direct SDK access

### Repository testability (Android)

Repositories that need persistent storage (favorites, onboarding flag, running mode, settings) accept a `KeyValueStore` interface instead of `Context` / `SharedPreferences`. Tests use an in-memory implementation — no Android framework needed.

### Repository testability (iOS)

Repositories that need persistent storage accept a custom `UserDefaults` for test isolation. Data repositories accept the data array directly for test data.

---

## 12. Platform-Specific Notes

### Android (Kotlin / Jetpack Compose)

- `Purchasely.start(...)` runs in `Application.onCreate()` along with `setEventListener(...)` and `setPaywallActionsInterceptor { ... }`
- `PLYPresentation.buildView(context)` returns `PLYPresentationView?` (extends `FrameLayout`) — wrap with `AndroidView` in Compose
- Domain layer (`domain/repository/`) defines interfaces; `data/` contains `*Impl` implementations — ViewModels depend on interfaces, not concrete classes
- Repositories accept a `KeyValueStore` interface — DI injects `SharedPreferencesKeyValueStore` in production, an in-memory store in tests
- Embedded banner Composables can pull dependencies via `koinInject()` (or equivalent) when needed
- Screens use `collectAsStateWithLifecycle()` (not `collectAsState()`) for lifecycle-aware Flow collection

### iOS (SwiftUI)

- `Purchasely.start(...)` runs at app start (e.g., `App.init` or `AppDelegate.application(_:didFinishLaunchingWithOptions:)`) along with the event delegate and paywall actions interceptor
- Async operations use Swift `async/await` — bridge SDK callbacks with `withCheckedContinuation`
- `presentation.controller` returns `PLYPresentationViewController?` for embedding via `UIViewControllerRepresentable`
- Embedded banner is a `UIViewControllerRepresentable` wrapping `presentation.controller`
- Modal display: resolve a `UIViewController` (e.g., via a `ViewControllerResolver` helper) and call `presentation.display(from:)`
- `presentation.height` is in points — use as `CGFloat` directly in `.frame(height:)`
- Prefetch from `onAppear` since `@StateObject` init does not have access to `@EnvironmentObject`

---

## Checklist for Production-Grade Integrations

> These items are **best-practice signals**, not pass / fail criteria. A perfectly valid integration may not adopt any of them. Use them as conversation starters when the team has explicitly asked for an architecture review.

### Universal (apply regardless of architecture choice)

- [ ] Uses `Purchasely.fetchPresentation(...)` + `display(...)` / `buildView(...)` / `controller`, not the deprecated `presentationView(...)` / `presentationController(...)`
- [ ] Presentations are prefetched (Android: in ViewModel `init`, iOS: from `onAppear`) when the user is not already premium
- [ ] Handles all `FetchResult` variants: success, client, deactivated, error
- [ ] No crashes on SDK errors — nothing is shown if fetch fails
- [ ] Uses `presentation.height` (dp on Android, points on iOS) for embedded view sizing
- [ ] User attributes are set on actual state changes, not on every recomposition / re-render
- [ ] Android Screens use `collectAsStateWithLifecycle()` (not `collectAsState()`) for lifecycle-aware collection
- [ ] `Purchasely.start(...)`, the event listener / delegate and the paywall actions interceptor are configured once at app start

### Recommended when adopting the wrapper pattern

- [ ] All Purchasely SDK calls are routed through a single dedicated class
- [ ] Screens / Views have zero `io.purchasely` / `import Purchasely` imports
- [ ] Modal paywalls (Android): ViewModel prefetches, emits the presentation reference via `SharedFlow`, Screen resolves Activity and calls `presentation.display(activity)` (typically via the wrapper)
- [ ] Modal paywalls (iOS): ViewModel prefetches, shows a loader while loading, Screen provides the ViewController on display
- [ ] Embedded paywalls: ViewModel prefetches, Screen uses a reusable banner component with the prefetched result / controller
- [ ] Login / logout, restore, consent, synchronize go through the wrapper from ViewModels
- [ ] SDK enum / type imports (`PLYRunningMode`, `PLYDataProcessingPurpose`, etc.) are tolerated outside the wrapper
- [ ] Tests use a mock implementation of the wrapper (iOS protocol mock or MockK on Android) — never the real SDK

### Recommended when using the reactive Observer-mode flow

- [ ] Observer-mode purchases flow through a native billing service via reactive subjects (not direct SDK calls inside the billing service)
- [ ] The native billing service has zero Purchasely / SDK imports

### Recommended when adopting the prefetch cache (iOS especially)

- [ ] In-memory cache keyed by `placementId[/contentId]`, populated on first `Purchasely.fetchPresentation(...)`
- [ ] Cache invalidated on user-attribute changes (iOS), successful `Purchasely.synchronize()`, and running-mode change
