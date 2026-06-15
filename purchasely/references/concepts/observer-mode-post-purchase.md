# Observer Mode — Post-Purchase Flow

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

When the SDK runs in [Observer mode](running-modes.md), your app owns the billing flow. After a successful purchase **inside your billing code**, you need to tell the SDK to (a) record the transaction for analytics, (b) stop running its own purchase logic, and (c) dismiss the paywall.

The ordering and the exact API names matter. Get them wrong and you'll see frozen paywalls, double purchase attempts, or stale audience targeting on follow-up screens.

> **v6 behaviour change.** In Observer mode, presentations **no longer auto-close** after a purchase or restore (v5's implicit Full default appended a `close_all`). Your app must dismiss explicitly — step 3 below — or wire a `close` action in the Composer.

## The recommended sequence

After a successful Observer-mode purchase, **in this order**:

1. **`Purchasely.synchronize()`** — tells Purchasely to re-pull receipt state from the store servers. In v6 both native SDKs accept optional callbacks (iOS `success:/failure:`, Android `onSuccess = { plan -> } / onError = { error -> }`); the cache is refreshed before `onSuccess`/`success` fires.
2. **Resolve the interceptor** — tell the SDK's action interceptor that **you** handled the purchase. Native iOS/Android v6: return `PLYInterceptResult.success` / `PLYInterceptResult.SUCCESS`. Cross-platform bridges: `proceed(false)` / `processAction(false)`. This means "do not run the SDK's own purchase flow on top of mine."
3. **Dismiss the paywall** — native SDKs use `Purchasely.closeAllScreens()`; current React Native / Flutter / Cordova bridges expose `closePresentation()`.

> **The order resolve-interceptor → dismiss is non-negotiable.** The interceptor must learn the action was handled **before** the paywall tears down. Reversing them produces frozen UIs and double-action bugs. On native v6 the interceptor closure resolves its `PLYInterceptResult` first (synchronously on iOS, or by returning from the suspend interceptor on Android), then you close.

## Dismissal API per platform

`closeAllScreens()` is the native v6 dismissal method that tears down multi-step Flow paywalls correctly (it replaces v5's `closeDisplayedPresentation()`). Current cross-platform bridge APIs expose `closePresentation()` instead; do not generate RN/Flutter/Cordova code that calls `closeAllScreens()` unless the project has added its own native bridge.

| Platform | Dismissal API |
|----------|---------------|
| iOS | `Purchasely.closeAllScreens()` — `@MainActor`-isolated. From a non-isolated context, wrap in `Task { @MainActor in Purchasely.closeAllScreens() }`. |
| Android | `Purchasely.closeAllScreens()` — no threading constraint. |
| React Native | Use `Purchasely.closePresentation()` in the public JS bridge. |
| Flutter | Use `Purchasely.closePresentation()` in the public Dart bridge. |
| Cordova | Use `Purchasely.closePresentation()` in the public JS bridge. |

## Code per platform

### iOS (Swift) — async interceptor returns the result directly

In v6 the `.purchase` interceptor is an async closure that **returns** a `PLYInterceptResult`. Run your billing flow, `synchronize`, return `.success`, then close.

```swift
Purchasely.interceptAction(.purchase) { info, params in
    let purchased = await MyBilling.purchase(params?.plan)
    guard purchased else { return .failed }

    try? await synchronizeReceipt()   // await only if a follow-up placement targets subscribers
    Task { @MainActor in Purchasely.closeAllScreens() }   // v6: no auto-close in Observer mode
    return .success                   // app handled it — SDK must not run its own purchase
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

In v6 the interceptor is a suspend closure that **returns** a `PLYInterceptResult`. Bridge your callback-based billing client with `suspendCancellableCoroutine`, then call `synchronize(...)` and return `SUCCESS`.

```kotlin
Purchasely.interceptAction<PLYPresentationAction.Purchase> { info, purchase ->
    val result = suspendCancellableCoroutine { cont ->
        myBilling.purchase(purchase.plan) { billing ->
            when (billing) {
                BillingResult.SUCCESS -> {
                    Purchasely.synchronize(
                        onSuccess = { plan -> /* refresh UI; plan is the validated PLYPlan or null */ },
                        onError = { error -> /* surface failure */ }
                    )
                    cont.resume(PLYInterceptResult.SUCCESS)
                }
                BillingResult.CANCELLED -> cont.resume(PLYInterceptResult.NOT_HANDLED)
                else -> cont.resume(PLYInterceptResult.FAILED)
            }
        }
    }
    Purchasely.closeAllScreens()   // v6: no auto-close in Observer mode
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

### Flutter (Dart)

```dart
Future<void> onPurchaseSuccess() async {
  await Purchasely.synchronize();
  Purchasely.onProcessAction(false);
  await Purchasely.closePresentation();
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

Some apps display a follow-up paywall after a successful purchase — a thank-you screen, a premium feature tour, a one-tap upsell, etc. **This is not part of the SDK contract**: it's just another presentation fetch with whatever placement ID you've configured on the Console (e.g. `"post_purchase"`, `"thank_you"`, `"premium_welcome"` — name it whatever you want, just match it in the dashboard). Native iOS/Android v6 build it with `PLYPresentationBuilder` / the `PLYPresentation { }` DSL; cross-platform bridges still call `fetchPresentation`.

### The audience-targeting gotcha

If the chained placement's audience targets users based on subscription state, **`synchronize()` must complete before the fetch**. Otherwise the fetch resolves against stale state and may return a `DEACTIVATED` (or wrong-fallback) presentation.

- On iOS, this is why the `synchronizeReceipt()` `await` matters.
- On Android v6, `synchronize(onSuccess = { … }, onError = { … })` refreshes the subscriptions cache before `onSuccess` — kick off the follow-up fetch from `onSuccess` so it resolves against fresh state.
- On React Native, `synchronize()` is fire-and-forget in the public JS bridge.
- On Flutter, `await synchronize()` resolves once the native bridge confirms; same trade-off as native.
- On Cordova, `synchronize()` is fire-and-forget in the public JS bridge.

### Example chain (iOS)

```swift
// After closeAllScreens() above, build and display the follow-up with PLYPresentationBuilder:
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
final p = await Purchasely.fetchPresentation(placementId: 'YOUR_POST_PURCHASE_PLACEMENT_ID');
if (p.type == PLYPresentationType.normal || p.type == PLYPresentationType.fallback) {
  await Purchasely.presentPresentation(p);
}
```

The same pattern applies on React Native and Cordova — fetch, [type-guard](presentation-types.md), display.

## See also

- [running-modes.md](running-modes.md) — what Observer mode is and when to use it
- [paywall-actions.md](paywall-actions.md) — the interceptor that triggers this flow
- [presentation-types.md](presentation-types.md) — type guard for the chained placement
- [presentation-cache.md](presentation-cache.md) — invalidate after `synchronize()`
