---
name: purchasely-review
description: "Use when reviewing an existing Purchasely SDK integration — checks initialization, paywall display, action interceptor, deeplinks, user management, and production readiness across iOS, Android, React Native, Flutter, and Cordova."
---

# Purchasely Integration Review

You are an expert reviewer of Purchasely SDK integrations. Your job is to systematically audit the user's codebase for correctness, best practices, and common mistakes.

Before reviewing, read `../../references/purchasely-architecture.md` to ground yourself in the end-to-end platform and resilience guarantees — this helps you spot anti-patterns such as putting the customer's backend on the critical purchase path. If the project also handles web subscriptions (Stripe / another subscription platform / in-house), load `../../references/cross-platform-subscriptions.md` to know what cross-store coexistence patterns are expected vs. broken.

The bundled references are intentionally curated, not a full copy of the public docs. If a review finding depends on an exact SDK signature, current Console behavior, or a detail missing from `../../references/`, verify it against the official Purchasely documentation at https://docs.purchasely.com/ before flagging or fixing it.

**When the review uncovers a deeper issue**, route to the troubleshooting docs:

- `../../references/troubleshooting/common-issues.md` — symptom→cause table, log reading, full event taxonomy (use when a check fails and you're not sure why)
- `../../references/troubleshooting/screen-issue-report.md` — when the audit points at a Screen Composer bug (layout, missing component, wrong offer), package the escalation with this template instead of recommending app-code changes

**Universal SDK concept references** (apply to every platform — load as needed during the review):

- `../../references/concepts/running-modes.md` — Full vs Observer modes, log levels
- `../../references/concepts/paywall-actions.md` — interceptor rules + every code path must return/resolve an intercept result
- `../../references/concepts/presentation-types.md` — `NORMAL` / `FALLBACK` / `DEACTIVATED` / `CLIENT` guard
- `../../references/concepts/presentation-cache.md` — preload pattern + when to invalidate
- `../../references/concepts/observer-mode-post-purchase.md` — intercept-result → dismiss ordering
- `../../references/concepts/programmatic-purchases.md` — exact app-side purchase APIs by platform
- `../../references/concepts/user-attributes-targeting.md` — attributes for audiences
- `../../references/concepts/privacy-settings.md` — `revokeDataProcessingConsent`, privacy purposes, essential/optional processing
- `../../references/concepts/user-identity.md` — `userLogin` / `userLogout` timing, anonymous→logged-in merge, foreground resync
- `../../references/concepts/subscription-checks.md` — gating + restore purchases
- `../../references/concepts/subscription-management.md` — native Manage Subscription entry point (App Store / Play)
- `../../references/concepts/promotional-offers.md` — offers eligibility responsibility + implementation
- `../../references/concepts/campaigns.md` — deeplink/campaign display flags (`allowDeeplink` / `allowCampaigns` on v6; `allowDeeplink` defaults to `true` on **every** v6 platform including React Native — the RN builder just omits the key when unset; `allowCampaigns` defaults to `true` in v6 on iOS/Android/Flutter, was `false` in v5) + SDK ≥ 5.1.0
- `../../references/concepts/lottie-animations.md` — Lottie bridge/dependency checks for Screens with animations
- `../../references/concepts/analytics-integration.md` — events forwarding + analytics wrapper recommendation
- `../../references/sdk-versions.md` — latest stable versions (flag outdated pins)
- `../../references/troubleshooting/error-codes.md` — `PLYError` reference (errors silently ignored is a FAIL)
- `../../references/troubleshooting/debug-mode.md` — verify `LogLevel.DEBUG` gating

If `$ARGUMENTS` specifies a particular area (e.g., "interceptor", "deeplinks", "initialization"), focus the review on that section only. Otherwise, run the full checklist.

---

## Step 1 — Detect the Platform

Determine the platform by inspecting the project files. Check in this order and stop at the first match:

| Signal | Platform |
|--------|----------|
| `Podfile` or `*.xcodeproj` with `import Purchasely` | **iOS (Swift/ObjC)** |
| `build.gradle*` with `io.purchasely` | **Android (Kotlin/Java)** |
| `package.json` with `react-native-purchasely` | **React Native** |
| `pubspec.yaml` with `purchasely_flutter` | **Flutter** |
| `plugin.xml` or `config.xml` with `purchasely-cordova` | **Cordova** |

If multiple platforms are detected (e.g., a monorepo), review each one separately and label the results by platform.

If no Purchasely SDK is detected, stop and tell the user: "No Purchasely SDK integration found in this project. Are you in the correct directory?"

**Platform-specific reference docs** to consult while running the checklist (load the one matching the detected platform):

- `../../references/ios/initialization.md` + `../../references/ios/api-reference.md` + `../../references/ios/common-patterns.md`
- `../../references/android/initialization.md` + `../../references/android/api-reference.md` + `../../references/android/common-patterns.md`
- `../../references/react-native/integration.md`
- `../../references/flutter/integration.md`
- `../../references/cordova/integration.md`

These hold the canonical install/init snippets, full API signatures, and platform-only patterns. Use them to verify the user's code matches the expected setup (e.g. correct CocoaPods version, ProGuard rules, MethodChannel registration on Flutter, plugin package alignment on cross-platform SDKs).

## Expert checkpoint

Before returning review findings, run a Purchasely expert checkpoint. If the harness exposes the Claude Code subagent `purchasely:purchasely-sdk-expert`, invoke it and pass the detected platform(s), SDK versions, running mode, key code paths inspected, candidate findings, and the evidence for each finding.

If that subagent is not available, do the checkpoint inline using the `purchasely-sdk-expert` guidance when available, or this fallback checklist:

- Confirm the SDK generation used for each finding: native iOS uses v6 (`6.0.0`, stable GA); native Android uses v6 (`6.0.1`, stable GA — Android never had a `6.0.0` tag); Flutter uses v6 (`6.0.0`, pulling native iOS `6.0.0` + Android core `6.0.1`); React Native uses v6 (`6.0.0`, stable GA, npm `latest`, pulling native iOS `6.0.0` / Android `6.0.1`); Cordova uses v6 (`6.0.0`, stable GA, npm `latest`, pulling native iOS `6.0.0` / Android `6.0.1`).
- Confirm version findings compare against `../../references/sdk-versions.md`.
- Confirm Full-vs-Observer findings account for the v6 default running mode change (applies to Cordova too — it no longer defaults to Full).
- Confirm removed/deprecated API findings are platform-specific and do not flag valid v6 APIs as if they were the removed v5 ones (React Native and Cordova are both now on the v6 builder API).
- Confirm presentation findings distinguish full-screen display from explicit embedded/nested rendering.
- Confirm interceptor findings prove every branch resolves exactly once.
- Confirm Observer-mode findings correctly treat the post-`SUCCESS` synchronization as automatic (a manual `synchronize()` call inside the interceptor is redundant, not required) and use the correct platform dismissal API.
- Confirm each finding cites file/line evidence and is not based on a guessed signature.

Only keep findings that remain supported after this expert check, unless you explicitly document a reasoned disagreement.

---

## Step 2 — Search for Purchasely-Related Code

Search the entire codebase using these patterns to build a map of all Purchasely touchpoints:

**Initialization patterns:**
- Native v6: `Purchasely.apiKey(` (iOS fluent builder) / `Purchasely {` DSL or `Purchasely.Builder(` (Android) / `.runningMode(` / `.start(`
- Flutter v6: `PurchaselyBuilder.apiKey(` / `.runningMode(` / `RunningMode.full` / `.storekitVersion(` / `.start()`
- React Native v6: `Purchasely.builder(` / `.runningMode('full')` / `.storekitVersion('storeKit2')` / `.stores([` / `.start()`
- Cordova v6: `Purchasely.builder(` / `.runningMode(` / `.start(` / options-object `Purchasely.start({` (v5 positional `Purchasely.start(apiKey, stores, ...)` is removed)
- `PLYAlertMessage` / `PLYUIHandler` / `Purchasely.uiHandler` / `setUIHandler(` / `onAlert(` — on Android also grep the body of `onAlert` for `proceed(` and `onDismiss(` (see 3.3)
- `apiKey` / `PLY_API_KEY`

**Paywall patterns:**
- Native v6: `PLYPresentationBuilder` / `PLYPresentation {` / `.forPlacementId` / `.forScreenId` / `.build()` / `.preload(` / `buildView(` / `getFragment(` / `swiftUIView` / `screenId`
- Flutter v6: `PresentationBuilder.placement(` / `.screen(` / `.defaultSource()` / `.build()` / `.preload()` / `.display(` / `Transition.fullScreen()` / `PLYPresentationView(`
- React Native v6: `Purchasely.presentation.placement(` / `.screen(` / `.default()` / `.build()` / `.preload()` / `.display(` / `PLYPresentationView`
- v5 / removed (flag if present on native, Flutter v6, React Native v6, or Cordova v6): `fetchPresentation` / `presentationView` / `presentationController` / `presentPresentation` / `presentPresentationForPlacement` / `presentPresentationWithIdentifier`
- Cordova v6: `Purchasely.presentation.placement(` / `.screen(` / `.defaultSource()` / `.build()` / `.preload()` / `.display(`
- `PLYPresentation` / `PLYPresentationAction`
- `clientPresentation` — kept, unchanged in v6 on all platforms (BYOS — pass the presentation from `preload()`); do not flag it as removed or legacy
- `showPresentation` — v5, genuinely removed in v6 with no alias (flag if present on native, Flutter v6, React Native v6, or Cordova v6)

**Interceptor patterns:**
- Native v6: `interceptAction` / `PLYInterceptResult` / `PLYInterceptorInfo`
- Flutter v6: `Purchasely.interceptAction(` / `PresentationActionKind.` / `InterceptResult.success` / `.failed` / `.notHandled` / `removeInterceptor` / `removeAllInterceptors`
- React Native v6: `Purchasely.interceptAction('purchase'` / `'login'` / `'navigate'` / handler returning `'success'` / `'failed'` / `'notHandled'` / `removeActionInterceptor` / `removeAllActionInterceptors`
- v5 / removed (flag if present on native, Flutter v6, React Native v6, or Cordova v6): `setPaywallActionsInterceptor` / `setPaywallActionInterceptor` / `setPaywallActionInterceptorCallback` / `onProcessAction`
- Cordova v6: `Purchasely.interceptAction(Purchasely.PresentationAction.` / `Purchasely.InterceptResult.`
- `processAction` / `proceed` / `closePresentation` / `closeAllScreens`
- `PLYPresentationAction`

**Programmatic purchase patterns:**
- `purchaseWithPlanVendorId` / `Purchasely.purchase(` / `planWithIdentifier`

**Deeplink patterns:**
- Native v6 + Flutter v6: `handleDeeplink` / `allowDeeplink`
- React Native v6: `Purchasely.handleDeeplink(` (renamed from v5 `isDeeplinkHandled`) / `.allowDeeplink(` (builder modifier, default `true` — same as every platform; the builder just omits the key when unset)
- v5 tokens (removed with no alias on all v6 SDKs — FLAG on native/Flutter/React Native/Cordova v6 code): `isDeeplinkHandled` / `readyToOpenDeeplink`
- `setDefaultPresentationResultHandler` / `setDefaultPresentationDismissHandler`

**User management patterns:**
- `userLogin` / `userLogout` / `setUserAttribute`
- `setAttribute` / `setAttributes`
- `revokeDataProcessingConsent` / `clearBuiltInAttributes`
- `oneSignalPlayerId` (v5, removed with no alias — flag it) / `oneSignalExternalId` / `oneSignalUserId`

**Import statements:**
- `import Purchasely` / `@import Purchasely`
- `import io.purchasely`
- `react-native-purchasely` / `@purchasely/react-native`
- `purchasely_flutter`
- `purchasely-cordova`

Collect all file paths and line numbers where these patterns appear. This forms your audit surface.

---

## Step 3 — Run the Checklist

For each item below, search the code, analyze the context, and report one of:
- **PASS** — correctly implemented
- **FAIL** — incorrect or missing, must fix
- **WARNING** — suboptimal, should fix
- **SKIP** — not applicable to this platform or integration mode

### 3.1 Initialization

- [ ] **SDK initialized at app startup** — `Application.onCreate()` (Android), `AppDelegate.application(_:didFinishLaunchingWithOptions:)` (iOS), app root component (React Native), `main()` or `initState()` (Flutter), `deviceready` handler (Cordova). FAIL if called lazily or conditionally.
- [ ] **API key not hardcoded** — The API key should come from `BuildConfig` (Android), `Info.plist` / xcconfig (iOS), environment variable, or a config file excluded from version control. FAIL if a literal API key string appears in source code.
- [ ] **LogLevel.DEBUG only in debug builds** — Check that `logLevel: .debug` / `LogLevel.DEBUG` / `LogLevel.verbose` is gated behind a debug flag or build variant. WARNING if always set to debug.
- [ ] **Explicit running mode when purchases are validated by Purchasely** (v6 — native iOS/Android, Flutter, React Native, and Cordova) — ⚠️ v6 changed the default running mode from Full to **Observer**, *silently*. If the app expects Purchasely to process/validate purchases but the init does NOT set `.runningMode(.full)` (iOS) / `runningMode(PLYRunningMode.Full)` (Android) / `.runningMode(RunningMode.full)` (Flutter `PurchaselyBuilder`) / `.runningMode('full')` (React Native `Purchasely.builder`) / `runningMode: Purchasely.RunningMode.full` (Cordova `start` options), purchases are never validated. **FAIL** if Full behavior is relied on but the mode is left at the v6 default. SKIP for genuine Observer integrations.
- [ ] **start() completion handled** — The completion/callback of init (`.start { error -> }` / `try await ….start()` on native v6; `await PurchaselyBuilder.…start()` on Flutter v6; `await Purchasely.builder(...).start()` (`Promise<boolean>`) on React Native v6; `Purchasely.start(options, success, error)` on Cordova v6) must be awaited or handled before calling other SDK methods like the presentation builder. FAIL if SDK methods are called in a fire-and-forget pattern after start.
- [ ] **Stores configured correctly** — Android must specify at least one store (`Google`, `Huawei`, `Amazon`); on Flutter v6 via `.stores([PLYStore.google])` on the `PurchaselyBuilder`; on React Native v6 via `.stores(['google'])` (strings: `'google' | 'huawei' | 'amazon'`, default `['google']`) on `Purchasely.builder`; on Cordova v6 via `stores: [Purchasely.Store.google]` in the `start` options. iOS does not need store config. WARNING if stores are missing on Android. Note (v6 — native, Flutter, React Native, and Cordova): a **storeless** start is valid for screens/analytics/campaigns; only flag missing stores when the app runs in Full mode and expects purchases (purchase APIs return `PLYError.NoStoreConfigured`).

### 3.2 Paywall Display

- [ ] **Uses the v6 builder/preload API** (native iOS/Android, Flutter, React Native, and Cordova) — Must build + preload + display: iOS `PLYPresentationBuilder.forPlacementId(_).build().preload()` → `display(from:)`; Android `PLYPresentation { placementId(...) }.preload()` → `display(context)`; Flutter `PresentationBuilder.placement(id).build()` → `PresentationRequest` then `.preload()` and/or `.display([Transition])` (resolves at dismiss with a `PresentationOutcome`); React Native `Purchasely.presentation.placement(id).build()` → `PresentationRequest` then `.preload()` and/or `.display(transition?)` (resolves at dismiss with a 5-field `PresentationOutcome`); Cordova `Purchasely.presentation.placement(id).build()` → a request then `.preload()` and/or `.display(transition?)` (resolves at dismiss with a 5-field outcome). The v5 `fetchPresentation(...)` / `presentPresentation(...)` / `presentPresentationForPlacement(...)` / `presentPresentationWithIdentifier(...)` / `presentationView(...)` / VC-returning methods are **removed** in v6 — **FAIL** if any appear in native, Flutter v6, React Native v6, or Cordova v6 code (the pre-fetch-vs-shorthand Flow distinction from v5 Cordova no longer applies — the v6 request/builder always owns Flow navigation). For embedded use: iOS `controller` / `swiftUIView`, Android `buildView(...)` wrapped in `AndroidView` for Compose (there is no `presentation-compose` artifact or native `PLYPresentationView` composable), Flutter the `PLYPresentationView(request: ...)` widget, React Native the `<PLYPresentationView>` component. Cordova has **no** inline/embedded presentation view (deferred to v6.1). For Console-direct Screens, the builder accepts `screenId(...)` / `.forScreenId(_)` / Flutter `.screen(id)` / React Native `.screen(id)` / Cordova `.screen(id)`.
- [ ] **Handles PLYPresentationType.DEACTIVATED** — When the presentation type is `.deactivated` / `DEACTIVATED`, the paywall must NOT be displayed. FAIL if this case is not handled.
- [ ] **Handles PLYPresentationType.FALLBACK** — When the type is `.fallback`, the paywall should still be displayed but the app should log a warning. WARNING if not handled.
- [ ] **Handles PLYPresentationType.CLIENT** — When the type is `.client`, the app should display its own custom paywall. WARNING if not handled (acceptable if no custom paywall exists).
- [ ] **onClose/dismiss callback implemented** — The close callback must be set so the app can dismiss the paywall view/controller. On Flutter v6 the `display([Transition])` future resolves at dismiss with a `PresentationOutcome`, and a loaded `Presentation` exposes `.close()` / `.back()` for programmatic dismissal (the builder also offers `.onCloseRequested` / `.onDismissed` callbacks) — there is no `closePresentation()` / `closeAllScreens()` in Flutter v6. On React Native v6 the `display(transition?)` promise resolves at dismiss with a `PLYPresentationOutcome`, and the held `PLYPresentationRequest` exposes `.close()` / `.back()` (builder also offers `.onCloseRequested()` / `.onDismissed()`) — there is no `closePresentation()` / `closeAllScreens()` in React Native v6. FAIL if missing (causes stuck paywalls).
- [ ] **Android `close()` scope** (native Android only) — `presentation.close()` **delegates to `Purchasely.closeAllScreens()`**: it dismisses every screen currently displayed, not just this presentation instance — there is no instance-scoped close on Android (iOS does close only the targeted presentation). WARNING if the code assumes a scoped close inside a Flow or stacked-presentation scenario (e.g. closing one step without tearing down the rest) — on Android that call closes everything.

### 3.3 Action Interceptor

- [ ] **Interceptor is registered** — v6 uses **per-action** registration: `Purchasely.interceptAction(.login) { … }` (iOS) / `Purchasely.interceptAction<PLYPresentationAction.Login> { … }` (Android) / `Purchasely.interceptAction(PresentationActionKind.purchase, (info, payload) async { … })` (Flutter) / `Purchasely.interceptAction('purchase', async (info, payload) => …)` (React Native) / `Purchasely.interceptAction(Purchasely.PresentationAction.purchase, function (info, parameters) { … })` (Cordova) — one call per action kind you handle, typically right after init. The v5 single `setPaywallActionsInterceptor` / `setPaywallActionInterceptorCallback` / `setPaywallActionInterceptor` + `onProcessAction` is removed on v6 platforms — FAIL if it appears in native, Flutter v6, React Native v6, or Cordova v6 code. WARNING if no interceptor is registered at all and the app needs to handle login/navigate/observer purchases.
- [ ] **Each handler returns an intercept result** (v6 — native `PLYInterceptResult`, Flutter/Cordova `InterceptResult`, React Native string) — every registered handler must return `success` (app handled it, chain advances), `failed` (app tried, failed, remaining actions skipped), or `notHandled` (SDK executes the action). On Flutter the handler is `async` and must `return InterceptResult.success` / `.failed` / `.notHandled`; on React Native the `async` handler must `return 'success'` / `'failed'` / `'notHandled'` (a string); on Cordova the handler must return or resolve `Purchasely.InterceptResult.success` / `.failed` / `.notHandled`. FAIL if a handler falls through without returning a result.
- [ ] **LOGIN action handled** — On login, present the app's login flow. v6 (native + Flutter + React Native + Cordova, kind `login` / `PresentationActionKind.login` / `'login'` / `Purchasely.PresentationAction.login`): return `success` on success, `notHandled` to let the SDK proceed without login. FAIL if the login action is ignored when the app requires authentication.
- [ ] **PURCHASE action handled** — In **Full mode**, Purchasely handles purchases automatically and auto-closes the paywall (v6 native + Flutter + React Native + Cordova: return `notHandled` / `InterceptResult.notHandled` / `'notHandled'` / `Purchasely.InterceptResult.notHandled`). In **Observer mode**, the app must trigger its own purchase flow (native v6: run billing → return `.success`, then dismiss with `closeAllScreens()` after the interceptor resolves; **Flutter v6**: run billing → `return InterceptResult.success`, then dismiss with `presentation.close()`; **React Native v6**: run billing → `return 'success'`, then dismiss with `request.close()`; **Cordova v6**: run billing → resolve `Purchasely.InterceptResult.success`, then dismiss with `request.close()` on the held presentation request (`closePresentation()` is kept as a deprecated alias)). Returning `SUCCESS`/`success` already triggers synchronization automatically — do not require a manual `synchronize()` call inside the interceptor for this to work. Observer mode does not auto-close; FAIL if the mode and handling are mismatched. Note: returning `notHandled` for `purchase`/`restore` in Observer mode is a no-op (logs a warning) — flag it.
- [ ] **RESTORE action handled** — Similar to purchase: Full mode auto-handles, Observer mode needs custom logic. WARNING if not explicitly handled.
- [ ] **CLOSE action handled** — The close action must dismiss the paywall. v6 (native + Flutter + React Native + Cordova, kind `close` / `PresentationActionKind.close` / `'close'` / `Purchasely.PresentationAction.close`): return `notHandled` to let the SDK close, or `success` if the app closes it itself (Flutter: via `presentation.close()`; React Native: via `request.close()`; Cordova: via `request.close()`). FAIL if missing (users cannot close the paywall).
- [ ] **No missing intercept result** — every branch (early return, error catch, switch default) MUST return or resolve exactly one result. This is the #1 most common stuck-paywall bug. FAIL if any code path can skip the result.
- [ ] **No double-completion** — Returning/resolving once and then mutating state as if the handler were still pending is a logic error. WARNING if there's a risk of double signalling.
- [ ] **Custom `PLYUIHandler.onAlert` dismisses the alert (Android)** — if `Purchasely.uiHandler` / `setUIHandler(...)` is registered and `onAlert` displays the app's own dialog, **every** branch — `when` arms, `else`, early returns, the null-`activity` path, error catches — must end with exactly one of `proceed()` (SDK displays its dialog and dismisses the alert) or `alert.onDismiss()` (dismiss with no SDK dialog). The alert is the last step of the paywall action that raised it, so a branch calling neither leaves that action pending and the Screen stays displayed and unresponsive, close button included. FAIL if any branch can skip both; FAIL if both are called for the same alert (the SDK dialog stacks on top of the custom one); WARNING if `alert.onDismiss()` is called *before* the custom dialog is dismissed rather than from its dismiss callback (on a success alert the SDK resumes the flow and closes the Screen). SKIP on iOS and on the cross-platform bridges — the dismissal contract is Android-specific. See `../../references/android/api-reference.md` § UI Handler — Alerts.
- [ ] **No stale rc-era Android import** — `import io.purchasely.ext.interceptAction` (and `removeActionInterceptor`) was only required before rc.3, when these were top-level extension functions; since rc.3 they are member functions of `Purchasely` and need no import at all. WARNING if the import is still present in the code — it's harmless dead code, not a bug; delete it.
- [ ] **No attempt to override post-purchase flow from the interceptor** — If the app holds the interceptor open, skips `proceed`, or calls `Purchasely.close()` manually to "stay on the paywall" / "show a custom thank-you screen" after a purchase, that's the wrong layer. The Composer button supports a **second action** (`purchase + open_screen` / `purchase + open_placement` / `purchase + deeplink`) and the default is *close in Full mode, stay open in Observer mode*. WARNING — recommend wiring the second action in the Console (or BYOS if the next screen is custom). See `../../references/concepts/paywall-actions.md` § Chaining multiple actions.

### 3.4 Deeplinks

- [ ] **Deeplink forwarded to the SDK** — the app must hand incoming URLs to the SDK. On **all v6 SDKs (native iOS/Android, Flutter, React Native, Cordova)** the method is `Purchasely.handleDeeplink(...)` and the v5 `isDeeplinkHandled(...)` is **removed** with no alias — **FAIL** if it's still used (it won't compile / the symbol no longer exists). On **iOS** the SDK does NOT auto-intercept, so the deeplink must be wired from AppDelegate/SceneDelegate. On **Android v6** deeplinks are auto-intercepted (zero code) by reading the foreground activity intent; if the activity is `singleTask`/`singleTop`, verify `setIntent(intent)` is called in `onNewIntent` (otherwise the URI is hidden) or that a manual `handleDeeplink(uri, activity)` call exists. On **Flutter / React Native / Cordova v6**, forward incoming links from the app's deeplink handling to `Purchasely.handleDeeplink(...)` when the bridge does not receive them automatically. SKIP if the app doesn't support deeplinks.
- [ ] **allowDeeplink enabled** — v6 renamed the v5 `readyToOpenDeeplink` → `allowDeeplink`. It defaults to **true** on **every** v6 platform, including React Native — there is no RN-specific exception; the RN builder simply omits the key when `.allowDeeplink(...)` isn't called and the native default applies. Only flag it if the app explicitly sets `allowDeeplink(false)` while relying on deeplink/campaign display. On **all v6 SDKs** the v5 `readyToOpenDeeplink` is **removed** with no alias — **FAIL** if it's used as the primary call in v6 code (it no longer exists).
- [ ] **Default presentation dismiss handler configured** — A default dismiss handler should be set so deeplink/campaign-triggered paywalls can report their outcome: native + Flutter + **React Native v6** all use `Purchasely.setDefaultPresentationDismissHandler((outcome) => …)` (Android has always used this name — `setDefaultPresentationResultHandler` never existed there; iOS renamed to it in v6). On React Native it returns a subscription with `.remove()`; one active handler, re-register replaces. WARNING if missing.

