---
name: migrate
description: "Use when migrating an existing Purchasely SDK integration between major SDK versions. Supports Android (Kotlin/Java) and iOS (Swift) native SDK v5.x to v6.0.0."
---

# Purchasely SDK Migration Guide

You are migrating an existing Purchasely SDK integration. You must edit the user's project and verify each migration phase with the platform build/test commands. Android and iOS native v5.x -> v6.0.0 are supported. React Native, Flutter, and Cordova v6 migrations are not ready — stop and explain if asked.

Reference files:
- `references/android/migration-v6.md` — authoritative Android v5.x -> v6.0.0 migration checklist and API mapping.
- `references/ios/migration-v6.md` — authoritative iOS v5.x -> v6.0.0 migration checklist and API mapping.
- `references/android/api-reference.md` / `references/ios/api-reference.md` — current SDK API surface per platform.
- `references/sdk-versions.md` — current supported SDK versions.

## Arguments

`$ARGUMENTS` may contain:
- `android` / `ios` — target platform. If omitted, detect it from the project files. If the project is React Native, Flutter, or Cordova, stop and explain that only native Android and iOS v5 -> v6 are supported by this migration skill right now.
- `from:5.x` / `from:5.7.4` — optional source version.
- `to:6.0.0` — optional target version. Default to `6.0.0`.
- `mavenLocal` — Android only. Add `mavenLocal()` when the SDK 6.0.0 artifact is only available locally.

## Mandatory Workflow — Android

1. Detect Android project files: `settings.gradle(.kts)`, `build.gradle(.kts)`, version catalogs, `gradle-wrapper.properties`, and app modules. Detect the **primary call-site language** of `Purchasely.start(...)` — Kotlin or Java — because that drives the initialization rewrite (Kotlin DSL vs fluent Builder).
2. Read `references/android/migration-v6.md`.
3. Find current Purchasely usages with ripgrep:
   - `Purchasely`, `PLYPresentation`, `PLYPresentationAction`, `setPaywallActionsInterceptor`, `fetchPresentation`, `presentationView`, `readyToOpenDeeplink`, `isDeeplinkHandled`, `PLYPresentationProperties`, `PLYProductViewResult`, `PaywallObserver`.
4. Update Gradle first:
   - Pin Purchasely Android artifacts to `6.0.0`.
   - Bump Google Play Billing direct dependencies to `8.3.0` (Purchasely `google-play:6.0.0` resolves to PBL v8). If the app calls `queryProductDetailsAsync`, update the lambda to read `queryResult.productDetailsList`.
   - Add `mavenLocal()` before `google()` / `mavenCentral()` only when requested or required to resolve local artifacts.
   - Move to Gradle/AGP/Kotlin versions required by the project and SDK. With AGP 9, remove `org.jetbrains.kotlin.android` (root `apply false`, every module `plugins { }` block, and the version catalog) because Kotlin support is built into AGP. Leaving it applied fails with `Cannot add extension with name 'kotlin', as there is an extension already registered with that name`.
   - Also remove the `android { kotlinOptions { jvmTarget = "..." } }` block once `kotlin-android` is gone — that DSL is no longer resolvable.
5. Compile immediately. Treat compiler errors as the migration worklist.
6. Apply API migrations in small passes and compile after each pass.
7. **Rewrite initialization to the Kotlin DSL by default.** Replace `Purchasely.Builder(context).apiKey(...)…build().start { ... }` with the `Purchasely { context(...); apiKey(...); …; onInitialized { error -> ... } }` DSL entrypoint. The `onInitialized` callback fires once with a nullable `PLYError`. **Only keep the fluent `Purchasely.Builder(...).build().start { error -> ... }` form when the project is a Java project (no Kotlin source set) or when the call site is in a `.java` file** — the DSL is Kotlin-only.
8. **Observer mode**: if the app used `processAction(Boolean)` to gate the SDK on the host purchase flow, port that to a `pendingResult: ((PLYInterceptResult) -> Unit)?` field + a `suspendCancellableCoroutine` bridge inside the new `suspend` interceptor (see `references/android/migration-v6.md` → "Observer-mode bridge"). Resolve `pendingResult` from the existing transaction-result handler (`SUCCESS` / `NOT_HANDLED` / `FAILED`), and clear it in `close()`/`restart()` before `removeAllActionInterceptors()` to avoid leaking suspended coroutines.
9. Update tests to the v6 API and run unit tests.
10. Run the final Android assemble command before reporting completion.

## Mandatory Workflow — iOS

1. Detect the iOS project: `*.xcodeproj` / `*.xcworkspace`, `project.yml` (XcodeGen), `Package.swift`, or a `Podfile`. Detect how Purchasely is integrated — **SPM** or **CocoaPods** — because that drives the dependency bump.
2. Read `references/ios/migration-v6.md`.
3. Find current Purchasely usages with ripgrep:
   - `Purchasely`, `start(withAPIKey`, `paywallObserver`, `readyToOpenDeeplink`, `isDeeplinkHandled`, `setPaywallActionsInterceptor`, `fetchPresentation`, `PresentationView`, `PLYProductViewControllerResult`, `PLYPresentationActionParameters`.
4. Bump the dependency to `6.0.0` first (SPM `from: "6.0.0"` or Podfile `~> 6.0`), resolve packages / `pod install`, and clean the build folder. If consuming the unreleased `develop` snapshot, set up the local Swift package workaround described in the reference.
5. Add `@preconcurrency import Purchasely` at SDK call sites compiled under Swift 6 strict concurrency, and relax test targets to `SWIFT_STRICT_CONCURRENCY = minimal`.
6. Compile immediately. Treat compiler errors as the migration worklist; apply API migrations in small passes and recompile after each.
7. **Rewrite initialization** from `Purchasely.start(withAPIKey:...)` to the fluent `Purchasely.apiKey(...)…​.start { error in }` chain (single `Error?` completion). Map `.paywallObserver` -> `.observer` and `readyToOpenDeeplink` -> `allowDeeplink`.
8. **Replace the interceptor**: `setPaywallActionsInterceptor` -> typed `interceptAction(.login/.navigate/.purchase/.restore)` closures that are `async` and return `PLYInterceptResult` (`proceed(true)` -> `.notHandled`, `proceed(false)` -> `.success`, failures -> `.failed`/`.error`). In Observer mode, `await` the native StoreKit flow inside the closure and return its result directly — iOS needs no coroutine bridge.
9. **Migrate presentation loading**: `fetchPresentation(...)` -> `PLYPresentationBuilder.from(placementId:).build().preload { ... }`; dismissal tuple -> `PLYPresentationOutcome`; embedded `PresentationView` -> wrap `presentation.controller` (`PLYPresentationViewController`) in `UIViewControllerRepresentable`.
10. If the project uses XcodeGen, run `xcodegen generate`. Update tests to the v6 API.
11. Run the final iOS `xcodebuild build` then `xcodebuild test` before reporting completion.

## Output Requirements

In the final answer, list:
- Every file changed.
- The v6 API migrations applied.
- Every verification command run and whether it passed.
- Any warnings left for the user, especially SDK resource warnings, local-only `mavenLocal()` dependency resolution (Android), or the unreleased-`develop` local Swift package workaround and `.storeKit1` init note (iOS).
