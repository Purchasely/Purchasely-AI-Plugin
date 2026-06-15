# User Attributes & GDPR Consent — Universal Patterns

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

User attributes are key-value pairs the SDK forwards to Purchasely servers. They power **audience targeting**, **paywall personalization**, and **flow gating** on the dashboard. Set them whenever your app learns something about the user. For SDK-level processing consent and revocation, use [privacy-settings.md](privacy-settings.md).

## When to set attributes

| Trigger | Reason |
|---------|--------|
| User signs up / logs in | Identify the user (`first_name`, `email`, `tier`, `signup_date`). |
| User updates their profile | Keep attributes fresh (`is_power_user`, `articles_read`). |
| User passes an in-app milestone | Trigger placement targeting (`completed_onboarding`, `created_first_project`). |
| User grants/revokes consent | `gdpr_consent`, `consent_date`. |

> **Attribute changes can change which audience matches** → invalidate any [presentation cache](presentation-cache.md) after setting attributes.

## Supported attribute types

Same on every platform; only the method signatures differ:

| Type | Use for |
|------|---------|
| String | Names, IDs, opaque tags. |
| Int (long) | Counters, ages. |
| Double | Scores, ratios. |
| Bool | Feature flags, consent. |
| Date | Signup date, last-active date. |
| String array | Tags, segments. |

## Code per platform

### iOS (Swift)

```swift
Purchasely.setUserAttribute(withStringValue: user.firstName,  forKey: "first_name")
Purchasely.setUserAttribute(withStringValue: user.email,      forKey: "email")
Purchasely.setUserAttribute(withIntValue:    user.age,        forKey: "age")
Purchasely.setUserAttribute(withDateValue:   user.signupDate, forKey: "signup_date")
Purchasely.setUserAttribute(withBoolValue:   user.isPowerUser,forKey: "is_power_user")
```

### Android (Kotlin)

```kotlin
Purchasely.setUserAttribute("first_name",   user.firstName)
Purchasely.setUserAttribute("email",        user.email)
Purchasely.setUserAttribute("age",          user.age)         // Int
Purchasely.setUserAttribute("signup_date",  user.signupDate)  // Date
Purchasely.setUserAttribute("is_power_user",user.isPowerUser) // Boolean
```

### React Native (TypeScript)

```ts
Purchasely.setUserAttributeWithString('first_name', user.firstName);
Purchasely.setUserAttributeWithString('email', user.email);
Purchasely.setUserAttributeWithNumber('age', user.age);
Purchasely.setUserAttributeWithDate('signup_date', user.signupDate);
Purchasely.setUserAttributeWithBoolean('is_power_user', user.isPowerUser);
```

### Flutter (Dart)

```dart
Purchasely.setUserAttributeWithString('first_name',   user.firstName);
Purchasely.setUserAttributeWithString('email',        user.email);
Purchasely.setUserAttributeWithInt('age',             user.age);
Purchasely.setUserAttributeWithDouble('score',        user.score);
Purchasely.setUserAttributeWithDate('signup_date',    user.signupDate);
Purchasely.setUserAttributeWithBoolean('is_power_user', user.isPowerUser);
```

### Cordova (JavaScript)

```js
Purchasely.setUserAttributeWithString('first_name',   user.firstName);
Purchasely.setUserAttributeWithString('email',        user.email);
Purchasely.setUserAttributeWithInt('age',             user.age);
Purchasely.setUserAttributeWithDouble('score',        user.score);
Purchasely.setUserAttributeWithDate('signup_date',    user.signupDate.toISOString());
Purchasely.setUserAttributeWithBoolean('is_power_user', user.isPowerUser);
```

## Reading and removing attributes

| Action | iOS | Android | RN | Flutter | Cordova |
|--------|-----|---------|----|---------|---------|
| Read all | `Purchasely.userAttributes` | `Purchasely.userAttributes` | `Purchasely.userAttributes()` | `Purchasely.userAttributes()` | `Purchasely.userAttributes(cb)` |
| Read one | `Purchasely.userAttribute(for:)` | `Purchasely.userAttribute(key)` | `Purchasely.userAttribute(key)` | `Purchasely.userAttribute(key)` | `Purchasely.userAttribute(key, cb)` |
| Remove | `Purchasely.clearUserAttribute(forKey:)` | `Purchasely.clearUserAttribute(key)` | `Purchasely.clearUserAttribute(key)` | `Purchasely.clearUserAttribute(key)` | `Purchasely.clearUserAttribute(key)` |
| Remove all | `Purchasely.clearUserAttributes()` | `Purchasely.clearUserAttributes()` | `Purchasely.clearUserAttributes()` | `Purchasely.clearUserAttributes()` | `Purchasely.clearUserAttributes()` |

## GDPR consent pattern

Initialize the SDK **always** (paywall display and subscription operations require it). Set consent-related attributes only after the user grants consent, and call `revokeDataProcessingConsent(...)` for processing categories the user declines.

### iOS

```swift
Purchasely
    .apiKey("YOUR_API_KEY")
    .runningMode(.full)          // default is .observer in v6 — set .full for purchase handling
    .storekitSettings(.storeKit2)
    .logLevel(.warn)
    .start { _ in }

if hasUserConsent() {
    enableTracking()
} else {
    showConsentDialog { granted in if granted { enableTracking() } }
}

func enableTracking() {
    Purchasely.setUserAttribute(withBoolValue: true, forKey: "gdpr_consent")
    Purchasely.setUserAttribute(withDateValue: Date(),  forKey: "consent_date")
}
```

### Android / RN / Flutter / Cordova

Same shape — initialize unconditionally, then set `gdpr_consent` (Bool) and `consent_date` (Date / ISO string) once the user opts in. If consent is revoked later, call `revokeDataProcessingConsent(...)` for the declined processing purposes, clear consent marker attributes if you store them, and reset any PII attributes you stored.

## Anti-patterns

- ❌ Skipping `Purchasely.start()` until consent is granted — paywalls won't display, fetch errors propagate.
- ❌ Treating `clearUserAttributes()` as GDPR revocation — use [privacy-settings.md](privacy-settings.md) and `revokeDataProcessingConsent(...)` for SDK processing control.
- ❌ Setting all attributes once at app start with stale values — refresh on login and profile updates.
- ❌ Forgetting to invalidate the [presentation cache](presentation-cache.md) after attribute changes — audiences resolve against old state.
- ❌ Storing very large strings as attributes — the dashboard truncates and audience rules misfire.

## See also

- [presentation-cache.md](presentation-cache.md) — when to invalidate after attribute changes
- [privacy-settings.md](privacy-settings.md) — data processing purposes, revocation, essential vs optional processing
- [subscription-checks.md](subscription-checks.md) — gating content based on subscription, not just attributes
