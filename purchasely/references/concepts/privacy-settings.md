# Privacy Settings & Data Processing Consent

Applies to: **iOS, Android, React Native, Flutter, Cordova**. Requires **SDK 5.4.0+**.

Official docs: <https://docs.purchasely.com/docs/privacy-settings>

Purchasely is the data processor; the app owner is the data controller. Your app decides which processing is lawful, informs users, collects consent or opt-out choices, and translates that choice into SDK calls.

## GDPR roles and paperwork

| Role | Who | Meaning |
|------|-----|---------|
| **Data Controller** | The app publisher | Decides which processing is lawful and informs users accordingly |
| **Data Processor** | Purchasely | Processes data strictly under the controller's instructions |

- Data Processing Agreement (public): <https://www.purchasely.com/hubfs/PURCHASELY-DATA-PROCESSING-AGREEMENT.pdf>
- Compliant with **GDPR, COPPA and CCPA**; **SOC 2 certified**.
- Security overview: <https://www.purchasely.com/security> · Trust Center (certifications, policies, current subprocessor list): <https://app.vanta.com/purchasely.com/trust/grnmamthf8r38yu2xtlmwu>
- Hosting locations, subprocessors, breach notification and deletion deadlines are contractual — they are in the DPA.
- For a **DPIA**, the technical and organizational measures (TOMs) summary and the hosting regions for a specific contract are **provided on request** by the Purchasely contact or DPO — they are not published.

**No PII is required.** Purchasely never asks for an email address or a phone number; the user identifier is an opaque string of the publisher's choosing. Custom user attributes are entirely under the app's control — see [user-identity.md](user-identity.md).

## Processing register

Exposed in the SDK since **v5.4**, with the legal basis and revocability of each processing:

| # | Purpose | Legal basis | Revocable |
|---|---------|-------------|-----------|
| **1** | Operations strictly necessary for the service to function | Performance of contract | No |
| **2** | Audience measurement, statistical analysis, journey optimization | Legitimate interest **or** consent | Yes |
| **3** | Personalization of the journey and of the offers presented | Legitimate interest **or** consent | Yes |
| **4** | Recommendation of offers displayed spontaneously (Campaigns) | Legitimate interest **or** consent | Yes |

> The SDK is **not** wired to your CMP automatically. Translating the user's CMP choices into `revokeDataProcessingConsent` calls is the app's responsibility — there is no interface between the two.

## Processing purposes

| Purpose | What it disables when revoked |
|---------|-------------------------------|
| `analytics` | UI / SDK event collection. Use only as a last resort because conversion dashboards and A/B tests lose display/conversion data. |
| `identifiedAnalytics` | Identified analytics. UI / SDK events continue with anonymous identifiers only; optional analytics trackers are cleared. |
| `personalization` | Optional user attributes used for audience matching, paywall personalization, and offer customization. Essential attributes still work. |
| `campaigns` | Automatically triggered Campaigns / in-app experiences. |
| `thirdPartyIntegrations` | Forwarding subscription lifecycle events and subscription attributes to external integrations. |
| `allNonEssentials` | Revokes analytics, identified analytics, personalization, campaigns, and third-party integrations in one call. |

Processing strictly required to operate subscriptions cannot be revoked through this API.

## Lifecycle

1. Show your privacy notice / CMP.
2. Map the user's choice to the processing purposes to revoke.
3. Call `revokeDataProcessingConsent(...)` once with the full set of revoked purposes.
4. To reactivate all revokable processing, call the same API with an empty set/array.

The SDK persists the choice until changed or until the app is reinstalled.

## Code per platform

### iOS (Swift)

```swift
// Reject all non-essential processing
Purchasely.revokeDataProcessingConsent(for: [.allNonEssentials])

// Reactivate all processing
Purchasely.revokeDataProcessingConsent(for: [])
```

### Android (Kotlin)

```kotlin
// Reject all non-essential processing
Purchasely.revokeDataProcessingConsent(
    setOf(PLYDataProcessingPurpose.AllNonEssentials)
)

// Reactivate all processing
Purchasely.revokeDataProcessingConsent(emptySet())
```

### React Native (TypeScript)

```ts
import Purchasely, { PLYDataProcessingPurpose } from 'react-native-purchasely';

// Reject all non-essential processing
Purchasely.revokeDataProcessingConsent([
  PLYDataProcessingPurpose.ALL_NON_ESSENTIALS,
]);

// Reactivate all processing
Purchasely.revokeDataProcessingConsent([]);
```

