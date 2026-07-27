# User Identity — Universal Patterns

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

Identity is the source of **most production "the user paid but lost their subscription"** tickets. Getting the call sequence right — and understanding what happens to anonymous → logged-in transitions — eliminates a whole category of bugs.

## Pseudonymous by design

Purchasely never asks for an email address or a phone number. The identifier passed to `userLogin` is an **opaque string of your choosing** — an internal UUID is enough, with **no loss of functionality**:

- **Analytics** — every UI / SDK event and every Server Event carries that ID.
- **A/B tests** — assignment is a hash of the identifier (bucket 0–99), deterministic whether the ID is pseudonymous or not.
- **Audiences** — matched on the user attributes you push yourself; nothing forces identifying data into them.

Two rules: **do not use an email address as the user ID** (it brings PII into the platform for no benefit), and **do not hash at the last moment app-side** — the ID must stay stable and identical to what your backend and webhook consumers use, otherwise the link between user and subscription is unrecoverable.

## The model

Purchasely tracks two user concepts:

| Concept | Set by | Persisted | Used for |
|---------|--------|-----------|----------|
| **Anonymous ID** | SDK at first `start()` (per-install UUID) | Locally | Pre-login analytics, anonymous subscriptions |
| **App User ID** | Your app via `Purchasely.userLogin(userId)` | Server-side, cross-device | Cross-device sync, S2S webhooks, attribution |

A user can hold subscriptions under both identities. When you call `userLogin` after an anonymous purchase, **Purchasely transfers the anonymous receipt(s) to the logged-in user** — provided you call `userLogin` before the user signs out / before the receipt is wiped by an uninstall.

## Decision tree

```
Does your app have a login / signup flow?
├── No
│   └── Don't call userLogin / userLogout. Purchasely uses the anonymous ID
│       (still tracked across sessions on the same device).
│
└── Yes
    ├── Is the user already logged in when the app launches?
    │   └── YES → call userLogin(userId) inside / immediately after start() completion
    │             (before any presentation fetch / preload / synchronize call).
    │
    ├── Does the user log in mid-session (login screen)?
    │   └── YES → call userLogin(userId) on successful authentication, BEFORE you
    │             route to the post-login screen and BEFORE refreshing subscription
    │             status. Anonymous receipts are merged automatically.
    │
    └── Does the user log out?
        └── YES → call userLogout() on sign-out. The next session starts with a
                  fresh anonymous ID. Cached subscription state is cleared.
```

## When to call `userLogin`

| Trigger | Why |
|---------|-----|
| App launch with a persisted session | Restores the cross-device view of the subscriber's state. |
| End of `signIn` / `signUp` success | Merges any anonymous receipts; needs to happen **before** subscription gating runs. |
| `applicationDidBecomeActive` / `onResume` after a logout-then-login on another device | Pulls latest server-side state if the user logged in elsewhere. |

> **Order matters.** If a presentation fetch/preload runs before `userLogin`, the audience evaluation may run against the anonymous user (no targeting matches). Always **set the identity first**, then fetch.

## When to call `userLogout`

| Trigger | Why |
|---------|-----|
| User signs out | Clears the App User ID, derived subscription cache, and user attributes for this device. |
| Account deletion | Same as logout. |

Do **not** call `userLogout` on logout-then-immediate-login (e.g. switching between accounts via SSO) — call `userLogin` with the new ID directly. The SDK handles the swap.

## Resyncing on foreground

A user may renew, cancel, or be charged while the app is backgrounded. To keep client-side gating fresh, call the SDK's sync entry point on foreground:

| Platform | API |
|----------|-----|
| iOS | `Purchasely.synchronize(success:failure:)` from `applicationDidBecomeActive` or `.scenePhase == .active` |
| Android | `Purchasely.synchronize()` from `ProcessLifecycleOwner` `ON_START` |
| React Native | `Purchasely.synchronize()` from `AppState.addEventListener('change', …)` on `active` |
| Flutter | `Purchasely.synchronize()` from `WidgetsBindingObserver.didChangeAppLifecycleState(AppLifecycleState.resumed)` |
| Cordova | `Purchasely.synchronize()` from the `resume` event |

`synchronize()` is idempotent and cheap. It re-pulls receipts (Observer mode pushes the local receipt, Full mode pulls the server state) and re-evaluates entitlements.

> In **Full mode**, `synchronize()` runs implicitly inside `start()` and after each purchase — manual resync on foreground is best-practice, not required.
> In **Observer mode**, `synchronize()` is the only signal the SDK has that the receipt changed. Always call it.

## Code samples

### iOS (Swift)

```swift
// In your auth success handler
authService.signIn(email: email, password: password) { result in
    switch result {
    case .success(let user):
        Purchasely.userLogin(with: user.id) { shouldRefreshCredentials in
            // true when a subscription was transferred from the anonymous user
            // → re-fetch the user's rights from your backend
        }
    case .failure: break
    }
}

// In your logout handler
authService.signOut()
Purchasely.userLogout()

// In SceneDelegate.sceneDidBecomeActive (or App's @Environment(\.scenePhase))
Purchasely.synchronize(
    success: { /* state refreshed */ },
    failure: { _ in /* will retry next foreground */ }
)
```

### Android (Kotlin)

