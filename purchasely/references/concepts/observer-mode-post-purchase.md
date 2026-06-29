# Observer Mode — Post-Purchase Flow

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

When the SDK runs in [Observer mode](running-modes.md), your app owns the billing flow. After a successful purchase **inside your billing code**, you need to tell the SDK to (a) record the transaction for analytics and (b) stop running its own purchase logic.

The ordering and the exact API names matter. Get them wrong and you'll see frozen paywalls, double purchase attempts, or stale audience targeting on follow-up screens.

> **Full vs Observer — who closes the paywall.** The SDK appends an implicit `close_all` after a lone `purchase` / `restore` **only in Full mode** (verified in the SDK source: Android `Components.kt` gates it on `Purchasely.runningMode == PLYRunningMode.Full`; iOS `DefaultActionExecutor.appendCloseIfNeeded` early-returns unless `runningMode.validatesTransactions`). **In Observer mode the SDK does NOT auto-close after a purchase/restore.** The post-purchase interceptor flow is an Observer-mode flow (your app runs its own billing), so after you resolve the interceptor with a successful result you **must dismiss the paywall yourself with `Purchasely.closeAllScreens()`** — unless you wire a `close` / `close_all` action on the button in the Console. Call `closeAllScreens()` **after** the interceptor has resolved (from your async billing-result handler), not inside the interceptor closure before returning the result — that races the SDK. **Flutter v6** mirrors native: there is no `closeAllScreens()`/`closePresentation()` — dismiss with `presentation.close()` on the loaded `Presentation`, or a `close` action wired in the Composer. The remaining **cross-platform bridges** (React Native / Cordova) are on the v5 surface and dismiss with an explicit `closePresentation()`, or a `close` action wired in the Composer.

## The recommended sequence

After a successful Observer-mode purchase:

1. **`Purchasely.synchronize()`** — tells Purchasely to re-pull receipt state from the store servers. In v6 both native SDKs accept optional callbacks (iOS `success:/failure:`, Android `onSuccess = { plan -> } / onError = { error -> }`); the cache is refreshed before `onSuccess`/`success` fires.
2. **Resolve the interceptor** — tell the SDK's action interceptor that **you** handled the purchase. Native iOS/Android v6: return `PLYInterceptResult.success` / `PLYInterceptResult.SUCCESS`. Flutter v6: return `InterceptResult.success`. React Native / Cordova bridges: `proceed(false)` / `processAction(false)`. This means "do not run the SDK's own purchase flow on top of mine." In Observer mode the SDK does **not** auto-close on a successful result — you dismiss in step 3.
3. **Dismiss the paywall** — Observer mode does not auto-close after a purchase/restore (that implicit `close_all` is Full-only). After resolving the interceptor, dismiss the paywall yourself: native iOS/Android v6 call `Purchasely.closeAllScreens()`; Flutter v6 calls `presentation.close()` on the loaded `Presentation`; React Native / Cordova bridges call `closePresentation()`. You can skip this step if a `close` / `close_all` action is wired on the button in the Console — then the SDK closes on that action.

> **Resolve first, then dismiss — never inside the closure.** Do not call `closeAllScreens()` / `closePresentation()` inside the interceptor closure *before* returning the result — that races the SDK. On native v6, dismiss **after** the interceptor closure has resolved its `PLYInterceptResult`, i.e. from your async billing-result handler (e.g. `onBillingSuccess()`), which runs once the suspended interceptor has resolved. On the cross-platform bridges, resolve the action with `processAction`/`proceed` **before** calling `closePresentation()`: the interceptor must learn the action was handled before the paywall tears down, or you get frozen UIs and double-action bugs.

## Dismissal API per platform

