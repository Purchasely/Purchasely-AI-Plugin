# Observer Mode — Post-Purchase Flow

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

When the SDK runs in [Observer mode](running-modes.md), your app owns the billing flow. After a successful purchase **inside your billing code**, you need to tell the SDK to (a) record the transaction for analytics and (b) stop running its own purchase logic.

The ordering and the exact API names matter. Get them wrong and you'll see frozen paywalls, double purchase attempts, or stale audience targeting on follow-up screens.

> **Full vs Observer — who closes the paywall.** The SDK appends an implicit `close_all` after a lone `purchase` / `restore` **only in Full mode** (verified in the SDK source: Android `Components.kt` gates it on `Purchasely.runningMode == PLYRunningMode.Full`; iOS `DefaultActionExecutor.appendCloseIfNeeded` early-returns unless `runningMode.validatesTransactions`). **In Observer mode the SDK does NOT auto-close after a purchase/restore.** The post-purchase interceptor flow is an Observer-mode flow (your app runs its own billing), so after you resolve the interceptor with a successful result you **must dismiss the paywall yourself** — unless you wire a `close` / `close_all` action on the button in the Console. Native iOS/Android call `Purchasely.closeAllScreens()` after the interceptor has resolved (from your async billing-result handler), not inside the interceptor closure before returning the result — that races the SDK. React Native v6 calls `request.close()` on the `PLYPresentationRequest`, Flutter v6 calls `presentation.close()` on the loaded `PLYPresentation`, and Cordova v6 calls `Purchasely.closePresentation()`.

> **`synchronize()` in the interceptor is obsolete — do not call it there.** In v6, returning a success result from the `purchase` / `restore` action interceptor in Observer mode already tells the SDK the transaction succeeded, and the SDK **auto-synchronizes** with Purchasely's servers as part of resolving that action. Calling `Purchasely.synchronize()` yourself inside the interceptor is redundant and is **not** the recommended flow below. Manual `synchronize()` calls are for purchases that happen **outside** the interceptor entirely — a fully custom home-grown sale screen, or a [BYOS](byos.md) screen driving its own store calls — where there is no interceptor resolution to trigger the auto-sync.

## The recommended sequence

After a successful Observer-mode purchase:

1. **Run your billing flow** — your own StoreKit / Play Billing call, or whatever custom billing stack the app already has.
2. **Resolve the interceptor** — tell the SDK's action interceptor that **you** handled the purchase. Native iOS/Android v6: return `PLYInterceptResult.success` / `PLYInterceptResult.SUCCESS`. React Native v6: return `'success'`. Flutter v6: return `PLYInterceptResult.success`. Cordova v6: return or resolve `Purchasely.InterceptResult.success`. This means "do not run the SDK's own purchase flow on top of mine," and — new in v6 — it **auto-synchronizes** with Purchasely's servers; do not call `Purchasely.synchronize()` yourself here. In Observer mode the SDK does **not** auto-close on a successful result — you dismiss in step 3.
3. **Dismiss the paywall** — Observer mode does not auto-close after a purchase/restore (that implicit `close_all` is Full-only). After resolving the interceptor, dismiss the paywall yourself: native iOS/Android v6 call `Purchasely.closeAllScreens()`; React Native v6 calls `request.close()` on the `PLYPresentationRequest`; Flutter v6 calls `presentation.close()` on the loaded `PLYPresentation`; Cordova v6 calls `Purchasely.closePresentation()`. You can skip this step if a `close` / `close_all` action is wired on the button in the Console — then the SDK closes on that action.

> **Resolve first, then dismiss — never inside the closure.** Do not call `closeAllScreens()` / `request.close()` / `presentation.close()` / `closePresentation()` inside the interceptor closure *before* returning the result — that races the SDK. Dismiss **after** the interceptor handler has resolved its result (`PLYInterceptResult` on native iOS/Android and Flutter v6, a string result on React Native v6, or `Purchasely.InterceptResult` on Cordova v6), i.e. from your async billing-result handler (e.g. `onBillingSuccess()`), which runs once the suspended interceptor has resolved.

## Dismissal API per platform