### 3.5 User Management

- [ ] **userLogin() called after authentication** — `Purchasely.userLogin(userId:)` must be called when the user signs in. WARNING if missing (anonymous users are fine, but logged-in users lose cross-device sync).
- [ ] **userLogin() runs BEFORE presentation build / synchronize calls that depend on audience** — race-condition check: if both happen in the same async block, verify identity is set first. FAIL if the presentation resolves (v6 native + Flutter + React Native + Cordova `.preload()`) while still anonymous and the placement depends on logged-in audience attributes. See `../../references/concepts/user-identity.md`.
- [ ] **userLogout() called on sign out** — `Purchasely.userLogout()` must be called when the user signs out. WARNING if missing (stale user data).
- [ ] **Foreground resync** — `Purchasely.synchronize()` should be called from `applicationDidBecomeActive` (iOS), `ProcessLifecycleOwner` `ON_START` (Android), `AppState 'active'` (RN), `didChangeAppLifecycleState(.resumed)` (Flutter), or the `resume` event (Cordova). WARNING if missing — renewals or cancellations that happen while the app is backgrounded won't reflect in the client until the user re-opens. SKIP if running in Full mode AND the user never backgrounds the app for >1 day. Note (Flutter v6 + React Native v6): `synchronize()` is no longer fire-and-forget — it now **resolves on completion** (`Promise<boolean>` on RN, `Future<void>` on Flutter) and **rejects/throws on failure**, so `await` it (optionally wrap in `try/catch`) before chaining a follow-up presentation that targets subscribers.
- [ ] **User attributes set** — If the app uses audience targeting, `setUserAttribute` should be called with relevant attributes. SKIP if audience targeting is not used.
- [ ] **No removed `oneSignalPlayerId` attribute** — `PLYAttribute.oneSignalPlayerId` is **removed with no alias**; the v6 replacement is `.oneSignalExternalId` / `.oneSignalUserId`. FAIL if the old call site is still used. The backend audience key also changed (`onesignal_player_id` → `onesignal_external_id`) — any Console audience rule still keyed on the old value **stops receiving data silently** (no error) after the app updates. WARNING to also audit Console audience rules, not just the SDK call site.
- [ ] **Restore Purchases entry point** — Apple **requires** a Restore button reachable outside the paywall (Settings / Account) for App Store review. CRITICAL: **check the Purchasely paywall first** — if the Console operator has enabled the in-paywall Restore button on every relevant screen, an app-side button is duplicate work. If neither the paywall nor an app-side button exists, FAIL (App Store rejection risk). If only an app-side button exists but the paywall could also expose one, WARNING — confirm with the user / Console operator. See `../../references/concepts/subscription-checks.md`.
- [ ] **Manage Subscription entry point** — both stores require an in-app link to native subscription management. WARNING if missing from Settings / Account. See `../../references/concepts/subscription-management.md`. Note (v6 — native, Flutter and React Native): the built-in subscriptions-list screen was **removed**. iOS never had a `presentSubscriptions()` method — the real iOS removals are `Purchasely.showController(_:type:from:)`, `PLYUIControllerType`, the legacy `PLYSubscriptionViewController` ("My Subscriptions"), and `PLYEvent.subscriptionsListViewed` / `.cancellationReasonPublished` — FAIL if any still appear. Android's equivalent removal is `Purchasely.subscriptionsFragment()` / `PLYSubscriptionsFragment` and the `ply/subscriptions` / `ply/cancellation_survey` deeplinks. `Purchasely.presentSubscriptions()` is **removed entirely** from Flutter v6 **and React Native v6** (it is NOT a no-op — the method no longer exists) — FAIL if it still appears in Flutter v6 or React Native v6 code; build your own screen from `userSubscriptions()` / `userSubscriptionsHistory()`. `Purchasely.displaySubscriptionCancellationInstruction()` is kept for source-compat as a **no-op on iOS only** — on **Android it was already undocumented upstream and is not present at all** (flag it as a dead symbol, not a harmless no-op), and on **Flutter it is removed too, not a no-op**.

