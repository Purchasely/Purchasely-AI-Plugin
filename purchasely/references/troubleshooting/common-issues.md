# Troubleshooting: Common Issues

## 0. Diagnostic Logs — Read Before Patching

When something looks wrong (paywall doesn't close, wrong screen reappears, purchase doesn't unlock premium…), do **not** start patching code. The Purchasely SDK emits a detailed log stream — read it first, the answer is almost always there.

### Log sources

| Prefix | Source | What it tells you |
|--------|--------|-------------------|
| `[Purchasely][YYYY-MM-DD HH:MM:SS.mmm]<Level>` | SDK internal logs | SDK lifecycle (config, fetch, validation, receipt status) |
| `[Purchasely] Event: <NAME>` | SDK analytics events | Every paywall view, purchase, restore, dismiss, error |
| `[YourApp] Event: <NAME> \| Properties: {…}` | App-side mirror of SDK events (via `PLYEventDelegate` / `EventListener`) | Same events, with the full property bag — useful to inspect targeting context |
| `[YourApp] …` | App-side instrumentation around SDK calls | Local decisions (chained placement, sync result, observer mode dispatch) |

> `[Purchasely]` is emitted by the SDK and is identical in every integration — that is your grep target (`grep "\[Purchasely\]"`). Add an app-side prefix (e.g. `[YourApp]`) around the decision points (chain trigger, sync result, fetch outcome) so a teammate can reproduce the diagnostic workflow.

Set the SDK log level to `.debug` (iOS) / `LogLevel.DEBUG` (Android) during development.

### Key SDK events to watch

The SDK fires named events. Each carries a property bag (placement_id, displayed_presentation, flow_id, step_id, plan, …) — the source of truth for *what the SDK actually did*.

| Event | Fires when | Useful properties |
|-------|------------|-------------------|
| `APP_CONFIGURED` | `Purchasely.start(...)` completed successfully | `sdk_version`, `running_mode`, `storekit_version` |
| `APP_STARTED` | SDK has finished its full startup (config + initial fetches) | `session_id`, `session_count` |
| `PRESENTATION_LOADED` | Paywall fetched and ready. **Fires once per prefetched placement at startup, plus on every fetch** | `placement_id`, `displayed_presentation`, `internal_presentation_id`, `flow_id`, `display_mode`, `paywall_request_duration_in_ms` |
| `PRESENTATION_VIEWED` | Paywall on screen | same + `paywall_rendering_time_in_ms`, `display_method` |
| `PRESENTATION_CLOSED` | Paywall dismissed (any reason) | same + `screen_duration` |
| `PLAN_SELECTED` | User taps a plan | `plan`, `purchasely_plan_id`, `store_product_id` |
| `IN_APP_PURCHASING` | Purchase tap, billing flow opens | `plan` |
| `IN_APP_PURCHASED` | Native purchase succeeds (before validation) | `plan`, `transaction_id` |
| `RECEIPT_CREATED` | SDK builds the receipt payload, about to validate | `receipt_status` |
| `RECEIPT_VALIDATED` | Server validation succeeded | `receipt_status: completed` |
| `RECEIPT_FAILED` | Server validation refused the receipt | `error` |
| `IN_APP_PURCHASE_FAILED` | Whole purchase attempt failed | `error` |
| `IN_APP_RENEWED` | Receipt confirms an active subscription | `running_subscriptions`, `plan` |
| `IN_APP_RESTORED` | Restore flow finds an active receipt | `plan` |
| `IN_APP_DEFERRED` / `IN_APP_NOT_PURCHASED` | Pending / cancelled | `plan` |

### How to read a purchase log trace

Annotated slice for one Observer-mode purchase (placement IDs are app-specific — substitute yours):

```
[Purchasely] Receipt status: transmitting          ← SDK starts validating the receipt
[Purchasely] Successfully retrieved subscriptions.
[Purchasely] Receipt status: completed             ← receipt validated
[Purchasely] Event: RECEIPT_VALIDATED
[YourApp]   Event: RECEIPT_VALIDATED | Properties: {  ← App mirrors via PLYEventDelegate
  placement_id: "<your_placement_id>",
  flow_id: "<your_flow_id>",
  displayed_presentation: "<your_paywall_id>",
  plan: "<your_plan_vendor_id>",
  running_subscriptions: [{ plan, product }],      ← user is now subscribed ✓
  …
}
[Purchasely] Event: IN_APP_RENEWED                 ← subscription confirmed active
[Purchasely] Interceptor executed action purchase. Skipping SDK execution.
                                                   ↑ your resolved intercept result (e.g. `.success`) acknowledged
[Purchasely] Event: PRESENTATION_CLOSED            ← paywall dismissed
```

