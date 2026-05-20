# Analytics Integration — Universal Patterns

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

Purchasely emits a rich event stream — both **on-device** (UI / SDK events) and **server-side** (subscription lifecycle webhooks). Most teams want those events flowing into Firebase, Amplitude, AppsFlyer, Mixpanel, Adjust, Branch, internal mirrors, etc.

There are **two complementary integration paths**, and you should think about both before writing forwarding code.

## Path A — Server-side (recommended for billing events)

Purchasely's **3rd-party integrations** (Console → Settings → Integrations) and **Webhooks** push subscription lifecycle events (`IN_APP_PURCHASE`, `RENEWAL`, `CANCELLATION`, `EXPIRATION`, `REFUND`, …) directly from Purchasely's backend to:

- Firebase / Google Analytics 4
- Amplitude
- AppsFlyer / Adjust / Branch / Singular / Kochava
- Mixpanel, Iterable, Braze, Customer.io, …
- Your own webhook endpoint

Why server-side:

- **No client code to maintain.** Toggle in the Console.
- **Single source of truth.** The Purchasely server already deduplicates events, validates receipts, and handles refund / billing-issue lifecycle — your client never sees those.
- **Reliable on refunds / renewals.** A renewal that happens while the app is uninstalled still fires.

Setup checklist:

- [ ] Enable the desired 3rd-party integration in the Console
- [ ] Activate the events you want forwarded
- [ ] Pass your 3rd-party analytics SDK `user_id` to Purchasely as a [user attribute](user-attributes-targeting.md), so events land on the right user in both systems
- [ ] Validate end-to-end with a sandbox purchase

