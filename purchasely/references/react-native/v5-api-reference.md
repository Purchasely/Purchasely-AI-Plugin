# React Native SDK v5.x API — reference for MIGRATION ONLY (removed in v6)

> **Do not write new v5 code.** This is a compact snapshot of the legacy v5.x public React Native API so the `purchasely-migrate` skill can **recognize** existing v5 code in a project and map it forward. Every paywall symbol below is **removed in v6.0.0-rc.2** (not deprecated — it fails to compile and no longer exists at runtime). For the v6 surface, see [`integration.md`](integration.md); for the step-by-step migration, see [`migration-v6.md`](migration-v6.md).

Each entry adds a one-line `-> v6` pointer.

## How to recognize a v5 React Native integration

Grep the project for any of these legacy tokens — a hit on a paywall token means the integration is on v5:

```
Purchasely.start({           startWithAPIKey
fetchPresentation            presentPresentation
presentPresentationForPlacement                  presentPresentationWithIdentifier
presentProductWithIdentifier presentPlanWithIdentifier
showPresentation             hidePresentation             closePresentation
setPaywallActionInterceptorCallback              onProcessAction
PaywallAction.               PLYPaywallAction
setDefaultPresentationResultCallback             setDefaultPresentationResultHandler
readyToOpenDeeplink          isDeeplinkHandled            presentSubscriptions
clientPresentationDisplayed  clientPresentationClosed
displaySubscriptionCancellationInstruction
ProductResult.PRODUCT_RESULT_                     isFullscreen:
RunningMode.TRANSACTION_ONLY  RunningMode.PAYWALL_OBSERVER
```

> **Deeplink API changed.** `isDeeplinkHandled(uri)` is **removed** in v6 React Native and **renamed** to `handleDeeplink(uri)` (no alias). A hit on `isDeeplinkHandled` means the integration is on v5 — flag it. `readyToOpenDeeplink(bool)` → `.allowDeeplink(bool)` on the builder.

## Initialization (v5)

```typescript
import Purchasely, { LogLevels, RunningMode } from 'react-native-purchasely';

await Purchasely.start({
  apiKey: 'YOUR_API_KEY',
  androidStores: ['Google'],
  storeKit1: false,              // false = StoreKit 2
  userId: 'user_id',
  logLevel: LogLevels.ERROR,
  runningMode: RunningMode.FULL, // implicit default in v5
});

Purchasely.readyToOpenDeeplink(true);
```

- `Purchasely.start({ apiKey, androidStores, storeKit1, userId, logLevel, runningMode })` -> v6: `Purchasely.builder(apiKey).appUserId(userId).runningMode('full').logLevel('error').stores(['google']).storekitVersion('storeKit2').start()` (returns `Promise<boolean>`). Options are now **strings**, not enums.
- `Purchasely.startWithAPIKey(apiKey, stores, userId, logLevel, runningMode)` -> v6: `Purchasely.builder(apiKey).appUserId(userId).runningMode('full').start()`.
- `RunningMode.FULL` / `RunningMode.PAYWALL_OBSERVER` / `RunningMode.TRANSACTION_ONLY` -> v6: string `'full'` / `'observer'`. `PAYWALL_OBSERVER` and `TRANSACTION_ONLY` are **removed** (only `'observer'` / `'full'` remain). **Default mode flipped from Full to `'observer'` in v6** (silent behavioural change — re-add `.runningMode('full')` explicitly).
- `Purchasely.readyToOpenDeeplink(true)` -> v6: `.allowDeeplink(true)` on the builder (or `Purchasely.allowDeeplink(true)`).

## Action interceptor (v5)

```typescript
Purchasely.setPaywallActionInterceptorCallback((result) => {
  const { action, parameters, info } = result;
  switch (action) {
    case Purchasely.PaywallAction.PURCHASE:
      Purchasely.onProcessAction(true);  // let SDK continue
      break;
    case Purchasely.PaywallAction.LOGIN:
      Purchasely.onProcessAction(false); // app handled it
      break;
    case Purchasely.PaywallAction.NAVIGATE:
      Linking.openURL(parameters?.url);
      Purchasely.onProcessAction(false);
      break;
    default:
      Purchasely.onProcessAction(true);
  }
});
```

