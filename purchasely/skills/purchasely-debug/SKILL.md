---
name: purchasely-debug
description: "Use when debugging Purchasely SDK issues — diagnoses common problems like blank paywalls, frozen UI, missing callbacks, purchase failures, and initialization errors across all platforms."
---

# Purchasely SDK Debug Skill

You are a Purchasely SDK integration debugger. Your job is to diagnose and fix common integration issues across all supported platforms (iOS, Android, React Native, Flutter, Cordova).

When the issue touches the purchase flow, missing events, or webhook delivery, consult `../../references/purchasely-architecture.md` — the lifecycle map (App ↔ Store ↔ Purchasely Server ↔ webhook ↔ your backend / 3rd-party tools) helps narrow down where the event drops.

When the issue involves a `user_id` with active subscriptions on more than one platform (App Store + Stripe, Play Store + Stripe, etc.), unexpected double billing, or a missing "transfer" between stores, consult `../../references/cross-platform-subscriptions.md` — coexistence is the documented default behavior, not a bug.

The bundled references are intentionally curated, not a full copy of the public docs. If the diagnosis depends on an exact SDK signature, current Console behavior, or a detail missing from `../../references/`, verify it against the official Purchasely documentation at https://docs.purchasely.com/ before patching code.

**Universal SDK concept references** (apply to every platform — load as needed during diagnosis):

- `../../references/concepts/paywall-actions.md` — interceptor rules + `proceed/processAction` must-call-once invariant (root cause of most "frozen UI" bugs)
- `../../references/concepts/presentation-types.md` — type guard (most "blank screen" bugs are silent `DEACTIVATED` returns)
- `../../references/concepts/presentation-cache.md` — stale presentations / stuck Flow paywalls + preload pattern
- `../../references/concepts/observer-mode-post-purchase.md` — `proceed/processAction → dismiss` ordering issues
- `../../references/concepts/running-modes.md` — Full vs Observer mode confusion
- `../../references/concepts/programmatic-purchases.md` — wrong app-side purchase API names (`purchase(planId)`, `purchase({ planId })`, Cordova positional callbacks)
- `../../references/concepts/user-identity.md` — `userLogin` ordering bugs (audience matches against anonymous user, subscriptions lost on logout, missing `synchronize` on resume)
- `../../references/concepts/user-attributes-targeting.md` — attributes not flowing to audience targeting
- `../../references/concepts/privacy-settings.md` — consent revocation, optional attributes ignored, Campaigns/analytics disabled
- `../../references/concepts/subscription-checks.md` — "user paid but premium gating doesn't unlock" bugs
- `../../references/concepts/subscription-management.md` — "user cancelled but the app doesn't reflect it" (foreground resync)
- `../../references/concepts/promotional-offers.md` — promo offer not applied / charged at regular price / `invalidOfferSignature`
- `../../references/concepts/campaigns.md` — trigger-based campaigns silently don't fire (missing `readyToOpenDeeplink` on v5 cross-platform RN / Cordova; on v6 — native iOS/Android and Flutter — it is `allowDeeplink`, default `true`, displayed immediately, and Android auto-intercepts)
- `../../references/concepts/lottie-animations.md` — blank/static Lottie blocks, missing native bridge/dependency, oversized animation JSON
- `../../references/concepts/analytics-integration.md` — events fire but don't reach Firebase/Amplitude/AppsFlyer (or duplicate)
- `../../references/architecture-patterns.md` — for projects using a wrapper class, diagnose wrapper-side issues (init order, decoupled Observer billing)
- `../../references/sdk-versions.md` — minimum versions for APIs (e.g. `closeAllScreens()`, Campaigns ≥ 5.1.0, promo offers ≥ 4.0.0)

