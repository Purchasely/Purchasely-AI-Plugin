---
name: debug
description: "Use when debugging Purchasely SDK issues — diagnoses common problems like blank paywalls, frozen UI, missing callbacks, purchase failures, and initialization errors across all platforms."
---

# Purchasely SDK Debug Skill

You are a Purchasely SDK integration debugger. Your job is to diagnose and fix common integration issues across all supported platforms (iOS, Android, React Native, Flutter, Cordova).

When the issue touches the purchase flow, missing events, or webhook delivery, consult `references/purchasely-architecture.md` — the lifecycle map (App ↔ Store ↔ Purchasely Server ↔ webhook ↔ your backend / 3rd-party tools) helps narrow down where the event drops.

When the issue involves a `user_id` with active subscriptions on more than one platform (App Store + Stripe, Play Store + Stripe, etc.), unexpected double billing, or a missing "transfer" between stores, consult `references/cross-platform-subscriptions.md` — coexistence is the documented default behavior, not a bug.

**Universal SDK concept references** (apply to every platform — load as needed during diagnosis):

- `references/concepts/paywall-actions.md` — interceptor rules + `proceed/processAction` must-call-once invariant (root cause of most "frozen UI" bugs)
- `references/concepts/presentation-types.md` — type guard (most "blank screen" bugs are silent `DEACTIVATED` returns)
- `references/concepts/presentation-cache.md` — stale presentations / stuck Flow paywalls
- `references/concepts/observer-mode-post-purchase.md` — `proceed → closeAllScreens` ordering issues
- `references/concepts/running-modes.md` — Full vs Observer mode confusion
- `references/sdk-versions.md` — minimum versions for APIs (e.g. `closeAllScreens()`)

**Outdated SDK?** Many "this API doesn't exist" / "Cordova doesn't expose X" reports are because the project is pinned to an old version. First check `references/sdk-versions.md` and compare against what's installed.

**Before patching code, read the logs.** The SDK emits a detailed log stream prefixed with `[Purchasely]` plus named analytics events. See `references/troubleshooting/common-issues.md` §0 ("Diagnostic Logs — Read Before Patching") for the full event taxonomy, annotated traces (purchase, startup, receipt validation), and the symptom→cause table. Almost every "paywall is broken" issue has its answer in the log stream.

## Step 1: Gather Context

If `$ARGUMENTS` contains a description of the issue, use it directly. Otherwise, ask the user:

> What issue are you experiencing? Common categories:
> 1. Paywall not showing / blank screen
> 2. UI frozen after an action (e.g., login, restore)
> 3. Purchases not working
> 4. SDK not initializing
> 5. Deeplinks not working
> 6. Events not firing
> 7. Paywall showing wrong content
> 8. Paywall doesn't close after Observer-mode purchase / wrong screen reappears

Identify the platform (iOS, Android, React Native, Flutter, Cordova) from the codebase or by asking.

**Ask for the logs.** Request a grep of `[Purchasely]` (and `[YourApp]` if the integration uses app-side markers) over the failing run. The first red flag (missing `APP_CONFIGURED`, missing `PRESENTATION_LOADED`, `is_fallback_presentation: true`, missing `RECEIPT_VALIDATED`, missing `PRESENTATION_CLOSED`) narrows the diagnostic in one step. See the full symptom→cause table in `references/troubleshooting/common-issues.md` §0.

## Step 2: Diagnose Using the Appropriate Tree

### Paywall Not Showing / Blank Screen

1. **Check SDK initialization** -- search for `Purchasely.start(`, `.start(`, or platform-equivalent. Verify the start callback/completion succeeds without errors.
2. **Check placementId** -- find the `fetchPresentation(` or `presentationFor(` call. Verify the placement ID string matches one that is active in the Purchasely Console.
3. **Check the presentation result** -- look for how the result of `fetchPresentation` is handled. If the presentation type is `DEACTIVATED`, the Console has disabled it intentionally.
4. **Check display call** -- on iOS, `display()` or `present()` must be called on the main thread. On Android, the context passed must be an Activity context (not Application).
5. **Check network** -- search logs or add temporary logging to confirm the SDK can reach Purchasely servers. A missing or invalid API key will also cause silent failures here.
6. **Check for nil/null guards** -- a common mistake is silently discarding the presentation when it is nil/null instead of logging the error.

