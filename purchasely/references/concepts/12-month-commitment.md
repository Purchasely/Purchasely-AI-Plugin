# 12-Month Commitment Plans — Monthly Billing with Annual Commitment

Applies to: **iOS, Android, React Native, Flutter, Cordova**. The billing model itself is store-specific (Apple vs. Google); the SDK surfaces it the same way across platforms.

A 12-month commitment plan charges the subscriber monthly but locks them into a 12-month term — cheaper-feeling than an annual upfront charge, while giving the business the same commitment length. Apple and Google implement this with different underlying mechanisms.

Official doc: [Understanding Offer Types — 12-Month Commitment](https://docs.purchasely.com/docs/understanding-offer-types).

## Apple — "Monthly with 12-Month Commitment"

A dedicated App Store billing plan type.

- Requires **iOS / iPadOS / tvOS / visionOS 26.4+**, **StoreKit 2**, and **Purchasely SDK 6.0+** (iOS, Flutter, React Native, Cordova).
- **Automatic fallback**: outside the **US** and **Singapore**, or on an older OS that doesn't support the plan, the App Store automatically falls back to the plan's configured **"1 Year Upfront"** price. No app-side branching is required — the store resolves this transparently.

## Google — native installment subscriptions

Google Play has its own native **installment subscriptions** mechanism. Unlike Apple's plan, it requires **no SDK-side configuration** — the installment terms (commitment length, monthly price) are configured entirely in the **Google Play Console**, on the base plan.

## Screen Composer pricing tags

Use these tags in Screen Composer text blocks to render the right price for a commitment plan:

| Tag | Renders |
|-----|---------|
| `{{MONTHLY_AMOUNT}}` | The per-month charge |
| `{{PRICE}}` | The plan's display price |
| `{{AMOUNT}}` | The total commitment amount |

## Reading the commitment from the interceptor

The `purchase` action interceptor exposes the commitment details alongside the usual plan/offer parameters:

- `params.billingPlanType` — which billing plan is being purchased.
- `plan.commitmentInfo` — commitment length and progress for the selected plan.

iOS exposes these as `PLYBillingPlanType`, `PLYCommitmentInfo`, and `PLYCommitmentProgress`. See [paywall-actions.md](paywall-actions.md) for the full per-action interceptor contract these fields ride on.

## Webhooks — server-to-server

Installment billing events forward through the usual S2S webhook channel:

- `INSTALLMENT_PAID`
- `INSTALLMENT_REFUNDED`

Both carry `commitment_*` attributes (commitment length, progress, remaining installments) alongside the standard subscription payload.

## See also

- [promotional-offers.md](promotional-offers.md) — the other Apple/Google offer mechanisms (intro offers, promotional offers, offer codes)
- [paywall-actions.md](paywall-actions.md) — full `purchase` action interceptor payload
- [subscription-management.md](subscription-management.md) — opening the native Manage Subscription page for a committed plan
