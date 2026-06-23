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

> The APIs below are the **native v6** entry points (iOS Swift / Android Kotlin). Flutter is also on **v6** and follows the same model with its own Dart API (`PurchaselyBuilder`, `PresentationBuilder` / `PresentationRequest`, `Purchasely.interceptAction(...)` returning `InterceptResult`, `presentation.close()`). React Native is also on **v6** with its own JS/TS API: `Purchasely.builder('KEY')....start()`, `Purchasely.presentation.placement(id).build()` (a `PresentationRequest` with `.preload()` / `.display()` / `.close()`), `Purchasely.interceptAction('purchase', handler)` returning a `'success' | 'failed' | 'notHandled'` string, and the embedded `PLYPresentationView` component. Cordova remains on v5 and uses its own v5 method names.

| Category | Purchasely APIs it encapsulates |
|----------|--------------------------------|
| **Init & Lifecycle** | `Purchasely.apiKey(...)....start()` (iOS) / `Purchasely { ... }` or `Purchasely.Builder(...).build().start { ... }` (Android), `Purchasely.close()`, `Purchasely.closeAllScreens()` |
| **Interceptor** | per-action `Purchasely.interceptAction(...) { ... }` returning `PLYInterceptResult` (LOGIN, NAVIGATE, PURCHASE, RESTORE) |
| **Events** | `Purchasely.setEventListener(...)` / `PLYEventDelegate` |
| **Presentations** | `PLYPresentationBuilder` (iOS) / `PLYPresentation { ... }` (Android), `.build().preload()`, `presentation.display(...)`, `presentation.buildView(...)` / `getFragment(...)` (Android) / `presentation.controller` / `presentation.swiftUIView` (iOS) |
| **User Attributes** | `Purchasely.setUserAttribute(...)`, `Purchasely.incrementUserAttribute(...)` (native v6 return `Deferred<Boolean>` on Android) |
| **User Management** | `Purchasely.userLogin(...)`, `Purchasely.userLogout()`, `Purchasely.anonymousUserId` |
| **Purchases** | `Purchasely.restoreAllProducts(...)`, `Purchasely.synchronize(...)`, `Purchasely.signPromotionalOffer(...)` (iOS), `Purchasely.userSubscriptionsHistory(...)` |
| **Consent** | `Purchasely.setUserAttribute(forDataProcessingPurposes:...)` (iOS) / equivalent on Android |
| **Info** | `Purchasely.sdkVersion`, `Purchasely.handleDeeplink(...)` |

### SDK types you can keep visible to the rest of the app

`PLYRunningMode`, `PLYDataProcessingPurpose`, `PLYPresentationAction` (a sealed class in v6), `PLYInterceptorInfo`, `PLYInterceptResult`, `PLYPresentationOutcome`, `PLYPresentationViewController`, `EventListener` / `PLYEventDelegate`, `PLYOfferSignature`, `LogLevel` / `PLYLogger.PLYLogLevel` — these are enums / types needed for configuration, interceptor logic, and presentation handling. They are not SDK call points so leaking them outside the wrapper is fine.

> **Android tip:** If you want to keep `PLYPresentation` itself out of ViewModels / Screens, wrap it in an opaque value class (e.g. `@JvmInline value class PresentationHandle(...)`). Optional.

### Platform implementation hints

**Android (Kotlin):**
- Singleton via DI (Koin / Hilt / manual) so ViewModels receive it via constructor injection
- App entry point calls a single `initialize(application, apiKey, logLevel)` that wraps the `Purchasely { ... }` DSL (or `Purchasely.Builder(...).build().start { ... }`), setting `runningMode(PLYRunningMode.Full)` when the app processes purchases

**iOS (Swift):**
- Singleton + protocol (`PurchaselyWrapping` or any name) so ViewModels accept the protocol type and tests inject a mock implementation
- App entry point calls a single `initialize(apiKey:, appUserId:, logLevel:, onReady:)` that wraps the fluent builder (`Purchasely.apiKey(...).runningMode(.full)....start()`)

