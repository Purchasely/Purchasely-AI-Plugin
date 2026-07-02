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
- `../../references/concepts/paywall-actions.md` — interceptor rules + every code path must call `proceed/processAction`
- `../../references/concepts/presentation-types.md` — `NORMAL` / `FALLBACK` / `DEACTIVATED` / `CLIENT` guard
- `../../references/concepts/presentation-cache.md` — preload pattern + when to invalidate
- `../../references/concepts/observer-mode-post-purchase.md` — `proceed/processAction → dismiss` ordering
- `../../references/concepts/programmatic-purchases.md` — exact app-side purchase APIs by platform
- `../../references/concepts/user-attributes-targeting.md` — attributes for audiences
- `../../references/concepts/privacy-settings.md` — `revokeDataProcessingConsent`, privacy purposes, essential/optional processing
- `../../references/concepts/user-identity.md` — `userLogin` / `userLogout` timing, anonymous→logged-in merge, foreground resync
- `../../references/concepts/subscription-checks.md` — gating + restore purchases
- `../../references/concepts/subscription-management.md` — native Manage Subscription entry point (App Store / Play)
- `../../references/concepts/promotional-offers.md` — offers eligibility responsibility + implementation
- `../../references/concepts/campaigns.md` — deeplink display flag (`readyToOpenDeeplink` on v5 Cordova; renamed `allowDeeplink` on v6 — native iOS/Android, Flutter and React Native; default `true` on native v6, `false` on React Native) + SDK ≥ 5.1.0
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

- Confirm the SDK generation used for each finding: React Native uses v6 (`6.0.0-rc.2`); native iOS / native Android / Flutter use v6 (`6.0.0-rc.1`); Cordova uses v5 (`5.7.3`).
- Confirm version findings compare against `../../references/sdk-versions.md`.
- Confirm Full-vs-Observer findings account for the v6 default running mode change.
- Confirm removed/deprecated API findings are platform-specific and do not flag valid v5 Cordova APIs (React Native is now on the v6 API).
- Confirm presentation findings distinguish full-screen display from explicit embedded/nested rendering.
- Confirm interceptor findings prove every branch resolves exactly once.
- Confirm Observer-mode findings include `synchronize()` and the correct platform dismissal API.
- Confirm each finding cites file/line evidence and is not based on a guessed signature.

Only keep findings that remain supported after this expert check, unless you explicitly document a reasoned disagreement.

---

## Step 2 — Search for Purchasely-Related Code

Search the entire codebase using these patterns to build a map of all Purchasely touchpoints:

**Initialization patterns:**
- Native v6: `Purchasely.apiKey(` (iOS fluent builder) / `Purchasely {` DSL or `Purchasely.Builder(` (Android) / `.runningMode(` / `.start(`
- Flutter v6: `PurchaselyBuilder.apiKey(` / `.runningMode(` / `RunningMode.full` / `.storekitVersion(` / `.start()`
- React Native v6: `Purchasely.builder(` / `.runningMode('full')` / `.storekitVersion('storeKit2')` / `.stores([` / `.start()`
- Cordova / v5: `Purchasely.start` / `Purchasely.start(` / `withAPIKey`
- `PLYAlertMessage` / `PLYUIHandler`
- `apiKey` / `PLY_API_KEY`

**Paywall patterns:**
- Native v6: `PLYPresentationBuilder` / `PLYPresentation {` / `.forPlacementId` / `.forScreenId` / `.build()` / `.preload(` / `buildView(` / `getFragment(` / `swiftUIView` / `screenId`
- Flutter v6: `PresentationBuilder.placement(` / `.screen(` / `.defaultSource()` / `.build()` / `.preload()` / `.display(` / `Transition.fullScreen()` / `PLYPresentationView(`
- React Native v6: `Purchasely.presentation.placement(` / `.screen(` / `.default()` / `.build()` / `.preload()` / `.display(` / `PLYPresentationView`
- v5 / removed (flag if present on native, Flutter v6, or React Native v6): `fetchPresentation` / `presentationView` / `presentationController` / `presentPresentation` / `presentPresentationForPlacement` / `presentPresentationWithIdentifier`
- Cordova v5: `fetchPresentation` / `presentPresentation`
- `PLYPresentation` / `PLYPresentationAction`
- `clientPresentation` / `showPresentation`

