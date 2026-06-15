---
name: purchasely-migrate
description: "Use when migrating an existing Purchasely SDK integration between major SDK versions. Supports native Android (Kotlin & Java) and native iOS (Swift & Objective-C) v5.x to v6.0.0-rc1 — handles every v5→v6 breaking change so a project can be upgraded in a single prompt."
---

# Purchasely SDK Migration Guide

You are migrating an existing Purchasely SDK integration. You must edit the user's project and verify each migration phase with the platform build/test commands. **Native Android (Kotlin & Java) and native iOS (Swift & Objective-C) v5.x → v6.0.0-rc1 are supported.** React Native, Flutter, and Cordova v6 migrations are not ready — stop and explain if asked.

The goal is a **one-prompt upgrade**: detect the platform and call-site language, rewrite every v5 API to its v6 form, and leave the project building with no v5-only symbols remaining.

## ⚠️ The change you must surface first: default running mode is now Observer

This is the single most impactful v6 change and it is **silent** — the project keeps compiling.

- v5 defaulted to **Full** mode (Purchasely processes and validates purchases).
- v6 defaults to **Observer** mode (Purchasely only observes transactions).

**If the app relies on Purchasely to handle and validate purchases, you MUST set the running mode to Full explicitly during the init rewrite:**

```swift
// iOS — Swift
Purchasely.apiKey("API_KEY").runningMode(.full).start { error in }
```
```kotlin
// Android — Kotlin
Purchasely { context(applicationContext); apiKey("API_KEY"); runningMode(PLYRunningMode.Full); /* … */ onInitialized { error -> } }
```

Determine the project's intended mode before rewriting init: if the v5 code did not pass a running mode (or passed Full / did not pass `.paywallObserver`), it was running in **Full** — so the v6 rewrite **must add `.runningMode(.full)` / `runningMode(PLYRunningMode.Full)`**. Only omit it when the app genuinely runs its own billing and was already in Observer mode. In Observer mode, presentations also **no longer auto-close** after purchase/restore (v5 Full auto-appended a `close_all`); if the app relied on auto-close, that is another reason to set Full.

## Reference files

- `../../references/android/migration-v6.md` — authoritative Android v5.x → v6.0.0-rc1 migration checklist and API mapping.
- `../../references/ios/migration-v6.md` — authoritative iOS v5.x → v6.0.0-rc1 migration checklist and API mapping.
- `../../references/android/v5-api-reference.md` / `../../references/ios/v5-api-reference.md` — the **v5** API surface, used to recognize the legacy code you are replacing.
- `../../references/android/api-reference.md` / `../../references/ios/api-reference.md` — the **v6** API surface to migrate to.
- `../../references/concepts/running-modes.md` — running modes and the default-mode change.
- `../../references/sdk-versions.md` — current supported SDK versions.

**Always fact-check against the official documentation when a detail is uncertain or not covered by these references.** Same source, two mirrors — use whichever is easier:
- GitHub: `https://github.com/Purchasely/Documentation/` on the branch matching the target version (`v6.0`).
- Online: `https://docs.purchasely.com` on the version matching the target (the v6 docs). The v5→v6 guides live under "Migrating to Purchasely → Migrating from SDK 5 to 6".

Never invent a signature: if the references and the official docs disagree, the official docs win; if neither is conclusive, say so rather than guessing.

## Arguments

`$ARGUMENTS` may contain:
- `android` / `ios` — target platform. If omitted, detect it from the project files. If the project is React Native, Flutter, or Cordova, stop and explain that only native Android and iOS v5 → v6 are supported by this migration skill right now.
- `from:5.x` / `from:5.7.4` — optional source version.
- `to:6.0.0-rc1` — optional target version. Default to `6.0.0-rc1`.
- `mavenLocal` — Android only. Add `mavenLocal()` when the SDK 6.0.0-rc1 artifact is only available locally.

## Mandatory Workflow — Android (Kotlin & Java)