### Flutter (Dart)

```dart
// Reject all non-essential processing
Purchasely.revokeDataProcessingConsent([
  PLYDataProcessingPurpose.allNonEssentials,
]);

// Reactivate all processing
Purchasely.revokeDataProcessingConsent([]);
```

### Cordova (JavaScript)

```js
// Reject all non-essential processing
Purchasely.revokeDataProcessingConsent([
  Purchasely.DataProcessingPurpose.allNonEssentials
]);

// Reactivate all processing
Purchasely.revokeDataProcessingConsent([]);
```

## User attributes and legal basis

Custom user attributes can be marked as essential or optional. If `personalization` is revoked, optional user attributes are wiped or ignored for audience matching. Essential attributes can still be used.

Examples:

```ts
// React Native
Purchasely.setUserAttributeWithString(
  'subscription_tier',
  'gold',
  PLYDataProcessingLegalBasis.ESSENTIAL,
);
```

```dart
// Flutter
Purchasely.setUserAttributeWithString(
  'subscription_tier',
  'gold',
  PLYDataProcessingLegalBasis.essential,
);
```

```js
// Cordova
Purchasely.setUserAttributeWithString(
  'subscription_tier',
  'gold',
  Purchasely.DataProcessingLegalBasis.essential
);
```

## Built-in attributes

If the user revokes consent for personalization or asks to reset non-essential attributes, use:

| Platform | API |
|----------|-----|
| iOS | `Purchasely.clearBuiltInAttributes()` |
| Android | `Purchasely.clearBuiltInAttributes()` |
| React Native | `Purchasely.clearBuiltInAttributes()` |
| Flutter | `Purchasely.clearBuiltInAttributes()` |
| Cordova | `Purchasely.clearBuiltInAttributes()` |

## Apps targeting children or families

Revoking `analytics` is the maximal setting — it stops all UI / SDK event collection and is the mode intended for children-oriented and privacy-focused apps:

```swift
Purchasely.revokeDataProcessingConsent(for: [.analytics])
```
```kotlin
Purchasely.revokeDataProcessingConsent(setOf(PLYDataProcessingPurpose.Analytics))
```

> **The trade-off is explicit.** Paywall displays are no longer measured, so conversion dashboards and A/B test reports are lost. Revenue and subscription data are unaffected (server events). Use deliberately, never as a default.

Store-level family protections need no app code: **Ask to Buy / PSD2** emits `IN_APP_DEFERRED` plus a native, localizable "Waiting for approval" screen (`ply_modal_alert_in_app_deferred_*`), and the entitlement opens only once the purchase is approved; **Family Sharing** carries `is_family_shared` on every server event and fires `FAMILY_SHARED_REVOKED` when the owner removes access.

## Deleting one user's data

`POST https://s2s.purchasely.io/user_deletion_requests` — signed with the Client shared secret:

```shell
curl --request POST \
  --url https://s2s.purchasely.io/user_deletion_requests \
  --header 'X-API-KEY: <app API key>' \
  --header 'Authorization: <HMAC-SHA256 signature of the body>' \
  --header 'Content-Type: application/json' \
  --data '{"user_id":"12345"}'
```

Processed asynchronously; returns a deletion request identifier support can trace. It covers irreversible pseudonymization of the identifier on all subscription events (including subscriptions transferred from or to that user), deletion of the stored webhook history and associated tokens, erasure of the attached devices' IP addresses, purge of stored purchases in the real-time database, and deletion marking of the user.

> **Throttling: 50 requests per 10 minutes.** Beyond that the endpoint returns `429` and blocks for 10 minutes.

**Export / portability** goes through the existing channels — S2S webhooks (most complete), third-party forwarding, the Client API, or CSV exports. See [../console-and-data.md](../console-and-data.md).

## Anti-patterns

- Do not delay `Purchasely.start()` until consent is granted; paywall display and subscription operations still require the SDK.
- Do not call `clearUserAttributes()` as a substitute for `revokeDataProcessingConsent(...)`; revocation controls SDK processing behavior.
- Do not revoke `analytics` casually; it removes the data needed for conversion dashboards and A/B test reporting.
- Do not send multiple incremental revocation calls when one full set is available; the docs recommend aggregating purposes in one call.

## See also

- [user-attributes-targeting.md](user-attributes-targeting.md) — setting essential vs optional attributes
- [analytics-integration.md](analytics-integration.md) — third-party forwarding and consent gating
- [campaigns.md](campaigns.md) — Campaign behavior when `campaigns` is revoked
