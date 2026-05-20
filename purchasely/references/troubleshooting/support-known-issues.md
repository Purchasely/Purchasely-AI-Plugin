# Support-Derived Known Issues & Fixes

Use this file when a user describes a symptom that matches a known support pattern. These are not generic SDK rules; verify SDK version, running mode, logs, and Console configuration before applying a fix.

## iOS internal Open Placement child modal swipe dismissal

**Symptom:** an internal Open Placement action opens a child modal; the user swipes the child down and the parent Screen does not receive the expected dismissal callback/interceptor state.

**Known fix:** this is an edge case around child modal dismissal callbacks. Mitigate in the Console by rolling back or changing the Screen action path so the child Screen is not dismissible through the problematic modal swipe path. If code is involved, make sure every intercepted action still calls `proceed(...)` exactly once.

## iOS StoreKit 2 purchase hang at `IN_APP_PURCHASING`

**Symptom:** logs show `IN_APP_PURCHASING` but never advance to `IN_APP_PURCHASED`, `RECEIPT_CREATED`, or `RECEIPT_VALIDATED`.

**Known fix:** collect full Purchasely debug logs, StoreKit version, OS version, transaction ID if any, and the app's post-purchase handler. Inspect StoreKit 2 `Transaction.updates` consumption and any custom post-purchase handler that could block or swallow transaction updates before Purchasely observes them.

## iOS promotional offer is nil / not offered

**Symptoms:** promotional offer is nil, missing from `plan.promoOffers`, or purchase cannot find the expected promo offer.

**Known fixes:**

1. Upgrade to SDK **5.7.4+** when the issue matches the promotional-offer eligibility fix.
2. Check Screen Composer for duplicated promotional-offer IDs or duplicated offer rows.
3. Verify App Store Connect promotional-offer credentials / SK2 signing credentials are present in the Purchasely Console.
4. In StoreKit 2 Observer/custom flows, call `Purchasely.syncPurchase(...)` before `transaction.finish()` so receipt state and eligibility are not stale.

## iOS 26 annual billed monthly display

**Symptom:** annual subscription billed monthly displays a confusing total/monthly price combination on iOS 26.

**Known fix:** target the Purchasely SDK 6.0/6.1 line when available for updated StoreKit handling. Be explicit that Apple StoreKit has a total-price display limitation for this billing style; the SDK cannot always force the exact merchandising copy the customer wants.

## Android promo-code / developer-determined offer placements

**Symptom:** complex audience rules around promo-code placements show the wrong paywall or fail to expose a regular fallback path.

**Known fix:** simplify the Console setup. Prefer one paywall containing the regular/no-offer plan plus the offer plan, and let Google Play store eligibility decide which offer can be purchased. Avoid over-splitting audiences unless there is a clear business rule that the store cannot enforce.

## iOS Promoted IAP in PaywallObserver mode

**Symptom:** App Store Promoted IAP launches before the app/SDK is fully ready in PaywallObserver mode.

**Known fix:** register the app's `SKPaymentTransactionObserver` early enough for Promoted IAP, but balance this with Purchasely deeplink/display readiness by calling `readyToOpenDeeplink` only when UI is ready. Newer SDK versions include fixes around this startup timing; upgrade before adding custom workarounds.

## iOS Flow with custom UIHandler

**Symptom:** a custom UIHandler receives a Flow presentation but displaying it through a manually controlled controller path breaks Flow close controls or step transitions.

**Known fix:** call `presentation.display(from: nil)` for Flow display unless the user explicitly needs to embed the Purchasely Screen inside their own controller/window. The display path lets the SDK own Flow navigation and dismissal.

## Identified user migration

**Symptom:** an anonymous subscriber later logs in, but downstream systems do not merge the anonymous and identified histories correctly.

**Known fix:** rely on Purchasely's user migration webhooks for the subscription ownership transfer, and handle Braze/profile merging separately. Do not assume the Braze merge is automatic just because Purchasely transferred the receipt; wire the exact webhook events used by the backend/CRM pipeline and test anonymous -> identified migration end to end.
