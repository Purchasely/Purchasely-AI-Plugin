# Observer Mode — Post-Purchase Flow

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

When the SDK runs in [Observer mode](running-modes.md), your app owns the billing flow. After a successful purchase **inside your billing code**, you need to tell the SDK to (a) record the transaction for analytics, (b) stop running its own purchase logic, and (c) dismiss the paywall.

The ordering and the exact API names matter. Get them wrong and you'll see frozen paywalls, double purchase attempts, or stale audience targeting on follow-up screens.

## The recommended sequence

After a successful Observer-mode purchase, **in this order**:

1. **`Purchasely.synchronize()`** — tells Purchasely to re-pull receipt state from the store servers. Fire-and-forget on most platforms; on iOS you may `await` it (see below) if you plan to chain a follow-up placement that targets subscribers.
2. **`proceed(false)` / `processAction(false)`** — tell the SDK's action interceptor that **you** handled the purchase. The `false` value means "do not run the SDK's own purchase flow on top of mine."
3. **Dismiss the paywall** — native SDKs use `Purchasely.closeAllScreens()`; current React Native / Flutter / Cordova bridges expose `closePresentation()`.

> **The order `proceed/processAction → dismiss` is non-negotiable.** The interceptor must learn the action was handled **before** the paywall tears down. Reversing them produces frozen UIs and double-action bugs.

## SDK version requirements

`closeAllScreens()` is the native dismissal method that tears down multi-step Flow paywalls correctly. Current cross-platform bridge APIs expose `closePresentation()` instead; do not generate RN/Flutter/Cordova code that calls `closeAllScreens()` unless the project has added its own native bridge.

| Platform | Minimum SDK |
|----------|-------------|
| iOS | **5.7.5+** — `@MainActor`-isolated. From a non-isolated context, wrap in `Task { @MainActor in Purchasely.closeAllScreens() }`. |
| Android | **5.7.4+** — no threading constraint. |
| React Native | Use `Purchasely.closePresentation()` in the public JS bridge. |
| Flutter | Use `Purchasely.closePresentation()` in the public Dart bridge. |
| Cordova | Use `Purchasely.closePresentation()` in the public JS bridge. |

If you cannot upgrade native SDKs, fall back to the older dismissal API available in that SDK, but be aware older APIs may not correctly dismiss Flow paywalls.

## Code per platform

### iOS (Swift) — `await synchronize` only if chaining a follow-up

```swift
@MainActor
private func handlePurchaseSuccess(proceed: @escaping (Bool) -> Void) async {
    do {
        try await synchronizeReceipt()    // await only if a follow-up placement targets subscribers
        proceed(false)
        Purchasely.closeAllScreens()
    } catch {
        proceed(false)
        Purchasely.closeAllScreens()
    }
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

### Android (Kotlin)

```kotlin
private fun onPurchaseSuccess(processAction: (Boolean) -> Unit) {
    Purchasely.synchronize()       // fire-and-forget (no callback on Android)
    processAction(false)
    Purchasely.closeAllScreens()
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

Some apps display a follow-up paywall after a successful purchase — a thank-you screen, a premium feature tour, a one-tap upsell, etc. **This is not part of the SDK contract**: it's just another `fetchPresentation` call with whatever placement ID you've configured on the Console (e.g. `"post_purchase"`, `"thank_you"`, `"premium_welcome"` — name it whatever you want, just match it in the dashboard).

### The audience-targeting gotcha

If the chained placement's audience targets users based on subscription state, **`synchronize()` must complete before the fetch**. Otherwise the fetch resolves against stale state and may return a `DEACTIVATED` (or wrong-fallback) presentation.

- On iOS, this is why the `synchronizeReceipt()` `await` matters.
- On Android, `synchronize()` is fire-and-forget so there's no awaitable handle. The cache refresh is usually fast enough in practice, but it's the trade-off.
- On React Native, `synchronize()` is fire-and-forget in the public JS bridge.
- On Flutter, `await synchronize()` resolves once the native bridge confirms; same trade-off as native.
- On Cordova, `synchronize()` is fire-and-forget in the public JS bridge.

### Example chain (iOS)

```swift
// After closeAllScreens() above:
Purchasely.fetchPresentation(for: "YOUR_POST_PURCHASE_PLACEMENT_ID") { presentation, error in
    guard let p = presentation,
          p.type == .normal || p.type == .fallback,
          let top = UIApplication.shared.topViewController() else { return }
    p.display(from: top)
} completion: { _, _ in /* dismissed */ }
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
