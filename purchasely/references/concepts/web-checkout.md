# Web Checkout — Stripe Payment Links

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

Web Checkout routes a purchase to a **Stripe Payment Link** opened in the device browser instead of the store's in-app purchase flow — typically used to steer a targeted audience (e.g. a specific store country) to web billing.

Official doc: [Web Checkout](https://docs.purchasely.com/docs/web-checkout).

## Flow

1. The user taps a paywall button configured with the `webCheckout` action.
2. The SDK opens the plan's **Stripe Payment Link** in the system browser.
3. The user completes payment on Stripe's hosted page.

Targeting who sees a Web Checkout button is done the normal way — build a Console audience on `Store country` / `Store name` (e.g. serve Web Checkout only to `US` App Store or Play Store users) and attach it to the paywall or the button's visibility rule.

## Interceptor

`webCheckout` is an action kind like any other — register a per-action interceptor for it exactly as you would for `purchase` or `open_screen`. See [paywall-actions.md](paywall-actions.md) for the general per-action interceptor contract (`interceptAction` / `PLYInterceptResult` / string result depending on platform).

## Events

Web Checkout has its own dedicated SDK/UI events, separate from the regular purchase event stream:

| Event | Fires when |
|-------|------------|
| `WEB_CHECKOUT_TAPPED` | The user taps the Web Checkout button |
| `WEB_CHECKOUT_OPENED_IN_WEB_BROWSER` | The Stripe Payment Link successfully opens in the browser |
| `WEB_CHECKOUT_ERROR` | The link fails to open or Stripe reports an error |
| `WEB_CHECKOUT_TIMED_OUT` | The flow times out waiting for a result |

## Flutter bridge gotcha

The iOS `webCheckout` interceptor payload changed format between SDK versions — the raw action-kind value moved from a **legacy `Int` raw value** to a **string**. The Flutter bridge tolerates both formats. If `webCheckout` interception appears to be a no-op on iOS after bumping the native SDK, check whether the Flutter bridge is still matching against the old integer format.

## See also

- [paywall-actions.md](paywall-actions.md) — per-action interceptor contract shared by every action kind, including `webCheckout`
- [user-attributes-targeting.md](user-attributes-targeting.md) — building audiences on `Store country` / `Store name`
- [12-month-commitment.md](12-month-commitment.md) — another store-billing variant surfaced through paywall actions