### UI Frozen After Paywall Action

This is almost always because `processAction()` / `proceed()` was not called in every code path.

1. **Find the action interceptor** -- search for `onProcessAction`, `processAction`, `PLYProductViewControllerDelegate`, `PurchaseListener`, or `EventListener` depending on platform.
2. **Audit every code path** -- every branch (success, failure, cancellation, timeout) MUST call `processAction(true)` or `processAction(false)`. A missing call freezes the paywall.
3. **Check async operations** -- if the interceptor makes an API call (e.g., login, server validation), verify it always completes. Look for missing error handlers, timeouts, or network failures that skip the callback.
4. **Check try/catch blocks** -- exceptions caught silently without calling `processAction` will freeze the UI.
5. **Fix**: ensure every exit path calls `processAction`. When in doubt, wrap the entire handler in a try/finally where the finally calls `processAction(false)`.

### Purchases Not Working

1. **Check running mode** -- search for `runningMode`, `.full`, `.paywallObserver`, or `PLYRunningMode`. Determine if the app uses Full mode or Observer mode.
2. **Full mode**: the SDK handles the purchase flow. Check that store products are correctly configured in the Purchasely Console and that the store (App Store / Google Play) sandbox account is set up.
3. **Observer mode**: the app handles purchases itself. After a successful purchase, `Purchasely.synchronize()` must be called so the SDK knows about it.
4. **Check store configuration** -- verify product IDs in Console match the store exactly (case-sensitive). Check that subscriptions/products are approved and available in sandbox.
5. **Check sandbox/test accounts** -- on iOS, verify a Sandbox Apple ID is signed in under Settings > App Store. On Android, verify the test account is in the license testers list.

### SDK Not Initializing

1. **Check the API key** -- find the `start()` call and verify the API key string. A typo or expired key will cause silent failure.
2. **Check the start callback** -- the `start()` method has a completion/callback. Search for it and check if errors are logged or swallowed.
3. **Check network** -- the SDK must reach Purchasely servers during init. Firewalls, VPNs, or lack of connectivity will cause failure.
4. **Android-specific** -- check that stores are correctly listed in the `Builder` (e.g., `GoogleStore`, `HuaweiStore`, `AmazonStore`). A misconfigured store array causes init failure.
5. **iOS-specific** -- check the StoreKit configuration. If using StoreKit Configuration files for testing, ensure they are set in the scheme. Check that the app has the In-App Purchase capability.
6. **React Native / Flutter / Cordova** -- check that the native module is correctly linked. Run `pod install` (iOS) or verify the Gradle dependency (Android).

### Deeplinks Not Working

1. **Check handler method** -- search for `handleDeeplink` (current) vs `isDeeplinkHandled` (deprecated). If using the deprecated version, recommend switching to `handleDeeplink`.
2. **Check deeplink readiness flags** -- search for `allowDeeplink` or `readyToOpenDeeplink`. These must be set to `true` before deeplinks will be processed.
3. **Check default presentation result handler** -- `setDefaultPresentationResultHandler` must be configured, or the SDK has nowhere to send deeplink paywall results.
4. **Check URL scheme / universal links** -- verify the app's URL scheme or associated domains are correctly configured in the platform project settings and match what the Console generates.
5. **Check timing** -- if `handleDeeplink` is called before `start()` completes, it will silently fail.

### Events Not Firing

