# Sandbox & Testing — iOS and Android

Purchasely-side and store-side configuration required to validate purchases without real charges. Source docs:

- [Testing purchases in Sandbox](https://docs.purchasely.com/docs/testing)
- [Apple In-App Purchases](https://docs.purchasely.com/docs/apple-in-app-purchases)
- [Google In-App Purchases](https://docs.purchasely.com/docs/google-in-app-purchases)

## Universal rules

- **No simulator / emulator.** Apple StoreKit sandbox and Google Play Billing both refuse non-physical devices. Use real devices, sandbox accounts, or TestFlight / Play internal track.
- **Sandbox purchases never produce real charges** — and they don't transfer to production. Production subscribers stay production-side.
- **Use the [Debug Mode](../troubleshooting/debug-mode.md)** alongside sandbox to preview draft Screens and Flows without exposing them to real users.

---

## Apple (App Store / StoreKit)

### Prerequisites

- [ ] App configured in **App Store Connect** with at least one In-App Purchase product (subscription, non-consumable, …)
- [ ] **Paid Apps agreement** signed and active in App Store Connect → Agreements
- [ ] **Tax & banking** complete (otherwise products show as unavailable even in sandbox)
- [ ] At least one **Sandbox Apple ID** created in App Store Connect → Users and Access → Sandbox
- [ ] App built for a **physical device** (sandbox does not work in the simulator)

### Setting up a sandbox tester on the device

1. On the device: **Settings → App Store → Sandbox Account**.
2. Sign in with the Sandbox Apple ID.
3. The Sandbox Account is separate from the regular Apple ID — purchases happen against it; the real Apple ID is untouched.
4. First purchase triggers a "Sign in with your Sandbox Apple ID" prompt. Subsequent purchases reuse it.

### TestFlight

- TestFlight builds can purchase IAPs (simulated, no charge).
- Useful for testing the full TestFlight install path + subscription lifecycle (renewal, expiry, upgrade, downgrade, intro offers, promo offers).
- Family Sharing and a few subscription details may not fully replicate production.

### Quirks to know

- **Slow.** Sandbox can take 30+ s to complete a purchase. Don't tighten timeouts based on production assumptions.
- **Renewals are accelerated.** A monthly sub renews every 5 minutes in sandbox (Apple decides the cadence; subject to change).
- **Reset introductory offer eligibility:** App Store Connect → Sandbox Apple ID → Edit subscription → Reset eligibility. The reset has an unknown delay — relaunch the app to see it take effect.
- **`environment: Sandbox` in receipts.** Your backend (and Purchasely's server) detect this — production receipt validation against Sandbox fails by design.

### Common failures

| Symptom | Likely cause |
|---------|--------------|
| Products empty / `productNotFound` | Paid Apps agreement not signed, tax forms incomplete, product not "Ready to Submit" |
| Sandbox sign-in keeps reverting to the real Apple ID | Signed into Sandbox under Settings → iTunes & App Store (wrong path) instead of Settings → App Store → Sandbox Account |
| Purchase succeeds in sandbox but Purchasely server rejects | StoreKit 2 Issuer ID / Private Key missing or incorrect in the Console (Settings → Stores) |

---

## Google (Play Store / Play Billing)

### Prerequisites

- [ ] App configured in **Google Play Console** with at least one In-App Product / Subscription
- [ ] Manifest contains `<uses-permission android:name="com.android.vending.BILLING" />` (already included if you use `io.purchasely:google-play`)
- [ ] **APK/AAB uploaded to at least an Internal Testing track** (this unlocks IAP for testers)
- [ ] **License Tester** added in Play Console → Settings → License Testing → add the Google account used on the test device
- [ ] **Internal Tester** invitation accepted via the email link Google sends

### Tester setup recap

| Role | Where | Required for |
|------|-------|--------------|
| Internal Tester | Play Console → Testing → Internal testing → Testers | Installing the test build from Play Store |
| License Tester | Play Console → Settings → License Testing | Sandbox purchases (no charge) on any track (internal, alpha, beta, production) |

A device account must be **both** to fully test: Internal Tester to install, License Tester to purchase without being charged.

### Quirks to know

- **First purchase requires a delay.** Right after uploading the AAB to internal track, products are not immediately purchasable on devices — wait 5-15 minutes for Google to propagate.
- **No "sandbox account" abstraction.** Unlike Apple, Google uses the device's actual Google account. License Tester status is what makes the purchase free.
- **Renewals are accelerated.** Monthly subs renew every 5 minutes; yearly subs renew every 30 minutes (subject to Google changes).
- **Testing in production.** You don't need a "real" production purchase to validate the integration. If you must, **remove yourself from License Testers first** and use a different payment method.
- **Reset purchase state.** Settings → Account → Purchase history → cancel and remove the test subscription.

### Common failures

| Symptom | Likely cause |
|---------|--------------|
| `BillingResult.DEVELOPER_ERROR` / products empty | App not uploaded to a tester track yet, or the device account isn't a License Tester |
| Purchases work but Purchasely shows no subscription | API key mismatched (Dev vs Prod), or the Google Service Account in the Console doesn't have access to the publisher account |
| Sandbox purchase actually charged the card | Account is **not** a License Tester for this app — remove the payment method or add the tester immediately |
| After GPBL v8 migration, prices empty | See [google-play-billing-v8](../troubleshooting/error-codes.md#google-play-billing-v8) — use `billing-ktx` |

---

## Cross-platform SDKs (React Native / Flutter / Cordova)

The same rules apply to the native build underneath. Extra gotchas:

- **One App Store IAP setup + one Google Play IAP setup** — the cross-platform plugin doesn't shortcut store config.
- Always test on a **physical device** for both iOS and Android paths.
- Watch the [common-issues.md](../troubleshooting/common-issues.md) entries on cross-platform plugin alignment if products work on one platform and not the other.

---

## Recommended testing checklist (per release)

- [ ] Fresh install → anonymous user → first purchase succeeds → `IN_APP_PURCHASE` event fires
- [ ] Restore Purchases button (Settings) re-pulls receipt and reactivates premium
- [ ] User signs in → `userLogin` called → previous anonymous purchase merges
- [ ] User signs out → `userLogout` called → premium gating returns to free
- [ ] Subscription renewal (sandbox accelerated) → `IN_APP_RENEWED` event, UI refreshes
- [ ] Cancel from native Manage Subscriptions → app reflects state after `synchronize()`
- [ ] Restore again with a brand-new sandbox tester → "no subscription found" shows the paywall, not an error
- [ ] Debug Mode → preview a draft Screen on the test device, ship to "Internal Testers" audience

## See also

- [debug-mode.md](../troubleshooting/debug-mode.md) — preview draft Screens without going to production
- [error-codes.md](../troubleshooting/error-codes.md) — what `PLYError` cases mean
- [common-issues.md](../troubleshooting/common-issues.md) §3 — purchase failures
