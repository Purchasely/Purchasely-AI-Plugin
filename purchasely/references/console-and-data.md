# Console, A/B Tests & Data — Answers Beyond the SDK

Client questions rarely stop at the SDK. This file covers the **Console-side and data-side answers** an SDK expert gets asked in the same thread: environments, A/B test reading, dashboard discrepancies, exports and webhooks.

Not SDK API surface — no code here except where the app is involved.

## Environments

One Purchasely **app per environment** is the recommended pattern: staging and production are separate apps, each with its own API key, catalogue and Screens. The mobile app passes the API key matching its build configuration.

Consequences to plan for:

- **Plan IDs differ between apps**, so a Screen duplicated across environments always needs its Offering remapped.
- **Dashboards are per app** — staging traffic never pollutes production numbers.
- **Webhook endpoints are per app** — staging can point at a test endpoint.
- Test purchases appearing in production dashboards almost always means the **test build is using the production API key**.

### Moving a Screen from staging to production

Use **Duplicate** from the Screens **list** view (row `⋮` actions), not from inside the Composer, then pick the target app. There is **no "Promote" action** and no automated export/import.

Duplicate does **not** carry over:

- the **Placement** that displays the Screen,
- the **Audiences**, A/B tests and Campaigns pointing at it.

After duplicating, replace the **Plans** in the Offering (Plan IDs differ per app) and publish in the target app.

### Why a deprecated Product or Plan cannot be deleted

Deleting it would break the history of the subscribers attached to it. Any Plan or Product with purchase history — **including sandbox and test transactions** — cannot be removed.

Retiring a Plan means **stopping referencing it**: remove it from every Screen's Offering, from A/B test and Campaign variants, then publish. Existing subscribers are untouched and no new user is offered it. A genuine Console-level cleanup (a Product created by mistake, no production purchase behind it) needs a support request with the exact IDs.

### Roles and access

| Role | Can invite users | Notes |
|------|------------------|-------|
| **Admin** | Yes | Manages team members and their per-app access |
| **Member** | No | Same product access, no user management |

Access is granted **per app** (or "All apps" to include future ones). "I just got access but see no data" is almost always an access-scope problem: no app granted, wrong app selected, or an app with no traffic yet — the SDK versions dashboard is the fastest way to tell whether any SDK ever reported in.

The first access to an account is granted by the Purchasely team; the invitation mail comes from `account-update[at]purchasely.io`.

### A Console tab times out

Some views aggregate over the full subscription history. Narrow the date range and filters first; a consistent timeout on a reasonable range is a bug worth reporting with app name, tab and filters.

## A/B tests

- Up to **26 variants** per test.
- **Deterministic assignment**: a hash of the user identifier buckets the user (0–99), so a given user always sees the same variant. Works identically with pseudonymous IDs.
- **Bayesian significance** computed in the Console.
- **Stripe / web transactions are included** in the results.

### Why variants are not split 50/50

- **Weights are configurable** and must total 100 — use *Equalize* for an even split; the defaults are not necessarily what you want.
- **Assignment is deterministic, not balanced in real time** — over a small sample, the hash does not produce an exactly even split.
- **Unique Viewers counts `PRESENTATION_VIEWED` events**, not assignments. If one variant is a Flow and the other a single Screen, or one renders slower, exposure counts diverge with identical weights.
- **Anonymous users reinstalling** get a new identifier, therefore a new bucket.

A large, persistent imbalance none of these explains is worth reporting with the test ID, configured weights and observed counts.

### Structures and constraints

- **Screen A vs Screen B** — the standard case. Keep the test **type** consistent: a UI test changes the Screen, a Price test changes the Plans. Mixing them makes the result uninterpretable.
- **Paywall vs no paywall** — the variant serves no Screen, the SDK returns a `DEACTIVATED` presentation and the app shows nothing. That measures the paywall's own impact.
- **One Placement per test** — a Placement already used by another test cannot be reused.
- **One test per Audience + Placement** combination.
- An **Audience ID cannot be changed** once associated with an A/B test or a transaction.

### When to read the result

- Run **1–2 weeks minimum** to cover a full weekly cycle.
- Aim for **95%+** Bayesian significance.
- Watch **View to Paid** (subscriptions started + trials converted, over unique viewers) rather than raw counts.
- **Trial Ongoing** users have not resolved yet — reading early overstates whichever variant pushed trials hardest.
- Revenue, ARPU and ARPPU stay live even after the test is stopped.

> A/B testing **between Flows**, or a Flow against a Screen, is a **Premium** capability. Testing your own paywall against a Purchasely one goes through [BYOS](concepts/byos.md) — and purchases made in your own screen must be synchronized, otherwise that arm reports no revenue.

