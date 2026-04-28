# Cross-platform subscriptions — coexistence rule

> Use when a question or issue involves a single `user_id` holding subscriptions on more than one platform (App Store + Stripe, Play Store + Stripe, etc.), Stripe S2S receipts, double billing, or "transfer" expectations between stores.

## Rule

**Purchasely does not enforce a single active subscription per `user_id` across platforms.** Any combination of App Store / Play Store / Huawei / Amazon / Stripe subscriptions for the same `user_id` will coexist as active in Purchasely. Each subscription emits its own lifecycle events independently.

## What `POST /receipts` (Stripe S2S) actually does

When a Stripe subscription receipt is posted to `https://s2s.purchasely.io/receipts`:

1. Receipt is validated and a new Purchasely subscription record is created for the `user_id`.
2. Stripe lifecycle events are emitted (`SUBSCRIPTION_STARTED`, `TRIAL_STARTED`, `ACTIVATE`, …).
3. **No cross-platform check is performed.** A pre-existing App Store / Play Store subscription on the same `user_id` is left untouched and continues its own lifecycle.

There is no "TRANSFER" event in this scenario. Purchasely's transfer logic only fires when an existing subscription's owning `user_id` changes (typical case: anonymous purchase later attached to a logged-in user) — not when a receipt arrives on a different platform for the same `user_id`.

## Concrete example

```
Day 1  [iOS]    SUBSCRIPTION_STARTED + TRIAL_STARTED + ACTIVATE   user_id=abc
Day 2  [Stripe] SUBSCRIPTION_STARTED + TRIAL_STARTED + ACTIVATE   user_id=abc   ← both now active
Day 8  [iOS]    TRIAL_NOT_CONVERTED + DEACTIVATE                  ← natural Apple expiry, not a transfer
```

Both subscriptions were ACTIVE simultaneously between Day 2 and Day 8.

## Recommendations to the developer

When this comes up, suggest one of:

1. **Block before purchase** — query the user's current Purchasely subscription status (via SDK or via your backend kept in sync through Purchasely webhooks) and refuse to launch the App Store / Play Store flow or send a Stripe receipt if an active subscription already exists on another platform.
2. **Warn with custom UI** — show a screen explaining that the user already has an active subscription elsewhere and instruct them to cancel it from the relevant store account first.
3. **Accept coexistence** — only if the product genuinely allows multiple concurrent subscriptions per user.

Do not suggest server-side workarounds that involve "force-deactivating" the other platform's subscription via Purchasely — that is not exposed and would not stop the underlying store from billing the user.

## Public documentation

Linked from the [Stripe configuration page](https://docs.purchasely.com/docs/stripe-configuration#iv-associating-stripe-subscriptions-to-purchasely) (callout under section IV).