The trace tells you, in order:
1. **Receipt validated** (`RECEIPT_VALIDATED`, `IN_APP_RENEWED`) — purchase succeeded server-side.
2. **Interceptor acknowledged** (`Skipping SDK execution`) — your resolved intercept result (`PLYInterceptResult.success` / `'success'` / etc., see [paywall-actions.md](../concepts/paywall-actions.md)) was received.
3. **Paywall dismissed** (`PRESENTATION_CLOSED`) — the platform's dismiss API ran (`closeAllScreens()` on native iOS/Android, `presentation.close()` on Flutter v6, `request.close()` on React Native v6 and Cordova v6).

If you chain a follow-up placement after the purchase, expect an additional `Successfully retrieved presentation Optional("<your_followup_placement_id>")` → `PRESENTATION_LOADED` → `PRESENTATION_VIEWED` sequence at the end of the trace.

If any of those three is missing, you have a defined symptom — see the table below.

### Symptom → likely cause

| Symptom (in logs) | Likely cause | Where to look |
|-------------------|--------------|---------------|
| No `RECEIPT_VALIDATED` event | Receipt failed server-side validation | Check `[Purchasely] Receipt status: …` — `failed` / `error` → check StoreKit config, sandbox account, server clock |
| `IN_APP_PURCHASED` but no `IN_APP_RENEWED` | Receipt validated but no active subscription state | Dashboard → Subscribers → look up the transaction; check store product config |
| `PRESENTATION_CLOSED` never fires after a successful purchase | Dismiss API not called, or called before the action was acknowledged | Verify the order: the action MUST be acknowledged before dismissal. Native iOS/Android use `closeAllScreens()`; Flutter v6 uses `presentation.close()`; React Native v6 and Cordova v6 use `request.close()` |
| Android: Screen stays displayed and ignores every tap after a purchase / restore / error dialog | A custom `PLYUIHandler.onAlert` displayed its own dialog without calling `proceed()` or `alert.onDismiss()`, so the paywall action never completed | See §2, Cause A. Check every branch of `onAlert`, including the early returns |
| `pendingSuccessfulPurchase=false` after a real purchase | The flag was never set (transaction handler didn't run, or wrong mode) | Check interceptor `.purchase` case took the Observer branch |
| Follow-up `fetchPresentation` returns `type=deactivated` or `error=…` | The chained placement is missing / typo / deactivated on the dashboard | Dashboard → Placements → check the exact vendor ID. Common gotcha: typo in the placement_id string |
| Follow-up placement returns a presentation, but renders "the previous paywall again" | The Flow hosting the original placement chains a post-purchase step that points to the wrong paywall | The event's `flow_id` and `displayed_presentation` reveal the chained step. Dashboard → Flows → inspect `<flow_id>` post-purchase branches |
| `IN_APP_RESTORED` but premium UI doesn't update | `userSubscriptions(...)` not called after the purchase completes, or callback not wired to your premium state | Check your post-purchase refresh path |
| `is_fallback_presentation: true` on `PRESENTATION_LOADED` | Audience targeting failed, SDK served the default — usually a stale presentation cache | Trigger an attribute change → invalidate cache. Or call `PresentationCache.shared.invalidateAll()` explicitly (iOS) |
| Interceptor `billingPlanType` is `.unspecified` when you expected `.monthly` (iOS commitment) | US/Singapore storefront (auto-fallback), iOS < 26.4, plan not configured monthly, **or** several dynamic offerings mapping the same plan with different billing types | See §12. Check storefront + iOS version first; then whether the same plan is mapped by multiple offering references |

### Reading event property bags

Useful fields when debugging:

- `placement_id` + `internal_placement_id` — which placement the SDK was working on
- `displayed_presentation` + `internal_presentation_id` + `template` — which paywall design was rendered (template ID matches Console > Paywalls)
- `flow_id` + `flow_session_id` + `internal_flow_id` + `step_id` + `from_step_id` — flow position. Detects when a flow continues into a post-purchase step
- `is_fallback_presentation: true` — SDK fell back to the default paywall instead of resolving via audience targeting
- `display_mode` — `full_screen` / `push` — how the SDK is rendering (a `push` after `full_screen` indicates a flow step continuation)
- `purchasable_plans` — empty array on a non-purchase placement (e.g. a thank-you / confirmation screen) is normal
- `running_subscriptions` (on `IN_APP_RENEWED`) — confirms which entitlement is active after validation
- `paywall_request_duration_in_ms` + `paywall_rendering_time_in_ms` — performance budget

### Reading SDK lifecycle logs (startup)

Annotated startup slice:

```
[Purchasely] N products declared: <your_product_id>                      ← SDK reads its configured products
[Purchasely] [AppStore][Storekit2] Fetching app store products:          ← StoreKit2 fetches App Store metadata
              <your_store_product_id_1>,
              <your_store_product_id_2>,
              …
[Purchasely] Successfully retrieved presentation Optional("<paywall_id>") ← prefetched paywalls (one log per placement)
[Purchasely] [AppStore][Storekit2] Fetched app store products and found … ← all store products resolved
[Purchasely] N products available for sale: <your_product_id>            ← product mapping resolved
[Purchasely] N plans available for sale: <your_plan_vendor_id>, …
[Purchasely] Event: APP_CONFIGURED                                       ← ✓ Purchasely.start() succeeded
[Purchasely] Event: PRESENTATION_LOADED                                  ← one event per prefetched placement
[Purchasely] Event: PRESENTATION_VIEWED                                  ← the first paywall shown to user
[Purchasely] Event: APP_STARTED                                          ← ✓ initial fetches done, SDK fully ready
[Purchasely] Successfully retrieved subscriptions.                       ← initial subscriptions() polls
```

**Order matters:**
1. **Products fetch** from the App Store / Play Store (before any paywall can show real prices)
2. **Presentations fetch** in parallel (one `Successfully retrieved presentation` per prefetched placement)
3. **`APP_CONFIGURED`** — SDK marks itself as ready
4. **`PRESENTATION_LOADED` × N** — one event per prefetched placement; useful to confirm all your placements were resolved
5. **`PRESENTATION_VIEWED`** — first paywall actually shown
6. **`APP_STARTED`** — full startup completed
7. **Initial `userSubscriptions` polls** — SDK refreshes subscription state

**Red flags at startup:**
- `APP_CONFIGURED` never fires → `start(...)` failed. Check API key, network, the `onReady`/`onConfigured` callback's `error` argument.
- `0 products available for sale` → product IDs in Console don't match any store products. Check Console > Products and store consoles.
- `0 plans available for sale` → plans configured but no store products bound. Console > Products > plan → store binding.
- `PRESENTATION_LOADED` missing for an expected placement → placement undefined / deactivated / wrong audience targeting on dashboard.
- `is_fallback_presentation: true` on `PRESENTATION_VIEWED` → audience targeting failed, default paywall served.

### Reading receipt validation logs

Receipt processing has its own log stream — useful when StoreKit confirms locally but Purchasely doesn't recognise the subscription. **Validation can fail without aborting the StoreKit transaction**, so always check both sides.

Sandbox-failure trace (annotated):

```
[Purchasely] [AppStore][Storekit2][Listener] Transaction verified:       ← StoreKit verified the transaction locally
              <your_store_product_id>
[Purchasely] Receipt created.                                            ← receipt payload built
[Purchasely] Event: RECEIPT_CREATED
[Purchasely] Refreshing receipt status for validation.
[Purchasely] Receipt status: verifying                                   ← server-side validation in progress
[Purchasely] Receipt is still being processed (status: verifying)
[Purchasely] Receipt status: failed                                      ← ⛔ server refused
[Purchasely] ⛔️ Receipt validation failed.
              [Sandbox error] The receipt sent by Apple doesn't
              contain a valid purchase. …
[Purchasely] Event: RECEIPT_FAILED
[Purchasely] Event: IN_APP_PURCHASE_FAILED
[Purchasely] [AppStore][Storekit2][Listener] Transaction verified:       ← StoreKit retries / fires the entitlement again
              <your_store_product_id>
[Purchasely] Event: IN_APP_RENEWED                                       ← ✓ eventually recovers
```

**How to read `Receipt status`:** the SDK polls until a terminal status.

| Status | Meaning |
|--------|---------|
| `transmitting` | Receipt being uploaded to Purchasely's server |
| `verifying` | Server validating with Apple / Google |
| `completed` | Validated, entitlement granted ✓ |
| `failed` | Validation refused — see the error message that follows |

**Common `failed` causes (App Store sandbox):**
- Sandbox account not signed in / mismatched
- StoreKit Configuration file used in Xcode (local testing) but receipt sent to real Apple servers
- Receipt from a different bundle ID / environment
- Clock skew (server vs device > a few minutes)
- For real prod issues: check Apple / Google service status before debugging code

### Quick diagnostic checklist

When a teammate says "paywall is broken", ask in this order:
1. **Which platform** and **which placement_id**?
2. **Console grep**: `grep -E "\[Purchasely\]|\[YourApp\]"` over the run
3. **First red flag**: missing `APP_CONFIGURED` (config)? Missing `PRESENTATION_LOADED` (placement/audience)? `is_fallback_presentation: true` (cache)?
4. **Dashboard cross-check**: does the placement exist? Is it deactivated? Which paywall is attached? Is it in a flow that chains elsewhere?

---

## 1. Paywall Not Showing

**Symptoms:** `PLYPresentationBuilder(...).build().preload()` returns nil/throws, or the presentation never displays.

**Causes and Solutions:**

- **SDK not initialized:** Ensure `Purchasely.apiKey(...).start()` has completed successfully before calling any presentation method. Wait for the `start()` completion (`error == nil`) or the awaited call to return without throwing.
- **Invalid placement ID:** Verify the placement vendor ID in the Purchasely dashboard matches exactly (case-sensitive).
- **Presentation type is DEACTIVATED:** Always check `presentation.type` before displaying — see [presentation-types.md](../concepts/presentation-types.md). A deactivated presentation returns valid data but should not be shown.
- **Wrong thread (iOS):** On iOS, `start()` must be called on the main thread. Calling from a background queue can silently fail.
- **No active presentation:** Ensure a presentation is assigned to the placement in the dashboard.

```swift
// iOS v6: Verify initialization before presenting
Purchasely.apiKey("KEY").storekitSettings(.storeKit2).start { error in
    guard error == nil else {
        print("SDK not ready: \(error!.localizedDescription)")
        return
    }
    // Now safe to build and preload a presentation
}
```

> **Legacy (v5).** `Purchasely.start(withAPIKey:storekitSettings:completion:)` with a `(success, error)` 2-parameter completion, and `Purchasely.presentationController(for:)`, were removed in v6 in favour of the builder (`Purchasely.apiKey(...).start { error in }`) and `PLYPresentationBuilder`.

## 2. UI Frozen / Paywall Stuck

**Symptoms:** Paywall buttons stop responding, spinner never dismisses, app appears frozen.

**Cause A (Android, custom `PLYUIHandler`):** an `onAlert` branch displayed the app's own dialog and called neither `proceed()` nor `alert.onDismiss()`. The alert is the last step of the paywall action that raised it (purchase, restore, plan change); the SDK keeps that action open until the alert is dismissed, so the Screen stays displayed and stops reacting to taps, close button included. Early v5 releases did not wait for the dismissal, so apps that migrate to v6 with an existing handler surface this for the first time.

**Solution:** end every `onAlert` branch with exactly one of `proceed()` (SDK displays its dialog and dismisses the alert) or `alert.onDismiss()` (dismiss with no SDK dialog), the latter from the dismiss callback of your own dialog — after it closes, never before.

```kotlin
Purchasely.uiHandler = object : PLYUIHandler {
    override fun onAlert(alert: PLYAlertMessage, purchaselyView: View, activity: Activity?, proceed: () -> Unit) {
        val context = activity ?: return proceed() // no activity: let the SDK display the alert
        showMyDialog(context, alert.getTitleContent(), alert.getContentMessage()) { alert.onDismiss() }
    }
}
```

`onDismiss()` is on the `PLYAlertMessage` base class, so it covers every alert type without a `when` branch. Never call both `proceed()` and `onDismiss()` for the same alert — the SDK dialog would appear on top of yours.

**Cause B (all platforms):** the action was not acknowledged in all code paths of the interceptor — a returned `PLYInterceptResult` (`success` / `failed` / `notHandled`) on native iOS/Android v6 and Flutter v6, a returned `'success' / 'failed' / 'notHandled'` string on React Native v6, or a returned/resolved `Purchasely.InterceptResult` on Cordova v6.

**Solution:** Ensure every branch resolves exactly once. Native iOS/Android v6, Flutter v6, React Native v6, and Cordova v6 all return or resolve a result.

**Native iOS v6:**

```swift
Purchasely.interceptAction(.login) { _, _ in
    let loggedIn = await showLogin()
    return loggedIn ? .success : .notHandled
}
```

**Flutter v6:**

```dart
await Purchasely.interceptAction(PLYPresentationActionKind.login, (info, payload) async {
  final ok = await showLogin();
  return ok ? PLYInterceptResult.success : PLYInterceptResult.notHandled;
});
```

**React Native v6:**

```ts
Purchasely.interceptAction('login', async (info, payload) => {
  const ok = await showLogin()
  return ok ? 'success' : 'notHandled'
})
```

**Cordova v6:**

```ts
Purchasely.interceptAction(Purchasely.PresentationAction.login, async (info, parameters) => {
  const ok = await showLogin();
  return ok
    ? Purchasely.InterceptResult.success
    : Purchasely.InterceptResult.notHandled;
});
```

## 3. Purchases Fail

**Symptoms:** Purchase flow starts but fails, error in callback, transaction not completed.

**Causes and Solutions:**

- **Wrong running mode:** In `.observer` / `Observer` mode, the SDK does not process purchases. Either switch to `.full` / `Full` mode, or handle purchases in your action interceptor.
- **Store configuration:** Verify your products are configured correctly in App Store Connect / Google Play Console and match the plan IDs in the Purchasely dashboard.
- **Sandbox account (iOS):** On iOS, ensure you are signed in with a Sandbox Apple ID in Settings > App Store > Sandbox Account.
- **Google Play test track:** On Android, ensure the app is published to at least an internal test track and the test account is added to the testers list.
- **Missing store dependency (Android):** Verify the correct store artifact is included (e.g., `io.purchasely:google-play`).

## 4. Events Fire Twice

**Symptoms:** Analytics events are duplicated, purchase callbacks trigger multiple times.

**Cause:** Event listener registered in a lifecycle method that is called multiple times (e.g., `onResume`, `viewWillAppear`).

**Solution:** Register the listener once, in a method that is called only once:

```kotlin
// BAD: Registered in onResume (called every time activity resumes)
override fun onResume() {
    super.onResume()
    Purchasely.setEventListener { event -> trackEvent(event) }  // DUPLICATE!
}

// GOOD: Registered in onCreate (called once)
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    Purchasely.setEventListener { event -> trackEvent(event) }
}
```

## 5. Wrong Paywall Displayed

**Symptoms:** A different paywall shows than expected, or a fallback paywall appears.

**Causes and Solutions:**

- **Audience targeting:** The user may not match the audience criteria for the expected presentation. Check user attributes and audience rules in the dashboard.
- **A/B test:** The user may be in a different A/B test variant. Check the active A/B test configuration.
- **Placement vs presentation:** A placement can have multiple presentations assigned (audiences, A/B tests). Verify which presentation is active for the target audience.
- **Fallback presentation:** If the primary presentation fails to load (network issue), the SDK shows the fallback. Check `presentation.type == .fallback`.
- **Cache:** The SDK caches presentations. Call `Purchasely.synchronize()` to force a refresh.

## 6. Deeplinks Not Working

**Symptoms:** Tapping a Purchasely deeplink does nothing, or the app opens but no paywall appears.

**Causes and Solutions:**

- **`handleDeeplink` not called:** Ensure you call `Purchasely.handleDeeplink(url)` (iOS) or `Purchasely.handleDeeplink(uri, activity)` (Android) in your deeplink handler.
- **`allowDeeplink` not set:** The SDK queues deeplinks until `allowDeeplink` is `true` (the v6 default, but check for an explicit `allowDeeplink(false)` left over from a gated onboarding flow that never flips back). Call `Purchasely.allowDeeplink(true)` when your root view controller / main activity is ready if you gated it.
- **URL scheme not configured:** Verify the URL scheme or universal link / app link is properly configured in your app settings.
- **SDK not initialized:** If the deeplink arrives before `start()` completes, it will be lost. Initialize the SDK as early as possible.

```swift
// iOS v6: Handle deeplink in SceneDelegate
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    Purchasely.handleDeeplink(url)
}

// Only needed if you gated deeplinks with allowDeeplink(false) at init:
Purchasely.allowDeeplink(true)
```

> **Legacy (v5).** `Purchasely.readyToOpenDeeplink(true)` was renamed `Purchasely.allowDeeplink(true)` in v6 — see [campaigns.md](../concepts/campaigns.md#sdk-setup--gating-campaign-display).

## 7. User Attributes Not Syncing

**Symptoms:** Audience targeting based on attributes does not work, attributes appear empty in the dashboard.

**Cause:** Attributes set before `start()` completes are lost.

**Solution:** Set attributes only after the SDK initialization callback confirms success:

```kotlin
// v6: the builder's start() completion takes a single nullable PLYError
Purchasely.Builder(applicationContext)
    .apiKey("KEY")
    .stores(listOf(GoogleStore()))
    .build()
    .start { error ->
        if (error == null) {
            // NOW safe to set attributes
            Purchasely.setUserAttribute("tier", "premium")
            Purchasely.setUserAttribute("articles_read", 42)
        }
    }
```

> **Legacy (v5).** The 2-parameter `start { success, error -> }` callback was replaced by a single nullable `error` parameter in the v6 builder's `start(...)`.

**Related — campaign on a custom-attribute audience is hit-or-miss on the first launch:** `setUserAttribute(...)` saves the value but does **not** re-evaluate any campaign. A trigger-based campaign evaluates its audience when the trigger resolves (default `APP_STARTED` → shortly after start), using the attributes held at that moment. If the attribute is set after that, the audience won't match on the **first** launch; because the value is persisted in the SDK's disk cache, it matches **from the next session** (hence the "it worked once" symptom). To make it reliable on first launch, gate campaigns until attributes are set — `allowCampaigns(false)` → `setUserAttribute(...)` → `allowCampaigns(true)` (ordering: start → set attributes → allow campaigns). See [campaigns.md](../concepts/campaigns.md#custom-attribute-audiences-set-the-attribute-before-campaigns-are-evaluated).

## 8. Paywall Disappears Immediately

**Symptoms:** Paywall flashes on screen and then vanishes.

**Cause:** The view controller or fragment is not strongly referenced and gets deallocated.

**Solutions:**

**iOS:** Hold a strong reference to the controller. In v6, prefer `presentation.display(from:)` (the SDK owns the reference and Flow close controls); only reach for the raw `presentation.controller` when you need to embed it yourself:

```swift
// BAD: the raw controller is not retained, so it may be deallocated immediately
func showPaywall() async throws {
    let presentation = try await PLYPresentationBuilder.forPlacementId("ONBOARDING").build().preload()
    let vc = presentation?.controller
    present(vc!, animated: true)  // vc may be deallocated
}

// GOOD (preferred): let the SDK own display + retention
func showPaywall() async throws {
    let presentation = try await PLYPresentationBuilder.forPlacementId("ONBOARDING").build().preload()
    presentation?.display(from: self)
}

// GOOD (if you must embed it yourself): store the controller as a property
var paywallController: UIViewController?

func showPaywall() async throws {
    let presentation = try await PLYPresentationBuilder.forPlacementId("ONBOARDING").build().preload()
    paywallController = presentation?.controller
    present(paywallController!, animated: true)
}
```

> **Legacy (v5).** `Purchasely.presentationController(for:)` was removed in v6 in favour of `PLYPresentationBuilder` + `preload()`, exposing `presentation.display(from:)` or `presentation.controller`.

**Android:** Ensure the Fragment is properly attached to a container and the Activity is not finishing:

```kotlin
// Ensure activity is not finishing
if (!isFinishing && !isDestroyed) {
    presentation.display(this)
}
```

## 9. ProGuard Stripping SDK Classes (Android)

**Symptoms:** App crashes on SDK initialization or paywall display in release builds, `ClassNotFoundException` or `NoSuchMethodError`.

**Solution:** Add ProGuard keep rules:

```proguard
# proguard-rules.pro
-keep class io.purchasely.** { *; }
-keep class io.purchasely.ext.** { *; }

# Google Play Billing
-keep class com.android.vending.billing.** { *; }

# Huawei IAP (if applicable)
-keep class com.huawei.hms.iap.** { *; }
```

Verify rules are applied by checking your `build.gradle`:

```kotlin
android {
    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

## 10. App Crashes on SDK Init

**Symptoms:** App crashes immediately on launch after adding the Purchasely SDK.

**Causes and Solutions:**

- **Missing store dependencies (Android):** Ensure you have at least one store artifact. Without `io.purchasely:google-play` (or another store), the SDK cannot initialize.
  ```kotlin
  // Must include at least one store
  implementation("io.purchasely:google-play:+")
  ```

- **Invalid API key:** A malformed or expired API key causes initialization failure. Verify the key in the Purchasely dashboard under Settings > API Keys.

- **Conflicting dependencies (Android):** Check for version conflicts with Google Play Billing or other in-app purchase libraries:
  ```bash
  ./gradlew app:dependencies | grep billing
  ```

- **Missing entitlements (iOS):** Ensure the In-App Purchase capability is enabled in your Xcode project under Signing & Capabilities.

- **Multidex (Android):** If your app exceeds the 64K method limit, enable multidex:
  ```kotlin
  android {
      defaultConfig {
          multiDexEnabled = true
      }
  }
  ```

## 11. App Freezes After Closing a Flow Paywall — `.close` vs `.closeAll`

**Symptoms:** After dismissing a Purchasely Flow paywall (a placement configured as a flow, i.e. `presentation.internalFlowId != nil`), the paywall visually closes but the underlying app UI becomes unresponsive. No crash, no error — taps simply don't register. Most visible on SwiftUI hosts but the root cause affects all platforms.

**Root cause — Console configuration, NOT an SDK bug:**

The Purchasely SDK defines two semantically distinct close actions:

| Action    | Purpose                          | Effect                                           |
|-----------|----------------------------------|--------------------------------------------------|
| `.close`    | **Back navigation** in a multi-step flow | Pops the current step, **keeps the flow window alive** for the previous step |
| `.closeAll` | **Exit** the paywall entirely        | Clears `flowSteps`, **closes the flow window**  |

The SDK holds flow presentations inside a dedicated `PLYWindow` (iOS) / custom overlay (Android) that stays alive across steps. When `.close` is triggered on the only *visible* step but there are preloaded (not-yet-shown) steps queued in `flowSteps` or registered controllers, the window remains alive waiting for the next step — which will never come, because the user wanted to exit. The stale window intercepts touches and the app appears frozen.

**Convention:**
- **X button / "Not now" / "Skip"** = `.closeAll` (user intent: exit the paywall)
- **Back arrow inside a multi-step flow** = `.close` (user intent: go back one step)

**Diagnosis:** Look at the interceptor action and the flow's step count:

```swift
// iOS v6 — register per-action interceptors
Purchasely.interceptAction(.close) { info, params in
    print("Action: close")
    return .notHandled   // let the SDK run its default behaviour while diagnosing
}
Purchasely.interceptAction(.closeAll) { info, params in
    print("Action: closeAll")
    return .notHandled
}
```

If `.close` fires from what the user perceives as "exit the paywall", the **paywall is misconfigured**.

**Solution (preferred): fix the Console configuration**

1. Open the paywall in the Screen Composer
2. Select the X / dismiss button
3. Change its action from `close` to `closeAll`
4. Publish and retest

**Solution (fallback): intercept `.close` app-side**

If you cannot modify the Console config (e.g. legacy paywalls, A/B tests), map `.close` to `.closeAll` in your interceptor:

```swift
// iOS v6 — in the .close action interceptor
Purchasely.interceptAction(.close) { info, params in
    // Treat X as full exit, not back navigation
    Purchasely.closeAllScreens()
    return .success   // we handled it
}
```

```kotlin
// Android v6 — in the Close action interceptor
Purchasely.interceptAction<PLYPresentationAction.Close> { info, _ ->
    Purchasely.closeAllScreens()
    PLYInterceptResult.SUCCESS
}
```

**Why clients don't hit this in prod:** most customer paywalls created via the Screen Composer default to `.closeAll` on their dismiss button, because that matches the "exit paywall" user intent. The bug surfaces on legacy or hand-configured paywalls that use `.close` on a single-step flow.

> **Legacy (v5).** `Purchasely.setPaywallActionsInterceptor { action, params, info, proceed in }` (one global callback, `action.rawValue` switch, `proceed(Bool)`) and the Android `processAction(Boolean)` companion were removed in v6 in favour of one `interceptAction(...)` registration per action kind, returning a `PLYInterceptResult` — see [paywall-actions.md](../concepts/paywall-actions.md).

**Related defensive work:** see Purchasely-iOS-Sources PR #563 which adds SDK-level safeguards (`closeFlow()` called when no visible content remains) so misconfigured paywalls degrade gracefully instead of freezing.

## 12. Dynamic Offering Billing Type Resolves to `.unspecified` (iOS Commitment)

**Symptoms:** On iOS, a 12-month **monthly-commitment** plan is expected but the purchase interceptor reports `parameters.billingPlanType == .unspecified` (or the purchase runs up-front). Often reported as "I set `billingPlanType: .monthly` on the dynamic offering but the interceptor says `unspecified`."

**Check in order:**

1. **Storefront** — monthly commitment is not offered in the **US** or **Singapore** App Stores; the SDK falls back to up-front there. Test on another storefront (sandbox / TestFlight account).
2. **iOS version** — the feature requires **iOS 26.4+** and **SDK v6+**.
3. **Plan configuration** — the plan must carry the monthly commitment billing type (Screen Composer, or the dynamic offering's `billingPlanType`).
4. **Same plan mapped by multiple offering references (most common when it "randomly" fails).** If you register more than one `setDynamicOffering` reference that resolves to the **same plan** in the same presentation, with **different** billing types (e.g. one `.monthly` and one `.upFront`), the plan appears more than once with conflicting billing types and the SDK can no longer pick the right one — it resolves to `.unspecified`.

**Fix:** map a given plan to a **single** billing plan type per presentation. If you need both up-front and monthly-commitment variants on screen, back them with **two distinct plans/products**. Call `Purchasely.clearDynamicOfferings()` before re-registering so a leftover offering from a previous screen/session doesn't add a second mapping for the same plan. Register offerings **before** fetching/displaying the placement (they are applied server-side at fetch).

See [dynamic-offerings.md](../concepts/dynamic-offerings.md) and [monthly-commitment.md](../concepts/monthly-commitment.md).

## 13. Prices Render as a Dash or Empty

**Symptoms:** the Screen renders but price placeholders (`{{PRICE}}`, `{{AMOUNT}}`, …) show a dash or nothing.

**Check in order:** Plan not mapped to a store product for the platform under test → store product not purchasable yet (App Store "Ready to Submit" + price schedule + paid apps agreement; Google Play product **active** + app published on a track) → tester account not eligible / wrong storefront → **Android-only Google Play Billing dependency conflict** (prices fine on iOS but not Android; on SDK 5.x this is `billing` vs `billing-ktx`; on React Native / Flutter / Cordova the main package and the Google package must be on the **exact same version**) → `start()` failed.

Full checklist: [screen-resolution.md](../concepts/screen-resolution.md#prices-render-as-a-dash-or-empty). Sandbox/TestFlight prices in USD are expected store behavior, not a bug — see [testing/README.md](../testing/README.md).

## 14. A Published Console Change Is Not Visible in the App

**Symptoms:** the Screen was edited and published in the Console, the device still shows the old one.

**Check in order:** saved but **not published** (drafts require Debug Mode) → the SDK **cached** the Screen for the session (fully close and reopen the app, or dismiss and re-open the paywall so it re-fetches) → the Placement resolves to a **different Screen** than the default because an Audience or a running A/B test overrides it → an already-bucketed A/B test user keeps their variant by design.

A screenshot taken without reopening the paywall may predate the change entirely. See [screen-resolution.md](../concepts/screen-resolution.md#a-published-change-is-not-visible-in-the-app).

## 15. Custom Font Not Applied / Text Clipped on One Platform

**Symptoms:** the Console font is ignored on device, or multiline text is clipped on iOS *or* Android only.

**Cause:** Screens render with **native** components, so the font must exist in the **native project**. The file uploaded in the Console is used **only for the Composer preview** and is never shipped. The iOS field must match the font's **PostScript name** (not the filename); the Android field must match the resource name. A missing font is silently substituted by the OS, which changes line height and wrapping — hence clipping on one platform only.

Full prerequisites: [screen-resolution.md](../concepts/screen-resolution.md#custom-fonts--the-font-must-exist-in-the-native-project).