---

## 2. Observer Mode: Reactive Purchase Flow (optional)

**Recommendation: In Observer mode you can decouple the native billing service from the Purchasely SDK using reactive flows. This pattern works well alongside the wrapper above. Teams that prefer to call `Purchasely.synchronize()` directly from their billing client also have a fully valid Observer integration.**

### Architecture

```
Purchasely interceptor (suspends)          Native billing service
    │                                           │
    │ PURCHASE (observer) ──────────────────►   │
    │   emit PurchaseRequest                     │
    │   suspend until result                     │ Native billing
    │                                           │ (Play Billing / StoreKit 2)
    │   ◄────────────────────────────────────   │
    │   TransactionResult                        │
    │                                           │
    │ Purchasely.synchronize()                   │
    │ return PLYInterceptResult.SUCCESS          │
    │ closeAllScreens() (Observer doesn't         │
    │   auto-close; or wire a Console close action)│
    │ refresh entitlement state                  │
```

> **Native v6:** the interceptor has no `proceed` callback. The per-action handler returns a `PLYInterceptResult`; to wait for the asynchronous native billing result, suspend inside the handler (Android `suspendCancellableCoroutine`, iOS the `async` interceptor form or the completion-based overload), then return `.success` / `.failed` once the `TransactionResult` arrives. This is an **Observer-mode** flow, and **Observer mode does not auto-close** after a purchase/restore (the implicit `close_all` is Full-only). So once the interceptor has resolved with a successful result, dismiss the paywall yourself with `Purchasely.closeAllScreens()` from your billing-result handler — unless a `close` / `close_all` action is wired on the button in the Console. **Do not call `closeAllScreens()` inside the interceptor closure before returning the result** — that races the SDK. (Full mode auto-closes: the SDK appends `close_all` itself, no manual close needed.)

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

### Result handling (native v6: return value, not a callback)

When the per-action handler receives `PURCHASE` / `RESTORE` (in Observer mode), emit a `PurchaseRequest` / `RestoreRequest` and **suspend the handler** until the matching `TransactionResult` arrives (Android `suspendCancellableCoroutine`; iOS the `async` interceptor or completion form). Then return the corresponding `PLYInterceptResult`.

**Race guard:** ensure the suspended continuation is resumed exactly once — resume with `.failed` if a second action would otherwise orphan the first (the SDK cancels a pending handler when a new one starts).

### Interceptor rules

| Action | Observer mode (native v6) | Full mode (native v6) |
|--------|---------------|-----------|
| PURCHASE | emit PurchaseRequest, suspend, then return `.success`/`.failed` | return `.notHandled` |
| RESTORE | emit RestoreRequest, suspend, then return `.success`/`.failed` | return `.notHandled` |
| LOGIN | run login, return `.success` (or `.notHandled` to let the SDK proceed) | same |
| NAVIGATE | open URL, return `.success` | open URL, return `.success` |
| Other | return `.notHandled` | return `.notHandled` |

### TransactionResult handling

| Result | Actions (native v6) |
|--------|---------|
| Success | `Purchasely.synchronize(...)` → resume handler with `PLYInterceptResult.SUCCESS` → after the handler has resolved, `Purchasely.closeAllScreens()` to dismiss (Observer mode does not auto-close; skip if a Console `close` action is wired) → refresh entitlements |
| Cancelled | resume handler with `PLYInterceptResult.FAILED` |
| Error | resume handler with `PLYInterceptResult.FAILED` |
| Idle | ignore |

### Native billing service rules

- **Zero Purchasely / SDK imports** — pure native billing service
- Observes purchase / restore requests from reactive channels
- Emits `TransactionResult` back through reactive channels
- Android: takes `billingClientFactory` lambda for testability
- iOS: takes injected closures for `anonymousUserId` and `signPromotionalOffer`

---

## 3. SDK Initialization

**Rule: the init builder is the only entry point that brings the SDK up. Call it once at app launch, then configure the event listener / delegate and the per-action interceptors right after.**

