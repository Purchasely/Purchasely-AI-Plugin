# Campaigns — Universal Patterns

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

> **⚠️ Minimum SDK version: 5.1.0** (see [sdk-versions.md](../sdk-versions.md))

**Campaigns** are no-code automations configured in the Purchasely Console. They display a Screen (paywall, in-app message, survey…) to an Audience either:

- **on an event trigger** (e.g. `APP_STARTED`), or
- **on a Placement** (instead of the Placement's default rules).

Campaigns are the recommended way to schedule promos (Black Friday, anniversary offers), run retention flows, or centralise display rules — without shipping code.

## Why use them

| Without campaigns | With campaigns |
|-------------------|----------------|
| 5 placements showing the same Black Friday paywall → maintain 5 ordered audience/screen lists | One campaign associated to 5 placements |
| Cron a backend release at midnight to switch paywall | Schedule start / end date in the Console |
| Cancel-survey logic spread across paywall actions + user attributes + app code | One campaign keyed on `cancellation_survey` attribute |

Docs:

- [Campaigns overview](https://docs.purchasely.com/docs/campaigns)
- [Campaign configuration](https://docs.purchasely.com/docs/campaign-configuration)
- [Campaign SDK implementation](https://docs.purchasely.com/docs/campaigns-implementation)
- [Campaign use cases](https://docs.purchasely.com/docs/campaigns-use-cases)

## The four campaign dimensions

| Dimension | Value | Notes |
|-----------|-------|-------|
| **WHO** | Audience | Built-in attributes (`Total number of Screens dismissed`, `Active Offer Type`, …) and custom attributes set via `setUserAttribute` |
| **WHEN** | Event trigger + scheduling | Default trigger is `APP_STARTED` (app launch / cold restart). Add capping (`X displays per user per Y`), exposure window, impression cap |
| **WHAT** | Screen | Any Purchasely Screen — paywall, survey, message, flow |
| **WHERE** | Placement(s) | Optional — when set, the campaign overrides the Placement's default rules |

> **Important.** Capping (frequency, impression, exposure window) applies **only to trigger-based delivery**. Placement-based delivery is NOT capped — the SDK evaluates the campaign every time the placement is called.

## SDK setup — gating campaign display

Trigger-based campaigns can be deferred until your app explicitly authorises display — useful when you have a splash / onboarding / login flow that must finish first. On **native iOS/Android v6, Flutter v6, and Cordova v6** the deeplink-readiness flag is `allowDeeplink` (on native/Flutter `allowCampaigns` is a separate flag from `allowDeeplink`); the **React Native** v5 bridge still exposes `readyToOpenDeeplink`.

### iOS (Swift)

```swift
Purchasely.allowCampaigns(false)    // queue campaigns during onboarding
// …later, when the launch routine is complete:
Purchasely.allowCampaigns(true)     // queued campaigns display immediately
```

`allowCampaigns` can also be set at init: `Purchasely.apiKey("…").allowCampaigns(false).start { … }`. It defaults to `true`.

### Android (Kotlin)

```kotlin
Purchasely.allowCampaigns = false   // queue campaigns during onboarding
// …later, when the launch routine is complete:
Purchasely.allowCampaigns = true    // queued campaigns display immediately
```

Or at init via the DSL / Builder: `allowCampaigns(false)`. Defaults to `true`.

### React Native (v5)

```ts
Purchasely.readyToOpenDeeplink(true);
```

### Cordova (v6)

```js
// v6 renamed readyToOpenDeeplink → allowDeeplink (default true)
Purchasely.allowDeeplink(false);   // defer campaign/deeplink display during onboarding
// …later, when the launch routine is complete:
Purchasely.allowDeeplink(true);    // queued campaigns/deeplinks display immediately
```

### Flutter (v6)

```dart
await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .allowCampaigns(false)   // queue campaigns; flip back when onboarding ends
    .allowDeeplink(true)     // separate flag from allowCampaigns
    .start();
```

`allowCampaigns` is set at init via `PurchaselyBuilder` and is a separate flag from `allowDeeplink`. Both default to `true`.

> **v6 native:** `allowCampaigns` and `allowDeeplink` are **independent** flags (in v5 a single flag governed both). Control campaign display with `allowCampaigns`; control deeplink presentations with `allowDeeplink` (defaults to `true`). Android also **auto-intercepts** deeplinks, so no manual `handleDeeplink` call is required for them.
> If you implement a [UI Handler](https://docs.purchasely.com/docs/ui-handler-deeplinks) to manage deeplink display yourself, **keep the presentation object returned** and do not refetch it — refetching loses the campaign context.

## Placement-based campaigns — no extra SDK code

You already fetch the placement (native iOS/Android v6: `PLYPresentationBuilder.forPlacementId("PLACEMENT_ID")` / `PLYPresentation { placementId("PLACEMENT_ID") }`; Flutter v6: `PresentationBuilder.placement("PLACEMENT_ID").build()`; method-based React Native v5 / Cordova v6: `fetchPresentation("PLACEMENT_ID")`). When a campaign targets that placement and the user matches the audience, the SDK substitutes the campaign's Screen for the Placement's default rules. Same `PLYPresentationType` handling, same display path. Nothing to change in your code.

## Typical use cases

| Goal | Audience | Trigger / Placement | Notes |
|------|----------|---------------------|-------|
| **Free-user conversion** | `Total number of Screens dismissed` > 20, not active subscriber | Trigger `APP_STARTED`, impression cap `1 per user` | Creates FOMO; show once |
| **Black Friday offer** | Not active subscriber | Schedule start/end + associate to home/settings/feature placements | Auto-activates and deactivates; centralised across all placements |
| **Welcome offer after signup** | All users right after account creation | Trigger `account_created`, exposure window 3 days, cap 1 / session | Combine with a [countdown](https://docs.purchasely.com/docs/countdown) block on the paywall |
| **Retention — cancellation reason** | `cancellation_survey` = `too_expensive` | Trigger `subscription_cancelled` or a placement opened after the survey | Build the audience from a custom attribute populated by a [user survey](https://docs.purchasely.com/docs/user-surveys) |
| **Win-back lapsed subscribers** | `Expired Sub. Offer Type` = `Free Trial`, expired < 90 days | Trigger `APP_STARTED`, capping `1 per week` | Pair with a [Promotional Offer](promotional-offers.md) targeted at lapsed subs |
| **Free-trial-to-paid extension** | `Subscription status` = `Auto-renewing disabled` AND `Active Offer Type` = `Free Trial` / `Intro Offer` | Trigger `APP_STARTED` or surface on a settings placement | Combine with a 2nd-chance promo |

## Universal events the SDK fires for campaigns

Subscribe via the event delegate / listener (see [analytics-integration.md](analytics-integration.md)) to mirror campaign metrics into your analytics:

| Event | Meaning |
|-------|---------|
| `CAMPAIGN_TRIGGERED` | Trigger matched a user; the SDK is about to evaluate display |
| `CAMPAIGN_DISPLAYED` | Campaign's Screen was actually shown |
| `CAMPAIGN_NOT_DISPLAYED` | Trigger matched but capping/exposure/eligibility blocked the display |

Property bag includes `campaign_id`, `campaign_name`, `screen_id`, `audience_id`, `trigger_name`.

## Anti-patterns

- ❌ **Leaving campaigns gated.** If you set `allowCampaigns = false` (native iOS/Android v6 and Flutter v6) / `allowDeeplink(false)` (Cordova v6) / `readyToOpenDeeplink(false)` (React Native v5) and never flip it back, trigger-based campaigns silently never appear.
- ❌ **Re-enabling campaigns too early.** If your splash screen runs after `start()`, flipping `allowCampaigns = true` (native iOS/Android v6 and Flutter v6) / `allowDeeplink(true)` (Cordova v6) / `readyToOpenDeeplink(true)` (React Native v5) while it is still up lands the campaign paywall on top of the splash. Wait until your launch routine is complete.
- ❌ **Coupling capping logic to placement-based campaigns.** Capping only applies on triggers — if you need capping on a placement, build the cap into your audience attribute or use a trigger.
- ❌ **Refetching the presentation returned by the deeplink handler.** You lose the campaign context (audience match, screen variant, exposure tracking).
- ❌ **Targeting subscribers with promotional offers without eligibility audience.** See [promotional-offers.md](promotional-offers.md#eligibility-is-your-responsibility-promotional-offers--developer-determined-offers).

## See also

- [paywall-actions.md](paywall-actions.md) — handling actions on the campaign Screen
- [user-attributes-targeting.md](user-attributes-targeting.md) — building audiences for `WHO`
- [promotional-offers.md](promotional-offers.md) — pairing campaigns with discounted offers
- [analytics-integration.md](analytics-integration.md) — mirroring `CAMPAIGN_*` events to third-party tools
- [presentation-types.md](presentation-types.md) — type guard applies the same way for campaign Screens
