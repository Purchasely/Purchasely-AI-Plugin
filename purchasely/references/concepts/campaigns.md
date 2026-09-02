# Campaigns — Universal Patterns

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

> **⚠️ Minimum SDK version: 5.1.0** (see [sdk-versions.md](../sdk-versions.md))

**Campaigns** are no-code automations configured in the Purchasely Console. They display a Screen (paywall, in-app message, survey…) to an Audience either:

- **on an event trigger** (e.g. `APP_STARTED`), or
- **on a Placement** (instead of the Placement's default rules).

> **Capping applies to trigger-based delivery only.** Impression cap, frequency and exposure window are evaluated on the trigger path (`APP_STARTED` and other event triggers). A campaign served through a Placement is never capped: the SDK evaluates it every time the app calls that placement. A report that "the campaign capping does not work" on a placement-served campaign is expected behaviour, not a defect. Detail under *The four campaign dimensions* and *Anti-patterns* below.

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

Trigger-based campaigns can be deferred until your app explicitly authorises display — useful when you have a splash / onboarding / login flow that must finish first. On **native iOS/Android v6, Flutter v6, and Cordova v6** campaigns and deeplinks are governed by **two independent flags**: `allowCampaigns` (campaign display) and `allowDeeplink` (deeplink presentations) — both default to `true`. **React Native v6** controls deeplink/campaign presentation readiness with `.allowDeeplink(...)` on the builder (it replaces v5's `readyToOpenDeeplink`); it also exposes an `.allowCampaigns(...)` modifier.

> **Migration note — `allowCampaigns` default flipped from `false` (v5) to `true` (v6) on iOS/Android/Flutter.** A client upgrading from v5 who never set `allowCampaigns` explicitly relied on the v5 default of `false` (campaigns effectively off until the app opted in). After upgrading to v6 the same code now runs with `allowCampaigns` defaulting to `true` — campaigns configured on the dashboard can start appearing even though nothing changed in the app's code. **This is expected v6 behaviour, not a regression** — if you need the old opt-in behaviour, set `allowCampaigns(false)` explicitly at init and flip it once your app is ready. Note also that actually **opening** a campaign's deeplink is additionally gated on the SDK's config being ready (fetched and applied) — `allowCampaigns` / `allowDeeplink` control *authorisation*, config-readiness controls *capability*.

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

### React Native (v6)

```ts
// Set at init on the builder. The native default is true; if you omit
// .allowDeeplink(...) the RN bridge doesn't send the key and the native
// default (true) applies. Set it to false explicitly to queue campaigns/
// deeplinks during a splash / onboarding / login flow, then flip to true
// once that flow is complete.
await Purchasely.builder('YOUR_API_KEY')
  .allowDeeplink(true)   // replaces v5's readyToOpenDeeplink(true)
  .start();
```

### Cordova (v6)

```js
// v6 renamed readyToOpenDeeplink -> allowDeeplink and added allowCampaigns (both default true)
Purchasely.allowCampaigns(false);  // queue campaigns during onboarding
Purchasely.allowDeeplink(false);   // defer deeplink presentations during onboarding
// later, when the launch routine is complete:
Purchasely.allowCampaigns(true);   // queued campaigns display immediately
Purchasely.allowDeeplink(true);    // queued deeplinks display immediately
```

Like native/Flutter v6, `allowCampaigns` and `allowDeeplink` are **independent** flags on Cordova v6 and can also be passed in the `Purchasely.start(...)` options object.

### Flutter (v6)

```dart
await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .allowCampaigns(false)   // queue campaigns; flip back when onboarding ends
    .allowDeeplink(true)     // separate flag from allowCampaigns
    .start();
```

`allowCampaigns` is set at init via `PurchaselyBuilder` and is a separate flag from `allowDeeplink`. Both default to `true`.

> **v6 native / Flutter / Cordova:** `allowCampaigns` and `allowDeeplink` are **independent** flags (in v5 a single flag governed both). Control campaign display with `allowCampaigns`; control deeplink presentations with `allowDeeplink` (defaults to `true`). Android also **auto-intercepts** deeplinks, so no manual `handleDeeplink` call is required for them.
> **React Native v6:** `.allowDeeplink(...)` on the builder gates campaign/deeplink presentations. The native default is `true` on every platform, RN included — if the app never calls `.allowDeeplink(...)`, the RN bridge simply omits the key and the native default (`true`) applies; there is also an `.allowCampaigns(...)` modifier. Deeplinks you receive yourself are passed with `Purchasely.handleDeeplink(url)` — the v5 `isDeeplinkHandled` was removed and renamed to `handleDeeplink` (no alias).
> If you implement a [UI Handler](https://docs.purchasely.com/docs/ui-handler-deeplinks) to manage deeplink display yourself, **keep the presentation object returned** and do not refetch it — refetching loses the campaign context.

> **React Native v6 — dismiss handler for SDK-opened presentations.** Campaigns, deeplinks and Promoted IAP open presentations the app didn't trigger. Register a single global handler to observe their outcome (the v6 replacement for v5's `setDefaultPresentationResultCallback`):
>
> ```ts
> const subscription = Purchasely.setDefaultPresentationDismissHandler((outcome) => {
>   // outcome.presentation is always populated (identifies the closed screen)
>   console.log(outcome.presentation?.screenId, outcome.purchaseResult, outcome.closeReason);
> });
> // one handler active (re-register replaces); clean up with:
> subscription.remove(); // or Purchasely.removeDefaultPresentationDismissHandler()
> ```

## Placement-based campaigns — no extra SDK code

You already fetch the placement (native iOS/Android v6: `PLYPresentationBuilder.forPlacementId("PLACEMENT_ID")` / `PLYPresentation { placementId("PLACEMENT_ID") }`; React Native v6: `Purchasely.presentation.placement("PLACEMENT_ID").build()`; Flutter v6: `PLYPresentationBuilder.placement("PLACEMENT_ID").build()`; Cordova v6: `Purchasely.presentation.placement("PLACEMENT_ID").build()`). When a campaign targets that placement and the user matches the audience, the SDK substitutes the campaign's Screen for the Placement's default rules. Same presentation-type handling, same display path. Nothing to change in your code.

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

- ❌ **Leaving campaigns gated.** If you explicitly set `allowCampaigns(false)` / `allowDeeplink(false)` (any v6 platform — native iOS/Android, Flutter, Cordova, React Native) and never re-authorise display, trigger-based campaigns silently never appear. Flip both back to `true` once your app is ready to show SDK-opened presentations.
- ❌ **Re-enabling campaigns too early.** If your splash screen runs after `start()`, flipping `allowCampaigns(true)` / `allowDeeplink(true)` while the splash screen is still up lands the campaign paywall on top of it. Wait until your launch routine is complete before re-authorising display.
- ❌ **Coupling capping logic to placement-based campaigns.** Capping only applies on triggers — if you need capping on a placement, build the cap into your audience attribute or use a trigger.
- ❌ **Refetching the presentation returned by the deeplink handler.** You lose the campaign context (audience match, screen variant, exposure tracking).
- ❌ **Targeting subscribers with promotional offers without eligibility audience.** See [promotional-offers.md](promotional-offers.md#eligibility-is-your-responsibility-promotional-offers--developer-determined-offers).

## See also

- [paywall-actions.md](paywall-actions.md) — handling actions on the campaign Screen
- [user-attributes-targeting.md](user-attributes-targeting.md) — building audiences for `WHO`
- [promotional-offers.md](promotional-offers.md) — pairing campaigns with discounted offers
- [analytics-integration.md](analytics-integration.md) — mirroring `CAMPAIGN_*` events to third-party tools
- [presentation-types.md](presentation-types.md) — type guard applies the same way for campaign Screens