**Interceptor patterns:**
- Native v6: `interceptAction` / `PLYInterceptResult` / `PLYInterceptorInfo`
- Flutter v6: `Purchasely.interceptAction(` / `PresentationActionKind.` / `InterceptResult.success` / `.failed` / `.notHandled` / `removeInterceptor` / `removeAllInterceptors`
- React Native v6: `Purchasely.interceptAction('purchase'` / `'login'` / `'navigate'` / handler returning `'success'` / `'failed'` / `'notHandled'` / `removeActionInterceptor` / `removeAllActionInterceptors`
- v5 / removed (flag if present on native, Flutter v6, or React Native v6): `setPaywallActionsInterceptor` / `setPaywallActionInterceptor` / `setPaywallActionInterceptorCallback` / `onProcessAction`
- Cordova v5: `setPaywallActionInterceptor` / `onProcessAction`
- `processAction` / `proceed` / `closePresentation` / `closeAllScreens`
- `PLYPresentationAction`

**Programmatic purchase patterns:**
- `purchaseWithPlanVendorId` / `Purchasely.purchase(` / `planWithIdentifier`

**Deeplink patterns:**
- Native v6 + Flutter v6: `handleDeeplink` / `allowDeeplink`
- React Native v6: `Purchasely.handleDeeplink(` (renamed from v5 `isDeeplinkHandled`) / `.allowDeeplink(` (builder modifier, default `false`)
- v5 (Cordova) / deprecated alias (flag if `readyToOpenDeeplink` is used as the primary name on native or Flutter v6): `isDeeplinkHandled` / `readyToOpenDeeplink`
- `setDefaultPresentationResultHandler` / `setDefaultPresentationDismissHandler`

**User management patterns:**
- `userLogin` / `userLogout` / `setUserAttribute`
- `setAttribute` / `setAttributes`
- `revokeDataProcessingConsent` / `clearBuiltInAttributes`

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
- [ ] **Explicit running mode when purchases are validated by Purchasely** (v6 — native iOS/Android, Flutter and React Native) — ⚠️ v6 changed the default running mode from Full to **Observer**, *silently*. If the app expects Purchasely to process/validate purchases but the init does NOT set `.runningMode(.full)` (iOS) / `runningMode(PLYRunningMode.Full)` (Android) / `.runningMode(RunningMode.full)` (Flutter `PurchaselyBuilder`) / `.runningMode('full')` (React Native `Purchasely.builder`), purchases are never validated. **FAIL** if Full behavior is relied on but the mode is left at the v6 default. SKIP for genuine Observer integrations and for Cordova still on v5.
- [ ] **start() completion handled** — The completion/callback of init (`.start { error -> }` / `try await ….start()` on native v6; `await PurchaselyBuilder.…start()` on Flutter v6; `await Purchasely.builder(...).start()` (`Promise<boolean>`) on React Native v6; `Purchasely.start(...)` on Cordova v5) must be awaited or handled before calling other SDK methods like the presentation builder / `fetchPresentation`. FAIL if SDK methods are called in a fire-and-forget pattern after start.
- [ ] **Stores configured correctly** — Android must specify at least one store (`Google`, `Huawei`, `Amazon`); on Flutter v6 via `.stores([PLYStore.google])` on the `PurchaselyBuilder`; on React Native v6 via `.stores(['google'])` (strings: `'google' | 'huawei' | 'amazon'`, default `['google']`) on `Purchasely.builder`. iOS does not need store config. Cordova (v5) must pass the correct store for the target platform. WARNING if stores are missing on Android. Note (v6 — native, Flutter and React Native): a **storeless** start is valid for screens/analytics/campaigns; only flag missing stores when the app runs in Full mode and expects purchases (purchase APIs return `PLYError.NoStoreConfigured`).

### 3.2 Paywall Display