On **native v6 in Observer mode** the SDK does **not** dismiss after a successful purchase/restore (the implicit `close_all` is Full-only), so you call `Purchasely.closeAllScreens()` yourself after resolving the interceptor — unless a `close` / `close_all` action is configured on the button in the Console. `closeAllScreens()` is the native v6 dismissal method (it replaces v5's `closeDisplayedPresentation()` and tears down multi-step Flow paywalls correctly). React Native v6 has no `closeAllScreens()` — dismiss with `request.close()` on the `PLYPresentationRequest` you built. Flutter v6 dismisses with `presentation.close()` on the loaded `PLYPresentation`. Cordova v6 exposes `closePresentation()` on the public JS bridge; do not generate bridge code that calls native `closeAllScreens()` unless the project has added its own native bridge.

| Platform | Post-purchase dismissal (Observer mode) |
|----------|-------------------------|
| iOS | Resolve with `.success`, then call `Purchasely.closeAllScreens()` (from your billing-result handler, after the interceptor resolves) — or wire a `close` action in the Console. It is `@MainActor`-isolated; from a non-isolated context wrap in `Task { @MainActor in Purchasely.closeAllScreens() }`. |
| Android | Resolve with `PLYInterceptResult.SUCCESS`, then call `Purchasely.closeAllScreens()` (from your billing-result handler, after the interceptor resolves) — or wire a `close` action in the Console. No threading constraint. |
| React Native | Resolve with `'success'`, then call `request.close()` on the `PLYPresentationRequest` — or wire a `close` action in the Console. |
| Flutter | Resolve with `PLYInterceptResult.success`, then call `presentation.close()` on the loaded `PLYPresentation` — or wire a `close` action in the Console. |
| Cordova | Resolve with `Purchasely.InterceptResult.success`, then call `Purchasely.closePresentation()` in the public JS bridge. |

> **Full mode** dismisses automatically: the SDK appends `close_all` after a lone purchase/restore, so no manual `closeAllScreens()` is needed there.

## Code per platform

### iOS (Swift) — async interceptor returns the result directly

In v6 the `.purchase` interceptor is an async closure that **returns** a `PLYInterceptResult`. Run your billing flow, then return `.success`. In Observer mode the SDK does not auto-close, so dismiss the paywall with `Purchasely.closeAllScreens()` **after** the interceptor has returned — or wire a `close` action in the Console.

```swift
Purchasely.interceptAction(.purchase) { info, params in
    let purchased = await MyBilling.purchase(params?.plan)
    guard purchased else { return .failed }

    return .success   // app handled it; returning success auto-synchronizes with Purchasely —
                       // do NOT call synchronize() here, and do NOT close here (that races the SDK)
}

// Called after the interceptor has resolved (Observer mode does not auto-close).
// Skip this if a `close` action is configured on the button in the Console.
@MainActor
private func onBillingSuccess() {
    Purchasely.closeAllScreens()      // dismiss the paywall ourselves in Observer mode
}
```

### Android (Kotlin) — suspend interceptor bridges your billing flow

In v6 the interceptor is a suspend closure that **returns** a `PLYInterceptResult`. Bridge your callback-based billing client with `suspendCancellableCoroutine`, then return `SUCCESS` — returning success auto-synchronizes with Purchasely, no manual `synchronize(...)` call needed. In Observer mode the SDK does not auto-close, so dismiss the paywall with `Purchasely.closeAllScreens()` from your billing-result handler **after** the interceptor has resolved — or wire a `close` action in the Console.

```kotlin
Purchasely.interceptAction<PLYPresentationAction.Purchase> { info, purchase ->
    suspendCancellableCoroutine { cont ->
        myBilling.purchase(purchase.plan) { billing ->
            when (billing) {
                BillingResult.SUCCESS -> cont.resume(PLYInterceptResult.SUCCESS)
                    // resolve; auto-synchronizes — do NOT close inside the closure
                BillingResult.CANCELLED -> cont.resume(PLYInterceptResult.NOT_HANDLED)
                else -> cont.resume(PLYInterceptResult.FAILED)
            }
        }
    }
}

// Called from your billing client's own success listener (not chained off the
// interceptor's return), after the interceptor has resolved (Observer mode
// does not auto-close). Skip this if a `close` action is configured on the
// button in the Console.
private fun onBillingSuccess() {
    Purchasely.closeAllScreens()   // dismiss the paywall ourselves in Observer mode
}
```

### React Native (TypeScript) — async interceptor returns the result directly

In v6 the `purchase` interceptor is an async handler that **returns** a string result. Run your billing flow, then return `'success'`. In Observer mode the SDK does not auto-close, so dismiss the paywall with `request.close()` on the `PLYPresentationRequest` you built **after** the interceptor has returned — or wire a `close` action in the Console.

```ts
// `request` is the PLYPresentationRequest you built and displayed:
//   const request = Purchasely.presentation.placement('PREMIUM').build();
//   request.display();

Purchasely.interceptAction('purchase', async (info, payload) => {
  const purchased = await myBilling.purchase(payload?.plan?.productId);
  if (!purchased) return 'failed';

  return 'success'; // app handled it; returning success auto-synchronizes — do NOT call
                     // synchronize() here, and do NOT close here (that races the SDK)
});

// Called after the interceptor has resolved (Observer mode does not auto-close).
// Skip this if a `close` action is configured on the button in the Console.
async function onPurchaseSuccess() {
  request.close(); // dismiss the paywall ourselves in Observer mode
}
```

### Flutter (Dart) — async interceptor returns the result directly

In v6 the `.purchase` interceptor is an async callback that **returns** a `PLYInterceptResult`. Run your billing flow, then return `PLYInterceptResult.success`. In Observer mode the SDK does not auto-close, so dismiss the paywall with `presentation.close()` on the loaded `PLYPresentation` **after** the interceptor has resolved — or wire a `close` action in the Console.

```dart
Purchasely.interceptAction(PLYPresentationActionKind.purchase, (info, payload) async {
  if (payload is! PLYPurchasePayload) return PLYInterceptResult.notHandled;

  final purchased = await myBilling.purchase(payload.plan['productId']);
  if (!purchased) return PLYInterceptResult.failed;

  return PLYInterceptResult.success; // app handled it; returning success auto-synchronizes —
                                      // do NOT call synchronize() here, and do NOT close here
                                      // (that races the SDK)
});

// Called after the interceptor has resolved (Observer mode does not auto-close).
// Skip this if a `close` action is configured on the button in the Console.
Future<void> onPurchaseSuccess(PLYPresentation presentation) async {
  await presentation.close();       // dismiss the paywall ourselves in Observer mode
}
```

### Cordova (JavaScript)

```js
Purchasely.interceptAction(Purchasely.PresentationAction.purchase, function (info, parameters) {
  return myBilling.purchase(parameters.plan).then(function (ok) {
    // returning success auto-synchronizes with Purchasely — do NOT call
    // Purchasely.synchronize() here
    return ok ? Purchasely.InterceptResult.success : Purchasely.InterceptResult.failed;
  });
});

function onPurchaseSuccess() {
  Purchasely.closePresentation(); // after the interceptor resolved
}
```

## Optional: chaining a follow-up placement

Some apps display a follow-up paywall after a successful purchase — a thank-you screen, a premium feature tour, a one-tap upsell, etc. **This is not part of the SDK contract**: it's just another presentation fetch with whatever placement ID you've configured on the Console (e.g. `"post_purchase"`, `"thank_you"`, `"premium_welcome"` — name it whatever you want, just match it in the dashboard). Native iOS/Android v6 build it with `PLYPresentationBuilder` / the `PLYPresentation { }` DSL; React Native v6 builds it with `Purchasely.presentation.placement(...)` → `PLYPresentationRequest`; Flutter v6 builds it with `PLYPresentationBuilder.placement(...)` → `PLYPresentationRequest` (`.preload()` / `.display(...)`); the Cordova v6 bridge still calls `fetchPresentation`.

### The audience-targeting gotcha

If the chained placement's audience targets users based on subscription state, that state must be fresh before the fetch — otherwise the fetch resolves against stale state and may return a `DEACTIVATED` (or wrong-fallback) presentation.

- **Purchase went through the paywall's action interceptor** (the recommended sequence above): resolving the interceptor with a success result already triggered the SDK's auto-synchronization. No extra `synchronize()` call is needed before the follow-up fetch.
- **Purchase happened outside the interceptor** (a fully custom sale screen, or [BYOS](byos.md)): there is no auto-sync. Call `Purchasely.synchronize()` yourself and wait for it to complete before fetching the follow-up placement — iOS/Android/Cordova accept `success/failure` (or `onSuccess`/`onError`) callbacks; React Native and Flutter `await` a `Future`/`Promise` that resolves once the native bridge confirms.

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
// Only needed if the purchase happened outside the interceptor (e.g. BYOS) —
// skip this call when the purchase was resolved through the action interceptor.
await Purchasely.synchronize();

final request = PLYPresentationBuilder
    .placement('YOUR_POST_PURCHASE_PLACEMENT_ID')
    .build();
final p = await request.preload();
if (p.type == PLYPresentationType.normal || p.type == PLYPresentationType.fallback) {
  await p.display(const PLYTransition.fullScreen());
}
```

The same pattern applies on React Native (build the request, `preload()`, [type-guard](presentation-types.md), `display()`) and Cordova (fetch, type-guard, display).

## See also

- [running-modes.md](running-modes.md) — what Observer mode is and when to use it
- [paywall-actions.md](paywall-actions.md) — the interceptor that triggers this flow
- [presentation-types.md](presentation-types.md) — type guard for the chained placement
- [presentation-cache.md](presentation-cache.md) — invalidate after `synchronize()`
