# Cordova SDK v5.x API — reference for MIGRATION ONLY (changed in v6)

> **Do not write new v5 code.** This is a compact snapshot of the legacy v5.x Cordova
> tokens so the `purchasely-migrate` skill can **recognize** existing v5 code in a project
> and map it forward. The Cordova JS surface stays **method-based** in v6, but three surfaces
> changed in a breaking way (`start`, the action interceptor, the presentation display mode)
> and several methods were renamed or removed. For the v6 surface, see
> [`integration.md`](integration.md); for the step-by-step migration, see
> [`migration-v6.md`](migration-v6.md).

## How to recognize a v5 Cordova integration

Grep the project for any of these legacy tokens — a hit means the integration is on v5
(also check the plugin pin: `@purchasely/cordova-plugin-purchasely@5.7.x` = v5):

```
Purchasely.start('              (positional string apiKey — v6 takes an options object)
setPaywallActionInterceptor     onProcessAction          PaywallAction
RunningMode.paywallObserver     RunningMode.transactionOnly
readyToOpenDeeplink             isDeeplinkHandled         Purchasely.handle(
setDefaultPresentationResultHandler
presentSubscriptions            presentProductWithIdentifier   presentPlanWithIdentifier
showPresentation                hidePresentation
isFullscreen                    closePaywall
```

## Breaking changes in v6

| v5 token | v6 equivalent |
|----------|---------------|
| `Purchasely.start(apiKey, stores, storeKit1, userId, logLevel, runningMode, s, e)` (positional) | `Purchasely.start(options, success, error)` — **single config object**, only `apiKey` required |
| `Purchasely.RunningMode.paywallObserver` / `.transactionOnly` | **removed**; use `Purchasely.RunningMode.observer` (values are now name strings `'observer'` / `'full'`) |
| `Purchasely.setPaywallActionInterceptor(cb)` + `Purchasely.onProcessAction(bool)` | **removed**; use per-action `Purchasely.interceptAction(kind, handler)` returning an `InterceptResult` |
| `Purchasely.PaywallAction` | **renamed** `Purchasely.PresentationAction` (same string values) |
| `isFullscreen` boolean on `present*` methods | **display mode** — a `Purchasely.TransitionType` string, a boolean (still accepted), or a transition object |
| `Purchasely.presentSubscriptions()` | **removed** (build your own from `userSubscriptions()` / `userSubscriptionsHistory()`) |
| `Purchasely.presentProductWithIdentifier()` / `presentPlanWithIdentifier()` | **removed** (use placement/screen presentation) |
| `Purchasely.showPresentation()` / `hidePresentation()` | **removed** (use `closePresentation()` / new `backPresentation()`) |
| `Purchasely.readyToOpenDeeplink(bool)` | `Purchasely.allowDeeplink(bool)` |
| `Purchasely.isDeeplinkHandled(url, s, e)` / `Purchasely.handle(...)` | `Purchasely.handleDeeplink(url, s, e)` |
| `Purchasely.setDefaultPresentationResultHandler(cb)` | `Purchasely.setDefaultPresentationDismissHandler(cb)` |
| `Purchasely.closePaywall()` | `Purchasely.closePresentation()` |

## Behaviour changes (no rename)

- **Default running mode** is now `Observer` (was `Full`). Pass `Purchasely.RunningMode.full`
  for purchase handling. In Observer mode, presentations no longer auto-close.
- **`Purchasely.synchronize()`** gains optional `(success, error)` callbacks and resolves on
  completion (was fire-and-forget). Calling it with no arguments still works.

## New in v6 (no v5 equivalent)

`allowCampaigns(bool)`, `presentPresentationForDefault(...)`, `fetchPresentationForDefault(...)`,
`backPresentation()`, `removeActionInterceptor(kind)`, `removeAllActionInterceptors()`,
`removeDefaultPresentationDismissHandler()`, and the constants `InterceptResult`,
`PresentationAction`, `PresentationType`, `CloseReason`, `TransitionType`, `DimensionType`,
`Store`, `StorekitVersion`.

## Unchanged in v6 (no migration needed)

These v5 Cordova methods are identical in v6 — listed here so `purchasely-migrate` does **not**
flag them: `fetchPresentation` / `fetchPresentationForPlacement`, `presentPresentation`,
`presentPresentationForPlacement` / `presentPresentationWithIdentifier` (only their
`isFullscreen` argument became a display mode), `closePresentation`, `userLogin` / `userLogout`,
`getAnonymousUserId`, `allProducts`, `productWithIdentifier`, `planWithIdentifier`,
`purchaseWithPlanVendorId`, `restoreAllProducts`, `silentRestoreAllProducts`, `userSubscriptions`
/ `userSubscriptionsHistory`, every `setUserAttributeWith*`, `userAttribute`,
`clearUserAttribute(s)`, `setAttribute`, `addEventsListener` / `removeEventsListener`,
`setThemeMode`, `setLanguage`, `setLogLevel`, `setDebugMode`, `isEligibleForIntroOffer`,
`signPromotionalOffer`, `revokeDataProcessingConsent`.
