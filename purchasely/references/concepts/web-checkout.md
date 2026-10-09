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

## Web-to-app redemption result (6.1.0+)

Native iOS / Android SDK 6.1.0+, and the Flutter, React Native and Cordova bridges 6.1.0+. A user buys on your website, taps the link in the confirmation email (`{scheme}://ply/redeem/{token}`) and lands in the app. The SDK tells your app when the redemption settles. On the bridges, call `webRedemptionListener(callback, appHandlesRedemptionAlert?)` on the builder, or `addWebRedemptionListener` / `removeWebRedemptionListener` after start. The result has `isSuccess`, `context.subscription`, `replay`, `errorCode` and `errorMessage`. See the web redemption section of the [Flutter](../flutter/integration.md#web-redemption-listener-610), [React Native](../react-native/integration.md#web-redemption-listener-610) and [Cordova](../cordova/integration.md#web-redemption-listener-610) integration guides. Cordova takes the callback first: `webRedemptionListener(callback, appHandlesRedemptionAlert)`.

Register the handler on the **builder only**. A redemption can settle during `start()`, so there is no runtime setter.

```swift
// iOS
final class RedemptionHandler: PLYWebRedemptionDelegate {
    func webRedemptionCompleted(result: PLYWebRedemptionResult) {
        switch result.asResult() {
        case .success(let context, let replay):
            unlockContent(for: context?.subscription, replay: replay)
        case .failure(let errorCode, let errorMessage):
            showError(errorMessage)
        }
    }
}

Purchasely.apiKey("your-api-key")
    .webRedemptionDelegate(handler, appHandlesRedemptionAlert: false)
    .start()
```

```kotlin
// Android
Purchasely.Builder(applicationContext)
    .apiKey("your-api-key")
    .stores(listOf(GoogleStore()))
    .webRedemptionListener(appHandlesRedemptionAlert = false) { result ->
        when (result) {
            is PLYWebRedemptionResult.Success -> unlockContent(result.context, result.replay)
            is PLYWebRedemptionResult.Failure -> showError(result.errorMessage)
        }
    }
    .build()
    .start()
```

| Topic | Behavior |
|-------|----------|
| Result (iOS) | `PLYWebRedemptionResult`: `isSuccess`, `context?.subscription`, `replay`, `errorCode`, `errorMessage`. Swift can use `asResult()` for an exhaustive `switch`. |
| Result (Android) | Sealed `PLYWebRedemptionResult`: `Success(context, replay)` and `Failure(errorCode, errorMessage)`. `context.subscription` can be `null`. |
| Delivery | Main thread, exactly once per settled redemption, success or failure. |
| `appHandlesRedemptionAlert = false` (default) | The SDK shows its own success or failure popin, then calls you when the user closes it. |
| `appHandlesRedemptionAlert = true` | No popin. You are called as soon as the redemption settles and your app owns the post-redemption screen. |
| `replay` | `true` when the user taps a link that was already redeemed. It is a success: unlock the content, but do not thank the user twice. |
| `allowDeeplink` | A redemption deeplink ignores it. A user who taps the email link always gets the subscription. |
| `errorMessage` | For an expired link it can contain a masked email (`j***@example.com`). Show it to the user. Do not send it to analytics. |
| User attributes | A successful redemption can restore the built-in and custom attributes of the web purchase. The SDK applies them before the entitlement refresh. |
| Lifetime | iOS keeps a **weak** reference to the delegate: keep a strong reference yourself. Android holds the listener until `Purchasely.close()`: do not capture an `Activity`. |

The SDK also sends the `REDEMPTION_CONSUMED` and `REDEMPTION_FAILED` events. Add the two cases if your code switches over the event type.

**Subscriptions outside the app catalog (6.2.0+).** A subscription whose plan is not in the app catalog, for example a web subscription, is returned by `userSubscriptions()` and in the redemption result. Its plan and product `vendorId` can be empty, so do not assume a non-empty value.

Official doc: [Web-to-app funnels (redemption)](https://docs.purchasely.com/docs/web2app).

## Flutter bridge gotcha

The iOS `webCheckout` interceptor payload changed format between SDK versions — the raw action-kind value moved from a **legacy `Int` raw value** to a **string**. The Flutter bridge tolerates both formats. If `webCheckout` interception appears to be a no-op on iOS after bumping the native SDK, check whether the Flutter bridge is still matching against the old integer format.

## See also

- [paywall-actions.md](paywall-actions.md) — per-action interceptor contract shared by every action kind, including `webCheckout`
- [user-attributes-targeting.md](user-attributes-targeting.md) — building audiences on `Store country` / `Store name`
- [monthly-commitment.md](monthly-commitment.md) — another store-billing variant surfaced through paywall actions
