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

## Anti-patterns

- ❌ Calling `proceed` / `processAction` inside an async block whose error path doesn't call it.
- ❌ Returning from the interceptor without calling `proceed` (e.g. `if (cond) return;`).
- ❌ Calling `proceed` twice (e.g. once in the happy path, once in `finally`).
- ❌ Doing heavy synchronous work in the interceptor — the paywall is waiting on you.

## See also

- [observer-mode-post-purchase.md](observer-mode-post-purchase.md) — exact `proceed → dismiss` sequence after Observer-mode purchases
- [presentation-types.md](presentation-types.md) — what to do when `fetchPresentation` returns `DEACTIVATED` or `CLIENT`
