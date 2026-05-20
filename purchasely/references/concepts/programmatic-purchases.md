# Programmatic Purchases — Exact APIs

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

Use this when the app starts a purchase outside a Purchasely paywall button, for example from a custom Settings screen, native upsell, or your own paywall. In **Full mode**, Purchasely can validate the transaction. In **Observer mode**, do not use these Full-mode purchase APIs; run the purchase in your billing layer and follow [observer-mode-post-purchase.md](observer-mode-post-purchase.md).

## Rule

There is no universal `Purchasely.purchase(planId: ...)` / `Purchasely.purchase({ planId })` API. Native SDKs purchase a `PLYPlan`; cross-platform bridges expose `purchaseWithPlanVendorId`.

| Platform | Correct API |
|----------|-------------|
| iOS | `Purchasely.plan(with:success:failure:)` -> `Purchasely.purchase(plan:contentId:success:failure:)` |
| Android | `Purchasely.plan(vendorId, onSuccess, onError)` -> `Purchasely.purchase(activity, plan, offer, contentId, onSuccess, onError)` |
| React Native | `Purchasely.purchaseWithPlanVendorId({ planVendorId, offerId?, contentId? })` |
| Flutter | `Purchasely.purchaseWithPlanVendorId(vendorId: ..., offerId?, contentId?)` |
| Cordova | `Purchasely.purchaseWithPlanVendorId(planId, offerId, contentId, success, error)` |

## Code per platform

### iOS (Swift)

```swift
Purchasely.plan(with: "premium_yearly") { plan in
    Purchasely.purchase(
        plan: plan,
        contentId: nil,
        success: {
            Purchasely.userSubscriptions(true, success: { subscriptions in
                // Refresh premium state from subscriptions
            }, failure: { error in
                // Surface refresh error if needed
            })
        },
        failure: { error in
            // Surface purchase error
        }
    )
} failure: { error in
    // Plan vendor ID is missing or products are unavailable
}
```

### Android (Kotlin)

```kotlin
Purchasely.plan(
    "premium_yearly",
    onSuccess = { plan ->
        Purchasely.purchase(
            activity = activity,
            plan = plan,
            offer = null,
            contentId = null,
            onSuccess = {
                Purchasely.userSubscriptions(invalidateCache = true, listener = listener)
            },
            onError = { error ->
                // Surface purchase error
            }
        )
    },
    onError = { error ->
        // Plan vendor ID is missing or products are unavailable
    }
)
```

### React Native (TypeScript)

```ts
const purchasedPlan = await Purchasely.purchaseWithPlanVendorId({
  planVendorId: 'premium_yearly',
  offerId: null,
  contentId: null,
});

const subscriptions = await Purchasely.userSubscriptions({ invalidateCache: true });
```

### Flutter (Dart)

```dart
final purchasedPlan = await Purchasely.purchaseWithPlanVendorId(
  vendorId: 'premium_yearly',
  offerId: null,
  contentId: null,
);

final subscriptions = await Purchasely.userSubscriptions();
```

### Cordova (JavaScript)

```js
Purchasely.purchaseWithPlanVendorId(
  'premium_yearly',
  null, // offerId
  null, // contentId
  function(plan) {
    Purchasely.userSubscriptions(function(subscriptions) {
      // Refresh premium state from subscriptions
    }, function(error) {
      // Surface refresh error
    });
  },
  function(error) {
    // Surface purchase error
  }
);
```

## Promotional offers

Do not substitute the regular purchase call for an offer-aware flow:

- Full mode + Purchasely paywall: no custom purchase code; Purchasely handles the offer configured on the Screen.
- iOS custom/Observer flow: use the promotional-offer APIs from [promotional-offers.md](promotional-offers.md).
- Android custom/Observer flow: pass the Google `offerToken` to your billing layer.
- React Native / Flutter / Cordova: use `signPromotionalOffer` for Apple signatures when your custom billing flow needs it.

## Anti-patterns

- Do not write `Purchasely.purchase({ planId: ... })` on React Native or Flutter.
- Do not write `Purchasely.purchase(planId: ...)` on iOS.
- Do not pass a store SKU where a Purchasely plan vendor ID is expected.
- Do not use Full-mode purchase APIs in Observer mode.

## See also

- [running-modes.md](running-modes.md) — Full vs Observer ownership
- [observer-mode-post-purchase.md](observer-mode-post-purchase.md) — after app-owned purchases
- [subscription-checks.md](subscription-checks.md) — refresh premium gating after purchase
- [promotional-offers.md](promotional-offers.md) — offer-aware purchase flows
