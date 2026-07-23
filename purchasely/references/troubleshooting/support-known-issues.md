# Support-Derived Known Issues & Fixes

Use this file when a user describes a symptom that matches a known support pattern. These are not generic SDK rules; verify SDK version, running mode, logs, and Console configuration before applying a fix.

> **Historical entries use v5 names.** Several entries below predate the v6 rename pass and still use v5 terminology verbatim. When applying an older entry to a v6 integration, map: `readyToOpenDeeplink` → `allowDeeplink`; `PaywallObserver` → `Observer`; `proceed(...)` / `processAction(...)` → the per-action `interceptAction(...)` result (`PLYInterceptResult` / string / etc., see [paywall-actions.md](../concepts/paywall-actions.md)).

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

**Known fix:** target the Purchasely SDK 6.0.x line for updated StoreKit handling. Be explicit that Apple StoreKit has a total-price display limitation for this billing style; the SDK cannot always force the exact merchandising copy the customer wants.

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

## Android: paywall not translated on Indonesian devices (< 6.0.1)

**Symptom:** on a device set to Indonesian, the paywall renders in the fallback/default language instead of the configured Indonesian translation, even though the translation exists on the dashboard.

**Known fix:** Android resource-qualifier mismatch — translations shipped under `values-id`, but Android actually resolves Indonesian locales against the qualifier `values-in` (Android still uses the legacy ISO 639-1 code `in` for Indonesian, not the more common `id`). Fixed in SDK **6.0.1** by shipping under the correct qualifier — upgrade rather than patching app-side resources.

## Flows: `PRESENTATION_VIEWED` missing at high volume (< 6.0.0-rc.3)

**Symptom:** on Flows with many steps/placements viewed in a single session, some `PRESENTATION_VIEWED` events are missing from the analytics stream — typically the earliest ones in a long session.

**Known fix:** an internal FIFO buffer tracking already-viewed presentations evicted entries once full (cap of 100), silently dropping the event for evicted entries under high-volume Flow usage. Fixed in **6.0.0-rc.3** by raising the cap to 200. Upgrade; don't build app-side dedup/backfill logic to work around it.

## iOS: app freezes on iPad after closing a campaign (fixed 6.0.0)

**Symptom:** on iPad specifically, dismissing a campaign-triggered presentation freezes the app — no crash, the UI simply stops responding.

**Known fix:** root cause was key-window restoration after the campaign's window was torn down — on iPad the previous key window wasn't always correctly restored, leaving the app without a responsive window. Fixed in SDK **6.0.0** — upgrade rather than adding app-side `makeKeyAndVisible()` workarounds, which don't reliably fix it.

## Callbacks on a preloaded presentation never fire (fixed rc.2)

**Symptom:** a presentation is preloaded well ahead of display; when the user later triggers `display()`, none of the lifecycle callbacks (`onPresented`, `onDismissed`, etc.) ever fire — no error logged either.

**Known fix:** the preloaded presentation was silently deallocated between preload and display when the app didn't keep a strong reference to it (or to the request that produced it) — nothing was logged to indicate this. Fixed in SDK **6.0.0-rc.2**. Regardless of the fix, keep a reference to the built request / loaded presentation — see [presentation-cache.md](../concepts/presentation-cache.md).

## Back button right-aligned / icon-text order reversed (fixed 6.0.0)

**Symptom:** the paywall's back button renders on the right side with the icon and label order swapped from what's configured in the Screen Composer.

**Known fix:** a rendering-engine layout bug affecting back-button composition. Fixed in SDK **6.0.0** — upgrade rather than compensating via Screen Composer styling tweaks.

## Video `autoplay: false` ignored (open bug in 6.0.0)

**Symptom:** a paywall video block configured with `autoplay: false` still starts playing automatically as soon as the Screen appears.

**Known fix:** none yet — this is an **open bug** in SDK **6.0.0**. There is no reliable app-side workaround (the video component doesn't expose a pause-on-appear hook); track the fix in a future release rather than spending time on a local patch.

## Lottie animation invisible with no error (`PLYLottieBridge` not exposed, iOS)

**Symptom:** a Lottie animation block on a paywall renders as blank space on iOS — no crash, no SDK error log.

**Known fix:** the Purchasely SDK does **not** link `lottie-ios` itself; it calls into the host app's Lottie rendering through a runtime bridge protocol, `PLYLottieBridge`. If the host app doesn't depend on `lottie-ios` and expose that bridge, the component silently renders nothing. This is expected behaviour, not an SDK bug — add the `lottie-ios` dependency and a `PLYLottieBridge` conformance to the app target that uses Lottie paywall blocks.

## iOS 18.4/18.5 DEBUG builds silently bypass the image disk cache

**Symptom:** on iOS 18.4/18.5, paywall images are re-downloaded on every appearance in **DEBUG** builds only; RELEASE builds cache normally.

**Known fix:** an iOS 18.4/18.5 `URLSession` behaviour change makes DEBUG-configuration sessions ephemeral for certain cache configurations, silently bypassing the on-disk image cache. This is an OS-level quirk, not a Purchasely regression — confirm the symptom disappears in a RELEASE/TestFlight build before treating it as an app or SDK bug.

## Purchase spinner stuck after cancelling (double purchase action on container + child label)

**Symptom:** the user taps a purchase button, cancels the native purchase sheet, and the paywall's loading spinner never dismisses — the button appears permanently stuck.

**Known fix:** Console misconfiguration, not an SDK bug — the `purchase` action was wired on **both** the button container and a child label/text element inside it. The tap fires two `purchase` actions; the SDK shows a loading spinner for the first and the second action's cancellation doesn't clear it (loader state is tracked per action instance, not per screen). Fix in the Screen Composer: remove the `purchase` action from the child label/text element and keep it only on the outer container that owns the loader.
