# Monthly Commitment Billing (Apple Advance Commitment) — iOS

Applies to: **iOS only** (native iOS SDK). Requires **iOS 26.4+** and **SDK v6+**.

Apple's **advance commitment** subscriptions let a long commitment period (e.g. a **12-month** commitment) be **billed monthly** instead of charged once up front. StoreKit models this as a *billing plan type* on the subscription: **up-front** vs **monthly**. The user commits to 12 months but is charged month by month.

Purchasely surfaces this as the public enum **`PLYBillingPlanType`**:

| Case | Meaning |
|------|---------|
| `.monthly` | 12-month commitment **billed monthly** (installment-style) |
| `.upFront` | Commitment **charged once up front** |
| `.unspecified` | No commitment billing info for this plan (plain subscription, or not configured) |

`.unspecified` is a deliberate third state — it is **not** the same as `.upFront`. Only an explicitly configured up-front commitment resolves to `.upFront`.

## Eligibility — all of these must hold

- **iOS 26.4 or later** on the device. The StoreKit billing-plan-type API and the monthly-commitment purchase option exist only from 26.4; on older iOS the feature is unavailable.
- **Purchasely iOS SDK v6+**.
- **Storefront**: monthly commitment is offered in most App Store countries but **not** in the **United States** and **Singapore** (as of Apple's current rollout). On a US or Singapore storefront the SDK automatically **falls back from `.monthly` to `.upFront`** — a US/SG tester seeing `.upFront` is expected behavior, not a bug.
- **App Store Connect**: the product must be configured with advance-commitment (monthly) pricing.
- **Purchasely configuration**: the plan must carry the monthly billing plan type — set on the plan in the Screen Composer, or supplied at runtime via a [dynamic offering](dynamic-offerings.md) (`billingPlanType: .monthly`, iOS-only).

## Setup checklist

1. **App Store Connect** — enable advance commitment / monthly billing on the (yearly) product.
2. **Purchasely Console** — set the plan's commitment billing type to monthly on the paywall, or pass it via `setDynamicOffering(..., billingPlanType: .monthly)`.
3. **App** — Purchasely iOS SDK v6+, test on a real device or simulator running **iOS 26.4+**, signed into a **non-US / non-Singapore** App Store account (sandbox or TestFlight).

## How it surfaces at runtime

- In the **purchase action interceptor**, `parameters.billingPlanType` reflects the resolved type for the tapped plan.
- In **Full** running mode, the SDK passes the correct StoreKit purchase option automatically when the resolved type is `.monthly`.
- In **Observer** mode, your own purchase code reads `parameters.billingPlanType` to decide how to purchase — so an incorrect value here changes what your app buys.

## When you expect `.monthly` but get `.unspecified`

Check, in order:

1. **Storefront** is not US / Singapore (those fall back to `.upFront`, and if the plan isn't set up as up-front either, you'll see `.unspecified`).
2. **iOS version** is 26.4+.
3. You did **not** map the **same plan to multiple offering references with different billing types** in one presentation — that ambiguity resolves to `.unspecified`. See the pitfall in [Dynamic offerings](dynamic-offerings.md#️-pitfall-one-plan--one-billing-type-per-presentation).
4. The plan actually carries the monthly commitment type in the Console / dynamic offering.

## Related

- [Dynamic offerings](dynamic-offerings.md) — how the `billingPlanType` is supplied at runtime, and the same-plan pitfall
- [Common issues](../troubleshooting/common-issues.md) — diagnostic entry for wrong / missing billing type
- [Programmatic purchases](programmatic-purchases.md) — app-side purchase APIs (Observer mode)