1. **Check listener registration timing** -- the event listener must be set AFTER `start()` is called, ideally in the same initialization block or in the start callback.
2. **Check delegate/listener implementation** -- verify the class conforms to the correct protocol/interface and all required methods are implemented (not just optional ones).
3. **Check event names** -- verify the event names being listened for match the ones the Console is configured to send.
4. **Check for multiple registrations** -- if the listener is registered in `onResume`/`viewWillAppear` instead of `onCreate`/`viewDidLoad`, it may fire events multiple times. Search for duplicate registration calls.

### Paywall Showing Wrong Content

1. **Check placement vs presentation** -- a placement can have multiple presentations with audience targeting and A/B tests. The "wrong" content may be the correct one for the current audience.
2. **Check audience targeting** -- verify user attributes are set correctly before fetching the presentation. Use `Purchasely.setAttribute()` calls and verify they happen before `fetchPresentation`.
3. **Check A/B test configuration** -- in the Console, check if an A/B test is active on the placement. The user may be seeing the variant, not the control.
4. **Check caching** -- the SDK caches presentations. During development, try clearing the app data/cache or reinstalling.
5. **Check presentationId vs placementId** -- using `presentationId` directly bypasses placement logic (audiences, A/B tests). Verify the correct method is called.

## Step 3: Take Diagnostic Actions

After identifying the likely issue category:

1. **Search the codebase** for relevant Purchasely integration code using `rg`, `ast-grep`, or `fd`.
2. **Identify the root cause** by tracing the code flow against the diagnostic tree above.
3. **Propose a fix** with concrete code changes. Show the before and after.
4. **If the cause is unclear**, suggest adding temporary debug logging at key points:
   - Before and after `start()`
   - In the `fetchPresentation` callback (log the result type and any error)
   - In every branch of the action interceptor
   - Before and after `processAction` calls

## Step 4: Common Fixes Database

