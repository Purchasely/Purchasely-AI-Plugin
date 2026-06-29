# Paywall Actions & Interceptor — Universal Concept

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

The **action interceptor** is a callback the SDK invokes when the user interacts with a paywall (taps Buy, Login, Restore, Close, etc.). It is the single most error-prone part of any Purchasely integration.

## The golden rule

**Every code path through the interceptor MUST resolve exactly once** — return a `PLYInterceptResult` / `InterceptResult` (native iOS/Android v6 and Flutter v6) or call the `proceed`/`processAction` callback (React Native / Cordova bridges).

If a branch (early return, error catch, `switch default`, `try/catch`, etc.) skips it, the paywall UI freezes permanently — this is the #1 most common Purchasely bug across all platforms. If a branch resolves twice, behavior is undefined.

When in doubt, wrap the handler in a `try/finally` (or equivalent) that resolves the result on every path (native iOS/Android & Flutter v6 returns `.notHandled` / `PLYInterceptResult.NOT_HANDLED` / `InterceptResult.notHandled`; React Native / Cordova calls `proceed(false)` / `processAction(false)`).

## `PLYPresentationAction`

Same set of actions on every platform; on **native iOS/Android v6 and Flutter v6** each action gets its own interceptor and you return a `PLYInterceptResult` / `InterceptResult`; on the React Native / Cordova bridges you handle one callback and call `proceed`/`processAction`.

The mapping between the v6 `PLYInterceptResult` / `InterceptResult` and the legacy `proceed`/`processAction` boolean is:

| `PLYInterceptResult` | Meaning | SDK behavior | Legacy boolean |
|----------------------|---------|--------------|----------------|
| `.success` / `SUCCESS` | App handled the action successfully | Chain advances to the next action | `proceed(false)` / `processAction(false)` |
| `.failed` / `FAILED` | App tried but failed | Remaining actions from this interaction are skipped | — |
| `.notHandled` / `NOT_HANDLED` | App doesn't want to handle it | SDK executes the action itself | `proceed(true)` / `processAction(true)` |

> 📘 `.notHandled` / `NOT_HANDLED` for `purchase` / `restore` in **Observer mode** logs a warning and skips — the SDK cannot execute purchases in Observer mode.

| Action | When triggered | Typical handling (native v6) |
|--------|---------------|------------------------------|
| `purchase` | User tapped a purchase button | Full mode → `.notHandled`. Observer mode → run your own billing flow, then `.success` (or `.failed`). |
| `restore` | User tapped Restore | Full mode → `.notHandled`. Observer mode → run your own restore, then `.success` (or `.failed`). |
| `login` | User tapped a login link | Show your login UI; on success `.success` (the app handled login and the action chain may continue). Use `.notHandled` only if you intentionally skip app login and let the SDK continue without it. |
| `close` | User tapped Close | `.notHandled` to let the SDK dismiss, or handle it and `.success`. |
| `navigate` | User tapped a custom navigation link | Handle the link (push a screen, open a URL), then `.success`. |
| `open_presentation` | User tapped a link to another presentation | Either let the SDK handle (`.notHandled`) or build it yourself and `.success`. |
| `promo_code` | User tapped Promo Code (iOS shows native sheet) | `.notHandled`. |

Casing / type reference per platform:

| Platform | Enum / sealed type |
|----------|--------------------|
| iOS | `Purchasely.interceptAction(.purchase)` / `.restore` / `.login` / `.close` / `.navigate` / `.openPresentation` / `.promoCode` |
| Android | Sealed class: `PLYPresentationAction.Purchase` / `.Restore` / `.Login` / `.Close` / `.Navigate` / `.OpenPresentation` / `.OpenPlacement` / `.PromoCode` |
| React Native | `PLYPaywallAction.PURCHASE` etc. (string constants) |
| Flutter | `PLYPresentationActionKind.purchase` / `.restore` / `.login` / `.close` / `.navigate` / `.openPresentation` / `.promoCode` |
| Cordova | String values: `'purchase'`, `'restore'`, `'login'`, `'close'`, `'navigate'`, `'open_presentation'`, `'promo_code'` |

## Registering the interceptor

Register **once** at initialization, ideally right after `start()`. On native iOS/Android v6 and Flutter v6 you register one interceptor **per action**; re-registering the same action replaces the previous handler. The React Native / Cordova bridges still register a single global callback.

### iOS (Swift)

In v6 the global `setPaywallActionsInterceptor` is removed; register per action and return a `PLYInterceptResult` (async closure form, recommended):

```swift
Purchasely.interceptAction(.login) { info, params in
    let loggedIn = await self.showLogin()
    return loggedIn ? .success : .notHandled   // success = app handled login; notHandled = continue without login
}

Purchasely.interceptAction(.purchase) { info, params in
    return .notHandled   // Full mode lets the SDK run the purchase
}
```

Completion-handler form (Objective-C-compatible):

```swift
Purchasely.interceptAction(.login) { info, params, completion in
    self.showLogin { loggedIn in completion(loggedIn ? .success : .notHandled) }
}
```

Remove with `Purchasely.removeActionInterceptor(.login)` / `Purchasely.removeAllActionInterceptors()`.

### Android (Kotlin)

`PLYPresentationAction` is now a sealed class; register a reified `interceptAction<T>` per action and return a `PLYInterceptResult`:

```kotlin
Purchasely.interceptAction<PLYPresentationAction.Login> { info, _ ->
    val loggedIn = showLogin()
    if (loggedIn) PLYInterceptResult.SUCCESS else PLYInterceptResult.NOT_HANDLED
}

Purchasely.interceptAction<PLYPresentationAction.Purchase> { info, purchase ->
    PLYInterceptResult.NOT_HANDLED   // Full mode lets the SDK run the purchase
}
```

> The reified `interceptAction<T>` / `removeActionInterceptor<T>()` are `inline` functions targeting JVM 11. Compile your Kotlin module with `jvmTarget = 11`, or use the `Class`-based overload (see Java below).

### Android (Java)

Java uses the `Class`-based overload and resolves the result via `result.invoke(...)`:

```java
Purchasely.interceptAction(PLYPresentationAction.Purchase.class, (info, action, result) -> {
    PLYPresentationAction.Purchase purchase = (PLYPresentationAction.Purchase) action;
    result.invoke(PLYInterceptResult.NOT_HANDLED);
});

Purchasely.interceptAction(PLYPresentationAction.Login.class, (info, action, result) -> {
    boolean loggedIn = showLogin();
    result.invoke(loggedIn ? PLYInterceptResult.SUCCESS : PLYInterceptResult.NOT_HANDLED);
});
```

Remove with `Purchasely.removeActionInterceptor(PLYPresentationAction.Purchase.class)` / `Purchasely.removeAllActionInterceptors()`.

### React Native (TypeScript)

```ts
Purchasely.setPaywallActionInterceptorCallback(result => {
  const { action } = result;
  switch (action) {
    case PLYPaywallAction.LOGIN:
      showLogin().then(ok => Purchasely.onProcessAction(!ok)); // false = handled; true = not handled
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

In v6 Flutter registers one interceptor **per action** and returns a `PLYInterceptResult` (mirroring native iOS/Android):

```dart
Purchasely.interceptAction(PLYPresentationActionKind.login, (info, payload) async {
  final ok = await showLogin();
  return ok ? PLYInterceptResult.success : PLYInterceptResult.notHandled;
});

Purchasely.interceptAction(PLYPresentationActionKind.purchase, (info, payload) async {
  return PLYInterceptResult.notHandled; // Full mode lets the SDK run the purchase
});
```

Remove with `Purchasely.removeActionInterceptor(PLYPresentationActionKind.login)` / `Purchasely.removeAllActionInterceptors()`.

### Cordova (JavaScript)

```js
Purchasely.setPaywallActionInterceptor(result => {
  switch (result.action) {
    case 'login':
      showLogin().then(ok => Purchasely.onProcessAction(!ok)); // false = handled; true = not handled
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

Native iOS/Android v6 and Flutter v6 return a `PLYInterceptResult` / `InterceptResult`; the React Native / Cordova bridges call `proceed`/`processAction` with the equivalent boolean (see the mapping table above).

| Action | Full mode | Observer mode |
|--------|-----------|---------------|
| `purchase` | `.notHandled` (`proceed(true)`) — SDK runs the purchase. | Run your own billing flow, call `Purchasely.synchronize()` on success, then `.success` (`proceed(false)`) so the SDK doesn't re-run a purchase. |
| `restore` | `.notHandled` (`proceed(true)`) — SDK restores. | Run your own restore, then `.success` / `.failed` (`proceed(success)`). |
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
| `login` | `purchase` | After login completes (your `.success` / `proceed(false)`), the SDK runs the purchase. |

Key points:

- **Default after `purchase` is intentional.** In Full mode the SDK closes the paywall on success so the user lands back in the app. In Observer mode the SDK has no opinion — it doesn't know what the app's purchase flow returned — and presentations **no longer auto-close** after a purchase/restore in v6 (in v5 the implicit Full default appended a `close_all`). If you want a different behaviour, **add a second action in the Composer**, don't try to coerce it from the interceptor.
- **The interceptor sees only the action being executed at this moment.** For a `purchase + open_placement` chain, you receive `purchase` first (return `.notHandled` / call `proceed(true)`); the SDK then triggers the second action on its own and you receive it as a separate interceptor call (e.g. `open_presentation`).
- **`.failed` short-circuits the chain.** If your v6 purchase branch returns `.failed`, the second action is **not** executed. In React Native / Cordova, call `processAction(false)` only when the app handled the action successfully and the chain may continue; use the bridge's error/cancel handling to avoid continuing after a failed app-side purchase.
- **Configuration is a Console concern.** Mobile engineers cannot add a "second action" from the SDK — ask the team running the Screen Composer to wire it in the button's Actions list.

## Anti-patterns

- ❌ Resolving the result inside an async block whose error path never returns / calls back (native iOS/Android & Flutter v6: return a `PLYInterceptResult` / `InterceptResult`; React Native / Cordova: call `proceed` / `processAction`).
- ❌ Returning from the interceptor without resolving (e.g. `if (cond) return;` on a React Native / Cordova callback).
- ❌ Resolving twice (e.g. once in the happy path, once in `finally`).
- ❌ Doing heavy synchronous work in the interceptor — the paywall is waiting on you.
- ❌ Trying to "stay on the paywall after purchase" by holding the interceptor open or skipping the result — instead, configure the button with no second action (Observer mode) or add an explicit `open_screen` / `open_placement` step.

## See also

- [observer-mode-post-purchase.md](observer-mode-post-purchase.md) — exact resolve-then-dismiss sequence after Observer-mode purchases
- [presentation-types.md](presentation-types.md) — what to do when a fetched presentation is `DEACTIVATED` or `CLIENT`
- [byos.md](byos.md) — Bring Your Own Screen: native screens inside a Flow, with their own `executeConnection(...)` chaining model
