# Dynamic Offerings — Runtime Plan / Offer Overrides

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

A **dynamic offering** lets your app decide, **at runtime**, which plan (and optionally which promotional offer) a paywall slot resolves to — without republishing the Screen. In the Screen Composer, a plan-picker option (or a CTA) is bound to an **offering reference** (a string key). At runtime you map that reference to a concrete plan with `setDynamicOffering(...)`.

Typical uses: contextual pricing (win-back vs onboarding), per-cohort plans, remote-config-driven experiments — all pointing the *same* screen at *different* plans.

## The one rule that trips people up: offerings are applied **server-side, at fetch time**

The SDK does **not** rewrite the paywall locally. When it fetches a presentation (the placement call), it sends the currently-registered offerings to the Purchasely backend, and the backend substitutes the mapped plan/offer into the returned paywall JSON.

Consequences:

- **Register offerings BEFORE you fetch / display the placement.** An offering set *after* the paywall is fetched has no effect until the next fetch.
- Offerings are **persisted** across app launches until you remove them — a stale offering from a previous session still applies. Call `removeDynamicOffering` / `clearDynamicOfferings` when a context ends.
- Because substitution is server-side, the *reference* must exactly match what the Screen Composer expects, and the *plan vendor id* must exist in your catalog.

## API by platform

`reference` + `planVendorId` are required; `offerVendorId` is optional (highlight a specific promotional offer). iOS additionally accepts `billingPlanType` — see [Monthly commitment billing](monthly-commitment.md).

```swift
// iOS (Swift) — call before fetchPresentation / display
Purchasely.setDynamicOffering(reference: "onboarding_offer",
                              planVendorId: "PURCHASELY_PLUS_YEARLY",
                              offerVendorId: nil) { success in
    // fetch / display the placement only after this returns true
}
Purchasely.getDynamicOfferings()                 // inspect
Purchasely.removeDynamicOffering(reference: "onboarding_offer")
Purchasely.clearDynamicOfferings()
```

```kotlin
// Android (Kotlin)
Purchasely.setDynamicOffering(
    reference = "onboarding_offer",
    planVendorId = "PURCHASELY_PLUS_YEARLY",
    offerVendorId = null,
) { success -> /* then fetch / display */ }
```

```ts
// React Native
const ok = await Purchasely.setDynamicOffering({
  reference: 'onboarding_offer',
  planVendorId: 'PURCHASELY_PLUS_YEARLY',
  offerVendorId: undefined,
})
```

```dart
// Flutter
final ok = await Purchasely.setDynamicOffering(
  DynamicOffering(reference: 'onboarding_offer', planVendorId: 'PURCHASELY_PLUS_YEARLY'),
);
```

`getDynamicOfferings`, `removeDynamicOffering`, and `clearDynamicOfferings` exist on every platform.

> **Note:** the `billingPlanType` argument is **iOS-only** at this time. Android, React Native, Flutter, and Cordova take `reference` / `planVendorId` / `offerVendorId` only.

## ⚠️ Pitfall: one plan → one billing type per presentation

Do **not** register several offering references that all resolve to the **same plan** within a single presentation while carrying **different billing plan types** (for example one `.monthly` and one `.upFront` on the same plan).

When you do, the returned paywall ends up describing that same plan **more than once with conflicting billing types**. The SDK matches a plan by its vendor id, so it can no longer tell which billing type applies to it, and may report **`.unspecified`** to the purchase interceptor (and use it for the purchase) even though one of the offerings requested `.monthly`. Symptom: `parameters.billingPlanType == .unspecified` in the interceptor instead of the `.monthly` you set on the offering.

Guidance:

- Map a given plan to **a single billing plan type per presentation**.
- If you need both an up-front and a monthly-commitment variant on screen, back them with **two distinct plans / products**, not two offering references on the same plan.
- When re-configuring, `clearDynamicOfferings()` first so a leftover offering from a previous screen/session doesn't add a second mapping for the same plan.

See [Monthly commitment billing](monthly-commitment.md) for the billing-type feature itself and [common issues](../troubleshooting/common-issues.md) for the diagnostic entry.

## Related

- [Monthly commitment billing (iOS)](monthly-commitment.md) — the `billingPlanType` feature
- [Promotional offers](promotional-offers.md) — what `offerVendorId` points at
- [Paywall actions](paywall-actions.md) — how a picker/CTA turns into a purchase action
- [Presentation cache](presentation-cache.md) — why "register before fetch" matters with preloading