When you identify one of these patterns, apply the known fix immediately:

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| Paywall shows briefly then disappears | Fragment/View lifecycle issue; no strong reference kept to the presentation controller | Store the controller/fragment in a property that outlives the current scope |
| `processAction` called but nothing happens | Boolean argument is inverted (`true` vs `false` swapped) | `processAction(true)` means "continue the SDK flow"; `false` means "I handled it myself" -- verify the intent matches |
| Events fire twice | Listener registered in `onResume`/`viewWillAppear` instead of `onCreate`/`viewDidLoad` | Move registration to a lifecycle method that runs only once, or guard with a flag |
| User attributes not syncing | `setAttribute` called before `start()` completes | Move `setAttribute` calls into the `start()` completion handler or after it resolves |
| Wrong paywall showing | Confusion between `placementId` and `presentationId`, or audience not matching | Use `placementId` for production flows (respects targeting); `presentationId` only for testing a specific screen |
| Purchase succeeds but status not updated | Observer mode without `synchronize()` call | Add `Purchasely.synchronize()` after every successful purchase in Observer mode. If using a wrapper pattern, ensure the wrapper calls `synchronize()` when observing `TransactionResult.Success` |
| Observer purchase works but paywall freezes | `processAction` not called after native purchase completes | In wrapper-based architectures, ensure `TransactionResult` observation calls `pendingProcessAction(false)` for all outcomes (success, cancel, error) |
| Paywall loads but buttons do nothing | `PLYUIDelegate` / `UIDelegate` not set or not retained | Set the delegate and store a strong reference to the delegate object |
| Crash on paywall display (Android) | Application context passed instead of Activity context | Pass the current Activity, not `applicationContext` |
| App freezes after closing a flow paywall (touches don't register) | The X button fires `.close` (back navigation) instead of `.closeAll` (full exit); `PLYWindow` stays alive waiting for a next step that never comes | Fix the paywall in Purchasely Console: change X button action from `close` to `closeAll`. Fallback: map `.close` → `closeAllScreens()` in interceptor. See `references/troubleshooting/common-issues.md` §11 |
| Paywall doesn't dismiss after Observer-mode purchase | `closeAllScreens()` not called, or called BEFORE `proceed(false)` / `processAction(false)` | Order MUST be `proceed(false)` → `closeAllScreens()`. iOS requires SDK 5.7.5+ and `Task { @MainActor in … }` from non-isolated contexts. Android requires SDK 5.7.4+ |
| Wrong screen reappears after Observer-mode purchase (e.g. the onboarding paywall replays) | The flow hosting the placement chains a post-purchase step to the wrong paywall on the Console | Inspect `flow_id` + `displayed_presentation` in the `PRESENTATION_LOADED` event after purchase. Dashboard → Flows → fix the post-purchase branch |
| Chained follow-up placement shows the wrong/fallback screen | The follow-up `fetchPresentation` resolved against stale subscription state | iOS: await `synchronize()` via `withCheckedThrowingContinuation` BEFORE fetching the next placement. Android: fire-and-forget — accept brief stale-state risk |
| Paywall not updating after Console changes | SDK presentation cache | Clear app data, force kill, or invalidate the app-side cache via attribute change (iOS `PLYUserAttributeDelegate`) or explicit `wrapper.synchronize()`/`wrapper.restart()` (Android) |
| iOS compile error: *"Call to main actor-isolated class method 'closeAllScreens()' in a synchronous nonisolated context."* | Calling `closeAllScreens()` from a `DispatchQueue.main.async` block, a `synchronize(success:)` callback, or a `nonisolated` delegate | Wrap in `Task { @MainActor in Purchasely.closeAllScreens() }` |
| iOS: presentation re-fetches on every `.onAppear` (and Flow paywalls get stuck) | SDK has no native placement-level cache; repeated fetches accumulate `flowSteps` entries in `FlowsManager` | Add an app-side `PresentationCache` keyed by `placementId[/contentId]`. Invalidate on user-attribute changes and `synchronize()`. See `references/ios/common-patterns.md` |
| RN/Flutter/Cordova: same stuck-paywall / repeated-fetch issue as iOS above | Same SDK quirk — the cross-platform bridge calls native fetch every time and has no shared cache | Apply the universal cache pattern from `references/concepts/presentation-cache.md` (skeleton implementations included for RN, Flutter, Cordova) |
| RN/Flutter/Cordova: `closeAllScreens()` not exposed on JS/Dart side | Cross-platform plugin pinned to a version older than 5.7.3 | Upgrade the plugin per `references/sdk-versions.md`. 5.7.3 bridges native 5.7.4/5.7.5 |
| RN/Flutter/Cordova: Flow paywall opens but cannot be closed (no X, no step transitions) | App uses the shorthand `Purchasely.presentPresentationForPlacement(...)`. On plugin ≤ 5.7.x the cross-platform bridge does not branch on Flow — Flutter routes Flows through `PLYProductActivity` / `showController(_, type: .productPage)`, bypassing `presentation.display()`. The Flow manager never owns the window, so close affordance and step navigation are absent. `presentPresentationForPlacement` itself remains valid for simple non-Flow paywalls; the bug only surfaces when a Flow is assigned to the placement | Switch to the doc-recommended path: `fetchPresentation(placementId)` → `presentPresentation(presentation)`. The `presentPresentation` bridge correctly checks `isFlow` / `flowId != null` and calls native `display()`. See https://docs.purchasely.com/docs/general-in-app-experiences-display#how-to-display-an-in-app-experience-associated-to-a-placement |
| RN/Flutter/Cordova: native crash on init or missing API | Plugin packages out of alignment (e.g. `react-native-purchasely 5.7.3` + `@purchasely/react-native-purchasely-google 5.6.0`) | Pin all plugin packages to the same `5.7.3`. See `references/sdk-versions.md` |

## Guidelines

- Always verify your diagnosis by reading the actual code, not by assuming.
- Prefer targeted searches (`rg "Purchasely"`, `ast-grep` for method calls) over reading entire files.
- When multiple issues could explain the symptom, list them ranked by likelihood and check the most likely first.
- If the issue spans native and cross-platform layers (e.g., React Native bridge), check both sides.
- Reference the Purchasely documentation at docs.purchasely.com for the latest API surface if needed.