**Platform-specific references** (load the one matching the project's platform when the bug is platform-specific):

- `../../references/ios/initialization.md` + `../../references/ios/api-reference.md` + `../../references/ios/common-patterns.md`
- `../../references/android/initialization.md` + `../../references/android/api-reference.md` + `../../references/android/common-patterns.md`
- `../../references/react-native/integration.md`
- `../../references/flutter/integration.md`
- `../../references/cordova/integration.md`

**Outdated SDK?** Many "this API doesn't exist" / "Cordova doesn't expose X" reports are because the project is pinned to an old version. First check `../../references/sdk-versions.md` and compare against what's installed.

**Before patching code, read the logs.** The SDK emits a detailed log stream prefixed with `[Purchasely]` plus named analytics events. See `../../references/troubleshooting/common-issues.md` §0 ("Diagnostic Logs — Read Before Patching") for the full event taxonomy, annotated traces (purchase, startup, receipt validation), and the symptom→cause table. Almost every "paywall is broken" issue has its answer in the log stream.

**Troubleshooting toolbox** (load as needed):

- `../../references/troubleshooting/debug-mode.md` — enabling SDK debug logging + Purchasely Debug Mode (preview drafts on device, switch language/theme, target the built-in `Internal Testers` audience)
- `../../references/troubleshooting/error-codes.md` — what each `PLYError` case means (iOS + Android), promotional-offer-specific errors, Google Play Billing v8 hang
- `../../references/troubleshooting/screen-issue-report.md` — template to package when escalating a Screen Composer bug to Purchasely Support
- `../../references/testing/README.md` — sandbox testing (Apple Sandbox Apple ID, Google License Tester)

## Expert checkpoint

Before patching code or declaring a root cause, run a Purchasely expert checkpoint. If the harness exposes the Claude Code subagent `purchasely:purchasely-sdk-expert`, invoke it and pass the platform, SDK version, running mode, logs or symptoms, relevant code paths, suspected root cause, and the smallest proposed fix.

If that subagent is not available, do the checkpoint inline using the `purchasely-sdk-expert` guidance when available, or this fallback checklist:

- Confirm the SDK generation: native iOS / native Android / Flutter use v6 (`6.0.0-rc.1`); React Native / Cordova use v5 (`5.7.3`).
- Confirm the suspected root cause matches the SDK logs, not just symptoms.
- Confirm the fix uses current platform APIs and does not introduce removed v6 symbols or invented signatures.
- Confirm running mode is explicit when Full purchase handling is expected.
- Confirm presentation loading/display and dismissal use the correct API for the platform and rendering mode.
- Confirm every interceptor branch resolves exactly once.
- Confirm Observer-mode purchases call `synchronize()` and use the right dismissal API.
- Confirm any Console-driven, campaign, BYOS, Lottie, or privacy claim was checked against the relevant reference.

Incorporate corrections before editing files or reporting the diagnosis.

## Step 0: Enable Debug Logging — Always Do This First

Almost no integration ticket can be diagnosed without the SDK log stream. Before touching any code, confirm `logLevel` is set to debug for the failing run, then ask the user to reproduce the issue and capture the logs.

| Platform | How to enable |
|----------|---------------|
| iOS (Swift, v6) | `.logLevel(.debug)` on the init builder chain (`Purchasely.apiKey(...).logLevel(.debug)...`) — or set `Purchasely.logLevel = .debug` at runtime |
| Android (Kotlin, v6) | `logLevel(LogLevel.DEBUG)` in the `Purchasely { ... }` DSL or on `Purchasely.Builder` (custom loggers now receive all messages regardless of level; `logcatEnabled` is a separate flag) |
| React Native | `logLevel: Purchasely.LogLevel.DEBUG` in `Purchasely.start({...})` |
| Flutter (v6) | `.logLevel(LogLevel.debug)` on the init builder chain (`PurchaselyBuilder.apiKey(...).logLevel(LogLevel.debug)...`) — or `Purchasely.setLogLevel(LogLevel.debug)` at runtime |
| Cordova | `Purchasely.LogLevel.DEBUG` as the 4th argument to `Purchasely.start(...)` |

> **Production note** — debug logs must be gated behind a build flag (`#if DEBUG`, `BuildConfig.DEBUG`, `__DEV__`, etc.). Shipping `.debug` in a release build leaks placement IDs, audience matches, and presentation IDs into device logs.

After enabling, ask the user to reproduce and grep `[Purchasely]` from the device log (Xcode console, `adb logcat -s Purchasely`, Metro / Flutter terminal, etc.).

**Also consider Debug Mode for visual issues.** If the symptom is "the wrong paywall appears" or "a draft Screen isn't previewing", point the user at `../../references/troubleshooting/debug-mode.md` — Purchasely's Console-side preview lets them validate the Screen on device under the `Internal Testers` audience without touching production.

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

**Ask for the logs.** Request a grep of `[Purchasely]` (and `[YourApp]` if the integration uses app-side markers) over the failing run. The first red flag (missing `APP_CONFIGURED`, missing `PRESENTATION_LOADED`, `is_fallback_presentation: true`, missing `RECEIPT_VALIDATED`, missing `PRESENTATION_CLOSED`) narrows the diagnostic in one step. See the full symptom→cause table in `../../references/troubleshooting/common-issues.md` §0.

## Step 2: Diagnose Using the Appropriate Tree

### Paywall Not Showing / Blank Screen

1. **Check SDK initialization** -- native v6: search for the init builder (`Purchasely.apiKey(` on iOS, `Purchasely {` / `Purchasely.Builder(` on Android) and `.start(`; Flutter v6: search for `PurchaselyBuilder.apiKey(` and `.start()` (the v5 `Purchasely.start({...})` is gone); cross-platform (RN / Cordova, v5): `Purchasely.start(`. Verify the start callback/completion succeeds without errors (native v6 callback is `start { error -> }` / `start { error in }`, a single nullable `PLYError`; Flutter v6 `.start()` returns a `Future<bool>`).
2. **Check placement / builder** -- native v6: find the `PLYPresentation { placementId(...) }` (Android) / `PLYPresentationBuilder.forPlacementId(...)` (iOS) call and confirm `.preload()` (or `.preload { … }`) is actually invoked — a built-but-never-preloaded/displayed presentation shows nothing. Flutter v6: find the `PresentationBuilder.placement(...)` / `.screen(...)` call and confirm `.build()` is followed by `.display(...)` (or `.preload()` then `.display(...)`) — a request that is built but never displayed shows nothing (the v5 `fetchPresentation(`/`presentPresentationForPlacement(` are gone). Cross-platform (RN / Cordova, v5): find the `fetchPresentation(` call. Verify the placement ID string matches one active in the Console (also accept a `screenId(...)` / `.forScreenId(...)` / Flutter `.screen(...)` for a direct Screen).
3. **Check the presentation result** -- look at the loaded presentation's `type`. If it is `DEACTIVATED` (Flutter v6: `PresentationType.deactivated`), the Console has disabled it intentionally (blank screen is expected). A common native v6 blank-paywall cause is building the presentation but never calling `display(...)`/`buildView(...)` on the loaded object; the Flutter v6 equivalent is building a `PresentationRequest` but never calling `.display(...)`.
4. **Check display call** -- on iOS, `display(from:)` must run on the main thread. On Android, `display(context)` needs an Activity context (not Application); for embedded use the View comes from `buildView(context) { outcome -> }` (wrap in `AndroidView` for Compose — there is no `PLYPresentationView` composable).
5. **Check network** -- search logs or add temporary logging to confirm the SDK can reach Purchasely servers. A missing or invalid API key will also cause silent failures here (native v6 surfaces `PLYError.Configuration` / `PLYError.configuration` when the key is blank).
6. **Check for nil/null guards** -- a common mistake is silently discarding the presentation (or the `.preload { loaded, error -> }` error) instead of logging it.

### UI Frozen After Paywall Action

The cause differs by platform:
- **Native iOS/Android (v6):** the per-action handler did **not return a `PLYInterceptResult`** on some path (or an `async` handler never resumed). There is no `processAction`/`proceed` callback in v6 — the handler's return value (`.success` / `.failed` / `.notHandled`) is the signal. A handler that throws, hangs on an unawaited async call, or falls through without returning will freeze the paywall.
- **Flutter (v6):** the per-action handler passed to `Purchasely.interceptAction(kind, handler)` did **not return an `InterceptResult`** on some path (or the `async` handler never completed). There is no `onProcessAction` in Flutter v6 — the handler's returned `InterceptResult` (`success` / `failed` / `notHandled`) is the signal. A handler that throws or falls through without returning will freeze the paywall.
- **Cross-platform (RN / Cordova, v5):** `onProcessAction()` was not called in every code path.

1. **Find the interceptor** -- native v6 / Flutter v6: search for `Purchasely.interceptAction`. Cross-platform (RN / Cordova, v5): `setPaywallActionInterceptor` / `onProcessAction`. Older native code may still reference the removed `setPaywallActionsInterceptor` — that won't compile against v6.
2. **Audit every code path** -- native v6: every branch (success, failure, cancellation, timeout) MUST return a `PLYInterceptResult`. Flutter v6: every branch MUST return an `InterceptResult`. Cross-platform (RN / Cordova, v5): every branch MUST call `onProcessAction(true/false)`. A missing return / missing call freezes the paywall.
3. **Check async operations** -- if the handler makes an API call (login, server validation), verify it always resolves. Native v6 `async` handlers must reach a `return`; the completion-based form must always invoke the completion. Flutter v6 `async` handlers must reach a `return InterceptResult.*`. Look for missing error handlers, timeouts, or network failures that skip it.
4. **Check try/catch blocks** -- native v6: a caught exception must still `return .failed` (or `.notHandled`). Flutter v6: a caught exception must still `return InterceptResult.failed` (or `.notHandled`). Cross-platform (RN / Cordova, v5): it must still call `onProcessAction(false)`.
5. **Fix**: ensure every exit path produces a result. Native v6: wrap in `do/catch` (Swift) / `try/finally` (Kotlin) and return `.failed` on error. Flutter v6: wrap in `try/catch` and `return InterceptResult.failed` on error. Cross-platform (RN / Cordova, v5): `try/finally` calling `onProcessAction(false)`.

### Purchases Not Working

1. **Check running mode** -- search for `runningMode`, `.full`, `.observer`/`PLYRunningMode.Observer`, or `PLYRunningMode`. ⚠️ **On native iOS/Android v6 the default changed from Full to Observer, silently.** If the init does NOT call `.runningMode(.full)` (iOS) / `runningMode(PLYRunningMode.Full)` (Android), the SDK is in Observer mode and will NOT process or validate purchases — this is the #1 "purchases stopped working after upgrading to v6" cause. (`PLYRunningMode.PaywallObserver` was also renamed to `PLYRunningMode.Observer`.)
2. **Full mode**: the SDK handles the purchase flow. Check that store products are correctly configured in the Console and that the store sandbox account is set up. On native v6, a Full-mode purchase with no store configured returns `PLYError.NoStoreConfigured`.
3. **Observer mode**: the app handles purchases itself. After a successful purchase, `Purchasely.synchronize()` must be called so the SDK validates the receipt. Native v6 Observer mode also does NOT auto-close the paywall (the implicit `close_all` is Full-only) — return `PLYInterceptResult.SUCCESS` to resolve the interceptor, then dismiss with `Purchasely.closeAllScreens()` from your billing-result handler (after the interceptor has resolved), unless a `close` / `close_all` action is configured on the button in the Console.
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

1. **Check handler method** -- native v6 / Flutter v6: `handleDeeplink(...)` (Flutter v6 keeps `isDeeplinkHandled` as a deprecated alias); cross-platform (RN / Cordova, v5): `handleDeeplink` (current) vs `isDeeplinkHandled` (deprecated). If the deprecated name is used, recommend switching.
2. **Check the deeplink display flag** -- native v6 and Flutter v6 renamed `readyToOpenDeeplink` → `allowDeeplink`, default **true** (so usually nothing to set; v6 displays deeplinks/campaigns immediately by default). Flutter v6 keeps `readyToOpenDeeplink` as a deprecated alias. On cross-platform (RN / Cordova, v5) `readyToOpenDeeplink(true)` must be set after the UI is ready. If an app explicitly set `allowDeeplink(false)`, deeplinks won't display.
3. **Android v6 auto-interception** -- Android v6 reads the foreground activity intent automatically (zero code). **Pitfall:** a `singleTask`/`singleTop` activity that receives the deeplink in `onNewIntent` WITHOUT calling `setIntent(intent)` hides the URI — the SDK never sees it. Verify `setIntent(intent)` is called, or fall back to a manual `handleDeeplink(uri, activity)`. iOS does NOT auto-intercept — `handleDeeplink(url)` must be wired from AppDelegate/SceneDelegate.
4. **Check the default dismiss/result handler** -- a default handler must be configured, or the SDK has nowhere to send deeplink paywall results. **iOS v6:** `Purchasely.setDefaultPresentationDismissHandler { outcome in }` (renamed from v5 `setDefaultPresentationResultHandler`). **Android v6:** still `setDefaultPresentationResultHandler`, callback now a single `outcome`. **RN / Cordova v5:** `setDefaultPresentationResultHandler` / `setDefaultPresentationResultCallback`.
5. **Check URL scheme / universal links** -- verify the app's URL scheme or associated domains are correctly configured and match what the Console generates.
6. **Check timing** -- if `handleDeeplink` is called before `start()` completes, it will silently fail. For a cold-start deeplink, pass it on the init builder (`.handleDeeplink(url)` / `.handleDeeplink(intent.data)`).

### Events Not Firing

1. **Check listener registration timing** -- the event listener must be set AFTER `start()` is called, ideally in the same initialization block or in the start callback.
2. **Check delegate/listener implementation** -- verify the class conforms to the correct protocol/interface and all required methods are implemented (not just optional ones).
3. **Check event names** -- verify the event names being listened for match the ones the Console is configured to send.
4. **Check for multiple registrations** -- if the listener is registered in `onResume`/`viewWillAppear` instead of `onCreate`/`viewDidLoad`, it may fire events multiple times. Search for duplicate registration calls.

### Paywall Showing Wrong Content

1. **Check placement vs presentation** -- a placement can have multiple presentations with audience targeting and A/B tests. The "wrong" content may be the correct one for the current audience.
2. **Check audience targeting** -- verify user attributes are set correctly before building/fetching the presentation. Use `Purchasely.setUserAttribute()` calls and verify they happen before the presentation resolves (native v6 `.preload()` / Flutter v6 `request.preload()` or `request.display(...)` / cross-platform RN / Cordova v5 `fetchPresentation`). Note: **Android** v6 user-attribute setters return `Deferred<Boolean>` and can be awaited if you need to guarantee ordering (iOS setters return no value).
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
   - Where the presentation finishes loading (native v6: the builder `onPresented` / `.preload` result — log type + error; Flutter v6: the builder `.onPresented` / `request.preload()` result — log `presentation.type` + `outcome.error`; cross-platform RN / Cordova v5: the `fetchPresentation` callback)
   - In every branch of the action interceptor
   - At each interceptor exit (native v6: log the returned `PLYInterceptResult`; Flutter v6: log the returned `InterceptResult`; cross-platform RN / Cordova v5: before/after `onProcessAction`)

## Step 4: Common Fixes Database

When you identify one of these patterns, apply the known fix immediately:

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| Paywall shows briefly then disappears | Fragment/View lifecycle issue; no strong reference kept to the presentation controller | Store the controller/fragment in a property that outlives the current scope |
| Interceptor result has the opposite effect of what's intended | Wrong `PLYInterceptResult` returned (native v6) / wrong `InterceptResult` returned (Flutter v6) or inverted boolean in `onProcessAction` (RN / Cordova, v5) | Native v6: `.notHandled` = "SDK, you do it"; `.success` = "I handled it, chain advances"; `.failed` = "I tried and failed, skip the rest". (Maps from v5: `processAction(true)` → `.notHandled`, `processAction(false)` → `.success`.) Flutter v6: same semantics with `InterceptResult.notHandled` / `.success` / `.failed`. Cross-platform (RN / Cordova, v5): `onProcessAction(true)` continues the SDK flow, `false` means you handled it -- verify the intent matches |
| Events fire twice | Listener registered in `onResume`/`viewWillAppear` instead of `onCreate`/`viewDidLoad` | Move registration to a lifecycle method that runs only once, or guard with a flag |
| User attributes not syncing | `setAttribute` called before `start()` completes | Move `setAttribute` calls into the `start()` completion handler or after it resolves |
| Wrong paywall showing | Confusion between `placementId` and `presentationId`, or audience not matching | Use `placementId` for production flows (respects targeting); `presentationId` only for testing a specific screen |
| Purchase succeeds but status not updated | Observer mode without `synchronize()` call | Add `Purchasely.synchronize()` after every successful purchase in Observer mode. If using a wrapper pattern, ensure the wrapper calls `synchronize()` when observing `TransactionResult.Success` |
| Observer purchase works but paywall freezes | The interceptor never signalled completion after the native purchase finished | Native v6: the `.purchase` handler must `return PLYInterceptResult.SUCCESS` (or `.FAILED`) for every outcome (success, cancel, error) -- a hung/unawaited billing call leaves it unsignalled. Flutter v6: the `PresentationActionKind.purchase` handler must `return InterceptResult.success` (or `.failed`) for every outcome. Cross-platform (RN / Cordova, v5): call `onProcessAction(false)` for all outcomes. In decoupled (reactive) architectures, make sure the billing result is mapped back to a returned result / completion for every branch |
| Paywall loads but buttons do nothing | `PLYUIDelegate` / `UIDelegate` not set or not retained | Set the delegate and store a strong reference to the delegate object |
| Crash on paywall display (Android) | Application context passed instead of Activity context | Pass the current Activity, not `applicationContext` |
| App freezes after closing a flow paywall (touches don't register) | The X button fires `.close` (back navigation) instead of `.closeAll` (full exit); `PLYWindow` stays alive waiting for a next step that never comes | Fix the paywall in Purchasely Console: change X button action from `close` to `closeAll`. Fallback: map `.close` → `closeAllScreens()` in interceptor. See `../../references/troubleshooting/common-issues.md` §11 |
| Paywall doesn't dismiss after Observer-mode purchase | Observer mode does **not** auto-close (the implicit `close_all` is Full-only), so the app must dismiss itself — the missing dismiss call is the bug; or (cross-platform) the dismiss/signal order is wrong | Native iOS/Android v6: inside the `.purchase` handler, `synchronize()` → `return PLYInterceptResult.SUCCESS`, then call `Purchasely.closeAllScreens()` from your billing-result handler **after** the interceptor has resolved (do not call it inside the interceptor closure before returning — that races the SDK). Or configure a `close` / `close_all` action on the button in the Console. iOS `closeAllScreens()` is `@MainActor`-isolated — wrap in `Task { @MainActor in … }` from non-isolated contexts. Flutter v6: inside the `PresentationActionKind.purchase` handler, `await Purchasely.synchronize()` → `return InterceptResult.success`, then dismiss with `presentation.close()` on the loaded `Presentation` (there is no `closePresentation()`/`closeAllScreens()` in Flutter v6) — or configure a `close` / `close_all` action on the button in the Console. Cross-platform (RN / Cordova, v5): `onProcessAction(false)` → `closePresentation()`, in that order |
| Wrong screen reappears after Observer-mode purchase (e.g. the onboarding paywall replays) | The flow hosting the placement chains a post-purchase step to the wrong paywall on the Console | Inspect `flow_id` + `displayed_presentation` in the `PRESENTATION_LOADED` event after purchase. Dashboard → Flows → fix the post-purchase branch |
| Chained follow-up placement shows the wrong/fallback screen | The follow-up `fetchPresentation` resolved against stale subscription state | iOS: await `synchronize()` via `withCheckedThrowingContinuation` BEFORE fetching the next placement. Android: fire-and-forget — accept brief stale-state risk |
| Paywall not updating after Console changes | SDK presentation cache | Clear app data, force kill, or invalidate any app-side cache via an attribute change (iOS `PLYUserAttributeDelegate`) or an explicit `Purchasely.synchronize()` (Android) |
| iOS compile error: *"Call to main actor-isolated class method 'closeAllScreens()' in a synchronous nonisolated context."* | Calling `closeAllScreens()` from a `DispatchQueue.main.async` block, a `synchronize(success:)` callback, or a `nonisolated` delegate | Wrap in `Task { @MainActor in Purchasely.closeAllScreens() }` |
| iOS: presentation re-fetches on every `.onAppear` (and Flow paywalls get stuck) | SDK has no native placement-level cache; repeated fetches accumulate `flowSteps` entries in `FlowsManager` | Add an app-side `PresentationCache` keyed by `placementId[/contentId]`. Invalidate on user-attribute changes and `synchronize()`. See `../../references/ios/common-patterns.md` |
| RN/Cordova (v5): same stuck-paywall / repeated-fetch issue as iOS above | Same SDK quirk — the v5 cross-platform bridge calls native fetch every time and has no shared cache | Apply the universal cache pattern from `../../references/concepts/presentation-cache.md` (skeleton implementations included for RN, Cordova) |
| Flutter (v6): repeated re-fetch / stuck Flow paywall | Re-displaying via a fresh `PresentationBuilder...build().display()` on every navigation refetches from the network | Build the `PresentationRequest` once, `await request.preload()` to fetch it, then `request.display([Transition])` the **same** request when ready; close programmatically with `presentation.close()` on the loaded `Presentation`. See the preload pattern in `../../references/concepts/presentation-cache.md` |
| RN/Cordova (v5): `closeAllScreens()` not exposed on JS side | Expected public bridge API mismatch | Use `closePresentation()` on the public JS side. `closeAllScreens()` is the native iOS/Android method unless the app has added a custom bridge |
| Flutter (v6): can't find `closePresentation()` / `closeAllScreens()` | Those methods do not exist in Flutter v6 | Dismiss via `presentation.close()` on the loaded `Presentation` (from `request.preload()` or `outcome.presentation`). `presentation.back()` navigates back inside a multi-step (Flow) presentation |
| RN/Cordova (v5): Flow paywall opens but cannot be closed (no X, no step transitions) | App uses the shorthand `Purchasely.presentPresentationForPlacement(...)`. On plugin ≤ 5.7.x the v5 cross-platform bridge does not branch on Flow, bypassing `presentation.display()`. The Flow manager never owns the window, so close affordance and step navigation are absent. `presentPresentationForPlacement` itself remains valid for simple non-Flow paywalls; the bug only surfaces when a Flow is assigned to the placement | Switch to the doc-recommended path: `fetchPresentation(placementId)` → `presentPresentation(presentation)`. The `presentPresentation` bridge correctly checks `isFlow` / `flowId != null` and calls native `display()`. See https://docs.purchasely.com/docs/general-in-app-experiences-display#how-to-display-an-in-app-experience-associated-to-a-placement |
| Flutter (v6): Flow paywall opens but cannot be closed | Wrong display entry point or no programmatic dismiss wired | Display Flows via `PresentationBuilder.placement(id).build().display([Transition])` (or `preload()` then `display()`); the v6 request correctly owns the Flow window. Dismiss with `presentation.close()` and step back with `presentation.back()`. `presentPresentationForPlacement`/`fetchPresentation` no longer exist in Flutter v6 |
| Lottie block is blank, static, or crashes while loading | Lottie is a weak dependency: the app is missing Airbnb Lottie, the iOS `PLYLottieBridge`, the Android `PLYLottieInterface` / `Purchasely.lottieView` registration, or the JSON is too large/unsupported | Add the native bridge and dependency from `../../references/concepts/lottie-animations.md`; keep JSON under 2 MB and validate it in LottieFiles Preview |
| RN/Cordova (v5): native crash on init or missing API | Plugin packages out of alignment (e.g. `react-native-purchasely 5.7.3` + `@purchasely/react-native-purchasely-google 5.6.0`) | Pin all plugin packages to the same `5.7.3`. See `../../references/sdk-versions.md` |
| Flutter (v6): native crash on init or missing API | Plugin packages out of alignment | Pin `purchasely_flutter`, `purchasely_google` and `purchasely_android_player` to the same `6.0.0-rc.1` (the v6 release pulling native iOS `Purchasely 6.0.0-rc.1` and Android `io.purchasely:core 6.0.0-rc.1`). See `../../references/sdk-versions.md` |

## Step 5: Escalate to Purchasely Support (when the root cause is in the Screen / Console)

If the diagnosis points at a **Screen built with the Purchasely Screen Composer** (layout misalignment, missing component, wrong offer displayed even with correct integration code, draft preview that doesn't render, Flow that won't transition), the issue lives outside the codebase. Don't keep patching app code.

Walk the user through the `../../references/troubleshooting/screen-issue-report.md` template:

1. Run the self-checks at the top of the report — enable `LogLevel.DEBUG`, read the logs, activate Debug Mode, try a sandbox tester. Most "Screen bugs" turn out to be integration, targeting, or sandbox issues.
2. If the bug still reproduces, fill in **every field** of the template (Screen URL, observed vs expected, repro steps, screenshots, display method, SDK version + plugin alignment, device, OS, user context, log grep, environment, recent changes).
3. Send the completed report to Purchasely Support.

The template's structure mirrors what Support needs to triage on the first round-trip. Don't compress it — empty fields force back-and-forth.

## Step 6: Decode `PLYError` Cases

When the log contains a `PLYError` case you don't immediately recognize (e.g. `invalidOfferSignature`, `cloudServiceRevoked`, `GoogleDeveloperError`, `InvalidStoreVersion`), look it up in `../../references/troubleshooting/error-codes.md`. That file maps every iOS and Android case to its typical cause and fix, plus the promotional-offer-specific errors and the Google Play Billing v8 hang.

## Completion Build Gate

Before declaring a Purchasely issue fixed, build the user's app with the project's canonical command (prefer the existing CI/build script). If the build fails, fix the error, rerun the build, and run relevant tests again until the app builds successfully. Do not report the bug as resolved from a patch, log check, or manual reasoning alone; include the exact build/test commands and outcomes in the final response.

If the task was diagnosis-only and no code was changed, still run the local app build when available; report any failing build as a blocker rather than claiming the integration is healthy.

## Guidelines

- Always verify your diagnosis by reading the actual code, not by assuming.
- Prefer targeted searches (`rg "Purchasely"`, `ast-grep` for method calls) over reading entire files.
- When multiple issues could explain the symptom, list them ranked by likelihood and check the most likely first.
- If the issue spans native and cross-platform layers (e.g., React Native bridge), check both sides.
- Reference the Purchasely documentation at docs.purchasely.com for the latest API surface if needed.