```kotlin
// In your sign-in flow
authRepository.signIn(email, password)
    .onSuccess { user ->
        Purchasely.userLogin(user.id) { shouldRefresh ->
            // true when a subscription was transferred → refresh rights from your backend
        }
    }

// In your sign-out flow
authRepository.signOut()
Purchasely.userLogout()

// In Application.onCreate, register a foreground observer
ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
    override fun onStart(owner: LifecycleOwner) {
        Purchasely.synchronize()
    }
})
```

### React Native (TypeScript)

```ts
// Auth success
await Purchasely.userLogin(user.id);

// Logout
await Purchasely.userLogout();

// Foreground sync
AppState.addEventListener('change', (state) => {
  if (state === 'active') Purchasely.synchronize();
});
```

### Flutter (Dart)

```dart
// Auth success
await Purchasely.userLogin(user.id);

// Logout
await Purchasely.userLogout();

// Foreground sync — in a State that implements WidgetsBindingObserver
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) Purchasely.synchronize();
}
```

### Cordova (JavaScript)

```js
document.addEventListener('resume', () => {
  Purchasely.synchronize(() => {}, () => {});
}, false);
```

## Anonymous → logged-in merge — what to expect

1. App starts anonymous → user purchases premium → receipt is attached to the anonymous ID.
2. User signs up / signs in → you call `Purchasely.userLogin(newUserId)`.
3. Purchasely server transfers the anonymous receipt to `newUserId`.
4. `userSubscriptions` now returns the active subscription under the new identity.
5. The anonymous ID is retired.

> **Caveat.** If the user uninstalls before signing in, the anonymous ID is lost. There is no recovery path — Apple's `restoreAllProducts` will find the receipt again, but you can no longer attribute the original anonymous events.

On the webhook side a transfer emits **`DEACTIVATE` on the anonymous ID** and **`ACTIVATE` on the connected one**.

> **Only subscriptions transfer.** Consumables and non-consumables are **not** transferable from the anonymous user to the connected account.

## Anonymous user lifecycle

| Topic | Behavior |
|-------|----------|
| **Lifetime** | Tied to the installation. Stable while the app stays installed; uninstalling loses the ID with no recovery. |
| **Multi-device** | No — the anonymous ID is per install. Cross-device continuity requires a stable app-level ID that you provide. |
| **Entitlements** | Purchases attach to the `anonymous_user_id`; webhooks carry that field instead of `user_id`. |
| **Logout** | `userLogout()` removes the app ID, the SDK falls back to the device's anonymous ID, and user attributes are purged (Android: `userLogout(clearUserAttributes = false)` keeps them). The subscription stays attached to the identifier that owned it — it is **not** returned to the anonymous user. |
| **Reinstall, logged-in user** | Nothing to do — `userLogin` with the same ID restores entitlements from the backend. |
| **Reinstall, anonymous user** | A new `anonymous_user_id` is generated. **Restore** recovers the entitlement from the store, but the previous anonymous history and its event attribution are gone. |

> **Support tip.** Surface the `anonymous_user_id` somewhere in the app — a "My subscriptions" screen, or the footer of a contact email. It saves a lot of time when debugging a user-specific issue. Debug Mode also displays it.

## Unknown users

A purchase that reaches Purchasely **only through a store notification**, with no identifier attached. Causes:

- the purchase was made on an app version that did not have the SDK yet,
- the subscription came through **family sharing**,
- an error interrupted the purchase (app killed, network loss),
- **Observer mode** and the transaction completed outside the action interceptor without a `Purchasely.synchronize()` call.

Consequences: they appear in the Console subscription and one-time purchase listings, but **no webhook is sent** and nothing is forwarded to integrations (can be enabled on request). S2S forwarding keeps working.

Most resolve themselves: a family-shared subscription attaches automatically when the member opens the app, and an interrupted purchase is fixed by the user tapping **Restore**.

## One subscription, two accounts

Not by design: a subscription is attached to one identifier at a time, and a transfer **moves** it rather than duplicating it.

Family sharing is the store-provided exception — the member gets access, every server event carries `is_family_shared: true`, and `FAMILY_SHARED_REVOKED` fires when the owner removes access. Purchasely receives **no data about the payer**; the stores do not transmit it.

## Anti-patterns

- ❌ **Calling `userLogin` inside the `start()` closure without ordering.** If you also fetch/preload a presentation from the same closure, race the identity ahead.
- ❌ **Calling `userLogout` then `userLogin` on every app launch.** That generates a new anonymous ID each time and breaks attribution. Persist the session, restore the ID, call `userLogin` once.
- ❌ **Hashing or encrypting the userId before passing it.** The userId is a stable identifier you control — keep it stable, reversible, and consistent with your backend / webhooks. PII concerns belong to user attributes, not the ID.
- ❌ **Skipping `synchronize` on Observer mode.** Without it, the server never learns about purchases handled by your billing layer.

## See also

- [running-modes.md](running-modes.md) — Full vs Observer responsibilities around receipts
- [user-attributes-targeting.md](user-attributes-targeting.md) — setting attributes after `userLogin`
- [subscription-checks.md](subscription-checks.md) — gating premium content after login
- [observer-mode-post-purchase.md](observer-mode-post-purchase.md) — `synchronize → proceed → dismiss` ordering