1. Detect Android project files: `settings.gradle(.kts)`, `build.gradle(.kts)`, version catalogs, `gradle-wrapper.properties`, and app modules. Detect the **primary call-site language** of `Purchasely.start(...)` — Kotlin or Java — because that drives the initialization rewrite (Kotlin DSL vs fluent Builder) and the interceptor form (reified vs `Class`-based).
2. Read `../../references/android/migration-v6.md`, and skim `../../references/android/v5-api-reference.md` so you recognize every legacy symbol.
3. Find current Purchasely usages with ripgrep (these are the v5 symbols to replace): `Purchasely`, `PLYPresentation`, `PLYPresentationAction`, `setPaywallActionsInterceptor`, `processAction`, `fetchPresentation`, `presentationView`, `PLYPresentationProperties`, `PLYPresentationActionParameters`, `PLYPresentationInfo`, `PLYProductViewResult`, `readyToOpenDeeplink`, `isDeeplinkHandled`, `PaywallObserver`, `subscriptionsFragment`, `purchaseHistory`, `isPastSubscriber`, `hasIntroductoryPrice`, `INTRO_`, `TRIAL_`, `presentationId`.
4. Update Gradle first:
   - Pin Purchasely Android artifacts to `6.0.0-rc1` (`io.purchasely:core`, `io.purchasely:google-play`, optional `io.purchasely:player`). There is **no `presentation-compose` artifact** — do not add one.
   - Bump Google Play Billing direct dependencies to `8.3.0` (Purchasely `google-play:6.0.0-rc1` resolves to PBL v8). If the app calls `queryProductDetailsAsync`, update the lambda to read `queryResult.productDetailsList`.
   - Add `mavenLocal()` before `google()` / `mavenCentral()` only when requested or required to resolve local artifacts.
   - Move to the Gradle/AGP/Kotlin versions required by the SDK (Gradle 9.3.0+, AGP 9, Kotlin 2.2.x / K2, JDK 17 to build, `minSdk 23`, `compileSdk 36`). With AGP 9, remove `org.jetbrains.kotlin.android` (root `apply false`, every module `plugins { }` block, and the version catalog) — Kotlin support is built into AGP. Leaving it applied fails with `Cannot add extension with name 'kotlin', as there is an extension already registered with that name`. Also remove the `android { kotlinOptions { jvmTarget = "..." } }` block once `kotlin-android` is gone.
   - The reified `interceptAction<T> { … }` / `removeActionInterceptor<T>()` are `inline` functions targeting JVM 11 — compile Kotlin modules with `jvmTarget = 11`, or use the non-inline `Class`-based overload.
