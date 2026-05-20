---
name: review
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
- `../../references/concepts/campaigns.md` — `readyToOpenDeeplink` + SDK ≥ 5.1.0
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

Before returning review findings, invoke the `Task` tool with `subagent_type: "purchasely:sdk-expert"` and ask it to sanity-check the review reasoning. Pass the detected platform(s), SDK versions, running mode, key code paths inspected, candidate findings, and the evidence for each finding. Only keep findings that remain supported after this expert check, unless you explicitly document a reasoned disagreement.

---

## Step 2 — Search for Purchasely-Related Code

Search the entire codebase using these patterns to build a map of all Purchasely touchpoints:

**Initialization patterns:**
- `Purchasely.start` / `Purchasely.Builder` / `Purchasely.start(`
- `PLYAlertMessage` / `PLYUIHandler`
- `withAPIKey` / `apiKey` / `PLY_API_KEY`

**Paywall patterns:**
- `fetchPresentation` / `presentationView` / `presentationController`
- `PLYPresentation` / `PLYPresentationAction`
- `clientPresentation` / `showPresentation`

**Interceptor patterns:**
- `setPaywallActionsInterceptor` / `interceptAction`
- `processAction` / `proceed` / `closePresentation`
- `PLYPresentationAction`

**Programmatic purchase patterns:**
- `purchaseWithPlanVendorId` / `Purchasely.purchase(` / `planWithIdentifier`

**Deeplink patterns:**
- `isDeeplinkHandled` / `handleDeeplink` / `readyToOpenDeeplink`
- `setDefaultPresentationResultHandler`

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
- [ ] **start() completion handled** — The completion/callback of `Purchasely.start()` must be awaited or handled before calling other SDK methods like `fetchPresentation`. FAIL if SDK methods are called in a fire-and-forget pattern after start.
- [ ] **Stores configured correctly** — Android must specify at least one store (`Google`, `Huawei`, `Amazon`). iOS does not need store config. Cross-platform SDKs must pass the correct store for the target platform. WARNING if stores are missing on Android.

### 3.2 Paywall Display