**Android (v6):** `Application.onCreate()` runs the `Purchasely { ... }` DSL (or `Purchasely.Builder(...).build().start { ... }`) then sets the event listener and the `interceptAction(...)` handlers.
**iOS (v6):** App start (e.g., `App.init` / `AppDelegate`) runs `Purchasely.apiKey(...)....start()` then sets the event delegate and the `interceptAction(...)` handlers.

What needs to happen at init:
1. The init builder with API key, **running mode** (⚠️ v6 defaults to Observer — set `.full` explicitly to process purchases), StoreKit settings / stores
2. Event listener / delegate
3. Per-action interceptors (`Purchasely.interceptAction(...)`)
4. Deeplink flag (native v6 `allowDeeplink`, default true)
5. (Observer mode only) Reactive subscriptions for the purchase flow

### Restart on running-mode change

When the SDK running mode changes (Full ↔ Observer), call `Purchasely.close()` then re-run the init builder — the SDK does not let you toggle the running mode in place. Cancel any pending purchase / restore continuations before closing so they do not orphan.

---

## 4. Presentation Loading: Build + preload, then display (native v6)

**Rule: Build the presentation, `preload()` it, then `display(...)` (modal) or `buildView(...)` / `getFragment(...)` / `controller` / `swiftUIView` (embedded). The v5 `fetchPresentation(...)` / `presentationView(...)` / `presentationController(...)` / VC-returning methods are removed on native v6.**

### Why

- Building + preloading + displaying gives full control over the presentation lifecycle (and `preload` does the network work, so a later `display` is instant)
- You can inspect `presentation.type` before deciding what to do (`NORMAL`, `CLIENT`, `DEACTIVATED`)
- You can handle errors from the preload step separately from display errors

### Pattern

```kotlin
// Android (v6) — coroutine preload, then display or buildView
val loaded = PLYPresentation { placementId(placementId) }.preload()
loaded.display(activity)
// or for embedded:
val view = loaded.buildView(context) { outcome -> /* ... */ }   // wrap in AndroidView for Compose
```

```swift
// iOS (v6) — async build + preload, then display or controller
let presentation = try await PLYPresentationBuilder
    .forPlacementId(placementId)
    .build()
    .preload()
presentation.display(from: viewController)
// or for embedded:
let controller = presentation.controller        // UIKit
let swiftUIView = presentation.swiftUIView       // SwiftUI
```

> Map preload outcomes to a small app-side sealed type (e.g. `FetchResult.Success(presentation, height)` / `Client(...)` / `Deactivated` / `Error(message)`) so the rest of the app does not depend on raw SDK error types.

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
    runCatching { PLYPresentation { placementId(placementId) }.preload().toFetchResult() }
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

Caching preloaded presentations in memory (keyed by `placementId[/contentId]`) is a useful optimization, **not a requirement**. Note that on native v6 you can simply hold the loaded presentation from `preload()` and call `display(...)` on it later (no extra network call), which covers most cases. A dedicated app-side cache still prevents:

- Duplicate network calls when SwiftUI `.onAppear` fires repeatedly (nav back, sheet dismiss, etc.)
- Accumulation of stale `flowSteps` entries in the SDK's `FlowsManager` for **flow** placements — a known SDK issue where each rebuild appends a new entry and dismissing the only visible step leaves a stuck `PLYWindow`. Caching / reusing the loaded presentation avoids re-building the same flow.

**Cache invalidation triggers (when you adopt this cache):**
- `PLYUserAttributeDelegate.onUserAttributeSet` / `onUserAttributeRemoved` (iOS) — any attribute change can alter audience targeting
- Successful `Purchasely.synchronize()` — subscription state may have changed
- Running-mode change (Full ↔ Observer) — the session is reset

> **Note:** Invalidation is coarse-grained (clear all) because the SDK does not expose attribute → audience dependencies. On native v6, prefer simply holding the loaded presentation from `preload()` and reusing it — the builder/preload split already avoids most redundant network calls, so a separate cache is rarely needed.