- `setPaywallActionInterceptorCallback(cb)` + `Purchasely.onProcessAction(bool)` -> v6: per-action `Purchasely.interceptAction(kind, handler)`; the handler returns a **`PLYInterceptResult`** string instead of calling `onProcessAction`.
- `onProcessAction(false)` (app handled) -> v6: return `'success'`.
- `onProcessAction(true)` (let SDK continue) -> v6: return `'notHandled'`. New failure path -> return `'failed'`.
- `Purchasely.PaywallAction.*` / `PLYPaywallAction` (`PURCHASE`, `RESTORE`, `LOGIN`, `CLOSE`, `CLOSE_ALL`, `NAVIGATE`, `OPEN_PRESENTATION`, `OPEN_PLACEMENT`, `PROMO_CODE`, `WEB_CHECKOUT`) -> v6: the enum is **removed**; use **string kinds** (`'purchase'`, `'restore'`, `'login'`, `'close'`, `'closeAll'`, `'navigate'`, `'openPresentation'`, `'openPlacement'`, `'promoCode'`, `'webCheckout'`).
- `result.parameters` (`parameters.plan`, `parameters.url`, …) -> v6: typed payload discriminated by `payload?.kind` on each handler (`payload.plan`, `payload.url`, …). `result.info` -> v6: `PLYInterceptorInfo` (`{ contentId?, presentation? }`) as the handler's first argument.
- Remove handlers -> v6: `Purchasely.removeActionInterceptor(kind)` / `Purchasely.removeAllActionInterceptors()`.

## Fetch & display a presentation (v5)

```typescript
import { PLYPresentationType, ProductResult } from 'react-native-purchasely';

const presentation = await Purchasely.fetchPresentation({
  placementId: 'ONBOARDING',
  contentId: null,
});

const result = await Purchasely.presentPresentation({
  presentation,
  isFullscreen: true,
});

switch (result.result) {
  case ProductResult.PRODUCT_RESULT_PURCHASED: break;
  case ProductResult.PRODUCT_RESULT_RESTORED:  break;
  case ProductResult.PRODUCT_RESULT_CANCELLED: break;
}
```

- `Purchasely.fetchPresentation({ placementId })` -> v6: `Purchasely.presentation.placement(id).build().preload()` (resolves a `PLYLoadedPresentation`).
- `Purchasely.presentPresentation({ presentation, isFullscreen })` -> v6: `request.display(transition?)` (preload then display the same request). `isFullscreen: true` -> `display({ type: 'fullScreen' })`.
- `Purchasely.presentPresentationForPlacement({ placementVendorId, isFullscreen })` -> v6: `Purchasely.presentation.placement(id).build().display()`.
- `Purchasely.presentPresentationWithIdentifier({ presentationVendorId })` -> v6: `Purchasely.presentation.screen(id).build().display()`.
- `Purchasely.presentProductWithIdentifier(productId, …)` -> v6: `Purchasely.presentation.screen(id).contentId(contentId).build().display()`.
- `Purchasely.presentPlanWithIdentifier(planId, …)` -> v6: `Purchasely.presentation.screen(id).build().display()`.
- `result.result` of `ProductResult` (`PRODUCT_RESULT_PURCHASED` / `_RESTORED` / `_CANCELLED`) -> v6: `outcome.purchaseResult` **string union** (`'purchased'` / `'restored'` / `'cancelled'` / `null`) on the 5-field `PLYPresentationOutcome`.
- `presentation.id` -> v6: `presentation.screenId` (the `id` alias is deprecated but still present).

## Presentation lifecycle (v5)

```typescript
Purchasely.showPresentation();
Purchasely.hidePresentation();
Purchasely.closePresentation();
```

- `showPresentation()` -> v6: `request.display()`.
- `hidePresentation()` / `closePresentation()` -> v6: `request.close()` (iOS closes the targeted request; Android currently dismisses all displayed presentations).

## Default presentation result handler (v5)

```typescript
Purchasely.setDefaultPresentationResultCallback((result) => { /* … */ });
// or setDefaultPresentationResultHandler(...)
```

