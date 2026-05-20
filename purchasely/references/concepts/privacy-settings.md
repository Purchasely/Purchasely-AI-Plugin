# Privacy Settings & Data Processing Consent

Applies to: **iOS, Android, React Native, Flutter, Cordova**. Requires **SDK 5.4.0+**.

Official docs: <https://docs.purchasely.com/docs/privacy-settings>

Purchasely is the data processor; the app owner is the data controller. Your app decides which processing is lawful, informs users, collects consent or opt-out choices, and translates that choice into SDK calls.

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

## Anti-patterns

- Do not delay `Purchasely.start()` until consent is granted; paywall display and subscription operations still require the SDK.
- Do not call `clearUserAttributes()` as a substitute for `revokeDataProcessingConsent(...)`; revocation controls SDK processing behavior.
- Do not revoke `analytics` casually; it removes the data needed for conversion dashboards and A/B test reporting.
- Do not send multiple incremental revocation calls when one full set is available; the docs recommend aggregating purposes in one call.

## See also

- [user-attributes-targeting.md](user-attributes-targeting.md) — setting essential vs optional attributes
- [analytics-integration.md](analytics-integration.md) — third-party forwarding and consent gating
- [campaigns.md](campaigns.md) — Campaign behavior when `campaigns` is revoked
