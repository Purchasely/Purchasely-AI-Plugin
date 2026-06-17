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
                                                   ↑ proceed(false) acknowledged
[Purchasely] Event: PRESENTATION_CLOSED            ← paywall dismissed
```

The trace tells you, in order:
1. **Receipt validated** (`RECEIPT_VALIDATED`, `IN_APP_RENEWED`) — purchase succeeded server-side.
2. **Interceptor acknowledged** (`Skipping SDK execution`) — your `proceed(false)` was received.
3. **Paywall dismissed** (`PRESENTATION_CLOSED`) — the platform's dismiss API ran (`closeAllScreens()` on native iOS/Android, `presentation.close()` on Flutter v6, `closePresentation()` on React Native / Cordova).

If you chain a follow-up placement after the purchase, expect an additional `Successfully retrieved presentation Optional("<your_followup_placement_id>")` → `PRESENTATION_LOADED` → `PRESENTATION_VIEWED` sequence at the end of the trace.

If any of those three is missing, you have a defined symptom — see the table below.

### Symptom → likely cause

| Symptom (in logs) | Likely cause | Where to look |
|-------------------|--------------|---------------|
| No `RECEIPT_VALIDATED` event | Receipt failed server-side validation | Check `[Purchasely] Receipt status: …` — `failed` / `error` → check StoreKit config, sandbox account, server clock |
| `IN_APP_PURCHASED` but no `IN_APP_RENEWED` | Receipt validated but no active subscription state | Dashboard → Subscribers → look up the transaction; check store product config |
| `PRESENTATION_CLOSED` never fires after a successful purchase | Dismiss API not called, or called before `proceed(false)` | Verify the order: `proceed(false)` MUST precede dismissal. Native iOS/Android use `closeAllScreens()`; Flutter v6 uses `presentation.close()`; React Native / Cordova use `closePresentation()` |
| `pendingSuccessfulPurchase=false` after a real purchase | The flag was never set (transaction handler didn't run, or wrong mode) | Check interceptor `.purchase` case took the Observer branch |
| Follow-up `fetchPresentation` returns `type=deactivated` or `error=…` | The chained placement is missing / typo / deactivated on the dashboard | Dashboard → Placements → check the exact vendor ID. Common gotcha: typo in the placement_id string |
| Follow-up placement returns a presentation, but renders "the previous paywall again" | The Flow hosting the original placement chains a post-purchase step that points to the wrong paywall | The event's `flow_id` and `displayed_presentation` reveal the chained step. Dashboard → Flows → inspect `<flow_id>` post-purchase branches |
| `IN_APP_RESTORED` but premium UI doesn't update | `userSubscriptions(...)` not called after the purchase completes, or callback not wired to your premium state | Check your post-purchase refresh path |
| `is_fallback_presentation: true` on `PRESENTATION_LOADED` | Audience targeting failed, SDK served the default — usually a stale presentation cache | Trigger an attribute change → invalidate cache. Or call `PresentationCache.shared.invalidateAll()` explicitly (iOS) |

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

**Symptoms:** `presentationController` or `fetchPresentation` returns nil/null, paywall never appears.

**Causes and Solutions:**

- **SDK not initialized:** Ensure `Purchasely.start()` has completed successfully before calling any presentation method. Wait for the `success == true` callback.
- **Invalid placement ID:** Verify the placement vendor ID in the Purchasely dashboard matches exactly (case-sensitive).
- **Presentation type is DEACTIVATED:** Always check `presentation.type` before displaying. A deactivated presentation returns valid data but should not be shown.
- **Wrong thread (iOS):** On iOS, `Purchasely.start()` must be called on the main thread. Calling from a background queue can silently fail.
- **No active presentation:** Ensure a presentation is assigned to the placement in the dashboard.

```swift
// iOS: Verify initialization before presenting
Purchasely.start(withAPIKey: "KEY", storekitSettings: .storeKit2) { success, error in
    guard success else {
        print("SDK not ready: \(error?.localizedDescription ?? "")")
        return
    }
    // Now safe to present
}
```

## 2. UI Frozen / Paywall Stuck

**Symptoms:** Paywall buttons stop responding, spinner never dismisses, app appears frozen.

**Cause:** the action was not acknowledged in all code paths of the interceptor — a returned `PLYInterceptResult` on native iOS/Android v6, a returned `InterceptResult` (`success` / `failed` / `notHandled`) on Flutter v6, or `onProcessAction(true/false)` on React Native / Cordova v5.

**Solution:** Ensure every branch resolves exactly once. Native iOS/Android v6 and Flutter v6 return a result; React Native / Cordova v5 call `onProcessAction(true/false)`.

**Native iOS v6:**

```swift
Purchasely.interceptAction(.login) { _, _ in
    let loggedIn = await showLogin()
    return loggedIn ? .success : .notHandled
}
```

**Flutter v6:**

```dart
await Purchasely.interceptAction(PresentationActionKind.login, (info, payload) async {
  final ok = await showLogin();
  return ok ? InterceptResult.success : InterceptResult.notHandled;
});
```

**React Native / Cordova v5:**

```ts
Purchasely.setPaywallActionInterceptor(result => {
  switch (result.action) {
    case PLYPaywallAction.LOGIN:
      showLogin().then(ok => Purchasely.onProcessAction(!ok));
      return;
    default:
      Purchasely.onProcessAction(true);
  }
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
- **`readyToOpenDeeplink` not set:** The SDK queues deeplinks until `readyToOpenDeeplink` is set to `true`. Call this when your root view controller / main activity is ready.
- **URL scheme not configured:** Verify the URL scheme or universal link / app link is properly configured in your app settings.
- **SDK not initialized:** If the deeplink arrives before `start()` completes, it will be lost. Initialize the SDK as early as possible.

```swift
// iOS: Handle deeplink in SceneDelegate
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    Purchasely.handleDeeplink(url)
}

// Signal ready
Purchasely.readyToOpenDeeplink(true)
```

## 7. User Attributes Not Syncing

**Symptoms:** Audience targeting based on attributes does not work, attributes appear empty in the dashboard.

**Cause:** Attributes set before `start()` completes are lost.

**Solution:** Set attributes only after the SDK initialization callback confirms success:

```kotlin
Purchasely.Builder(applicationContext)
    .apiKey("KEY")
    .stores(listOf(GoogleStore()))
    .build()
    .start { success, error ->
        if (success) {
            // NOW safe to set attributes
            Purchasely.setUserAttribute("tier", "premium")
            Purchasely.setUserAttribute("articles_read", 42)
        }
    }
```

## 8. Paywall Disappears Immediately

**Symptoms:** Paywall flashes on screen and then vanishes.

**Cause:** The view controller or fragment is not strongly referenced and gets deallocated.

**Solutions:**

**iOS:** Hold a strong reference to the controller:

```swift
// BAD: Controller is deallocated immediately
func showPaywall() {
    let vc = Purchasely.presentationController(for: "ONBOARDING")
    present(vc!, animated: true)  // vc may be deallocated
}

// GOOD: Present modally (UIKit retains it) or store as property
var paywallController: UIViewController?

func showPaywall() {
    paywallController = Purchasely.presentationController(for: "ONBOARDING")
    present(paywallController!, animated: true)
}
```

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
// In your PaywallActionsInterceptor
Purchasely.setPaywallActionsInterceptor { action, params, info, proceed in
    print("Action: \(action) rawValue=\(action.rawValue)")
    // rawValue 0 = .close, rawValue 1 = .closeAll
    proceed(true)
}
```

If you see `rawValue: 0` (`.close`) fired from what the user perceives as "exit the paywall", the **paywall is misconfigured**.

**Solution (preferred): fix the Console configuration**

1. Open the paywall in the Screen Composer
2. Select the X / dismiss button
3. Change its action from `close` to `closeAll`
4. Publish and retest

**Solution (fallback): intercept `.close` app-side**

If you cannot modify the Console config (e.g. legacy paywalls, A/B tests), map `.close` to `.closeAll` in your interceptor:

```swift
// iOS — in the paywall actions interceptor
case .close:
    // Treat X as full exit, not back navigation
    proceed(false) // we handled it
    Purchasely.closeAllScreens()
```

```kotlin
// Android — in the paywall actions interceptor
PLYPresentationAction.CLOSE -> {
    processAction(false)
    Purchasely.closeAllScreens()
}
```

**Why clients don't hit this in prod:** most customer paywalls created via the Screen Composer default to `.closeAll` on their dismiss button, because that matches the "exit paywall" user intent. The bug surfaces on legacy or hand-configured paywalls that use `.close` on a single-step flow.

**Related defensive work:** see Purchasely-iOS-Sources PR #563 which adds SDK-level safeguards (`closeFlow()` called when no visible content remains) so misconfigured paywalls degrade gracefully instead of freezing.