See [3rd-party analytics integration](https://docs.purchasely.com/docs/analytics-3rd-party) for the per-vendor mapping.

## Path B — Client-side (recommended for UI events)

The on-device events (`PRESENTATION_VIEWED`, `BUTTON_CLICKED`, `PRESENTATION_CLOSED`, `PLAN_SELECTED`, …) tell you **how the paywall is being interacted with**, not whether a charge happened. Forward those from the SDK event delegate / listener to your analytics SDK.

API per platform:

| Platform | Hook |
|----------|------|
| iOS | `Purchasely.setEventDelegate(self)` with a class conforming to `PLYEventDelegate` |
| Android | `Purchasely.eventListener = object : EventListener { override fun onEvent(event: PLYEvent) { … } }` |
| React Native | `Purchasely.addEventListener((event) => { … })` |
| Flutter | `Purchasely.purchaseListener` / `Purchasely.eventStream.listen((event) => { … })` |
| Cordova | `Purchasely.addEventsListener((event) => { … })` |

See [UI SDK Events](https://docs.purchasely.com/docs/ui-sdk-events) for the full event taxonomy and property bag fields.

## Recommended architecture — an analytics wrapper

> **Pattern, not requirement.** This is the same shape as the optional Purchasely SDK wrapper described in [architecture-patterns.md](../architecture-patterns.md): a single class that owns every call into your third-party analytics, mapped to your domain events. The Purchasely SDK works without this — the wrapper is for testability and to keep vendor-specific code in one place.

**Why a single wrapper:**

- One class to swap when you change analytics vendor
- One place to map Purchasely event names → your taxonomy
- Easy to mock in tests (the rest of the app sees an interface, not Firebase)
- Easy to gate by [GDPR consent](user-attributes-targeting.md) — flip the consent flag once, every downstream tool stops receiving events

### iOS (Swift) — example shape

```swift
protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent)
    func identify(userId: String)
}

final class AnalyticsManager: AnalyticsTracking {
    private let firebase: FirebaseAnalyticsAdapter
    private let amplitude: AmplitudeAdapter
    private let appsflyer: AppsFlyerAdapter

    func track(_ event: AnalyticsEvent) {
        firebase.log(event.name, parameters: event.properties)
        amplitude.logEvent(event.name, withEventProperties: event.properties)
        appsflyer.logEvent(name: event.name, values: event.properties)
    }

    func identify(userId: String) {
        firebase.setUserID(userId)
        amplitude.setUserId(userId)
        appsflyer.setCustomerUserID(userId)
        // Forward to Purchasely so events arriving on the server can be reconciled
        Purchasely.setUserAttribute(withStringValue: userId, key: "amplitude_user_id")
    }
}

// Wire Purchasely → AnalyticsManager
final class PurchaselyEventForwarder: NSObject, PLYEventDelegate {
    let analytics: AnalyticsTracking
    init(analytics: AnalyticsTracking) { self.analytics = analytics }

    func eventTriggered(_ event: PLYEvent, properties: [String: Any]?) {
        analytics.track(AnalyticsEvent(
            name: "purchasely_\(event.name.lowercased())",
            properties: properties ?? [:]
        ))
    }
}

// At startup
Purchasely.setEventDelegate(PurchaselyEventForwarder(analytics: analyticsManager))
```

### Android (Kotlin) — example shape

```kotlin
interface AnalyticsTracking {
    fun track(name: String, properties: Map<String, Any?>)
    fun identify(userId: String)
}

class AnalyticsManager(
    private val firebase: FirebaseAdapter,
    private val amplitude: AmplitudeAdapter,
    private val appsflyer: AppsFlyerAdapter,
) : AnalyticsTracking {
    override fun track(name: String, properties: Map<String, Any?>) {
        firebase.logEvent(name, properties)
        amplitude.logEvent(name, properties)
        appsflyer.logEvent(name, properties)
    }
    override fun identify(userId: String) {
        firebase.setUserId(userId)
        amplitude.setUserId(userId)
        appsflyer.setCustomerUserId(userId)
        Purchasely.setUserAttribute("amplitude_user_id", userId)
    }
}

// Wire Purchasely → AnalyticsManager
Purchasely.eventListener = object : EventListener {
    override fun onEvent(event: PLYEvent) {
        analyticsManager.track(
            "purchasely_${event.name.name.lowercase()}",
            event.properties.toMap(),
        )
    }
}
```

### React Native / Flutter / Cordova

Same shape — keep one `AnalyticsManager` (or `AnalyticsService`, `Telemetry`, whatever your codebase calls it), forward Purchasely events with `Purchasely.addEventListener` (RN / Cordova) or `Purchasely.eventStream.listen` (Flutter), and pass through to your N vendor SDKs.

## What to track from the client vs the server

| Event | Source |
|-------|--------|
| Paywall views, taps, dismissals, close reasons | Client (UI events) |
| Plan selected, button clicked | Client |
| Purchase attempt (UI), purchase failed (UI) | Client |
| Purchase completed (receipt-validated) | **Server** (via webhook / 3rd-party) |
| Renewals, refunds, cancellations, billing issues | **Server** |
| Subscription start / end / win-back conversion | **Server** |

The client sees "the user tapped buy". The server sees "the user was actually charged". Don't trust the client to fire `purchase_completed` — wire it through the webhook so you don't double-count, miss refunds, or attribute pending purchases.

## Pairing user IDs across systems

For Path A to land events on the right Amplitude / Firebase / AppsFlyer user, the analytics SDK's user ID has to flow into Purchasely. Two options:

1. **As a [user attribute](user-attributes-targeting.md)** — `setUserAttribute("amplitude_user_id", "...")`. Purchasely forwards it on every webhook event.
2. **As the Purchasely user ID** — call `Purchasely.userLogin(yourAppUserId)` and reuse the same ID in your analytics SDK. Simplest if you control all the user IDs.

Pick **one** scheme and document it — mixing the two produces the silent "events arrive but the user is unknown" bug.

## Anti-patterns

- ❌ **Forwarding client-side purchase events to billing analytics.** They will silently fire before receipt validation, double-count on retries, and miss refunds.
- ❌ **N event delegates wired to N SDKs.** Goes through one wrapper. When you change vendor, you have one file to update.
- ❌ **Ignoring `GDPR consent`.** The wrapper should short-circuit `track()` until consent is granted (see [user-attributes-targeting.md](user-attributes-targeting.md)).
- ❌ **Calling `identify()` before `userLogin()`.** The Purchasely user ID must be set first so the analytics ID maps onto an identifiable subscriber.

## See also

- [user-attributes-targeting.md](user-attributes-targeting.md) — user attributes are how Purchasely forwards your analytics IDs server-side
- [user-identity.md](user-identity.md) — `userLogin` / `userLogout` ordering
- [paywall-actions.md](paywall-actions.md) — intercepting paywall actions for client-side analytics
- [campaigns.md](campaigns.md) — campaigns fire `CAMPAIGN_*` events you may want to mirror
- [Purchasely Analytics docs](https://docs.purchasely.com/docs/analytics-3rd-party)
- [Purchasely UI SDK events](https://docs.purchasely.com/docs/ui-sdk-events)
- [Purchasely Server Events](https://docs.purchasely.com/docs/server-events)
