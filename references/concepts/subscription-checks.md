# Subscription Status & Restore — Universal Patterns

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

Two related concerns sit outside the paywall display flow but are essential for any production integration:

1. **Subscription status checks** — gating premium content based on whether the user has an active subscription.
2. **Restore purchases** — a user action (often a button in Settings) that pulls receipt state back from the store.

## When to check subscription status

| Trigger | Why |
|---------|-----|
| App launch (after `start()` resolves) | Hide/show premium UI before the user navigates. |
| User opens premium-gated content | Final gate check before showing or showing a paywall. |
| After a successful purchase | Refresh derived UI state. |
| After `synchronize()` succeeds | Receipt state may have changed. |
| Pull-to-refresh in account screens | User-initiated refresh. |

> The SDK caches subscription state. Pass `invalidateCache=true` (Android) / equivalent on other platforms only when you need a forced re-pull — e.g. right after a known purchase or restore.

## `userSubscriptions` — code per platform

### iOS (Swift)

```swift
Purchasely.userSubscriptions(
    success: { subscriptions in
        let hasActive = subscriptions?.contains { sub in
            sub.plan.vendorId == "premium_monthly" ||
            sub.plan.vendorId == "premium_yearly"
        } ?? false
        completion(hasActive)
    },
    failure: { _ in completion(false) }
)
```

### Android (Kotlin)

```kotlin
Purchasely.userSubscriptions(invalidateCache = false, object : SubscriptionsListener {
    override fun onSuccess(subscriptions: List<PLYSubscription>) {
        val hasActive = subscriptions.any {
            it.plan?.vendorId in setOf("premium_monthly", "premium_yearly")
        }
        callback(hasActive)
    }
    override fun onFailure(error: PLYError) { callback(false) }
})
```

### React Native (TypeScript)

```ts
const subs = await Purchasely.userSubscriptions();
const hasActive = subs.some(
  s => s.plan?.vendorId === 'premium_monthly' ||
       s.plan?.vendorId === 'premium_yearly',
);
```

### Flutter (Dart)

```dart
final subs = await Purchasely.userSubscriptions();
final hasActive = subs.any((s) =>
    s.plan?.vendorId == 'premium_monthly' ||
    s.plan?.vendorId == 'premium_yearly');
```

### Cordova (JavaScript)

```js
Purchasely.userSubscriptions(
  subs => {
    const hasActive = subs.some(
      s => s.plan?.vendorId === 'premium_monthly' ||
           s.plan?.vendorId === 'premium_yearly',
    );
    callback(hasActive);
  },
  err => callback(false),
);
```

## Gating + automatic paywall fallback

A common pattern: check subscription, gate content, fall back to a paywall on miss.

```text
checkSubscriptionAccess():
    hasAccess = await userSubscriptions has active premium plan
    if hasAccess:
        showPremiumContent()
    else:
        fetch and display "PREMIUM_UPSELL" placement
        on successful purchase:
            refresh access state
```

Build this on top of the [presentation-types.md](presentation-types.md) guard — never assume the fetched placement is displayable.

## Restore purchases

Restore is a user-initiated action (usually a "Restore Purchases" button in Settings). It pulls receipt state from the store and re-applies any active subscriptions to the current user.

| Platform | API |
|----------|-----|
| iOS | `Purchasely.restoreAllProducts(success:failure:)` |
| Android | `Purchasely.restoreAllProducts(onSuccess:onError:)` |
| React Native | `Purchasely.restoreAllProducts()` (async) |
| Flutter | `Purchasely.restoreAllProducts()` (async) |
| Cordova | `Purchasely.restoreAllProducts(success, error)` |

### iOS (Swift)

```swift
Purchasely.restoreAllProducts(
    success: { plan in /* restored */ },
    failure: { error in /* surface to UI */ }
)
```

### Android (Kotlin)

```kotlin
Purchasely.restoreAllProducts(
    onSuccess = { plan -> /* restored */ },
    onError = { error -> /* surface */ }
)
```

### React Native / Flutter / Cordova

```ts
try {
  const plan = await Purchasely.restoreAllProducts();
} catch (err) { /* surface */ }
```

> On iOS, restore may prompt the user to sign in to the App Store. On Android, it queries Google Play Billing locally (no prompt). The user experience differs; account for that in your UI copy.

> **Observer mode:** if you handle restores yourself, intercept the `RESTORE` action in the [paywall actions interceptor](paywall-actions.md), run your own restore flow, then call `Purchasely.synchronize()` followed by `proceed(success)`.

## Close paywalls programmatically

After a manual gate-then-purchase flow, dismiss the paywall via `Purchasely.closeAllScreens()` (see [observer-mode-post-purchase.md](observer-mode-post-purchase.md) for SDK version requirements). Universal API across all platforms; iOS has an `@MainActor` requirement.

## Anti-patterns

- ❌ Polling `userSubscriptions` in a loop — use `synchronize()` + event delegate (Full mode) or your billing layer (Observer mode) to know when to recheck.
- ❌ Hardcoding `vendorId` strings in many places — keep them in a single constants file; they must match the Console exactly.
- ❌ Calling `restoreAllProducts()` automatically on every launch — restore is a user-triggered action. Auto-restore on launch produces redundant App Store prompts on iOS.
- ❌ Showing a "no subscription found" error if `userSubscriptions` is empty after restore — empty is the correct state for users who never paid. Show the paywall instead.

## See also

- [running-modes.md](running-modes.md) — Full vs Observer mode affects who runs the restore
- [paywall-actions.md](paywall-actions.md) — intercepting the `RESTORE` action in Observer mode
- [observer-mode-post-purchase.md](observer-mode-post-purchase.md) — `closeAllScreens()` version requirements