On **native v6 in Observer mode** the SDK does **not** dismiss after a successful purchase/restore (the implicit `close_all` is Full-only), so you call `Purchasely.closeAllScreens()` yourself after resolving the interceptor — unless a `close` / `close_all` action is configured on the button in the Console. `closeAllScreens()` is the native v6 dismissal method (it replaces v5's `closeDisplayedPresentation()` and tears down multi-step Flow paywalls correctly). Flutter v6 has no `closeAllScreens()`/`closePresentation()` — dismiss with `presentation.close()` on the loaded `Presentation`. The remaining cross-platform bridges (React Native / Cordova) expose `closePresentation()` and likewise require an explicit call after resolving; do not generate RN/Cordova code that calls `closeAllScreens()` unless the project has added its own native bridge.

| Platform | Post-purchase dismissal (Observer mode) |
|----------|-------------------------|
| iOS | Resolve with `.success`, then call `Purchasely.closeAllScreens()` (from your billing-result handler, after the interceptor resolves) — or wire a `close` action in the Console. It is `@MainActor`-isolated; from a non-isolated context wrap in `Task { @MainActor in Purchasely.closeAllScreens() }`. |
| Android | Resolve with `PLYInterceptResult.SUCCESS`, then call `Purchasely.closeAllScreens()` (from your billing-result handler, after the interceptor resolves) — or wire a `close` action in the Console. No threading constraint. |
| React Native | Resolve, then call `Purchasely.closePresentation()` in the public JS bridge. |
| Flutter | Resolve with `PLYInterceptResult.success`, then call `presentation.close()` on the loaded `PLYPresentation` — or wire a `close` action in the Console. |
| Cordova | Resolve, then call `Purchasely.closePresentation()` in the public JS bridge. |

> **Full mode** dismisses automatically: the SDK appends `close_all` after a lone purchase/restore, so no manual `closeAllScreens()` is needed there.

## Code per platform

### iOS (Swift) — async interceptor returns the result directly

In v6 the `.purchase` interceptor is an async closure that **returns** a `PLYInterceptResult`. Run your billing flow, `synchronize`, then return `.success`. In Observer mode the SDK does not auto-close, so dismiss the paywall with `Purchasely.closeAllScreens()` **after** the interceptor has returned — or wire a `close` action in the Console.

```swift
Purchasely.interceptAction(.purchase) { info, params in
    let purchased = await MyBilling.purchase(params?.plan)
    guard purchased else { return .failed }

    try? await synchronizeReceipt()   // await only if a follow-up placement targets subscribers
    return .success                   // app handled it; do NOT close here — that races the SDK
}

// Called after the interceptor has resolved (Observer mode does not auto-close).
// Skip this if a `close` action is configured on the button in the Console.
@MainActor
private func onBillingSuccess() {
    Purchasely.closeAllScreens()      // dismiss the paywall ourselves in Observer mode
}

private func synchronizeReceipt() async throws {
    try await withCheckedThrowingContinuation { cont in
        Purchasely.synchronize(
            success: { cont.resume() },
            failure: { cont.resume(throwing: $0 ?? NSError(domain: "Purchasely", code: -1)) }
        )
    }
}
```

### Android (Kotlin) — suspend interceptor bridges your billing flow

In v6 the interceptor is a suspend closure that **returns** a `PLYInterceptResult`. Bridge your callback-based billing client with `suspendCancellableCoroutine`, then call `synchronize(...)` and return `SUCCESS`. In Observer mode the SDK does not auto-close, so dismiss the paywall with `Purchasely.closeAllScreens()` from your billing-result handler **after** the interceptor has resolved — or wire a `close` action in the Console.

```kotlin
Purchasely.interceptAction<PLYPresentationAction.Purchase> { info, purchase ->
    val result = suspendCancellableCoroutine { cont ->
        myBilling.purchase(purchase.plan) { billing ->
            when (billing) {
                BillingResult.SUCCESS -> {
                    Purchasely.synchronize(
                        onSuccess = { plan ->
                            // refresh UI; plan is the validated PLYPlan or null.
                            // Observer mode does not auto-close — dismiss ourselves here,
                            // after the interceptor has resolved (skip if a `close` action
                            // is configured on the button in the Console).
                            Purchasely.closeAllScreens()
                        },
                        onError = { error -> /* surface failure */ }
                    )
                    cont.resume(PLYInterceptResult.SUCCESS)   // resolve; do NOT close inside the closure
                }
                BillingResult.CANCELLED -> cont.resume(PLYInterceptResult.NOT_HANDLED)
                else -> cont.resume(PLYInterceptResult.FAILED)
            }
        }
    }
    result
}
```

### React Native (TypeScript)

```ts
async function onPurchaseSuccess() {
  Purchasely.synchronize();
  Purchasely.onProcessAction(false);
  Purchasely.closePresentation();
}
```

### Flutter (Dart) — async interceptor returns the result directly

In v6 the `.purchase` interceptor is an async callback that **returns** a `PLYInterceptResult`. Run your billing flow, `await synchronize()`, then return `PLYInterceptResult.success`. In Observer mode the SDK does not auto-close, so dismiss the paywall with `presentation.close()` on the loaded `PLYPresentation` **after** the interceptor has resolved — or wire a `close` action in the Console.

```dart
Purchasely.interceptAction(PLYPresentationActionKind.purchase, (info, payload) async {
  if (payload is! PLYPurchasePayload) return PLYInterceptResult.notHandled;

  final purchased = await myBilling.purchase(payload.plan.productId);
  if (!purchased) return PLYInterceptResult.failed;

  await Purchasely.synchronize();   // resolves once the native bridge confirms
  return PLYInterceptResult.success;   // app handled it; do NOT close here — that races the SDK
});

// Called after the interceptor has resolved (Observer mode does not auto-close).
// Skip this if a `close` action is configured on the button in the Console.
Future<void> onPurchaseSuccess(PLYPresentation presentation) async {
  await presentation.close();       // dismiss the paywall ourselves in Observer mode
}
```

### Cordova (JavaScript)

```js
function onPurchaseSuccess() {
  Purchasely.synchronize();
  Purchasely.onProcessAction(false);
  Purchasely.closePresentation();
}
```

## Optional: chaining a follow-up placement

Some apps display a follow-up paywall after a successful purchase — a thank-you screen, a premium feature tour, a one-tap upsell, etc. **This is not part of the SDK contract**: it's just another presentation fetch with whatever placement ID you've configured on the Console (e.g. `"post_purchase"`, `"thank_you"`, `"premium_welcome"` — name it whatever you want, just match it in the dashboard). Native iOS/Android v6 build it with `PLYPresentationBuilder` / the `PLYPresentation { }` DSL; Flutter v6 builds it with `PresentationBuilder` → `PresentationRequest` (`.preload()` / `.display(...)`); the React Native / Cordova bridges still call `fetchPresentation`.

### The audience-targeting gotcha

If the chained placement's audience targets users based on subscription state, **`synchronize()` must complete before the fetch**. Otherwise the fetch resolves against stale state and may return a `DEACTIVATED` (or wrong-fallback) presentation.

- On iOS, this is why the `synchronizeReceipt()` `await` matters.
- On Android v6, `synchronize(onSuccess = { … }, onError = { … })` refreshes the subscriptions cache before `onSuccess` — kick off the follow-up fetch from `onSuccess` so it resolves against fresh state.
- On React Native, `synchronize()` is fire-and-forget in the public JS bridge.
- On Flutter, `await synchronize()` resolves once the native bridge confirms; same trade-off as native.
- On Cordova, `synchronize()` is fire-and-forget in the public JS bridge.

### Example chain (iOS)

```swift
// After you dismiss the purchase paywall (closeAllScreens() in Observer mode, or the Console close
// action), build and display the follow-up with PLYPresentationBuilder:
let presentation = try await PLYPresentationBuilder
    .forPlacementId("YOUR_POST_PURCHASE_PLACEMENT_ID")
    .build()
    .preload()
if let p = presentation,
   p.type == .normal || p.type == .fallback,
   let top = UIApplication.shared.topViewController() {
    p.display(from: top)
}
```

### Example chain (Flutter)

```dart
await Purchasely.synchronize();
final request = PLYPresentationBuilder
    .placement('YOUR_POST_PURCHASE_PLACEMENT_ID')
    .build();
final p = await request.preload();
if (p.type == PLYPresentationType.normal || p.type == PLYPresentationType.fallback) {
  await p.display(const PLYTransition.fullScreen());
}
```

The same pattern applies on React Native and Cordova — fetch, [type-guard](presentation-types.md), display.

## See also

- [running-modes.md](running-modes.md) — what Observer mode is and when to use it
- [paywall-actions.md](paywall-actions.md) — the interceptor that triggers this flow
- [presentation-types.md](presentation-types.md) — type guard for the chained placement
- [presentation-cache.md](presentation-cache.md) — invalidate after `synchronize()`