- `setDefaultPresentationResultCallback(cb)` / `setDefaultPresentationResultHandler(cb)` -> v6: `Purchasely.setDefaultPresentationDismissHandler(outcome => …)` (global handler for SDK-opened presentations: campaigns, deeplinks, Promoted IAP). Remove with `subscription.remove()` or `removeDefaultPresentationDismissHandler()`. For paywalls **you** display, use `request.onDismissed(...)` instead.

## Deeplinks (v5)

```typescript
const handled = await Purchasely.isDeeplinkHandled('app://ply/...');
```

- `Purchasely.isDeeplinkHandled(uri)` -> v6: **renamed** to `Purchasely.handleDeeplink(uri)` (returns `Promise<boolean>`). No alias — a hit on `isDeeplinkHandled` is a v5 token to migrate.

## Subscriptions UI & client presentations (v5)

```typescript
Purchasely.presentSubscriptions();
Purchasely.displaySubscriptionCancellationInstruction();
Purchasely.clientPresentationDisplayed(presentation);
Purchasely.clientPresentationClosed(presentation);
```

- `Purchasely.presentSubscriptions()` -> v6: **REMOVED — no replacement.** The native subscriptions screen was dropped from both native SDKs. Build your own screen from `Purchasely.userSubscriptions()` / `Purchasely.userSubscriptionsHistory()` (both unchanged).
- `Purchasely.displaySubscriptionCancellationInstruction()` -> v6: **REMOVED.**
- `Purchasely.clientPresentationDisplayed(...)` / `clientPresentationClosed(...)` -> v6: **REMOVED — no replacement.**

## Synchronize (v5)

```typescript
Purchasely.synchronize(); // fire-and-forget, returned void
```

- `Purchasely.synchronize()` -> v6: returns a **`Promise<boolean>`** that resolves on completion and rejects on failure. **Source-compatible** (fire-and-forget still works); do **not** flag existing calls — only mention you can now `await` it.

## Unchanged in v6 (do NOT flag)

These v5 APIs are identical in v6 — listed here only so the `purchasely-migrate` skill does **not** flag them as needing migration:

- **Identity**: `userLogin`, `userLogout`, `getAnonymousUserId`, `isAnonymous`.
- **Products / purchases**: `allProducts`, `productWithIdentifier`, `planWithIdentifier`, `purchaseWithPlanVendorId`, `signPromotionalOffer`, `isEligibleForIntroOffer`, `setDynamicOffering`, `getDynamicOfferings`, `removeDynamicOffering`, `clearDynamicOfferings`.
- **Subscriptions data / restore**: `userSubscriptions` (`{ invalidateCache }`), `userSubscriptionsHistory`, `restoreAllProducts`, `silentRestoreAllProducts`, `userDidConsumeSubscriptionContent`.
- **Attributes**: `setUserAttributeWithString` / `WithNumber` / `WithInt` / `WithDouble` / `WithBoolean` / `WithDate` / `WithStringArray` / `WithNumberArray` / `WithIntArray` / `WithDoubleArray` / `WithBooleanArray`, `incrementUserAttribute`, `decrementUserAttribute`, `userAttributes`, `userAttribute`, `clearUserAttribute`, `clearUserAttributes`, `clearBuiltInAttributes`, `setAttribute`.
- **Listeners**: `addEventListener` / `removeEventListener` (aliases `listenToEvents` / `stopListeningToEvents`), `addPurchasedListener` / `removePurchasedListener` (aliases `listenToPurchases` / `stopListeningToPurchases`), `addUserAttributeSetListener` / `removeUserAttributeSetListener`, `addUserAttributeRemovedListener` / `removeUserAttributeRemovedListener`, `setUserAttributeListener` / `clearUserAttributeListener`.
- **Config / misc**: `setLogLevel`, `setLanguage`, `setThemeMode`, `setDebugMode`, `allowDeeplink`, `allowCampaigns`, `revokeDataProcessingConsent`, `getConstants`.
- **Embedded component**: `PLYPresentationView` (`placementId`, `presentation`, `request`, `flex`, `onPresentationClosed`). Its `onPresentationClosed` receives a `PLYPresentationViewResult` (`{ result: ProductResult, plan }`), not the 5-field outcome.
- **`synchronize()`**: source-compatible (now awaitable; see above).

## See also

- [migration-v6.md](migration-v6.md) — full v5 -> v6 migration steps and v6 replacements.
- [integration.md](integration.md) — the v6 API surface.