- [ ] **Uses the v6 builder/preload API** (native iOS/Android, Flutter and React Native) — Must build + preload + display: iOS `PLYPresentationBuilder.forPlacementId(_).build().preload()` → `display(from:)`; Android `PLYPresentation { placementId(...) }.preload()` → `display(context)`; Flutter `PresentationBuilder.placement(id).build()` → `PresentationRequest` then `.preload()` and/or `.display([Transition])` (resolves at dismiss with a `PresentationOutcome`); React Native `Purchasely.presentation.placement(id).build()` → `PresentationRequest` then `.preload()` and/or `.display(transition?)` (resolves at dismiss with a 5-field `PresentationOutcome`). The v5 `fetchPresentation(...)` / `presentPresentation(...)` / `presentPresentationForPlacement(...)` / `presentPresentationWithIdentifier(...)` / `presentationView(...)` / VC-returning methods are **removed** in v6 — **FAIL** if any appear in native, Flutter v6, or React Native v6 code. For embedded use: iOS `controller` / `swiftUIView`, Android `buildView(...)` wrapped in `AndroidView` for Compose (there is no `presentation-compose` artifact or native `PLYPresentationView` composable), Flutter the `PLYPresentationView(request: ...)` widget, React Native the `<PLYPresentationView>` component. For Console-direct Screens, the builder accepts `screenId(...)` / `.forScreenId(_)` / Flutter `.screen(id)` / React Native `.screen(id)`.
- [ ] **Prefers `fetchPresentation` + `presentPresentation` over `presentPresentationForPlacement`** (Cordova only — still on v5) — The pre-fetch path is what the [official docs recommend](https://docs.purchasely.com/docs/general-in-app-experiences-display#how-to-display-an-in-app-experience-associated-to-a-placement); it's the only one that correctly displays **Flows** on plugin ≤ 5.7.x (the shorthand routes Flows through the legacy single-paywall path and the user gets a modal with no close affordance). `presentPresentationForPlacement` remains acceptable for placements guaranteed to host only simple non-Flow paywalls — WARNING otherwise, and FAIL if the same code path also relies on Flow steps. SKIP on native iOS/Android, Flutter v6, and React Native v6 (use the builder check above — `fetchPresentation`/`presentPresentation*` are removed there).
- [ ] **Handles PLYPresentationType.DEACTIVATED** — When the presentation type is `.deactivated` / `DEACTIVATED`, the paywall must NOT be displayed. FAIL if this case is not handled.
- [ ] **Handles PLYPresentationType.FALLBACK** — When the type is `.fallback`, the paywall should still be displayed but the app should log a warning. WARNING if not handled.
- [ ] **Handles PLYPresentationType.CLIENT** — When the type is `.client`, the app should display its own custom paywall. WARNING if not handled (acceptable if no custom paywall exists).
- [ ] **onClose/dismiss callback implemented** — The close callback must be set so the app can dismiss the paywall view/controller. On Flutter v6 the `display([Transition])` future resolves at dismiss with a `PresentationOutcome`, and a loaded `Presentation` exposes `.close()` / `.back()` for programmatic dismissal (the builder also offers `.onCloseRequested` / `.onDismissed` callbacks) — there is no `closePresentation()` / `closeAllScreens()` in Flutter v6. On React Native v6 the `display(transition?)` promise resolves at dismiss with a `PLYPresentationOutcome`, and the held `PLYPresentationRequest` exposes `.close()` / `.back()` (builder also offers `.onCloseRequested()` / `.onDismissed()`) — there is no `closePresentation()` / `closeAllScreens()` in React Native v6. FAIL if missing (causes stuck paywalls).

### 3.3 Action Interceptor

- [ ] **Interceptor is registered** — v6 uses **per-action** registration: `Purchasely.interceptAction(.login) { … }` (iOS) / `Purchasely.interceptAction<PLYPresentationAction.Login> { … }` (Android) / `Purchasely.interceptAction(PresentationActionKind.purchase, (info, payload) async { … })` (Flutter) / `Purchasely.interceptAction('purchase', async (info, payload) => …)` (React Native) — one call per action kind you handle, typically right after init. The v5 single `setPaywallActionsInterceptor` (native) / `setPaywallActionInterceptorCallback` + `onProcessAction` (Flutter v5) / `setPaywallActionInterceptor` + `onProcessAction` (React Native v5) is **removed** on native, Flutter v6 and React Native v6 — FAIL if it appears in native, Flutter v6, or React Native v6 code. Cordova (still v5) uses the single `setPaywallActionInterceptor` + `onProcessAction`. WARNING if no interceptor is registered at all and the app needs to handle login/navigate/observer purchases.
- [ ] **Each handler returns an intercept result** (v6 — native `PLYInterceptResult`, Flutter `InterceptResult`, React Native string) — every registered handler must return `success` (app handled it, chain advances), `failed` (app tried, failed, remaining actions skipped), or `notHandled` (SDK executes the action). On Flutter the handler is `async` and must `return InterceptResult.success` / `.failed` / `.notHandled`; on React Native the `async` handler must `return 'success'` / `'failed'` / `'notHandled'` (a string). FAIL if a handler falls through without returning a result. (Mapping from v5: `onProcessAction(false)` → `success`, `onProcessAction(true)` → `notHandled`.)
- [ ] **LOGIN action handled** — On login, present the app's login flow. v6 (native + Flutter + React Native, kind `login` / `PresentationActionKind.login` / `'login'`): return `success` on success, `notHandled` to let the SDK proceed without login. Cordova (v5): call `onProcessAction(true/false)`. FAIL if the login action is ignored when the app requires authentication.
- [ ] **PURCHASE action handled** — In **Full mode**, Purchasely handles purchases automatically and auto-closes the paywall (v6 native + Flutter + React Native: return `notHandled` / `InterceptResult.notHandled` / `'notHandled'`; Cordova v5: `onProcessAction(true)`). In **Observer mode**, the app must trigger its own purchase flow (native v6: return `.success` after `synchronize()`, then dismiss with `closeAllScreens()` after the interceptor resolves — Observer mode does not auto-close; **Flutter v6**: inside the `PresentationActionKind.purchase` handler run billing → `await Purchasely.synchronize()` → `return InterceptResult.success`, then dismiss with `presentation.close()` after the handler resolves — Observer mode does not auto-close, and there is no `closeAllScreens()`/`closePresentation()` in Flutter v6; **React Native v6**: inside the `'purchase'` handler run billing → `await Purchasely.synchronize()` → `return 'success'`, then dismiss with `request.close()` on the held `PLYPresentationRequest` after the handler resolves — Observer mode does not auto-close, and there is no `closeAllScreens()`/`closePresentation()` in React Native v6; Cordova v5: `onProcessAction(false)` → `closePresentation()`). FAIL if the mode and handling are mismatched. Note: returning `notHandled` for `purchase`/`restore` in Observer mode is a no-op (logs a warning) — flag it.
- [ ] **RESTORE action handled** — Similar to purchase: Full mode auto-handles, Observer mode needs custom logic. WARNING if not explicitly handled.
- [ ] **CLOSE action handled** — The close action must dismiss the paywall. v6 (native + Flutter + React Native, kind `close` / `PresentationActionKind.close` / `'close'`): return `notHandled` to let the SDK close, or `success` if the app closes it itself (Flutter: via `presentation.close()`; React Native: via `request.close()`). Cordova (v5): `onProcessAction(true)`. FAIL if missing (users cannot close the paywall).
- [ ] **Every Cordova interceptor path calls `onProcessAction()`** (Cordova only — still v5) — every branch (early return, error catch, switch default) MUST call `onProcessAction()` or the paywall freezes. This is the #1 most common v5 cross-platform Purchasely bug. FAIL if any code path can skip it. SKIP on native v6, Flutter v6 and React Native v6 (replaced by the `PLYInterceptResult` / `InterceptResult` / string return-value check above — there is no `onProcessAction`/`processAction`/`proceed` callback). On Flutter v6 / React Native v6 the equivalent freeze risk is a handler path that never returns a result — covered by the return-value check above.
- [ ] **No double-completion** — On Cordova (v5), calling `onProcessAction()` twice is undefined; on v6 (native + Flutter + React Native), returning then mutating state after the handler resolves is a logic error. WARNING if there's a risk of double signalling.
- [ ] **No attempt to override post-purchase flow from the interceptor** — If the app holds the interceptor open, skips `proceed`, or calls `Purchasely.close()` manually to "stay on the paywall" / "show a custom thank-you screen" after a purchase, that's the wrong layer. The Composer button supports a **second action** (`purchase + open_screen` / `purchase + open_placement` / `purchase + deeplink`) and the default is *close in Full mode, stay open in Observer mode*. WARNING — recommend wiring the second action in the Console (or BYOS if the next screen is custom). See `../../references/concepts/paywall-actions.md` § Chaining multiple actions.

### 3.4 Deeplinks

- [ ] **Deeplink forwarded to the SDK** — the app must hand incoming URLs to the SDK. On **native + Flutter v6** the method is `Purchasely.handleDeeplink(...)` (rename of v5 `isDeeplinkHandled(...)`) — WARNING if the deprecated `isDeeplinkHandled` is still used (removal in v7). ⚠️ On **React Native v6** the method was **renamed** to `Purchasely.handleDeeplink(uri)` (the v5 `isDeeplinkHandled` is removed with no alias, matching native iOS/Android and Flutter) — FLAG any remaining `isDeeplinkHandled` on React Native and rewrite it to `handleDeeplink`. On **iOS** the SDK does NOT auto-intercept, so the deeplink must be wired from AppDelegate/SceneDelegate. On **Android v6** deeplinks are auto-intercepted (zero code) by reading the foreground activity intent; if the activity is `singleTask`/`singleTop`, verify `setIntent(intent)` is called in `onNewIntent` (otherwise the URI is hidden) or that a manual `handleDeeplink(uri, activity)` call exists. On **Flutter v6** the app should forward incoming links from its deeplink handling (e.g. `uni_links` / `app_links` / router) to `Purchasely.handleDeeplink(uri)` for iOS; Android still benefits from the native auto-interception. SKIP if the app doesn't support deeplinks.
- [ ] **allowDeeplink enabled** — v6 (native + Flutter + React Native) renamed the v5 `readyToOpenDeeplink` → `allowDeeplink` (set via the init builder modifier `.allowDeeplink(true)`). On native/Flutter it defaults to **true**, so usually no action is needed; on **React Native** it defaults to **false**, so the app **must** call `.allowDeeplink(true)` on the `Purchasely.builder(...)` chain if it relies on campaign/deeplink display — WARNING (FAIL with campaigns) if RN relies on deeplink display but never sets it. On Cordova (v5) the old `readyToOpenDeeplink(true)` is still required after the UI is initialized. WARNING if the deprecated `readyToOpenDeeplink` name is used as the primary call in v6 native / Flutter v6 / React Native v6 code.
- [ ] **Default presentation dismiss handler configured** — A default result/dismiss handler should be set so deeplink/campaign-triggered paywalls can report their outcome: native/Flutter `setDefaultPresentationResultHandler`; **React Native v6** `Purchasely.setDefaultPresentationDismissHandler((outcome) => …)` (returns a subscription with `.remove()`; one active handler, re-register replaces). WARNING if missing.

### 3.5 User Management

- [ ] **userLogin() called after authentication** — `Purchasely.userLogin(userId:)` must be called when the user signs in. WARNING if missing (anonymous users are fine, but logged-in users lose cross-device sync).
- [ ] **userLogin() runs BEFORE presentation build / synchronize calls that depend on audience** — race-condition check: if both happen in the same async block, verify identity is set first. FAIL if the presentation resolves (v6 native + Flutter + React Native `.preload()` / Cordova `fetchPresentation`) while still anonymous and the placement depends on logged-in audience attributes. See `../../references/concepts/user-identity.md`.
- [ ] **userLogout() called on sign out** — `Purchasely.userLogout()` must be called when the user signs out. WARNING if missing (stale user data).
- [ ] **Foreground resync** — `Purchasely.synchronize()` should be called from `applicationDidBecomeActive` (iOS), `ProcessLifecycleOwner` `ON_START` (Android), `AppState 'active'` (RN), `didChangeAppLifecycleState(.resumed)` (Flutter), or the `resume` event (Cordova). WARNING if missing — renewals or cancellations that happen while the app is backgrounded won't reflect in the client until the user re-opens. SKIP if running in Full mode AND the user never backgrounds the app for >1 day. Note (Flutter v6 + React Native v6): `synchronize()` is no longer fire-and-forget — it now **resolves on completion** (`Promise<boolean>` on RN, `Future<void>` on Flutter) and **rejects/throws on failure**, so `await` it (optionally wrap in `try/catch`) before chaining a follow-up presentation that targets subscribers.
- [ ] **User attributes set** — If the app uses audience targeting, `setUserAttribute` should be called with relevant attributes. SKIP if audience targeting is not used.
- [ ] **Restore Purchases entry point** — Apple **requires** a Restore button reachable outside the paywall (Settings / Account) for App Store review. CRITICAL: **check the Purchasely paywall first** — if the Console operator has enabled the in-paywall Restore button on every relevant screen, an app-side button is duplicate work. If neither the paywall nor an app-side button exists, FAIL (App Store rejection risk). If only an app-side button exists but the paywall could also expose one, WARNING — confirm with the user / Console operator. See `../../references/concepts/subscription-checks.md`.
- [ ] **Manage Subscription entry point** — both stores require an in-app link to native subscription management. WARNING if missing from Settings / Account. See `../../references/concepts/subscription-management.md`. Note (v6 — native, Flutter and React Native): the built-in subscriptions screen was **removed**. `Purchasely.presentSubscriptions()` is **removed entirely** from Flutter v6 **and React Native v6** (it is NOT a no-op — the method no longer exists) — FAIL if it still appears in Flutter v6 or React Native v6 code; build your own screen from `userSubscriptions()` / `userSubscriptionsHistory()`. `Purchasely.displaySubscriptionCancellationInstruction()` is kept for source-compat but is a **no-op** on the native platforms.

### 3.6 Architecture (If a wrapper class exists)

If the project routes its Purchasely SDK calls through a single dedicated class — whatever its name (`PurchaselyWrapper`, `PurchaselyService`, `IAPManager`, …) — verify these recommended patterns. SKIP this entire section if there is no such class — do NOT suggest adding one unless the user asks.

- [ ] **SDK calls go through wrapper** — Search for direct Purchasely SDK calls outside the wrapper: init (`Purchasely.apiKey(`/`Purchasely {`/`PurchaselyBuilder.apiKey(`/`Purchasely.builder(`/`Purchasely.start`), presentation build (`PLYPresentationBuilder`/`PLYPresentation {`/`PresentationBuilder.`/`Purchasely.presentation.`/`fetchPresentation`), interceptor registration (`Purchasely.interceptAction`/`setPaywallActionInterceptor`). WARNING if the SDK is called directly from UI code alongside a wrapper.
- [ ] **Screens have zero SDK imports** — `import Purchasely` / `import io.purchasely` should not appear in ViewModel/Screen files. WARNING if found.
- [ ] **Observer mode billing decoupled** — If using Observer mode with a wrapper, check that the native PurchaseManager does NOT import the SDK. WARNING if it directly calls `synchronize()` or references the wrapper.
- [ ] **Wrapper owns init and interceptor** — init (`start()`) and the action interceptor registration (`Purchasely.interceptAction(...)` on v6 — native, Flutter and React Native; `setPaywallActionInterceptor` on Cordova v5) should be in the wrapper, not scattered. WARNING if init logic is outside.
- [ ] **Testable wrapper** — iOS: protocol for mocking. Android: DI-injectable. WARNING if not mockable.

See `../../references/architecture-patterns.md` for recommended patterns and improvements to suggest.

### 3.7 Production Readiness

- [ ] **SDK version is current** — Compare the pinned version against `../../references/sdk-versions.md` (**React Native** on **6.0.0-rc.2**; native iOS and Android and **Flutter** on **6.0.0-rc.1**; Cordova on 5.7.3). FAIL if older than minimum, WARNING if not at latest. FAIL if a floating version (`5.+`, `6.+`, `^5.0.0`, `~> 6.0`, `from:`/Up-to-Next-Major, `^6.0.0-rc.2`, etc.) is used instead of an exact pin. Because these v6 versions are pre-releases, they must be pinned exactly on every layer — iOS CocoaPods `pod 'Purchasely', '6.0.0-rc.1'`, SPM `exact: "6.0.0-rc.1"`, Carthage `== 6.0.0-rc.1`; Android `io.purchasely:core:6.0.0-rc.1`; **Flutter** `purchasely_flutter: 6.0.0-rc.1` (and `purchasely_google` / `purchasely_android_player` at the same `6.0.0-rc.1`, never `^`/`>=`); **React Native** `react-native-purchasely: 6.0.0-rc.2` (and `@purchasely/react-native-purchasely-google` / `-android-player` / `-amazon` / `-huawei` at the same `6.0.0-rc.2`, never `^`/`>=`), which pull native iOS `Purchasely 6.0.0-rc.2` and Android `io.purchasely:core 6.0.0-rc.2`.
- [ ] **Plugin packages aligned** (cross-platform only) — All `@purchasely/cordova-plugin-*` (5.x.y on Cordova) packages MUST be the same version; on **Flutter** all `purchasely_*` packages (`purchasely_flutter`, `purchasely_google`, `purchasely_android_player`) MUST be the same `6.0.0-rc.1`; on **React Native** all `react-native-purchasely*` packages (`react-native-purchasely`, `@purchasely/react-native-purchasely-google` / `-android-player` / `-amazon` / `-huawei`) MUST be the same `6.0.0-rc.2`. FAIL if mismatched.
- [ ] **ProGuard/R8 rules added** (Android only) — `proguard-rules.pro` must include Purchasely keep rules or the dependency must use `consumerProguardFiles`. WARNING if missing.
- [ ] **No removed / deprecated APIs** — Native v6 **removed**: `setPaywallActionsInterceptor`, `fetchPresentation` (native), `presentationView(for:)`/`presentationViewControllerFor`/`presentationController`, `subscriptionsFragment()` and all `PLYSubscriptions*`/`PLYSubscriptionCancellation*` UI, `purchaseHistory()` (→ `userSubscriptionsHistory()`), `isPastSubscriber()`, the `intro*`/`introductory*` plan methods and `PLYPlanTags.INTRO_PRICE`/`TRIAL_PRICE` (→ `offer*` / `PLYPlanTags.OFFER_PRICE`), `PLYPresentationInfo` (→ `PLYInterceptorInfo`), and — **Android only** — `PLYPresentationActionParameters` (Android replaced it with typed action subclasses; **iOS retains** `PLYPresentationActionParameters` as the interceptor `params`, so do not flag it on iOS). **FAIL** for each occurrence in native code (it won't compile against v6). Native v6 **deprecated** (removal v7): `readyToOpenDeeplink` (→ `allowDeeplink`), `isDeeplinkHandled` (→ `handleDeeplink`), pre-`start` class funcs like `setEnvironment`/`setThemeMode` (→ builder modifiers) — WARNING for each.
  - **Flutter v6 removed** (FAIL — the Dart symbol no longer exists): `Purchasely.start(...)` (→ `PurchaselyBuilder.apiKey(...).…start()`), `fetchPresentation` / `presentPresentation` / `presentPresentationForPlacement` / `presentPresentationWithIdentifier` / `presentProductWithIdentifier` / `presentPlanWithIdentifier` / `getPresentationView` (→ `PresentationBuilder` + `PresentationRequest` / `PLYPresentationView`), `closePresentation()` / `hidePresentation()` / `showPresentation()` / `closeAllScreens()` (→ `presentation.close()` / `.display()` / `.back()`), `setPaywallActionInterceptorCallback` + `onProcessAction` (→ `Purchasely.interceptAction(kind, handler)` returning `InterceptResult`), and `presentSubscriptions()` (no replacement — build your own from `userSubscriptions()` / `userSubscriptionsHistory()`). **Flutter v6 deprecated aliases** (WARNING): `readyToOpenDeeplink` (→ `allowDeeplink`), `isDeeplinkHandled` (→ `handleDeeplink`), and the `intro*` plan fields (→ `offer*`). `displaySubscriptionCancellationInstruction()` is kept but is a **no-op**.
  - **React Native v6 removed** (FAIL — the JS symbol no longer exists): the whole v5 paywall API — `Purchasely.start({...})` / `startWithAPIKey` (→ `Purchasely.builder('key')….start()`), `fetchPresentation` / `presentPresentation` / `presentPresentationForPlacement` / `presentPresentationWithIdentifier` / `presentProductWithIdentifier` / `presentPlanWithIdentifier` (→ `Purchasely.presentation.placement(id)` / `.screen(id)` / `.defaultSource()` + `PLYPresentationRequest`), `showPresentation()` / `hidePresentation()` / `closePresentation()` (→ `request.display()` / `request.close()` / `request.back()`), `setPaywallActionInterceptorCallback` + `onProcessAction` (→ `Purchasely.interceptAction(kind, handler)` returning the string `'success' | 'failed' | 'notHandled'`), `setDefaultPresentationResultCallback` / `setDefaultPresentationResultHandler` (→ `setDefaultPresentationDismissHandler`), `readyToOpenDeeplink` (→ the builder modifier `.allowDeeplink(true)`), **`isDeeplinkHandled(uri)` (→ `handleDeeplink(uri)` — renamed, no alias; FLAG it)**, `presentSubscriptions()` / `displaySubscriptionCancellationInstruction()` / `clientPresentationDisplayed` / `clientPresentationClosed` (**no replacement** — build your own from `userSubscriptions()` / `userSubscriptionsHistory()`; they are NOT no-ops, the methods no longer exist), the `PLYPaywallAction` enum, and the `RunningMode.TRANSACTION_ONLY` / `PAYWALL_OBSERVER` values. `synchronize()` is now awaitable (`Promise<boolean>`). `closeReason` values are `'button' | 'backSystem' | 'programmatic'` (no `interactiveDismiss`). The embedded `PLYPresentationView` component remains (now also accepts a preloaded `request` prop).
- [ ] **Error handling around presentation build** — The presentation can fail (network error, invalid placement). The error/failure case must be handled gracefully: native v6 `.preload { loaded, error -> }` / `.preload()` throwing; **Flutter v6** the `display([Transition])` future's `PresentationOutcome.error` (and `try/catch` around `.preload()` / `.display()`); **React Native v6** the `display(transition?)` promise's `PLYPresentationOutcome.error` (and `try/catch` around `.preload()` / `.display()`); Cordova v5 the `fetchPresentation` completion. FAIL if errors are silently ignored. Map known `PLYError` cases (see `../../references/troubleshooting/error-codes.md`) when surfacing failure to the user.
- [ ] **`PrivacyInfo.xcprivacy` present** (iOS only, builds against Xcode 15+ / iOS 17 SDK) — Apple requires a Privacy Manifest declaring the app's required reason API usage, third-party SDKs, and tracking domains. The Purchasely SDK ships its own `PrivacyInfo.xcprivacy` for its data collection. WARNING if the **app's** root `PrivacyInfo.xcprivacy` is missing — App Store Connect rejects submissions without it since May 2024.
- [ ] **Google Play Billing v8 awareness** (Android only) — If the project pins `com.android.billingclient:billing` (non-KTX) ≥ 8.x while Purchasely uses `billing-ktx`, prices can hang on `queryProductDetails()`. WARNING — recommend `com.android.billingclient:billing-ktx` and/or a Gradle `resolutionStrategy.force(...)`. See `../../references/troubleshooting/error-codes.md` § Google Play Billing v8.
- [ ] **`LogLevel.DEBUG` not shipped in release** — Confirm that `LogLevel.DEBUG` is gated behind a build flag (`#if DEBUG`, `BuildConfig.DEBUG`, `__DEV__`, etc.). WARNING if always-on. Debug logs leak placement IDs, audience matches, and presentation IDs.
- [ ] **Suggest real device testing** — Always recommend testing on a real device with a sandbox/test account, as simulators cannot process real purchases. See `../../references/testing/README.md` for Sandbox Apple ID and Play License Tester setup.

### 3.8 Observer Mode Post-Purchase (if Observer mode is detected)

- [ ] **Correct ordering** — Native iOS/Android v6: inside the `.purchase` interceptor, run billing → `synchronize()` → **return `PLYInterceptResult.SUCCESS`** (there is no `proceed`/`processAction` callback), then **dismiss with `Purchasely.closeAllScreens()`** from your billing-result handler **after** the interceptor has resolved. **Flutter v6**: inside the `PresentationActionKind.purchase` handler, run billing → `await Purchasely.synchronize()` → **`return InterceptResult.success`** (there is no `onProcessAction`), then dismiss with **`presentation.close()`** after the handler resolves (there is no `closeAllScreens()` / `closePresentation()` in Flutter v6). **React Native v6**: inside the `'purchase'` handler, run billing → `await Purchasely.synchronize()` → **`return 'success'`** (there is no `onProcessAction`), then dismiss with **`request.close()`** on the held `PLYPresentationRequest` after the handler resolves (there is no `closeAllScreens()` / `closePresentation()` in React Native v6). Observer mode does **not** auto-close after a purchase/restore (the implicit `close_all` is Full-only) — the dismissal is the app's job unless a `close` / `close_all` action is wired on the button in the Console. Do **not** call the dismiss inside the interceptor/handler closure before returning the result — that races the SDK (WARNING). Cordova (v5): `synchronize()` → `onProcessAction(false)` → `closePresentation()`, in that order — FAIL if reversed. See `../../references/concepts/observer-mode-post-purchase.md`.
- [ ] **Correct dismiss API** — native iOS/Android v6 should resolve the interceptor with a successful `PLYInterceptResult` and then dismiss with `closeAllScreens()` (not `closeDisplayedPresentation()`, which was renamed), since Observer mode does not auto-close. **Flutter v6** should resolve the handler with `InterceptResult.success` and then dismiss the loaded `Presentation` with `presentation.close()` — `closePresentation()` / `closeAllScreens()` no longer exist in Flutter v6. **React Native v6** should resolve the handler with `'success'` and then dismiss the held `PLYPresentationRequest` with `request.close()` — `closePresentation()` / `closeAllScreens()` no longer exist in React Native v6. Cordova (v5) should use `closePresentation()` unless the app added a custom native bridge. WARNING if the older or wrong-platform API is used, or if no dismissal happens in Observer mode and no Console `close` action is configured.
- [ ] **iOS `@MainActor` wrap** (iOS only) — when calling `closeAllScreens()` from a non-isolated context (inside a `synchronize` callback or `DispatchQueue.main.async`), it must be wrapped in `Task { @MainActor in ... }`. FAIL if missing on iOS v6 (`closeAllScreens()` is `@MainActor`-isolated).

### 3.9 Campaigns (if Campaigns are used in the Console)

SKIP this entire section if the project doesn't use Campaigns. To detect: ask the user, or check Purchasely Console → Campaigns. Otherwise:

- [ ] **SDK ≥ 5.1.0** — minimum version required for Campaigns. FAIL if pinned below.
- [ ] **Deeplink display enabled** — trigger-based campaigns are delivered through deeplinks. v6 (native + Flutter): `allowDeeplink` defaults to **true**, so usually no action is needed; FAIL only if the app sets `allowDeeplink(false)`, and on Android verify the auto-interception isn't broken (e.g. `singleTask` activity missing `setIntent(intent)`). On Flutter v6, also ensure incoming deeplinks reach `Purchasely.handleDeeplink(uri)` on iOS (Android auto-intercepts). **React Native v6**: `allowDeeplink` defaults to **false**, so `.allowDeeplink(true)` must be set on the `Purchasely.builder(...)` chain — FAIL if missing while campaigns are used; also forward incoming deeplinks to `Purchasely.handleDeeplink(uri)` (renamed from v5 `isDeeplinkHandled`) on iOS (Android auto-intercepts). Cordova (v5): `Purchasely.readyToOpenDeeplink(true)` must be called once after the splash/launch routine completes — FAIL if missing, WARNING if called inside the `start()` callback (the campaign paywall lands on top of the splash).
- [ ] **UI Handler keeps the returned presentation object** (if used) — refetching the presentation loses campaign context (audience match, screen variant, exposure tracking). WARNING if the handler refetches.

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
   The catch block on line 45 returns without producing a `PLYInterceptResult`. On v6 (native + Flutter + React Native) every branch of the handler must return `success` / `failed` / `notHandled` (Flutter: `InterceptResult.*`; React Native: the string `'success'` / `'failed'` / `'notHandled'`). (On Cordova v5 the equivalent bug is a path that never calls `onProcessAction()`, which freezes the paywall.)
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
