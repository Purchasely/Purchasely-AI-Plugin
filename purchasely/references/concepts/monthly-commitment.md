# Monthly Commitment Billing — Apple Advance Commitment & Google Play Installments

Applies to: **iOS, Android, React Native, Flutter, Cordova**. Two independent store mechanisms fall under this concept:

- Apple's **advance commitment** — a **12-month** commitment **billed monthly** instead of charged once up front. iOS-only purchase mechanism (StoreKit), surfaced via `PLYBillingPlanType`. Requires **iOS 26.4+** and **Purchasely SDK 6.0+** — native iOS, and the iOS side of Flutter, React Native, and Cordova bridges.
- Google Play's **native installment subscriptions** — Android's own commitment-plan primitive, configured entirely in the **Play Console** with no SDK-side plan type.

Official doc: [Understanding Offer Types — 12-Month Commitment](https://docs.purchasely.com/docs/understanding-offer-types).

## Apple — advance commitment (`PLYBillingPlanType`)

StoreKit models the commitment as a *billing plan type* on the subscription: **up-front** vs **monthly**. The user commits to 12 months but is charged month by month. Purchasely surfaces this as the public enum **`PLYBillingPlanType`**:

| Case | Meaning |
|------|---------|
| `.monthly` | 12-month commitment **billed monthly** (installment-style) |
| `.upFront` | Commitment **charged once up front** |
| `.unspecified` | No commitment billing info for this plan (plain subscription, or not configured) |

`.unspecified` is a deliberate third state — it is **not** the same as `.upFront`. Only an explicitly configured up-front commitment resolves to `.upFront`.

### Eligibility — all of these must hold

- **iOS 26.4 or later** on the device. The StoreKit billing-plan-type API and the monthly-commitment purchase option exist only from 26.4; on older iOS the feature is unavailable.
- **Purchasely iOS SDK v6+**.
- **Storefront**: monthly commitment is offered in most App Store countries but **not** in the **United States** and **Singapore** (as of Apple's current rollout). Outside eligible storefronts, or on an older OS that doesn't support the plan, the **App Store itself falls back** to the plan's configured **"1 Year Upfront"** price — no app-side branching required, the store resolves this transparently. The SDK's `billingPlanType` simply reflects the resolved type, so a US/SG tester seeing `.upFront` is expected behavior, not a bug.
- **App Store Connect**: the product must be configured with advance-commitment (monthly) pricing.
- **Purchasely configuration**: the plan must carry the monthly billing plan type — set on the plan in the Screen Composer, or supplied at runtime via a [dynamic offering](dynamic-offerings.md) (`billingPlanType: .monthly`, iOS-only).

### Setup checklist

1. **App Store Connect** — enable advance commitment / monthly billing on the (yearly) product.
2. **Purchasely Console** — set the plan's commitment billing type to monthly on the paywall, or pass it via `setDynamicOffering(..., billingPlanType: .monthly)`.
3. **App** — Purchasely iOS SDK v6+, test on a real device or simulator running **iOS 26.4+**, signed into a **non-US / non-Singapore** App Store account (sandbox or TestFlight).

### When you expect `.monthly` but get `.unspecified`

Check, in order:

1. **Storefront** is not US / Singapore (those fall back to `.upFront`, and if the plan isn't set up as up-front either, you'll see `.unspecified`).
2. **iOS version** is 26.4+.
3. You did **not** map the **same plan to multiple offering references with different billing types** in one presentation — that ambiguity resolves to `.unspecified`. See the pitfall in [Dynamic offerings](dynamic-offerings.md#pitfall-one-plan--one-billing-type-per-presentation).
4. The plan actually carries the monthly commitment type in the Console / dynamic offering.

## Google Play — native installment subscriptions

Google Play has its own native **installment subscriptions** mechanism, independent of Apple's plan type. It requires **no SDK-side configuration** — the installment terms (commitment length, monthly price) are configured entirely in the **Google Play Console**, on the base plan. There is no Android equivalent of `PLYBillingPlanType` to set: once the base plan is configured as an installment plan in the Play Console, Purchasely surfaces the resulting commitment info the same way it does for Apple (see below).

## Screen Composer pricing tags

Use these tags in Screen Composer text blocks to render the right price for a commitment plan, on either store:

| Tag | Renders |
|-----|---------|
| `{{MONTHLY_AMOUNT}}` | The per-month charge |
| `{{PRICE}}` | The plan's display price |
| `{{AMOUNT}}` | The total commitment amount |

## How it surfaces at runtime

- In the **purchase action interceptor**, `parameters.billingPlanType` reflects the resolved billing plan for the tapped plan (native iOS/Android; `params.billingPlanType` in the React Native / Flutter / Cordova bridges). A companion `commitmentInfo` field — `plan.commitmentInfo`, typed `PLYCommitmentInfo` / `PLYCommitmentProgress` on iOS — carries the commitment length and progress for the selected plan.
- In **Full** running mode, the SDK passes the correct StoreKit purchase option automatically when the resolved type is `.monthly`.
- In **Observer** mode, your own purchase code reads `parameters.billingPlanType` to decide how to purchase — so an incorrect value here changes what your app buys.

See [paywall-actions.md](paywall-actions.md) for the full per-action interceptor contract these fields ride on.

## Webhooks — server-to-server

Installment billing events forward through the usual S2S webhook channel:

- `INSTALLMENT_PAID`
- `INSTALLMENT_REFUNDED`

Both carry `commitment_*` attributes (commitment length, progress, remaining installments) alongside the standard subscription payload.

## Related

- [Dynamic offerings](dynamic-offerings.md) — how `billingPlanType` is supplied at runtime (iOS-only argument), and the same-plan pitfall
- [Promotional offers](promotional-offers.md) — the other Apple/Google offer mechanisms (intro offers, promotional offers, offer codes)
- [Paywall actions](paywall-actions.md) — full `purchase` action interceptor payload
- [Programmatic purchases](programmatic-purchases.md) — app-side purchase APIs (Observer mode)
- [Subscription management](subscription-management.md) — opening the native Manage Subscription page for a committed plan
- [Common issues](../troubleshooting/common-issues.md) — diagnostic entry for wrong / missing billing type