> **Note on the outcome handler:** The display result is delivered through the loaded presentation's `display(...)` / `buildView(...)` callback (`PLYPresentationOutcome`). If you reuse one loaded presentation across several display call sites, ensure the callbacks all perform the same work (e.g., refresh entitlements on purchased / restored).

> **Android:** the same concept applies — keep the loaded `PLYPresentation` from `preload()` and call `display(context)` later. Invalidate (re-build) on explicit `Purchasely.synchronize()` and running-mode changes.

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

### Android (Kotlin, v6)

- `PLYPresentation { ... }.preload()` — `suspend` API, call directly from a coroutine (or `.preload { loaded, error -> }` for the callback form)
- `loaded.display(context)` / `loaded.display(context, transition)` — **non-suspend** (Java-callable); returns a `PLYPresentationSession` you can `.await()` for the `PLYPresentationOutcome`
- `loaded.buildView(context) { outcome -> }` — returns a `PLYPresentationView?` (an Android View); the outcome callback fires later on purchase events

### iOS (Swift, v6)

- `PLYPresentationBuilder.forPlacementId(_).build().preload()` — `async`/`throws`; or `.preload { presentation, error in }` on the builder for the callback form
- `presentation.display(from:)` — must be called on the main thread; the dismissal `PLYPresentationOutcome` is delivered via the builder's `.onDismissed { outcome in }`
- `presentation.controller` — returns `PLYPresentationViewController?` (UIKit); `presentation.swiftUIView` for SwiftUI embedding

---

## 11. Testability

**Recommendation: Make Purchasely integration code testable by introducing a seam between your code and `Purchasely`. The exact seam depends on whether you adopted the wrapper pattern.**

### iOS

**With a wrapper class:** define a protocol (e.g. `PurchaselyWrapping`) that mirrors the SDK calls your app uses. ViewModels accept the protocol type via init with a default real implementation. Tests inject a mock implementation.

**Without a wrapper:** the static `Purchasely` API cannot be mocked directly. Two practical options:
- Inject **typed closures** into your ViewModels for the few SDK calls you exercise — e.g. `init(loadPresentation: (String) async throws -> any PLYPresentation = { try await PLYPresentationBuilder.forPlacementId($0).build().preload() })`. Tests pass canned closures.
- Or wrap each call site in a tiny **protocol-with-one-method** seam (the lightweight equivalent of a wrapper, scoped to the test surface).
- Tests that only need to assert non-SDK behavior (state transitions, premium gating logic) can stub the boundary and never touch the SDK.

### Android

**With a wrapper class:** inject the wrapper via Koin / Hilt constructor. Tests use MockK: `mockk<MyPurchaselyWrapper>(relaxed = true)`.

**Without a wrapper:** `Purchasely` is a Kotlin `object`, so direct calls are hard to intercept. Options:
- Use **MockK's static mocking** (`mockkStatic(Purchasely::class)`) to stub the SDK calls your ViewModel makes. Remember to `unmockkStatic` in `@After` — leftover static mocks leak across tests.
- Or inject **lambdas / functional interfaces** for the SDK calls you exercise (`loadPresentation: suspend (String) -> PLYPresentation = { PLYPresentation { placementId(it) }.preload() }`). Tests pass fakes.
- Tests covering only ViewModel state, premium gating, or domain logic can stub the boundary and skip the SDK entirely.

### Native billing service testability

- **Android:** constructor takes `billingClientFactory: (PurchasesUpdatedListener) -> BillingClient` — tests inject a mock `BillingClient`
- **iOS:** uses injected closures (`anonymousUserIdProvider`, `signPromotionalOfferProvider`) instead of direct SDK access

### Repository testability (Android)

Repositories that need persistent storage (favorites, onboarding flag, running mode, settings) accept a `KeyValueStore` interface instead of `Context` / `SharedPreferences`. Tests use an in-memory implementation — no Android framework needed.

### Repository testability (iOS)

