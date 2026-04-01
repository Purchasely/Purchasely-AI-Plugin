# Purchasely SDK Integration Guidelines

When working with Purchasely SDK code, follow these guidelines for correct integration of in-app subscription paywalls.

## SDK Overview

Purchasely is an in-app subscription monetization platform with SDKs for iOS (Swift/ObjC), Android (Kotlin/Java), React Native, Flutter, and Cordova. All SDKs share a unified API surface with platform-specific idioms. Two running modes: **Full** (Purchasely handles purchases) and **PaywallObserver** (observe only).

## Initialization

Always initialize with `start()` before any other SDK call. Call it early in the app lifecycle.

```swift
// iOS
Purchasely.start(withAPIKey: "YOUR_API_KEY", appUserId: "user_id", runningMode: .full, logLevel: .debug)
```

```kotlin
// Android
Purchasely.start(applicationContext, "YOUR_API_KEY", "user_id", PLYRunningMode.Full, PLYLogLevel.DEBUG)
```

```typescript
// React Native
Purchasely.start({ apiKey: 'YOUR_API_KEY', userId: 'user_id', runningMode: RunningMode.FULL, logLevel: LogLevel.DEBUG });
```

```dart
// Flutter
Purchasely.start(apiKey: 'YOUR_API_KEY', userId: 'user_id', runningMode: PLYRunningMode.full, logLevel: PLYLogLevel.debug);
```

Parameters:
- **apiKey** (required): your Purchasely API key
- **appUserId** (optional at start, can set later with `userLogin`)
- **runningMode**: `.full` or `.paywallObserver`
- **logLevel**: use `.debug` during development

## Paywall Display

Always use `fetchPresentation()` then display the result. Never use deprecated `presentationView`.

```swift
// iOS
let controller = try await Purchasely.fetchPresentation(for: "PLACEMENT_ID")
present(controller, animated: true)
```

```kotlin
// Android
val presentation = Purchasely.fetchPresentation("PLACEMENT_ID")
supportFragmentManager.beginTransaction()
    .replace(R.id.container, presentation.fragment)
    .commit()
```

Handle ALL presentation types:
- **NORMAL** — display the paywall
- **FALLBACK** — display (cached paywall, server unreachable)
- **DEACTIVATED** — skip display entirely, show nothing
- **CLIENT** — build your own paywall using the returned plans

## Action Interceptor (CRITICAL)

ALWAYS call `processAction()` / `proceed()` in EVERY code path. Skipping it freezes the UI permanently with no error.

```swift
// iOS
Purchasely.setPaywallActionsInterceptor { [weak self] action, parameters, info, proceed in
    switch action {
    case .login:
        self?.showLogin { proceed(true) }
    default:
        proceed(true)  // ALWAYS call proceed
    }
}
```

```kotlin
// Android
Purchasely.setPaywallActionsInterceptor { action, parameters, info, proceed ->
    when (action) {
        PLYPresentationAction.LOGIN -> showLogin { proceed(true) }
        else -> proceed(true)  // ALWAYS call proceed
    }
}
```

```typescript
// React Native
Purchasely.setPaywallActionInterceptor((result) => {
  if (result.action === PLYPaywallAction.LOGIN) {
    showLogin().then(() => Purchasely.onProcessAction(true));
  } else {
    Purchasely.onProcessAction(true); // ALWAYS call
  }
});
```

## Deeplinks

- Use `Purchasely.handleDeeplink(url)` — NOT deprecated `isDeeplinkHandled`
- Set `Purchasely.allowDeeplink = true` only AFTER your root UI is initialized and ready

## User Management

- `Purchasely.userLogin("user_id")` — call after successful authentication
- `Purchasely.userLogout()` — call on sign out
- Pass `appUserId` in `start()` if known at launch; call `userLogin` later otherwise

## Common Mistakes to Avoid

1. **Forgetting `processAction`/`proceed`** — the paywall UI freezes with no error logged
2. **Using deprecated APIs** — `presentationView` and `isDeeplinkHandled` are removed in v6
3. **Not handling DEACTIVATED** — showing a paywall when the server says deactivated breaks A/B tests
4. **Calling SDK methods before `start()`** — all calls silently fail or throw
5. **Not setting `allowDeeplink` after UI init** — deeplinks fire before navigation is ready and are lost

## v6 Migration Notes

Key breaking changes from v5 to v6:
- `presentationView` removed — use `fetchPresentation()` + display
- `isDeeplinkHandled` removed — use `handleDeeplink(url)`
- Presentation callback returns typed `PLYPresentation` with `.type` enum
- Action interceptor signature changed — `proceed` is now mandatory in all paths
- Minimum iOS 15 / Android API 24
- `PLY` prefix standardized on all public types

## Platform Quick Reference

| Feature | iOS | Android | React Native | Flutter |
|---------|-----|---------|--------------|---------|
| Start | `Purchasely.start(...)` | `Purchasely.start(...)` | `Purchasely.start({...})` | `Purchasely.start(...)` |
| Fetch paywall | `fetchPresentation(for:)` | `fetchPresentation(placementId)` | `fetchPresentation({placementId})` | `fetchPresentation(placementId:)` |
| User login | `userLogin(_:)` | `userLogin(userId)` | `userLogin(userId)` | `userLogin(userId)` |
| Deeplink | `handleDeeplink(_:)` | `handleDeeplink(uri)` | `handleDeeplink(url)` | `handleDeeplink(url)` |
| Running mode | `.full` / `.paywallObserver` | `Full` / `PaywallObserver` | `RunningMode.FULL` | `PLYRunningMode.full` |
| Platform enum | `IOS` | `GOOGLE` / `HUAWEI` / `AMAZON` | N/A (auto-detected) | N/A (auto-detected) |

## Testing Checklist

- [ ] `start()` called before any SDK interaction
- [ ] All `processAction`/`proceed` paths covered (no dead branches)
- [ ] DEACTIVATED presentation type handled (no-op, no UI shown)
- [ ] Deeplink handling configured after UI is ready
- [ ] PaywallObserver mode: your purchase flow works alongside SDK observation
