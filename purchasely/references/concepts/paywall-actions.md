# Paywall Actions & Interceptor — Universal Concept

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

The **action interceptor** is a callback the SDK invokes when the user interacts with a paywall (taps Buy, Login, Restore, Close, etc.). It is the single most error-prone part of any Purchasely integration.

## The golden rule

**Every code path through the interceptor MUST call the proceed/processAction callback exactly once.**

If a branch (early return, error catch, `switch default`, `try/catch`, etc.) skips it, the paywall UI freezes permanently — this is the #1 most common Purchasely bug across all platforms. If a branch calls it twice, behavior is undefined.

When in doubt, wrap the handler in a `try/finally` (or equivalent) that calls `proceed(false)` / `processAction(false)`.

## `PLYPresentationAction` enum

Same set of actions on every platform; only the casing changes.

| Action | When triggered | Typical handling |
|--------|---------------|------------------|
| `purchase` | User tapped a purchase button | Full mode → `proceed(true)`. Observer mode → run your own billing flow, then `proceed(success)`. |
| `restore` | User tapped Restore | Full mode → `proceed(true)`. Observer mode → run your own restore, then `proceed(success)`. |
| `login` | User tapped a login link | Show your login UI; on success `proceed(true)`, on cancel `proceed(false)`. |
| `close` | User tapped Close | Dismiss the paywall and `proceed(true)`. |
| `navigate` | User tapped a custom navigation link | Handle the link (push a screen, open a URL), then `proceed(true)`. |
| `open_presentation` | User tapped a link to another presentation | Either let the SDK handle (`proceed(true)`) or fetch yourself. |
| `promo_code` | User tapped Promo Code (iOS shows native sheet) | `proceed(true)`. |

Casing reference per platform:

| Platform | Enum |
|----------|------|
| iOS | `PLYPresentationAction.purchase` / `.restore` / `.login` / `.close` / `.navigate` / `.open_presentation` / `.promo_code` |
| Android | `PLYPresentationAction.PURCHASE` / `.RESTORE` / `.LOGIN` / `.CLOSE` / `.NAVIGATE` / `.OPEN_PRESENTATION` / `.PROMO_CODE` |
| React Native | `PLYPaywallAction.PURCHASE` etc. (string constants) |
| Flutter | `PLYPaywallAction.purchase` / `.restore` / `.login` / `.close` / etc. |
| Cordova | String values: `'purchase'`, `'restore'`, `'login'`, `'close'`, `'navigate'`, `'open_presentation'`, `'promo_code'` |

## Registering the interceptor

Register **once** at initialization, ideally right after `start()`. Re-registering replaces the previous interceptor.

### iOS (Swift)

```swift
Purchasely.setPaywallActionsInterceptor { [weak self] action, parameters, info, proceed in
    switch action {
    case .login:
        self?.showLogin { success in proceed(success) }
    case .purchase:
        proceed(true)   // Full mode lets the SDK continue
    default:
        proceed(true)
    }
}
```

### Android (Kotlin)

```kotlin
Purchasely.setPaywallActionsInterceptor { info, action, parameters, processAction ->
    when (action) {
        PLYPresentationAction.LOGIN -> showLogin { success -> processAction(success) }
        PLYPresentationAction.PURCHASE -> processAction(true)
        else -> processAction(true)
    }
}
```

### React Native (TypeScript)

```ts
Purchasely.setPaywallActionInterceptorCallback(result => {
  const { action } = result;
  switch (action) {
    case PLYPaywallAction.LOGIN:
      showLogin().then(ok => Purchasely.onProcessAction(ok));
      return;
    case PLYPaywallAction.PURCHASE:
      Purchasely.onProcessAction(true);
      return;
    default:
      Purchasely.onProcessAction(true);
  }
});
```

### Flutter (Dart)

```dart
Purchasely.setPaywallActionInterceptor((paywallAction) {
  switch (paywallAction.action) {
    case PLYPaywallAction.login:
      showLogin().then((ok) => Purchasely.onProcessAction(ok));
      break;
    case PLYPaywallAction.purchase:
      Purchasely.onProcessAction(true);
      break;
    default:
      Purchasely.onProcessAction(true);
  }
});
```