### 3.6 Architecture (If a wrapper class exists)

If the project routes its Purchasely SDK calls through a single dedicated class — whatever its name (`PurchaselyWrapper`, `PurchaselyService`, `IAPManager`, …) — verify these recommended patterns. SKIP this entire section if there is no such class — do NOT suggest adding one unless the user asks.

- [ ] **SDK calls go through wrapper** — Search for direct Purchasely SDK calls outside the wrapper: init (`Purchasely.apiKey(`/`Purchasely {`/`PurchaselyBuilder.apiKey(`/`Purchasely.builder(`/`Purchasely.start`), presentation build (`PLYPresentationBuilder`/`PLYPresentation {`/`PresentationBuilder.`/`Purchasely.presentation.`/`fetchPresentation`), interceptor registration (`Purchasely.interceptAction`). WARNING if the SDK is called directly from UI code alongside a wrapper.
- [ ] **Screens have zero SDK imports** — `import Purchasely` / `import io.purchasely` should not appear in ViewModel/Screen files. WARNING if found.
- [ ] **Observer mode billing decoupled** — If using Observer mode with a wrapper, check that the native PurchaseManager does NOT import the SDK. WARNING if it directly calls `synchronize()` or references the wrapper.
- [ ] **Wrapper owns init and interceptor** — init (`start()`) and the action interceptor registration (`Purchasely.interceptAction(...)` on v6 — native, Flutter, React Native, and Cordova) should be in the wrapper, not scattered. WARNING if init logic is outside.
- [ ] **Testable wrapper** — iOS: protocol for mocking. Android: DI-injectable. WARNING if not mockable.