5. Compile immediately. Treat compiler errors as the migration worklist.
6. Apply API migrations in small passes and compile after each pass.
7. **Rewrite initialization.** Default to the Kotlin DSL `Purchasely { context(...); apiKey(...); stores(...); runningMode(...); … onInitialized { error -> } }`. The callback now receives only a nullable `PLYError` (`start { error -> }`, not `start { isConfigured, error -> }`). **Set `runningMode(PLYRunningMode.Full)` explicitly when the app needs purchase handling/validation** (see the warning at the top). Map `PLYRunningMode.PaywallObserver` → `PLYRunningMode.Observer`. **Keep the fluent `Purchasely.Builder(...).build().start { error -> }` form for Java projects** (no Kotlin source set) or `.java` call sites — the DSL is Kotlin-only. Note: starting without a store is now valid (storeless); purchase APIs then return `PLYError.NoStoreConfigured` in Full mode.
8. **Action interceptor.** Replace the global `setPaywallActionsInterceptor` with per-action interceptors returning `PLYInterceptResult` (`SUCCESS`/`FAILED`/`NOT_HANDLED`; map `processAction(false)`→`SUCCESS`, `processAction(true)`→`NOT_HANDLED`). `PLYPresentationAction` is now a sealed class with typed parameters on each subclass (`Purchase.plan`, `Navigate.url`, …) — `PLYPresentationActionParameters` is gone. Use the reified `interceptAction<PLYPresentationAction.Purchase> { info, purchase -> … }` in Kotlin, or the **`Class`-based overload in Java**: `Purchasely.interceptAction(PLYPresentationAction.Purchase.class, (info, action, result) -> result.invoke(PLYInterceptResult.NOT_HANDLED))`. `PLYPresentationInfo` → `PLYInterceptorInfo`.
9. **Presentation API.** Replace `fetchPresentation(...)` / `PLYPresentationProperties` with `PLYPresentation { placementId(...) ; screenId(...) ; contentId(...) ; onPresented{…}; onCloseRequested{}; onDismissed{outcome->} }.preload { loaded, error -> }` (or `.preload()` in a coroutine, or the atomic `display(context, presentation, callback)`). **Do not put `flowId`/`productId`/`planId` on the builder — they are not exposed in v6;** display a Flow via its deeplink `app_scheme://ply/flows/FLOW_ID`. Update imports `io.purchasely.ext.*` → `io.purchasely.ext.presentation.*`. Rename `PLYPresentation.id` → `screenId` (keep `screenId`; do not rename Android code to `presentationId`) and `onClose` → `onCloseRequested`. `display(context)` is non-suspend and returns a `PLYPresentationSession` you can `.await()`. Callbacks now deliver one `PLYPresentationOutcome` (`purchaseResult`/`plan`/`closeReason`/`error`); `PLYProductViewResult` → `PLYPurchaseResult`.
10. **Embedded UI.** Replace `presentationView(...)` with `loaded.buildView(context) { outcome -> }` or `loaded.getFragment { outcome -> }`. For Jetpack Compose there is **no SDK composable** — wrap the view: `AndroidView(factory = { loaded.buildView(it) { outcome -> } })`. Do not reference `io.purchasely:presentation-compose` or a `PLYPresentationView` composable; `PLYPresentationView` is the Android `View` type that `buildView()` returns.
11. **Observer mode.** If the app used `processAction(Boolean)` to gate the SDK on the host purchase flow, port that to a `pendingResult: ((PLYInterceptResult) -> Unit)?` field + a `suspendCancellableCoroutine` bridge inside the new `suspend` interceptor (see `../../references/android/migration-v6.md` → "Observer-mode bridge"). On billing success call `Purchasely.synchronize(onSuccess = { … }, onError = { … })` then resolve with `SUCCESS`; resolve `NOT_HANDLED`/`FAILED` otherwise. Clear `pendingResult` in `close()`/`restart()` before `removeAllActionInterceptors()` to avoid leaking suspended coroutines.
12. **Other renames/removals.** Deeplinks: `readyToOpenDeeplink` → `allowDeeplink`, `isDeeplinkHandled(uri, activity)` → `handleDeeplink(uri, activity)`; v6 also auto-intercepts deeplinks (the manual call may become unnecessary, but watch the `singleTask`/`singleTop` + `setIntent()` pitfall). User-attribute mutations now return `Deferred<Boolean>` (`.await()` when you need the result). Replace removed APIs: `subscriptionsFragment()` and the subscription/cancellation UI (build your own from `userSubscriptions`/`userSubscriptionsHistory`), `purchaseHistory()` → `userSubscriptionsHistory()`, `isPastSubscriber()` → derive from history, and all `intro*`/`INTRO_*`/`TRIAL_*` → `offer*`/`OFFER_*`.
13. Update tests to the v6 API and run unit tests.
14. Run the final Android assemble command before reporting completion.

## Mandatory Workflow — iOS (Swift & Objective-C)

