# Error Codes — `PLYError` Reference

What each error case means, when it fires, and what to do about it. Errors surface in:

- iOS — `PLYError` enum cases passed to `failure:` closures and the `error` property of result handlers
- Android — `PLYError` sealed class instances passed to `onError(error)` callbacks
- React Native / Flutter / Cordova — error objects with `code` (string) and `message` mirroring the native error name

## How to use this page

1. Grep the SDK log stream for `PLYError` or the specific case name (e.g. `productNotFound`) — see [common-issues.md §0](common-issues.md#0-diagnostic-logs--read-before-patching).
2. Match the case to the table below.
3. Apply the fix. If multiple fixes apply, pick the one matching what you see in the log just before the error.

> Cases marked **iOS-only** or **Android-only** mean the platform's `PLYError` does not include the case. Their cross-platform JS/Dart mirror only carries a generic `error.code` string — fall back to inspecting `error.message`.

## Top-level cases (both platforms)

| Case | Meaning | Typical cause | Fix |
|------|---------|---------------|-----|
| `application(message:code:)` / `Application` | Generic wrapped error from the SDK | An underlying error didn't match a more specific case | Read the `message` — usually a clear store / network failure description |
| `parsing` / `Parsing` | SDK couldn't decode a response | Store returned malformed data, or app proxies / debugging tools tamper with traffic | Disable Charles / Proxyman / mitmproxy and retry on a clean network |
| `network(statusCode:error:)` / `Network` | HTTP request to Purchasely or the store failed | No connectivity, firewall, DNS, captive portal | Retry after `URLError.notConnectedToInternet` becomes false; check the user's network |
| `configuration` / `Configuration` | SDK misconfigured | Invalid API key, missing capability / permission, no store configured | Verify API key from Console → Settings; check store dependencies and Info.plist / manifest entries |
| `productNotFound` / `ProductNotFound` | The requested SKU / product id doesn't exist in the store | Wrong product id, store not ready (Apple agreements pending; Google AAB not uploaded), case-sensitive mismatch | Match the product id exactly to the store entry. See [testing/README.md](../testing/README.md) |
| `absentReceipt` / `AbsentReceipt` | No App Store receipt on iOS / no receipt to validate | First launch before any purchase, or receipt evicted by the OS | Trigger `restoreAllProducts` to refresh the receipt |
| `validationFailed` / `ValidationFailed(code)` | Receipt validation by Purchasely server failed | Sandbox receipt in production environment, or vice versa; or the Purchasely Console's StoreKit 2 / Service Account credentials are wrong | Check Console → Settings → Stores. Validate the `environment` field on the receipt matches the build |
| `clientInvalid` / `ClientInvalid` | StoreKit / Play Billing refuses to bill this client | Device unable to purchase (kid mode, parental restrictions, MDM lockdown) | Surface "purchases not allowed on this device" |
| `paymentCancelled` / `PaymentCancelled` | User cancelled the purchase sheet | Expected user action | No-op — do not show an error toast |
| `paymentInvalid` | StoreKit returned invalid payment | Malformed payment object, programmer error | Capture context and surface to support |
| `paymentNotAllowed` / `PaymentNotAllowed` | Payments disabled on the device | Restrictions (Screen Time, Family Sharing limits, MDM) | Surface a non-actionable explanation and offer a "Restore" path |
| `storeProductNotAvailable` / `StoreProductNotAvailable` | Product exists but is not purchasable in this storefront | Product not approved for this country, or the user is in a different App Store region than the Console assumes | Verify country availability in App Store Connect / Play Console |
| `cloudServicePermissionDenied` / `CloudServicePermissionDenied` | StoreKit refused access to the user's iCloud entitlements | iCloud signed-out or restricted | Prompt the user to sign in to iCloud |
| `cloudServiceNetworkConnectionFailed` / `CloudServiceNetworkConnectionFailed` | Store cloud service unreachable | Same as `network` but at the store layer | Retry later; check the user's network |
| `cloudServiceRevoked` / `CloudServiceRevoked` | The user revoked store cloud access | iCloud account changes | Surface "please sign in to the store again" |
| `purchaseAlreadyRunning` / `PurchaseAlreadyRunning` | Another purchase is already in progress | Double-tap on the purchase button | Disable the button while a purchase is in flight |
| `restorationAlreadyRunning` / `RestorationAlreadyRunning` | Another restore is already in progress | Double-tap on restore | Disable the button until the in-flight call resolves |
| `noProductsToRestore` / `NoProductsToRestore` | Restore succeeded but found nothing | Normal for users who never paid | Don't surface as an error — show the paywall instead |
| `restorationFailedWithErrors([Error])` / `RestorationFailedWithError` | Restore aggregated one or more failures | Mix of partial successes and failures | Inspect the inner errors |
| `restorationPartial([String], [Error])` / `RestorationPartial` | Some receipts restored, some failed | Network flake mid-restore | Re-run restore after stable network |
| `receiptValidationTimedOut` / `ReceiptValidationTimeOut` | Purchasely server didn't validate within timeout | Server load or your network → Purchasely RTT too high | Retry. Persistent — open a [screen-issue-report](screen-issue-report.md) |
| `untrackedEvent` | The SDK tried to fire an unknown analytics event | Internal — usually harmless | No action |
| `tooManyRequests(String?)` (iOS) | HTTP 429 from Purchasely | App spamming `fetchPresentation` / `synchronize` | Implement a debounce; never call in a render loop |
| `runningMode` (iOS) / — | Feature unavailable in this running mode | E.g. calling `purchase(...)` in Observer mode | Switch mode or stop calling Full-mode APIs |
| `unverifiedTransaction(String)` (iOS) | StoreKit 2 returned an unverified transaction | Receipt signature mismatch | Refuse the purchase; do not grant entitlement |
| `storekit2NotAvailable` (iOS) | StoreKit 2 not supported on this OS | iOS < 15 | Set `storekitSettings: .storeKit1` |
| `unknown` / `Unknown` | Catch-all | Anything else | Capture the wrapped exception and read the log |

## Promotional offer cases (iOS)

| Case | Meaning | Fix |
|------|---------|-----|
| `ineligibleForOffer` | The user isn't eligible for this Apple promotional offer | Check audience targeting — only past/active subscribers qualify; see [promotional-offers.md](../concepts/promotional-offers.md#eligibility-is-your-responsibility-promotional-offers--developer-determined-offers) |
| `purchaseNotAllowed` | StoreKit refused the purchase | Same handling as `paymentNotAllowed` |
| `invalidQuantity` | Offer config has a bad quantity | Console / App Store Connect mismatch — fix the offer in App Store Connect |
| `invalidOfferIdentifier` | The offer's vendor id doesn't match an existing App Store offer | Verify the vendorId in the Console matches App Store Connect exactly |
| `invalidOfferPrice` | App Store rejected the offer's price | Edit the price in App Store Connect |
| `invalidOfferSignature` | The signed offer JWS is invalid | Re-upload the App Store Connect API key in Console → Settings → Stores |
| `missingOfferParameters` | The purchase call didn't include all required offer params | Use `Purchasely.purchaseWithPromotionalOffer(...)` — never call the underlying StoreKit API directly |
| `productsTimeout` | Apple `requestProductDetails` didn't return in time | Retry; check Apple System Status |
| `presentationNotLoaded` | The presentation reference passed to `display()` is no longer valid | Re-fetch the presentation before re-displaying |
| `deferredPayment` | Purchase pending parental approval (Ask to Buy) | Surface "Purchase is pending approval" and finish via `IN_APP_PURCHASE` event |
| `psd2Required` | EU Strong Customer Authentication is required and the user hasn't completed it | StoreKit handles the prompt; just retry on user action |

## Android-only cases

| Case | Meaning | Fix |
|------|---------|-----|
| `UnsupportedFeature` | Google Play Billing returned `FEATURE_NOT_SUPPORTED` | Update Play Services on the device |
| `BillingUnavailable` | Play Billing service unavailable on this device | No Play Services (Huawei, Amazon, custom ROM). Add the right store dependency (`io.purchasely:huawei-services`, `io.purchasely:amazon`) |
| `NoStoreConfigured` | Purchase API called but no store was configured at `start()` | Add a store dependency and pass it to `Purchasely.Builder(...).stores(listOf(GoogleStore()))`. In SDK 6.0+ storeless integration is valid for paywall-only use but purchase APIs still need a store |
| `GoogleDeveloperError` | `BillingResult.DEVELOPER_ERROR` | App not on a tester track, or device account isn't a License Tester — see [testing/README.md](../testing/README.md) |
| `GoogleError` | Other Google Play Billing error | Read `message`; check Play Console status |
| `PurchasePending` | Purchase pending (e.g. cash/gift-card flow on Google Play) | Surface "Purchase pending" and listen for `IN_APP_PURCHASE` event when it clears |
| `HuaweiAccountNotLogged` | Huawei Mobile Services account not signed in | Prompt the user to sign in via Huawei |
| `InvalidStoreVersion(message)` | Mismatch between the store SDK version and what Purchasely expects | Realign Play Billing version. See the [Google Play Billing v8](#google-play-billing-v8) note below |
| `AlreadyPremium` | The user is already subscribed to the requested plan | Don't show the purchase button to active subscribers; gate via `userSubscriptions` |

## Google Play Billing v8

> **Symptom:** After migrating an Android app to **Google Play Billing 8.x**, prices stop appearing on Purchasely Screens. SDK initialization hangs in `queryProductDetails()` with no success or error callback.

**Likely cause** — the app pulls `com.android.billingclient:billing` (the non-KTX variant) while Purchasely uses `com.android.billingclient:billing-ktx`. An internal behavior change in GPBL 8 non-KTX can leave the request hanging.

**Fix #1 — switch to billing-ktx (recommended):**

```kotlin
dependencies {
    implementation("com.android.billingclient:billing-ktx:8.3.0")
}
```

**Fix #2 — force Gradle resolution to align both artifacts:**

```kotlin
configurations.all {
    resolutionStrategy {
        force("com.android.billingclient:billing:8.3.0")
        force("com.android.billingclient:billing-ktx:8.3.0")
    }
}
```

> Treat Google Play Billing v8 as a moving target — pin the version, watch the GPBL release notes, and re-test on each Purchasely SDK upgrade.

Source: [docs.purchasely.com/docs/google-play-billing-v8](https://docs.purchasely.com/docs/google-play-billing-v8)

## Cross-platform plugin error mapping

For React Native / Flutter / Cordova:

- iOS errors are forwarded as `error.code = "PLYError.<caseName>"` and `error.message = <localized description>`.
- Android errors are forwarded as `error.code = "PLYError.<ClassName>"`.

When the same logical error fires on both platforms (e.g. `productNotFound`), match on a normalised code (`error.code.endsWith("productNotFound")` / `error.code.endsWith("ProductNotFound")`).

## See also

- [common-issues.md §0](common-issues.md#0-diagnostic-logs--read-before-patching) — reading the SDK log stream to surface `PLYError` cases
- [debug-mode.md](debug-mode.md) — preview drafts on device
- [testing/README.md](../testing/README.md) — store sandbox configuration
- [screen-issue-report.md](screen-issue-report.md) — escalating to Purchasely Support