- [ ] **Uses fetchPresentation()** — Must use `fetchPresentation` (or platform equivalent), NOT the deprecated `presentationView` / `presentationController` / `presentationViewControllerFor`. WARNING if deprecated methods are used.
- [ ] **Prefers `fetchPresentation` + `presentPresentation` over `presentPresentationForPlacement`** (Flutter / React Native / Cordova only) — The pre-fetch path is what the [official docs recommend](https://docs.purchasely.com/docs/general-in-app-experiences-display#how-to-display-an-in-app-experience-associated-to-a-placement); it's the only one that correctly displays **Flows** on plugin ≤ 5.7.x (the shorthand routes Flows through the legacy single-paywall path and the user gets a modal with no close affordance). `presentPresentationForPlacement` remains acceptable for placements guaranteed to host only simple non-Flow paywalls — WARNING otherwise, and FAIL if the same code path also relies on Flow steps.
- [ ] **Handles PLYPresentationType.DEACTIVATED** — When the presentation type is `.deactivated` / `DEACTIVATED`, the paywall must NOT be displayed. FAIL if this case is not handled.
- [ ] **Handles PLYPresentationType.FALLBACK** — When the type is `.fallback`, the paywall should still be displayed but the app should log a warning. WARNING if not handled.
- [ ] **Handles PLYPresentationType.CLIENT** — When the type is `.client`, the app should display its own custom paywall. WARNING if not handled (acceptable if no custom paywall exists).
- [ ] **onClose/dismiss callback implemented** — The close callback must be set so the app can dismiss the paywall view/controller. FAIL if missing (causes stuck paywalls).

### 3.3 Action Interceptor

- [ ] **Interceptor is registered** — `setPaywallActionsInterceptor` (v5) or equivalent must be called, typically right after SDK initialization. WARNING if missing entirely.
- [ ] **LOGIN action handled** — When the action is `.login` / `LOGIN`, the app must present its login flow, then call `processAction(true)` on success or `processAction(false)` on cancel. FAIL if login action is ignored.
- [ ] **PURCHASE action handled** — In **Full mode**, Purchasely handles purchases automatically; the interceptor should call `processAction(true)`. In **Observer mode**, the app must trigger its own purchase flow. FAIL if the mode and handling are mismatched.
- [ ] **RESTORE action handled** — Similar to purchase: Full mode auto-handles, Observer mode needs custom logic. WARNING if not explicitly handled.
- [ ] **CLOSE action handled** — The close action must dismiss the paywall and call `processAction(true)`. FAIL if missing (users cannot close the paywall).
- [ ] **processAction() ALWAYS called** — Every code path through the interceptor MUST call `processAction()` / `proceed()`. If any branch (early return, error catch, switch default) skips it, the paywall UI will freeze permanently. This is the #1 most common Purchasely bug. FAIL if any code path can skip it.
- [ ] **No double calls to processAction()** — Calling `processAction()` twice causes undefined behavior. WARNING if there's a risk of double invocation.

### 3.4 Deeplinks

- [ ] **handleDeeplink() called** — `Purchasely.handleDeeplink()` (or `handle(deeplink:)`) must be called when the app receives a URL. WARNING if the deprecated `isDeeplinkHandled()` is used instead. SKIP if the app doesn't support deeplinks.
- [ ] **readyToOpenDeeplink set to true** — `Purchasely.readyToOpenDeeplink = true` (or `allowDeepLinkNavigation`) must be called after the app's UI is fully initialized (e.g., after the root view controller is set). WARNING if set too early (in start callback) or never set.
- [ ] **setDefaultPresentationResultHandler configured** — A default result handler should be set so deeplink-triggered paywalls can report their outcome. WARNING if missing.

### 3.5 User Management

- [ ] **userLogin() called after authentication** — `Purchasely.userLogin(userId:)` must be called when the user signs in. WARNING if missing (anonymous users are fine, but logged-in users lose cross-device sync).
- [ ] **userLogin() runs BEFORE fetchPresentation / synchronize calls that depend on audience** — race-condition check: if both happen in the same async block, verify identity is set first. FAIL if `fetchPresentation` resolves while still anonymous and the placement depends on logged-in audience attributes. See `../../references/concepts/user-identity.md`.
- [ ] **userLogout() called on sign out** — `Purchasely.userLogout()` must be called when the user signs out. WARNING if missing (stale user data).
- [ ] **Foreground resync** — `Purchasely.synchronize()` should be called from `applicationDidBecomeActive` (iOS), `ProcessLifecycleOwner` `ON_START` (Android), `AppState 'active'` (RN), `didChangeAppLifecycleState(.resumed)` (Flutter), or the `resume` event (Cordova). WARNING if missing — renewals or cancellations that happen while the app is backgrounded won't reflect in the client until the user re-opens. SKIP if running in Full mode AND the user never backgrounds the app for >1 day.
- [ ] **User attributes set** — If the app uses audience targeting, `setUserAttribute` should be called with relevant attributes. SKIP if audience targeting is not used.
- [ ] **Restore Purchases entry point** — Apple **requires** a Restore button reachable outside the paywall (Settings / Account) for App Store review. CRITICAL: **check the Purchasely paywall first** — if the Console operator has enabled the in-paywall Restore button on every relevant screen, an app-side button is duplicate work. If neither the paywall nor an app-side button exists, FAIL (App Store rejection risk). If only an app-side button exists but the paywall could also expose one, WARNING — confirm with the user / Console operator. See `../../references/concepts/subscription-checks.md`.
- [ ] **Manage Subscription entry point** — both stores require an in-app link to native subscription management. WARNING if missing from Settings / Account. See `../../references/concepts/subscription-management.md`.

### 3.6 Architecture (If a wrapper class exists)

If the project routes its Purchasely SDK calls through a single dedicated class — whatever its name (`PurchaselyWrapper`, `PurchaselyService`, `IAPManager`, …) — verify these recommended patterns. SKIP this entire section if there is no such class — do NOT suggest adding one unless the user asks.

- [ ] **SDK calls go through wrapper** — Search for direct `Purchasely.start`, `Purchasely.fetchPresentation`, `Purchasely.setPaywallActionsInterceptor` calls outside the wrapper. WARNING if SDK is called directly from UI code alongside a wrapper.
- [ ] **Screens have zero SDK imports** — `import Purchasely` / `import io.purchasely` should not appear in ViewModel/Screen files. WARNING if found.
- [ ] **Observer mode billing decoupled** — If using Observer mode with a wrapper, check that the native PurchaseManager does NOT import the SDK. WARNING if it directly calls `synchronize()` or references the wrapper.
- [ ] **Wrapper owns init and interceptor** — `start()` and `setPaywallActionsInterceptor` should be in the wrapper, not scattered. WARNING if init logic is outside.
- [ ] **Testable wrapper** — iOS: protocol for mocking. Android: DI-injectable. WARNING if not mockable.

See `../../references/architecture-patterns.md` for recommended patterns and improvements to suggest.

### 3.7 Production Readiness

- [ ] **SDK version is current** — Compare the pinned version against `../../references/sdk-versions.md` (iOS 5.7.5, Android 5.7.4, RN/Flutter/Cordova 5.7.3). FAIL if older than minimum, WARNING if not at latest. FAIL if a floating version (`5.+`, `^5.0.0`, etc.) is used instead of an exact pin.
- [ ] **Plugin packages aligned** (cross-platform only) — All `react-native-purchasely*`, `purchasely_*`, or `@purchasely/cordova-plugin-*` packages MUST be the same `5.x.y`. FAIL if mismatched.
- [ ] **ProGuard/R8 rules added** (Android only) — `proguard-rules.pro` must include Purchasely keep rules or the dependency must use `consumerProguardFiles`. WARNING if missing.
- [ ] **No deprecated methods** — Flag any use of deprecated Purchasely APIs: `presentationViewControllerFor`, `presentationView(for:)`, `isDeeplinkHandled`, `productViewControllerFor`, `planViewControllerFor`, `subscriptionViewController`. WARNING for each occurrence.
- [ ] **Error handling around fetchPresentation** — `fetchPresentation` can fail (network error, invalid placement). The error/failure case must be handled gracefully. FAIL if errors are silently ignored. Map known `PLYError` cases (see `../../references/troubleshooting/error-codes.md`) when surfacing failure to the user.
- [ ] **`PrivacyInfo.xcprivacy` present** (iOS only, builds against Xcode 15+ / iOS 17 SDK) — Apple requires a Privacy Manifest declaring the app's required reason API usage, third-party SDKs, and tracking domains. The Purchasely SDK ships its own `PrivacyInfo.xcprivacy` for its data collection. WARNING if the **app's** root `PrivacyInfo.xcprivacy` is missing — App Store Connect rejects submissions without it since May 2024.
- [ ] **Google Play Billing v8 awareness** (Android only) — If the project pins `com.android.billingclient:billing` (non-KTX) ≥ 8.x while Purchasely uses `billing-ktx`, prices can hang on `queryProductDetails()`. WARNING — recommend `com.android.billingclient:billing-ktx` and/or a Gradle `resolutionStrategy.force(...)`. See `../../references/troubleshooting/error-codes.md` § Google Play Billing v8.
- [ ] **`LogLevel.DEBUG` not shipped in release** — Confirm that `LogLevel.DEBUG` is gated behind a build flag (`#if DEBUG`, `BuildConfig.DEBUG`, `__DEV__`, etc.). WARNING if always-on. Debug logs leak placement IDs, audience matches, and presentation IDs.
- [ ] **Suggest real device testing** — Always recommend testing on a real device with a sandbox/test account, as simulators cannot process real purchases. See `../../references/testing/README.md` for Sandbox Apple ID and Play License Tester setup.

### 3.8 Observer Mode Post-Purchase (if Observer mode is detected)

- [ ] **Correct ordering** — Code must call `synchronize()` → `proceed/processAction(false)` → dismiss in this order. Native iOS/Android dismiss with `closeAllScreens()`; React Native / Flutter / Cordova public bridges dismiss with `closePresentation()`. FAIL if reversed. See `../../references/concepts/observer-mode-post-purchase.md`.
- [ ] **Correct dismiss API** — native iOS/Android should use `closeAllScreens()` (not `closeDisplayedPresentation()`); React Native / Flutter / Cordova should use `closePresentation()` unless the app added a custom native bridge. WARNING if the older or wrong-platform API is used.
- [ ] **iOS `@MainActor` wrap** (iOS only) — when calling `closeAllScreens()` from a non-isolated context (inside `synchronize` callback or `DispatchQueue.main.async`), it must be wrapped in `Task { @MainActor in ... }`. FAIL if missing on iOS 5.7.5+.

### 3.9 Campaigns (if Campaigns are used in the Console)

SKIP this entire section if the project doesn't use Campaigns. To detect: ask the user, or check Purchasely Console → Campaigns. Otherwise:

- [ ] **SDK ≥ 5.1.0** — minimum version required for Campaigns. FAIL if pinned below.
- [ ] **`Purchasely.readyToOpenDeeplink(true)` called once after the splash/launch routine completes** — trigger-based campaigns won't display without it. FAIL if missing. WARNING if called inside the `start()` callback (the campaign paywall lands on top of the splash).
- [ ] **UI Handler keeps the returned presentation object** (if used) — refetching the presentation loses campaign context (audience match, screen variant, exposure tracking). WARNING if the handler refetches.

### 3.10 Promotional Offers (if promo offers / offer codes are used)

SKIP if the app does not surface promotional offers, developer-determined offers, or offer codes. Otherwise:

- [ ] **SDK ≥ 4.0.0** — required for promotional offer purchase APIs.
- [ ] **Eligibility audiences defined** — Apple promotional offers and Google developer-determined offers are **your** responsibility to gate. WARNING if a promo paywall has no audience restriction (Apple: subscribers in the same group; Google: usually `ignore-offer` tag + opt-in). See `../../references/concepts/promotional-offers.md`.
- [ ] **Full mode auto-handles** — in Full mode, no app code is needed. WARNING if app code calls `purchaseWithPromotionalOffer` manually while in Full mode (duplicates the purchase).
- [ ] **Observer/custom paywall uses `subscriptionOffer` parameters** — `subscriptionId`, `basePlanId`, `offerId`, `offerToken` (Google) or signed offer (Apple). FAIL if a Promo offer purchase is attempted with regular `purchase(...)` instead of the offer-aware API.

### 3.11 Analytics & Events Forwarding (universal — low blocker, high payoff)

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
1. **[FAIL] processAction() not called in error handler** — `PaywallInterceptor.kt:45`
   The catch block on line 45 returns without calling processAction(). This will freeze the paywall if an error occurs during login.
   **Fix:** Add `Purchasely.processAction(false)` in the catch block.

### Warnings (should fix)
1. **[WARNING] API key hardcoded** — `AppDelegate.swift:12`
   ...

### Suggestions (nice to have)
1. ...

### Passed Checks
- [PASS] SDK initialized in AppDelegate
- [PASS] fetchPresentation used (not deprecated)
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
