---
name: migrate
description: "Use when migrating an existing Purchasely SDK integration between major SDK versions. Currently supports Android native SDK v5.x to v6.0.0 only."
---

# Purchasely SDK Migration Guide

You are migrating an existing Purchasely SDK integration. You must edit the user's project and verify each migration phase with the platform build/test commands. Do not work on iOS migration yet; iOS v6 is not ready.

Reference files:
- `references/android/migration-v6.md` — authoritative Android v5.x -> v6.0.0 migration checklist and API mapping.
- `references/android/api-reference.md` — current Android SDK API surface.
- `references/sdk-versions.md` — current supported SDK versions.

## Arguments

`$ARGUMENTS` may contain:
- `android` — required today. If omitted, detect the platform. If the project is not Android, stop and explain that only Android v5 -> v6 is supported by this migration skill right now.
- `from:5.x` / `from:5.7.4` — optional source version.
- `to:6.0.0` — optional target version. Default to `6.0.0`.
- `mavenLocal` — optional. Add `mavenLocal()` when the SDK 6.0.0 artifact is only available locally.

## Mandatory Workflow

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

## Output Requirements

In the final answer, list:
- Every file changed.
- The v6 API migrations applied.
- Every verification command run and whether it passed.
- Any warnings left for the user, especially SDK resource warnings or local-only `mavenLocal()` dependency resolution.
