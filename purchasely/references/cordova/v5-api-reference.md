# Cordova SDK v5.x API — reference for MIGRATION ONLY (renamed in v6)

> **Do not write new v5 code.** This is a compact snapshot of the legacy v5.x Cordova
> tokens so the `purchasely-migrate` skill can **recognize** existing v5 code in a project
> and map it forward. The Cordova JS surface is **method-based and almost unchanged** in v6 —
> only the handful of symbols below were renamed. For the v6 surface, see
> [`integration.md`](integration.md); for the step-by-step migration, see
> [`migration-v6.md`](migration-v6.md).

## How to recognize a v5 Cordova integration

Grep the project for any of these legacy tokens — a hit means the integration is on v5
(also check the plugin pin: `@purchasely/cordova-plugin-purchasely@5.7.x` = v5):

```
startWithAPIKey            RunningMode.paywallObserver
setPaywallActionInterceptorCallback        setDefaultPresentationResultHandler
readyToOpenDeeplink        isDeeplinkHandled         Purchasely.handle(
closePaywall
```

## Renamed in v6

| v5 token | v6 equivalent |
|----------|---------------|
| `Purchasely.startWithAPIKey(...)` | `Purchasely.start(...)` (positional args + success/error callbacks — **never** an object) |
| `Purchasely.RunningMode.paywallObserver` | `Purchasely.RunningMode.observer` (same value `2`) |
| `Purchasely.readyToOpenDeeplink(bool)` | `Purchasely.allowDeeplink(bool)` |
| `Purchasely.isDeeplinkHandled(url, s, e)` / `Purchasely.handle(...)` | `Purchasely.handleDeeplink(url, s, e)` |
| `Purchasely.setDefaultPresentationResultHandler(cb)` | `Purchasely.setDefaultPresentationDismissHandler(cb)` |
| `Purchasely.closePaywall()` | `Purchasely.closePresentation()` |

## Behaviour changes (no rename)

- **Default running mode** is now `Observer` (was `Full`). Pass `Purchasely.RunningMode.full`
  for purchase handling. In Observer mode, presentations no longer auto-close.
- **`Purchasely.synchronize()`** gains optional `(success, error)` callbacks and resolves on
  completion (was fire-and-forget). Calling it with no arguments still works.
- **`Purchasely.presentSubscriptions()`** is now a **no-op** (native subscriptions UI removed).

## Unchanged in v6 (no migration needed)

These v5 Cordova methods are identical in v6 — listed here so `purchasely-migrate` does **not**
flag them: `fetchPresentation` / `fetchPresentationForPlacement`, `presentPresentation`,
`presentPresentationForPlacement`, `setPaywallActionInterceptor` + `onProcessAction`,
`closePresentation`, `userLogin` / `userLogout`, `getAnonymousUserId`, `allProducts`,
`productWithIdentifier`, `planWithIdentifier`, `purchaseWithPlanVendorId`,
`restoreAllProducts`, `silentRestoreAllProducts`, `userSubscriptions` /
`userSubscriptionsHistory`, every `setUserAttributeWith*`, `userAttribute`,
`clearUserAttribute(s)`, `setAttribute`, `addEventsListener` / `removeEventsListener`,
`setThemeMode`, `setLanguage`, `setLogLevel`, `setDebugMode`, `isEligibleForIntroOffer`,
`signPromotionalOffer`, `revokeDataProcessingConsent`.