1. Detect the iOS project: `*.xcodeproj` / `*.xcworkspace`, `project.yml` (XcodeGen), `Package.swift`, or a `Podfile`. Detect how Purchasely is integrated — **SPM** or **CocoaPods** — and the **call-site language** (Swift vs Objective-C), because both drive the rewrite.
2. Read `../../references/ios/migration-v6.md`, and skim `../../references/ios/v5-api-reference.md` so you recognize every legacy symbol.
3. Find current Purchasely usages with ripgrep: `start(withAPIKey`, `paywallObserver`, `readyToOpenDeeplink`, `isDeeplinkHandled`, `setPaywallActionsInterceptor`, `proceed(`, `fetchPresentation`, `PresentationView`, `closeDisplayedPresentation`, `PLYProductViewControllerResult`, `PLYPresentationInfo`, `displayMode:`, plus Objective-C call sites (`[Purchasely startWithAPIKey`, `PLYPresentation *`).
4. Bump the dependency to `6.0.0-rc1` first — pin it **exactly** (SPM `exact: "6.0.0-rc1"`, CocoaPods `pod 'Purchasely', '6.0.0-rc1'`, Carthage `binary "https://raw.githubusercontent.com/Purchasely/Purchasely-iOS/master/Purchasely.json" == 6.0.0-rc1` then `carthage update`); floating ranges (`~> 6.0`, `from:`) do not resolve a pre-release and would silently drift. Resolve packages / `pod install` / `carthage update`, and clean the build folder.
5. Add `@preconcurrency import Purchasely` at SDK call sites compiled under Swift 6 strict concurrency, and relax test targets to `SWIFT_STRICT_CONCURRENCY = minimal`.
6. Compile immediately. Treat compiler errors as the migration worklist; apply API migrations in small passes and recompile after each.
7. **Rewrite initialization** from the removed `Purchasely.start(withAPIKey:…)` to the fluent chain `Purchasely.apiKey("…")…start()`. Prefer Swift async (`try await …start()`); use the completion form (`.start { error in }`, single `Error?`) when async is impractical or for Objective-C interop. **Objective-C:** `[[[[Purchasely apiKey:@"…"] appUserId:@"…"] runningMode:PLYRunningModeFull] startWithInitialized:^(NSError *e){}]`. **Set `.runningMode(.full)` explicitly when the app needs purchase handling/validation** (default is now `.observer`). Map `.paywallObserver` → `.observer`. Migrate the deprecated pre-`start` `set*` class funcs (`setEnvironment`, `setThemeMode`, …) to chain modifiers.
8. **Replace the interceptor.** `setPaywallActionsInterceptor` → typed `Purchasely.interceptAction(.login/.navigate/.purchase/.restore)` closures that are `async` and **return** a `PLYInterceptResult` (`proceed(true)` → `.notHandled`, `proceed(false)` → `.success`, failure → `.failed`). The completion-handler form `interceptAction(.x) { info, params, completion in completion(.success) }` is available for Objective-C / non-async call sites. `PLYPresentationInfo` → `PLYInterceptorInfo`. In Observer mode, `await` the native StoreKit flow inside the closure and return its result directly — iOS needs no coroutine bridge.
9. **Migrate presentation loading.** `fetchPresentation(...)` → `PLYPresentationBuilder.forPlacementId(...)` (or `.forScreenId(...)` / `.from(placementId:)`) `.build().preload { … }` (or `try await …preload()`); use `.onPresented`/`.onDismissed`. The convenience `Purchasely.display(for: placementId, transition: …)` replaces the old `display(for:displayMode:)` (param renamed `displayMode:` → `transition:`). The dismissal tuple `(PLYProductViewControllerResult, PLYPlan?)` becomes one `PLYPresentationOutcome` (`purchaseResult`/`plan`/`closeReason`/`error`). `Purchasely.closeDisplayedPresentation()` → `Purchasely.closeAllScreens()`.
10. **Embedded / SwiftUI.** The removed `controller.PresentationView` becomes `presentation.swiftUIView` for SwiftUI (returns `nil` for `.deactivated`); UIKit consumers keep `presentation.controller` (a `PLYPresentationViewController`, wrap in `UIViewControllerRepresentable` if needed).
11. **`PLYPresentation` is now a protocol.** In Objective-C change `PLYPresentation *` → `id<PLYPresentation>`; in Swift `any PLYPresentation` and `PLYPresentation` both compile. Reading members/calling methods is unchanged.
12. **Deeplinks.** `readyToOpenDeeplink(_:)` → `allowDeeplink(_:)`, `isDeeplinkHandled(deeplink:)` → `handleDeeplink(_:)`. iOS does **not** auto-intercept — keep passing deeplinks via `Purchasely.handleDeeplink(_:)` from `AppDelegate`/`SceneDelegate`.
13. If the project uses XcodeGen, run `xcodegen generate`. Update tests to the v6 API.
14. Run the final iOS `xcodebuild build` then `xcodebuild test` before reporting completion.

## Completion Build Gate

Before declaring the migration complete, build the user's app with the project's canonical command (Android: `./gradlew :app:assembleDebug` then `:app:testDebugUnitTest`; iOS: `xcodebuild build` then `xcodebuild test` on the `.xcworkspace`). If the build fails, fix the error, rerun the build, and run the tests again until the app builds successfully with no v5-only Purchasely symbols left. Do not report the migration as done from edits or reasoning alone; include the exact build/test commands and their outcomes in the final response.

## Output Requirements

In the final answer, list:
- Every file changed.
- The v6 API migrations applied (group by area: init / interceptor / presentation / deeplinks / removed APIs).
- Whether the running mode was set to Full explicitly, and why (or why Observer was kept).
- Every verification command run and whether it passed.
- Any warnings left for the user, especially local-only `mavenLocal()` dependency resolution (Android), removed UI you replaced with custom screens, or any detail you had to confirm against the official documentation.