See `../../references/architecture-patterns.md` for recommended patterns and improvements to suggest.

### 3.7 Production Readiness

- [ ] **SDK version is current** — Compare the pinned version against `../../references/sdk-versions.md` (**iOS (native)** on **6.0.0**, stable GA; **Android (native)** on **6.0.1**, stable GA — Android never had a `6.0.0` tag, the line went rc.1 → rc.2 → rc.3 → `6.0.1`; **Flutter** on **6.0.0**, pulling native iOS `6.0.0` + Android core `6.0.1`; **React Native** on **6.0.0**, stable GA (npm `latest`), pulling native iOS `6.0.0` + Android `6.0.1`; **Cordova** on **6.0.0**, stable GA (npm `latest`, not `@next`), pulling native iOS `6.0.0` / Android `6.0.1`). FAIL if older than minimum, WARNING if not at latest. FAIL if a floating version (`5.+`, `6.+`, `^5.0.0`, `^6.0.0`, etc.) is used on Android, Flutter, React Native, or Cordova instead of an exact pin. **iOS is the exception**: it's stable GA, so a minor-range pin is the recommended and expected form — CocoaPods `pod 'Purchasely', '~> 6.0'`, SPM `from: "6.0.0"` (Up to Next Major) — do not flag these as unpinned; only flag an iOS pin below `6.0.0` or an unbounded range. Exact pins elsewhere: Android `io.purchasely:core:6.0.1`; **Flutter** `purchasely_flutter: 6.0.0` (and `purchasely_google` / `purchasely_android_player` at the same `6.0.0`, never `^`/`>=`); **React Native** `react-native-purchasely: 6.0.0` (and `@purchasely/react-native-purchasely-google` / `-android-player` / `-amazon` / `-huawei` at the same `6.0.0`, never `^`/`>=`); **Cordova** `@purchasely/cordova-plugin-purchasely: 6.0.0` (and `-google` at the same `6.0.0`, never `^`/`>=`).
- [ ] **Plugin packages aligned** (cross-platform only) — All `@purchasely/cordova-plugin-*` packages MUST be the same `6.0.0`; on **Flutter** all `purchasely_*` packages (`purchasely_flutter`, `purchasely_google`, `purchasely_android_player`) MUST be the same `6.0.0`; on **React Native** all `react-native-purchasely*` packages (`react-native-purchasely`, `@purchasely/react-native-purchasely-google` / `-android-player` / `-amazon` / `-huawei`) MUST be the same `6.0.0`. FAIL if mismatched.
- [ ] **ProGuard/R8 rules added** (Android only) — `proguard-rules.pro` must include Purchasely keep rules or the dependency must use `consumerProguardFiles`. WARNING if missing.
- [ ] **No removed / deprecated APIs** — Native v6 **removed**: `setPaywallActionsInterceptor`, `fetchPresentation` (native), `presentationView(for:)`/`presentationViewControllerFor`/`presentationController`, `purchaseHistory()` (→ `userSubscriptionsHistory()`), `isPastSubscriber()`, the `intro*`/`introductory*` plan methods and `PLYPlanTags.INTRO_PRICE`/`TRIAL_PRICE` (→ `offer*` / `PLYPlanTags.OFFER_PRICE`), `PLYPresentationInfo` (→ `PLYInterceptorInfo`), the v5 deeplink methods `readyToOpenDeeplink` (→ `allowDeeplink`) and `isDeeplinkHandled` (→ `handleDeeplink`) — both removed with **no alias** on native iOS **and** Android — and — **Android only** — `PLYPresentationActionParameters` (Android replaced it with typed action subclasses; **iOS retains** `PLYPresentationActionParameters` as the interceptor `params`, so do not flag it on iOS). The removed subscriptions-list UI is **platform-specific, not a shared symbol**: on **Android** it's `Purchasely.subscriptionsFragment()` / `PLYSubscriptionsFragment` and the `ply/subscriptions` / `ply/cancellation_survey` deeplinks; on **iOS** it's `Purchasely.showController(_:type:from:)` / `PLYUIControllerType` / the legacy `PLYSubscriptionViewController` ("My Subscriptions") / `PLYEvent.subscriptionsListViewed` / `.cancellationReasonPublished` — iOS never had a `presentSubscriptions()` or `subscriptionsFragment()` method, don't flag those names as iOS removals. **FAIL** for each occurrence in native code (it won't compile against v6). Native v6 **deprecated** (removal v7): pre-`start` class funcs like `setEnvironment`/`setThemeMode` (→ builder modifiers) — WARNING for each.
  - **Flutter v6 removed** (FAIL — the Dart symbol no longer exists): `Purchasely.start(...)` (→ `PurchaselyBuilder.apiKey(...).…start()`), `fetchPresentation` / `presentPresentation` / `presentPresentationForPlacement` / `presentPresentationWithIdentifier` / `presentProductWithIdentifier` / `presentPlanWithIdentifier` / `getPresentationView` (→ `PresentationBuilder` + `PresentationRequest` / `PLYPresentationView`), `closePresentation()` / `hidePresentation()` / `showPresentation()` / `closeAllScreens()` (→ `presentation.close()` / `.display()` / `.back()`), `setPaywallActionInterceptorCallback` + `onProcessAction` (→ `Purchasely.interceptAction(kind, handler)` returning `InterceptResult`), `presentSubscriptions()` (no replacement — build your own from `userSubscriptions()` / `userSubscriptionsHistory()`), and the v5 deeplink methods `readyToOpenDeeplink` (→ `allowDeeplink`) / `isDeeplinkHandled` (→ `handleDeeplink`) — **removed with no alias** (matching native iOS/Android and React Native). **Flutter v6 deprecated aliases** (WARNING): the `intro*` plan fields (→ `offer*`). `displaySubscriptionCancellationInstruction()` is **removed on Flutter — not a no-op** (the underlying Android method it wrapped was already undocumented upstream) — FAIL if still called; build a custom UI from `userSubscriptions()` / `userSubscriptionsHistory()`.
  - **React Native v6 removed** (FAIL — the JS symbol no longer exists): the whole v5 paywall API — `Purchasely.start({...})` / `startWithAPIKey` (→ `Purchasely.builder('key')….start()`), `fetchPresentation` / `presentPresentation` / `presentPresentationForPlacement` / `presentPresentationWithIdentifier` / `presentProductWithIdentifier` / `presentPlanWithIdentifier` (→ `Purchasely.presentation.placement(id)` / `.screen(id)` / `.defaultSource()` + `PLYPresentationRequest`), `showPresentation()` / `hidePresentation()` / `closePresentation()` (→ `request.display()` / `request.close()` / `request.back()`), `setPaywallActionInterceptorCallback` + `onProcessAction` (→ `Purchasely.interceptAction(kind, handler)` returning the string `'success' | 'failed' | 'notHandled'`), `setDefaultPresentationResultCallback` / `setDefaultPresentationResultHandler` (→ `setDefaultPresentationDismissHandler`), `readyToOpenDeeplink` (→ the builder modifier `.allowDeeplink(true)`), **`isDeeplinkHandled(uri)` (→ `handleDeeplink(uri)` — renamed, no alias; FLAG it)**, `presentSubscriptions()` / `displaySubscriptionCancellationInstruction()` (**no replacement** — build your own from `userSubscriptions()` / `userSubscriptionsHistory()`; they are NOT no-ops, the methods no longer exist), the `PLYPaywallAction` enum, and the `RunningMode.TRANSACTION_ONLY` / `PAYWALL_OBSERVER` values. `synchronize()` is now awaitable (`Promise<boolean>`). `closeReason` values are `'button' | 'backSystem' | 'programmatic'` (no `interactiveDismiss`). The embedded `PLYPresentationView` component remains (now also accepts a preloaded `request` prop) and its `onPresentationClosed` callback emits the 5-field `PLYPresentationOutcome`. **`clientPresentationDisplayed` / `clientPresentationClosed` are KEPT, unchanged** in v6 (BYOS — pass the presentation from `preload()`) — do not flag them as removed.
  - **Cordova v6 removed** (FAIL — the JS symbol no longer exists): the v5 positional `Purchasely.start(apiKey, stores, storeKit1, userId, logLevel, runningMode, ok, err)` (→ `Purchasely.builder(apiKey)….start()` or the options-object `Purchasely.start({...}, ok, err)`), `fetchPresentation` / `fetchPresentationForPlacement` / `fetchPresentationForDefault` / `presentPresentation` / `presentPresentationForPlacement` / `presentPresentationWithIdentifier` / `presentProductWithIdentifier` / `presentPlanWithIdentifier` (→ `Purchasely.presentation.placement(id)` / `.screen(id)` / `.defaultSource()` + `.build().preload()`/`.display()`), `setPaywallActionInterceptor` + `onProcessAction` (→ `Purchasely.interceptAction(kind, handler)` returning `Purchasely.InterceptResult.success` / `.failed` / `.notHandled`; `PaywallAction` renamed `PresentationAction`), `setDefaultPresentationResultHandler` (→ `setDefaultPresentationDismissHandler`), **`readyToOpenDeeplink` (→ `.allowDeeplink(true)` — removed, no alias)**, **`isDeeplinkHandled(url, ok, err)` (→ `Purchasely.handleDeeplink(url, ok, err)` — renamed, no alias; FLAG it)**, `showPresentation()`, `hidePresentation()`, and `presentSubscriptions()` (**no replacement** — build your own from `userSubscriptions()` / `userSubscriptionsHistory()`; NOT a no-op, the method no longer exists). `Purchasely.closePresentation()` and `addEventsListener`/`removeEventsListener` are kept as **deprecated aliases** (→ `closeAllScreens()`-equivalent `request.close()`, and `addEventListener`/`removeEventListener`). `synchronize()` now accepts `(success, error)` callbacks (no longer strictly fire-and-forget, though a no-arg call still works). There is **no inline/embedded presentation view** on Cordova (deferred to v6.1).