Repositories that need persistent storage accept a custom `UserDefaults` for test isolation. Data repositories accept the data array directly for test data.

---

## 12. Platform-Specific Notes

### Android (Kotlin / Jetpack Compose, v6)

- The `Purchasely { ... }` DSL (or `Purchasely.Builder(...).build().start { ... }`) runs in `Application.onCreate()` along with `setEventListener(...)` and the per-action `Purchasely.interceptAction(...) { ... }` handlers
- `PLYPresentation.buildView(context) { outcome -> }` returns a `PLYPresentationView?` (an Android View extending `FrameLayout`) — wrap with `AndroidView` in Compose (there is no `presentation-compose` artifact or `PLYPresentationView` composable)
- Domain layer (`domain/repository/`) defines interfaces; `data/` contains `*Impl` implementations — ViewModels depend on interfaces, not concrete classes
- Repositories accept a `KeyValueStore` interface — DI injects `SharedPreferencesKeyValueStore` in production, an in-memory store in tests
- Embedded banner Composables can pull dependencies via `koinInject()` (or equivalent) when needed
- Screens use `collectAsStateWithLifecycle()` (not `collectAsState()`) for lifecycle-aware Flow collection

### iOS (SwiftUI, v6)

- The fluent builder (`Purchasely.apiKey(...)....start()`) runs at app start (e.g., `App.init` or `AppDelegate.application(_:didFinishLaunchingWithOptions:)`) along with the event delegate and the per-action `Purchasely.interceptAction(...)` handlers
- Async operations use Swift `async/await`; bridge any remaining SDK callbacks with `withCheckedContinuation`. Under Swift 6 strict concurrency, `@preconcurrency import Purchasely` at `@MainActor` call sites
- `presentation.controller` returns `PLYPresentationViewController?` for embedding via `UIViewControllerRepresentable`; `presentation.swiftUIView` is the native SwiftUI view
- Embedded banner can use `presentation.swiftUIView` directly, or a `UIViewControllerRepresentable` wrapping `presentation.controller`
- Modal display: resolve a `UIViewController` (e.g., via a `ViewControllerResolver` helper) and call `presentation.display(from:)`
- `presentation.height` is in points — use as `CGFloat` directly in `.frame(height:)`
- Prefetch from `onAppear` since `@StateObject` init does not have access to `@EnvironmentObject`

---

## Checklist for Production-Grade Integrations

> These items are **best-practice signals**, not pass / fail criteria. A perfectly valid integration may not adopt any of them. Use them as conversation starters when the team has explicitly asked for an architecture review.

### Universal (apply regardless of architecture choice)

- [ ] Uses the v6 builder + `preload()` + `display(...)` / `buildView(...)` / `controller` / `swiftUIView`, not the removed `fetchPresentation(...)` / `presentationView(...)` / `presentationController(...)`
- [ ] Presentations are preloaded (Android: in ViewModel `init`, iOS: from `onAppear`) when the user is not already premium
- [ ] Handles all `FetchResult` variants: success, client, deactivated, error
- [ ] No crashes on SDK errors — nothing is shown if preload fails
- [ ] Uses `presentation.height` (dp on Android, points on iOS) for embedded view sizing
- [ ] User attributes are set on actual state changes, not on every recomposition / re-render
- [ ] Android Screens use `collectAsStateWithLifecycle()` (not `collectAsState()`) for lifecycle-aware collection
- [ ] The init builder, the event listener / delegate and the per-action `interceptAction(...)` handlers are configured once at app start
- [ ] Running mode is set explicitly to Full (`.runningMode(.full)` / `runningMode(PLYRunningMode.Full)`) when the app expects Purchasely to process/validate purchases — v6 defaults to Observer silently

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

- [ ] Loaded presentations from `preload()` are held and reused (or an in-memory cache keyed by `placementId[/contentId]` is populated on first preload)
- [ ] Cache invalidated on user-attribute changes (iOS), successful `Purchasely.synchronize()`, and running-mode change
