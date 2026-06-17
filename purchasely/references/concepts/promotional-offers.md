# Promotional Offers, Offer Codes & Win-back — Universal Patterns

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

Purchasely supports four discount mechanisms surfaced by the App Store and Google Play. Picking the right one — and wiring it correctly in the SDK — is what determines whether a retention or acquisition campaign actually triggers.

## The four offer types

| Type | App Store | Google Play | Eligibility | Typical use |
|------|-----------|-------------|-------------|-------------|
| **Introductory Offer** | Free trial or discounted price for **new** subscribers | Free trial / intro price configured on the base plan | Determined by the store (one-time per subscription group) | Acquire new subscribers |
| **Promotional Offer** | Free period / discounted price for **active or lapsed** subscribers in the same subscription group | "Developer-determined" offer on a base plan | **You decide** who's eligible — surface the paywall only to targeted users | Retention, win-back |
| **Offer Code (one-time)** | Unique code per user, redeemed once (e.g. `YUHKJBKB`) | Same | Open to new, active, or expired subscribers (Apple) / per-store rules | Personalised acquisition, support gestures |
| **Offer Code (custom)** | Generic shareable code (e.g. `BLACKFRIDAY`) | Same | Same | Mass campaigns (Black Friday, partnerships) |

Source docs:

- [Understanding Offer Types](https://docs.purchasely.com/docs/understanding-offer-types)
- [Offer Code](https://docs.purchasely.com/docs/offer-code)
- [Configuring Promotional Offers (Apple)](https://docs.purchasely.com/docs/promotional-offers-configuration)
- [Configuring Developer-Determined Offers (Google)](https://docs.purchasely.com/docs/developer-determined-offers-configuration)
- [Implementing Promotional Offers](https://docs.purchasely.com/docs/promotional-offer-implementation)
- [Retention & Win-back](https://docs.purchasely.com/docs/retention-winback)

## SDK version requirement

Promotional offer purchase APIs require **SDK 4.0.0+**. On older versions, the user is charged the regular price silently.

## Eligibility is YOUR responsibility (Promotional Offers + Developer-Determined Offers)

> **You are responsible for the eligibility** of promotional / developer-determined offers. Apple does not enforce the "active or lapsed subscriber" rule, and Google flags developer-determined offers as eligible-to-all by default.

Two ways to control who sees them:

1. **Audience targeting on the paywall** (recommended) — build an audience using the built-in user attribute `Active Offer Type` (SDK ≥ 4.2.0) or `Expired Sub. Offer Type` (SDK ≥ 4.4.0), and surface the promo paywall only to that audience.
2. **`ignore-offer` tag on Google** — tag a developer-determined offer with `ignore-offer` so the SDK does not advertise it by default (you opt-in per paywall).

## `Active Offer Type` values

Useful for audience definitions in the Console:

| Value | Meaning |
|-------|---------|
| `Free Trial` | User is in an introductory free trial |
| `Intro Offer` | User is in an introductory discounted price |
| `Promotional Offer` | User benefits from a promotional offer |
| `Promo Code` | User redeemed an offer / promo code |
| `None` | User is paying the regular price (or no offer) |

`Expired Sub. Offer Type` exposes the same values for lapsed subscribers — perfect for win-back audiences (e.g. _"users who churned during a Promotional Offer"_).

## Webhook attribute

For server-side analytics and S2S forwarding, the `offer_type` attribute on `IN_APP_PURCHASE` / `RENEWAL` events takes one of: `NONE`, `INTRO_OFFER`, `FREE_TRIAL`, `PROMOTIONAL_OFFER`, `PROMO_CODE`.

Offer lifecycle events: `PROMO_CODE_STARTED` / `PROMOTIONAL_OFFER_STARTED` + `_CONVERTED` / `_NOT_CONVERTED`.

---

## Implementation

### Full mode — nothing to do

In Full mode (`runningMode: .full`), the SDK reads the offer on the paywall, signs the Apple promotional offer if needed (the Console must hold the Apple signing certificate — see [Configuring Promotional Offers](https://docs.purchasely.com/docs/promotional-offers-configuration#console-configuration)), and triggers the purchase end-to-end. **You do not need any custom code.**

### Observer mode / custom paywall — purchase the offer yourself

If you trigger purchases yourself (Observer mode, or your own paywall in Full mode), read the offer from the interceptor parameters and pass it back to the SDK.

#### iOS (Swift) — signed promotional offer purchase

```swift
// 1. Retrieve the plan
Purchasely.plan(with: "your_plan_vendor_id") { plan in
    guard let plan else { return }

    // 2. Pick the offer by vendorId (defined in the Purchasely Console)
    let promoOffer = plan.promoOffers.first { $0.vendorId == "your_promo_offer_vendor_id" }
    guard let promoOffer else { return }

    // 3. Trigger the signed purchase
    Purchasely.purchaseWithPromotionalOffer(
        plan: plan,
        contentId: nil,
        storeOfferId: promoOffer.storeOfferId,
        success: { /* purchased */ },
        failure: { error in /* surface */ }
    )
} failure: { error in /* surface */ }
```

The SDK fetches the Apple signature transparently. No app-side cryptography is required.

#### Android (Kotlin) — offer token from the interceptor

In v6 the offer parameters live on the `PLYPresentationAction.Purchase` sealed subclass; register a per-action interceptor and return a `PLYInterceptResult`:

```kotlin
Purchasely.interceptAction<PLYPresentationAction.Purchase> { info, purchase ->
    val sku = purchase.subscriptionOffer?.subscriptionId
    val basePlanId = purchase.subscriptionOffer?.basePlanId
    val offerId = purchase.subscriptionOffer?.offerId
    val offerToken = purchase.subscriptionOffer?.offerToken

    // Trigger your own Google Play Billing purchase with offerToken, then synchronize
    // …
    Purchasely.synchronize(onSuccess = { }, onError = { })

    PLYInterceptResult.SUCCESS   // app handled the purchase
}
```

#### React Native / Cordova — `subscriptionOffer` in interceptor parameters

```ts
Purchasely.setPaywallActionInterceptorCallback((result) => {
  if (result.action === PLYPaywallAction.PURCHASE) {
    // Cross-store generic fields
    const storeProductId = result.parameters.plan?.productId;
    const storeOfferId   = result.parameters.offer?.storeOfferId;

    // Google specifics (v5 / v6 / v8)
    const productId   = result.parameters.subscriptionOffer?.subscriptionId;
    const basePlanId  = result.parameters.subscriptionOffer?.basePlanId;
    const offerId     = result.parameters.subscriptionOffer?.offerId;
    const offerToken  = result.parameters.subscriptionOffer?.offerToken;

    // Apple specifics — call Purchasely.signPromotionalOffer({ storeProductId, storeOfferId })
    // to get { identifier, signature, keyIdentifier, timestamp } and pass them to your purchase flow

    // After your own purchase flow resolves:
    Purchasely.onProcessAction(false);
    Purchasely.closePresentation();
  } else {
    Purchasely.onProcessAction(true);
  }
});
```

#### Flutter (Dart) — `PurchasePayload` from the per-action interceptor

In v6 Flutter mirrors the native per-action model: register `Purchasely.interceptAction` for the purchase kind and return an `InterceptResult`.

```dart
Purchasely.interceptAction(PresentationActionKind.purchase, (info, payload) async {
  final purchase = payload as PurchasePayload;

  // Cross-store generic fields
  final storeProductId = purchase.plan?.productId;
  final storeOfferId   = purchase.offer?.storeOfferId;

  // Google specifics
  final productId  = purchase.subscriptionOffer?.subscriptionId;
  final basePlanId = purchase.subscriptionOffer?.basePlanId;
  final offerId    = purchase.subscriptionOffer?.offerId;
  final offerToken = purchase.subscriptionOffer?.offerToken;

  // Apple specifics — call Purchasely.signPromotionalOffer(...) to get the signature
  // and pass it to your own purchase flow, then synchronize:
  await Purchasely.synchronize();

  // After your own purchase flow resolves, dismiss the presentation:
  // await presentation.close();

  return InterceptResult.success; // app handled the purchase
});
```

See [Implementing Promotional Offers](https://docs.purchasely.com/docs/promotional-offer-implementation) for the full Swift / Kotlin / RN / Flutter samples.

---

## Offer codes — redemption UX

The redemption UX is platform-specific and worth surfacing in the design.

### iOS

- **One-time code** — opens the App Store offer-redemption sheet automatically.
- **Custom code** — can be triggered via:
  - the `promo code?` link on a Purchasely paywall, or
  - a dedicated promo-code paywall, or
  - a **Promo code custom action** (paywall action: `PROMO_CODE`, with the code pre-filled — Apple custom codes only).
- The Apple deeplink is `https://apps.apple.com/redeem?ctx=offercodes&id=APP_ID&code=CODE`.

### Android

- Redemption happens via the regular Play Billing flow: tap a CTA → **other payment methods** → enter the code.
- The Play deeplink is `https://play.google.com/redeem?code=CODE`.

> **Design implication.** Don't write a single "Redeem" UX. Either branch by platform, or rely on Purchasely's built-in paywall templates and the `PROMO_CODE` custom action — both already encode the right behaviour per OS.

---

## Retention & win-back recipe

A typical win-back funnel:

1. **Detect the lapsed user** — audience targeting on `Expired Subscription` attributes (`Expired Sub. Offer Type`, `Subscription end date`, etc.).
2. **Display the discounted paywall** — a Purchasely Screen containing the promotional offer plans, surfaced via a Placement or a Campaign (see [campaigns.md](campaigns.md)).
3. **Trigger the purchase** — Full mode handles it. Observer / custom paywall: use `purchaseWithPromotionalOffer` (iOS) or pass `offerToken` to your Play Billing client (Android).
4. **Track conversion** — `PROMOTIONAL_OFFER_CONVERTED` / `PROMO_CODE_CONVERTED` server events.

---

## Anti-patterns

- ❌ **Advertising a Google developer-determined offer to every user**. Either add audience targeting in the Console, or tag the offer with `ignore-offer` and opt-in per paywall.
- ❌ **Signing Apple promotional offers in the app**. The Console signs them server-side once you've uploaded the App Store Connect API key. Apps that try to sign client-side leak the private key.
- ❌ **Calling `purchaseWithPromotionalOffer` in Full mode without a custom paywall**. The SDK already does it. Calling it manually duplicates the purchase.
- ❌ **Hardcoding redemption UX as "open the App Store"**. Custom codes on iOS support an in-paywall flow; mass forking the UX to a browser breaks the funnel.

## See also

- [paywall-actions.md](paywall-actions.md) — `PURCHASE` action parameters (`subscriptionOffer`, `offer`, `plan`)
- [user-attributes-targeting.md](user-attributes-targeting.md) — building audiences on `Active Offer Type` / `Expired Sub. Offer Type`
- [campaigns.md](campaigns.md) — scheduling promotional paywalls without code
- [running-modes.md](running-modes.md) — Full vs Observer responsibilities