- [ ] **Error handling around presentation build** — The presentation can fail (network error, invalid placement). The error/failure case must be handled gracefully: native v6 `.preload { loaded, error -> }` / `.preload()` throwing; **Flutter v6** the `display([Transition])` future's `PresentationOutcome.error` (and `try/catch` around `.preload()` / `.display()`); **React Native v6** the `display(transition?)` promise's `PLYPresentationOutcome.error` (and `try/catch` around `.preload()` / `.display()`); **Cordova v6** the `.preload()` / `.display()` promise's `outcome.error` (and `.catch(...)` around both). FAIL if errors are silently ignored. Map known `PLYError` cases (see `../../references/troubleshooting/error-codes.md`) when surfacing failure to the user.
- [ ] **`PrivacyInfo.xcprivacy` present** (iOS only, builds against Xcode 15+ / iOS 17 SDK) — Apple requires a Privacy Manifest declaring the app's required reason API usage, third-party SDKs, and tracking domains. The Purchasely SDK ships its own `PrivacyInfo.xcprivacy` for its data collection. WARNING if the **app's** root `PrivacyInfo.xcprivacy` is missing — App Store Connect rejects submissions without it since May 2024.
- [ ] **Google Play Billing v8 awareness** (Android only) — If the project pins `com.android.billingclient:billing` (non-KTX) ≥ 8.x while Purchasely uses `billing-ktx`, prices can hang on `queryProductDetails()`. WARNING — recommend `com.android.billingclient:billing-ktx` and/or a Gradle `resolutionStrategy.force(...)`. See `../../references/troubleshooting/error-codes.md` § Google Play Billing v8.
- [ ] **`LogLevel.DEBUG` not shipped in release** — Confirm that `LogLevel.DEBUG` is gated behind a build flag (`#if DEBUG`, `BuildConfig.DEBUG`, `__DEV__`, etc.). WARNING if always-on. Debug logs leak placement IDs, audience matches, and presentation IDs.
- [ ] **Suggest real device testing** — Always recommend testing on a real device with a sandbox/test account, as simulators cannot process real purchases. See `../../references/testing/README.md` for Sandbox Apple ID and Play License Tester setup.