## Getting the data out

| Channel | What it gives |
|---------|---------------|
| **S2S webhooks** | Real-time JSON on the whole subscription lifecycle — entitlement events, 27 lifecycle events, offer events, `TRANSACTION_PROCESSED`. The most complete channel. |
| **Third-party forwarding** | Automatic forwarding of server events and subscription attributes to analytics / CRM tools. |
| **Client API** | `https://api.purchasely.io/client/mobile_applications/{app_id}` with a Bearer token — configuration and audience operations today. |
| **CSV export** | *Download CSV* on each dashboard, respecting the active filters and granularity. |

- **One webhook endpoint per app.** To fan out, receive on a single endpoint and dispatch downstream, or use the built-in integrations.
- Events not acknowledged with **HTTP 200 are retried**, so a temporary outage does not lose data.

### Server Events vs UI / SDK Events

| Family | Source | Used for |
|--------|--------|----------|
| **Server Events** | Purchasely backend | Entitlements, subscription lifecycle, offers, revenue. Retried, source of truth. |
| **UI / SDK Events** | The SDK, inside the app | Paywall views, interactions, conversion funnels, quiz answers. |

This distinction is the first thing to check when a number looks wrong: revenue and subscription counts come from Server Events; **everything about paywall exposure and conversion comes from UI / SDK Events emitted by the app**.

### Native integrations

- **Attribution / MMP** — Adjust, AppsFlyer, Branch
- **Analytics** — Amplitude, Mixpanel, Google Analytics for Firebase, Piano (AT Internet), Segment, CleverTap
- **Engagement / CRM** — Airship, Braze, Batch, Customer.io, Iterable, MoEngage, OneSignal, Brevo
- **Other** — Firebase, Slack, RevenueCat

Most are server-side, so they keep working when the app is closed. All forwarding can be switched off with `revokeDataProcessingConsent([.thirdPartyIntegrations])` — see [concepts/privacy-settings.md](concepts/privacy-settings.md).

### Nothing arrives on the S2S side

1. **Store server notifications are not configured** — Purchasely must be the notification target on the store side.
2. **The events concern [unknown users](concepts/user-identity.md)**, for which no webhook is sent by default (can be enabled on request).
3. **The endpoint is not returning HTTP 200**, so events are retried rather than delivered.
4. **The integration is enabled on a different app** than the one generating transactions.

## Why a dashboard number does not match your own

1. **Which event family the metric is built on.** Paywall views, conversion rates and A/B exposure come from UI / SDK events — if `analytics` consent is revoked, those numbers are structurally incomplete while revenue stays correct.
2. **Unknown users** appear in subscription listings but not in paywall dashboards, and generate no webhook.
3. **Time zone and granularity** — dashboards aggregate on their own period boundaries; a daily comparison against a UTC query drifts at the edges.
4. **Unique viewer counts are approximate by construction** at scale, so they never reconcile to the exact row count of a raw export.
5. **Filters still applied** — exports respect the filters visible on screen.

### Revenue vs the store's payout report

The Purchasely **Revenue** chart is **gross**:

- what the user paid, **VAT included**,
- **before** the store commission (typically 15–30%),
- attributed to the **transaction date**,
- and **not MRR** — a yearly subscription shows its full amount on the transaction day, not spread over 12 months.

A store payout report is net of commission, often net of tax, and attributed to a settlement period. The two are not supposed to match. Reconcile in this order: same date range → same platform filter → gross vs net → transaction date vs payout period → refunds (which land in a later period on the store side).

### Which dashboard answers which question

| Question | Dashboard |
|----------|-----------|
| Is my subscriber base growing? | Subscription base evolution · Paid subscription movements |
| How healthy is my base? | Subscription status · Subscription retention |
| How much revenue am I making? | MRR · Revenue |
| Do my paywalls convert? | Screens and conversions · Funnel |
| Which SDK versions are in the wild? | SDK versions |
| Is the platform healthy right now? | Platform health |
| How many active users? | Active users and app sessions |

## Migrating onto Purchasely

An existing subscriber base can be imported (subscribers base import + catalogue import) so historical subscribers get entitlements and appear in dashboards from day one. This is how most migrations start.

## See also

- [concepts/screen-resolution.md](concepts/screen-resolution.md) — how a Placement picks a Screen at runtime
- [concepts/privacy-settings.md](concepts/privacy-settings.md) — consent, GDPR roles, user deletion API
- [concepts/analytics-integration.md](concepts/analytics-integration.md) — app-side event forwarding
- [purchasely-architecture.md](purchasely-architecture.md) — end-to-end platform map