### Cordova (JavaScript)

```js
Purchasely.setPaywallActionInterceptor(result => {
  switch (result.action) {
    case 'login':
      showLogin().then(ok => Purchasely.onProcessAction(ok));
      return;
    case 'purchase':
      Purchasely.onProcessAction(true);
      return;
    default:
      Purchasely.onProcessAction(true);
  }
});
```

## Mode-dependent behaviour

| Action | Full mode | Observer mode |
|--------|-----------|---------------|
| `purchase` | `proceed(true)` — SDK runs the purchase. | Run your own billing flow, call `Purchasely.synchronize()` on success, then `proceed(false)` so the SDK doesn't re-run a purchase. |
| `restore` | `proceed(true)` — SDK restores. | Run your own restore, then `proceed(success)`. |
| `login` | App handles. SDK then re-fetches with the new user. | Same. |

## Chaining multiple actions on a single button

A button in the Screen Composer can carry **more than one action**. The actions execute **sequentially** once the first one completes successfully. This is configured in the Console (Screen Composer → button → Actions), **not in the SDK code**.

Typical chains:

| First action | Second action | Result |
|--------------|---------------|--------|
| `purchase` | *(none)* | Default: closes the presentation in **Full mode**, does nothing in **Observer mode** (the paywall stays open — your app decides what's next). |
| `purchase` | `open_screen` (next Flow step) | After successful purchase, the SDK advances the Flow to the next Screen. |
| `purchase` | `open_placement` | After successful purchase, the SDK fetches & displays the configured placement (e.g. an upsell, a thank-you screen). |
| `purchase` | `navigate` (deeplink) | After successful purchase, the SDK fires the deeplink. The app handles it via the interceptor (`navigate` action) or the deeplink listener. |
| `purchase` | `close` | Forces the dismiss even if the default would be to stay open (Observer). |
| `login` | `purchase` | After login completes (your `proceed(true)`), the SDK runs the purchase. |

Key points:

- **Default after `purchase` is intentional.** In Full mode the SDK closes the paywall on success so the user lands back in the app. In Observer mode the SDK has no opinion — it doesn't know what the app's purchase flow returned — so it leaves the paywall in place. If you want a different behaviour, **add a second action in the Composer**, don't try to coerce it from the interceptor.
- **The interceptor sees only the action being executed at this moment.** For a `purchase + open_placement` chain, you receive `purchase` first (call `proceed(true)`); the SDK then triggers the second action on its own and you receive it as a separate interceptor call (e.g. `open_presentation`).
- **`proceed(false)` short-circuits the chain.** If your purchase branch ends with `proceed(false)` (cancelled / failed / Observer-mode declined), the second action is **not** executed.
- **Configuration is a Console concern.** Mobile engineers cannot add a "second action" from the SDK — ask the team running the Screen Composer to wire it in the button's Actions list.

## Anti-patterns

- ❌ Calling `proceed` / `processAction` inside an async block whose error path doesn't call it.
- ❌ Returning from the interceptor without calling `proceed` (e.g. `if (cond) return;`).
- ❌ Calling `proceed` twice (e.g. once in the happy path, once in `finally`).
- ❌ Doing heavy synchronous work in the interceptor — the paywall is waiting on you.
- ❌ Trying to "stay on the paywall after purchase" by holding the interceptor open or skipping `proceed` — instead, configure the button with no second action (Observer mode) or add an explicit `open_screen` / `open_placement` step.

## See also

- [observer-mode-post-purchase.md](observer-mode-post-purchase.md) — exact `proceed → dismiss` sequence after Observer-mode purchases
- [presentation-types.md](presentation-types.md) — what to do when `fetchPresentation` returns `DEACTIVATED` or `CLIENT`
- [byos.md](byos.md) — Bring Your Own Screen: native screens inside a Flow, with their own `executeConnection(...)` chaining model