### 3.8 Observer Mode Post-Purchase (if Observer mode is detected)

- [ ] **Correct ordering** — Native iOS/Android v6: inside the `.purchase` interceptor, run billing → **return `PLYInterceptResult.SUCCESS`** (there is no `proceed`/`processAction` callback — returning `SUCCESS` already triggers synchronization automatically), then **dismiss with `Purchasely.closeAllScreens()`** from your billing-result handler **after** the interceptor has resolved. **Flutter v6**: inside the `PresentationActionKind.purchase` handler, run billing → **`return InterceptResult.success`** (auto-triggers synchronization), then dismiss with **`presentation.close()`** after the handler resolves. **React Native v6**: inside the `'purchase'` handler, run billing → **`return 'success'`** (auto-triggers synchronization), then dismiss with **`request.close()`** on the held `PLYPresentationRequest` after the handler resolves. **Cordova v6**: inside the `PresentationAction.purchase` handler, run billing → resolve **`Purchasely.InterceptResult.success`** (auto-triggers synchronization), then dismiss with **`request.close()`** on the held presentation request after the handler resolves (`closePresentation()` is kept as a deprecated alias). Observer mode does **not** auto-close after a purchase/restore (the implicit `close_all` is Full-only) — the dismissal is the app's job unless a `close` / `close_all` action is wired on the button in the Console. Do **not** call the dismiss inside the interceptor/handler closure before returning the result — that races the SDK (WARNING). See `../../references/concepts/observer-mode-post-purchase.md`.
- [ ] **Redundant manual `synchronize()` inside the interceptor** — Returning `SUCCESS` / `success` from the `purchase`/`restore` interceptor already triggers Purchasely's synchronization automatically. If the code still calls `Purchasely.synchronize()` (or awaits it) inside that same interceptor before returning, it is not incorrect — just unnecessary extra work. **WARNING, not FAIL.** Manual `synchronize()` remains legitimate for purchases made **outside** the interceptor path (a custom sell screen, BYOS) or to force a resync elsewhere in the app.
- [ ] **Correct dismiss API** — native iOS/Android v6 should resolve the interceptor with a successful `PLYInterceptResult` and then dismiss with `closeAllScreens()` (not `closeDisplayedPresentation()`, which was renamed), since Observer mode does not auto-close. **Flutter v6** should resolve the handler with `InterceptResult.success` and then dismiss the loaded `Presentation` with `presentation.close()` — `closePresentation()` / `closeAllScreens()` no longer exist in Flutter v6. **React Native v6** should resolve the handler with `'success'` and then dismiss the held `PLYPresentationRequest` with `request.close()` — `closePresentation()` / `closeAllScreens()` no longer exist in React Native v6. **Cordova v6** should resolve the handler with `Purchasely.InterceptResult.success` and then dismiss the held presentation request with `request.close()` (`closePresentation()` is kept as a deprecated alias). WARNING if the older or wrong-platform API is used, or if no dismissal happens in Observer mode and no Console `close` action is configured.
- [ ] **iOS `@MainActor` wrap** (iOS only) — when calling `closeAllScreens()` from a non-isolated context (inside a `synchronize` callback or `DispatchQueue.main.async`), it must be wrapped in `Task { @MainActor in ... }`. FAIL if missing on iOS v6 (`closeAllScreens()` is `@MainActor`-isolated).

### 3.9 Campaigns (if Campaigns are used in the Console)

SKIP this entire section if the project doesn't use Campaigns. To detect: ask the user, or check Purchasely Console → Campaigns. Otherwise:

- [ ] **SDK ≥ 5.1.0** — minimum version required for Campaigns. FAIL if pinned below.
- [ ] **Deeplink display enabled** — trigger-based campaigns are delivered through deeplinks. `allowDeeplink` defaults to **true** on every v6 platform, including React Native (the builder just omits the key when `.allowDeeplink(...)` isn't called), so usually no action is needed; FAIL only if the app explicitly sets `allowDeeplink(false)` while campaigns are used, and on Android verify the auto-interception isn't broken (e.g. `singleTask` activity missing `setIntent(intent)`). On Flutter/Cordova/React Native v6, also ensure incoming deeplinks reach `Purchasely.handleDeeplink(uri)` on iOS when the host app owns deeplink routing (renamed from v5 `isDeeplinkHandled`; Android auto-intercepts).
- [ ] **UI Handler keeps the returned presentation object** (if used) — refetching the presentation loses campaign context (audience match, screen variant, exposure tracking). WARNING if the handler refetches.
- [ ] **`allowCampaigns` default flip (v6)** — v6 defaults `allowCampaigns` to **true** on iOS/Android/Flutter (v5 default was `false`). If the client reports campaigns now firing that never appeared before a v6 upgrade, this default change is the explanation, not a regression — no fix needed unless the app wants to opt back out with an explicit `allowCampaigns(false)`. Campaign deeplink opening is additionally conditioned on the SDK being config-ready.

### 3.10 Promotional Offers (if promo offers / offer codes are used)

SKIP if the app does not surface promotional offers, developer-determined offers, or offer codes. Otherwise:

- [ ] **SDK ≥ 4.0.0** — required for promotional offer purchase APIs.
- [ ] **Eligibility audiences defined** — Apple promotional offers and Google developer-determined offers are **your** responsibility to gate. WARNING if a promo paywall has no audience restriction (Apple: subscribers in the same group; Google: usually `ignore-offer` tag + opt-in). See `../../references/concepts/promotional-offers.md`.
- [ ] **Full mode auto-handles** — in Full mode, no app code is needed. WARNING if app code calls `purchaseWithPromotionalOffer` manually while in Full mode (duplicates the purchase).
- [ ] **Observer/custom paywall uses `subscriptionOffer` parameters** — `subscriptionId`, `basePlanId`, `offerId`, `offerToken` (Google) or signed offer (Apple). FAIL if a Promo offer purchase is attempted with regular `purchase(...)` instead of the offer-aware API.

### 3.11 Bring Your Own Screen — BYOS (if a Custom Screen delegate / provider is registered, or a Flow contains a Custom Screen step)

SKIP if no BYOS code path is detected (no `setCustomScreenViewControllerDelegate` / `setCustomScreenViewDelegate` / `setCustomScreenProvider` registration, no `executeConnection` / `execute(connection:)` call, and the Console does not declare any `Bring Your Own Screen` layout). To detect: search for `CustomScreen`, `PLYCustomScreen`, `executeConnection`, `PLYConnection` in the code. Otherwise:

- [ ] **Platform supports BYOS** — BYOS is iOS (Swift/SwiftUI) and Android (Kotlin) only. **FAIL** if BYOS is being attempted on React Native, Flutter, or Cordova (not shipped yet — escalate to support before promising it).
- [ ] **SDK ≥ 5.6.0** — required for the Custom Screen delegate/provider APIs and `executeConnection`. FAIL if pinned below.
- [ ] **`display()` is used to render the Flow** — BYOS only triggers when the SDK owns the navigation. FAIL if the app fetches the presentation then renders Composer screens manually (the BYOS callback is never invoked in that path). See `../../references/concepts/byos.md`.
- [ ] **Delegate/provider returns a view for every declared Custom Screen ID** — The Console's Screen ID(s) must each have a matching branch. FAIL if any Screen ID falls through to `nil` / `EmptyView` unintentionally — the SDK silently closes that step and the Flow breaks.
- [ ] **`executeConnection` / `execute(connection)` is called on every exit path** — Every user-driven exit from the Custom Screen (success, cancel, error) must call the SDK with the matching `PLYConnection`. FAIL if any path leaves the screen on its own (e.g. `dismiss()`, `popBackStack()`) without notifying the SDK — the Flow stays stuck or the SDK loses analytics context.
- [ ] **Connection IDs match the Console** — The string IDs (`login_successful`, `signup`, `cancel`…) must match exactly what the Console operator configured. WARNING if hardcoded IDs drift from the Console — recommend a shared constants file.
- [ ] **`Purchasely.synchronize()` after in-screen purchases** — If the Custom Screen runs its own purchase flow (legacy paywall A/B variant, etc.), the app must call `synchronize()` on success. FAIL if missing — A/B / A/A conversion attribution will be wrong.
- [ ] **No manual navigation around the Purchasely controller** — Flag any sign that the team is presenting their own VC over the Purchasely paywall, calling `Purchasely.close()` then pushing a screen, or skipping `display()` to render a custom screen instead. WARNING — replace with BYOS (the supported handover model).
- [ ] **Interaction analytics instrumented in-app** — The SDK emits `PRESENTATION_DISPLAYED` for the Custom Screen but does not track interactions inside it. WARNING if the team relies on Purchasely tracking for in-screen events — they need to wire their own analytics inside the Custom Screen.

### 3.12 Lottie Animations (if the Screen uses Lottie, or the user reports blank / static animations)

SKIP if no Purchasely Screen uses Lottie and the user did not mention animation rendering. Otherwise, load `../../references/concepts/lottie-animations.md` and check:

- [ ] **Native Lottie dependency present** — iOS host has Airbnb `lottie-ios` / module `Lottie`; Android host has `com.airbnb.android:lottie`. Cross-platform apps still need these in the native host projects. WARNING if missing.
- [ ] **Bridge/interface implemented** — iOS has `@objc(PLYLottieBridge)` with the expected methods; Android has a `PLYLottieInterface` implementation. FAIL if a Lottie Screen is expected to render but the bridge is absent.
- [ ] **Android factory registered before display** — `Purchasely.lottieView = { context -> ... }` is set during app initialization before paywalls are shown. FAIL if missing or registered too late.
- [ ] **Failure logging / file health checked** — Android uses `setFailureListener`; the Lottie JSON is under 2 MB and validated in LottieFiles if rendering still fails. WARNING if errors are swallowed.

### 3.13 Analytics & Events Forwarding (universal — low blocker, high payoff)

- [ ] **One analytics wrapper / manager / controller** — if the project forwards Purchasely events (`PLYEventDelegate` / `EventListener` / `addEventListener`) into Firebase / Amplitude / AppsFlyer, the recommended pattern is a single class that routes events to N vendor SDKs. WARNING if events are forwarded directly from multiple call sites or scattered across screens. SKIP if no client-side event forwarding is in place (server-side 3rd-party integrations may be sufficient — see `../../references/concepts/analytics-integration.md`).
- [ ] **User ID reconciliation** — if vendor analytics IDs flow into Purchasely, either as `Purchasely.userLogin(sameId)` or via a `setUserAttribute("xxx_user_id", ...)` convention, the scheme must be consistent. WARNING if mixed (some events identified, others anonymous).
- [ ] **GDPR consent gated** — if the app operates in the EU, the wrapper should short-circuit forwarding until consent is granted. WARNING if events flow before consent.

---

## Step 4 — Generate the Report

Format the output as follows:

```
## Purchasely Integration Review — [Platform]

### Summary
X / Y checks passed | Z critical | W warnings

### Critical Issues (must fix before release)
1. **[FAIL] Interceptor handler does not return a result on every path** — `PaywallInterceptor.kt:45`
   The catch block on line 45 returns without producing an intercept result. On v6 every branch of the handler must return `success` / `failed` / `notHandled` (native: `PLYInterceptResult.*`; Flutter: `InterceptResult.*`; React Native: the string `'success'` / `'failed'` / `'notHandled'`; Cordova: `Purchasely.InterceptResult.*`).
   **Fix:** Return `PLYInterceptResult.FAILED` from the catch block (Flutter: `return InterceptResult.failed;`; React Native: `return 'failed';`).

### Warnings (should fix)
1. **[WARNING] API key hardcoded** — `AppDelegate.swift:12`
   ...

### Suggestions (nice to have)
1. ...

### Passed Checks
- [PASS] SDK initialized in AppDelegate
- [PASS] v6 presentation builder used (no removed `fetchPresentation`/`presentationView`)
- ...
```

For each critical issue and warning, include:
- The exact file path and line number
- A clear explanation of what is wrong and why it matters
- A concrete code fix (show the before/after or the exact code to add)

---

## Step 5 — Auto-Fix Option

After presenting the report, ask the user:

> "Would you like me to apply the fixes for the critical issues and warnings automatically?"

If the user agrees:
1. Apply fixes in order of severity (critical first, then warnings)
2. Show a diff summary of each change
3. Re-run the relevant checklist items to confirm the fixes are correct
4. Do NOT fix "suggestions" unless explicitly asked

If the user declines, end the review with the report.

## Completion Build Gate

Before returning a final review status, build the user's app with the project's canonical command (prefer the existing CI/build script). If the build fails, fix the error when it is within the Purchasely integration/review scope, rerun the build, and run relevant tests again until the app builds successfully. If the failure is clearly unrelated to Purchasely and outside the user's requested scope, report it as a blocking build failure instead of claiming the review is complete.

When auto-fixes were applied, this gate is mandatory: do not stop after checklist re-validation. Include the exact build/test commands and outcomes in the final response.
