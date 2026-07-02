# Presentation Type — Universal Type Guard

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

Every fetched/preloaded presentation carries a `type` field telling you what the dashboard returned. **You must check the type before displaying** — calling `display(...)` on a `DEACTIVATED` presentation is undefined behaviour and a `CLIENT` presentation isn't a real paywall at all. Native iOS/Android, React Native and Flutter v6 obtain the presentation with `PLYPresentationBuilder` / the `PLYPresentation { }` DSL / `Purchasely.presentation....build()` / `PresentationBuilder` + `preload`; the v5 Cordova bridge still calls `Purchasely.fetchPresentationForPlacement(...)`.

## The four types

| Type | Meaning | Action |
|------|---------|--------|
| `NORMAL` | A real paywall returned by the dashboard. | Display it. |
| `FALLBACK` | A fallback paywall (network issue, original not found, or audience targeting fell through). | Display it — fallbacks exist to ensure the user always sees something. |
| `DEACTIVATED` | The presentation was disabled on the dashboard for this user / audience / placement. | **Do NOT display.** Skip silently or send the user elsewhere. |
| `CLIENT` | Client-side presentation — the dashboard returned **only the data** (plans, products, metadata) but expects **your own UI**. | Build your own paywall with `presentation.plans`. |

> **Naming gotcha:** the placement ID string must match the Console exactly. Typos silently return a `DEACTIVATED` presentation.

## Casing reference

| Platform | Enum |
|----------|------|
| iOS | `PLYPresentationType.normal` / `.fallback` / `.deactivated` / `.client` |
| Android | `PLYPresentationType.NORMAL` / `.FALLBACK` / `.DEACTIVATED` / `.CLIENT` |
| React Native | `PLYPresentationType.NORMAL` / `.FALLBACK` / `.DEACTIVATED` / `.CLIENT` |
| Flutter | `PresentationType.normal` / `.fallback` / `.deactivated` / `.client` |
| Cordova | String values: `'NORMAL'`, `'FALLBACK'`, `'DEACTIVATED'`, `'CLIENT'` |

## Fetch + guard pattern

### iOS (Swift)

```swift
let presentation = try await PLYPresentationBuilder
    .forPlacementId("PREMIUM_PAYWALL")
    .onDismissed { outcome in /* purchase outcome via outcome.purchaseResult */ }
    .build()
    .preload()

guard let presentation = presentation else { return }
switch presentation.type {
case .normal, .fallback:
    presentation.display(from: self)
case .deactivated:
    // Dashboard disabled this presentation — skip
    return
case .client:
    // Build your own UI from presentation.plans
    showCustomPaywall(plans: presentation.plans)
@unknown default:
    break
}
```

If the app explicitly needs to own the container (embedded `UIViewController`, custom `UIWindow`, nested inline Screen in an article/list, or push inside an existing navigation stack), use `presentation.controller` (UIKit) or `presentation.swiftUIView` (SwiftUI) instead of `display(from:)`. For regular modal/full-screen Flow display, prefer `display(from:)` so the SDK owns Flow close controls and step transitions.

### Android (Kotlin)

```kotlin
PLYPresentation { placementId("PREMIUM_PAYWALL") }.preload { loaded, error ->
    if (loaded == null) return@preload
    when (loaded.type) {
        PLYPresentationType.NORMAL,
        PLYPresentationType.FALLBACK -> loaded.display(activity)
        PLYPresentationType.DEACTIVATED -> { /* skip */ }
        PLYPresentationType.CLIENT -> showCustomPaywall(loaded.plans)
    }
}
```

### React Native (TypeScript)

```ts
import Purchasely, { PLYPresentationType } from 'react-native-purchasely';

const request = Purchasely.presentation.placement('PREMIUM_PAYWALL').build();
const presentation = await request.preload();

if (!presentation) {
  return;
}

switch (presentation.type) {
  case PLYPresentationType.NORMAL:
  case PLYPresentationType.FALLBACK: {
    // request.display() shows the preloaded screen and resolves at dismiss
    // with a PLYPresentationOutcome (required for Flows).
    const outcome = await request.display();
    handleResult(outcome);
    break;
  }
  case PLYPresentationType.DEACTIVATED:
    return; // skip silently
  case PLYPresentationType.CLIENT:
    showCustomPaywall(presentation.plans);
    break;
}
```

### Flutter (Dart)

```dart
final request = PresentationBuilder
    .placement('PREMIUM_PAYWALL')
    .build();

final presentation = await request.preload();

if (presentation == null) {
  return;
}

switch (presentation.type) {
  case PresentationType.normal:
  case PresentationType.fallback:
    // display(...) resolves at dismiss with a PresentationOutcome (required for Flows).
    final outcome = await request.display(const Transition.fullScreen());
    handleResult(outcome);
    break;
  case PresentationType.deactivated:
    return;
  case PresentationType.client:
    showCustomPaywall(presentation.plans);
    break;
}
```

### Cordova (JavaScript)

```js
Purchasely.fetchPresentationForPlacement(
  'PREMIUM_PAYWALL',
  null,
  presentation => {
    switch (presentation.type) {
      case 'NORMAL':
      case 'FALLBACK':
        Purchasely.presentPresentation(
          presentation,
          true,
          null,
          result => handleResult(result),
          err => console.error(err),
        );
        break;
      case 'DEACTIVATED':
        return; // skip silently
      case 'CLIENT':
        showCustomPaywall(presentation.plans);
        break;
    }
  },
  err => console.error(err),
);
```

## Why this matters

The dashboard can disable a placement for an audience without redeploying the app. Apps that don't guard the type will:

- Display a deactivated placement (visible to users you wanted to exclude).
- Crash or show a blank screen when the SDK returns `CLIENT` and they call `display()` on it.
- Mis-attribute analytics events when a fallback fires silently.

## Display vs embedded container

Use `display()` / bridge `presentPresentation(...)` by default. Switch to container APIs only when the app explicitly needs to embed or control the Purchasely UI:

| Platform | Default display | Embedded / nested API |
|----------|-----------------|-----------------------|
| iOS | `presentation.display(from:)` | `presentation.controller` (UIKit) / `presentation.swiftUIView` (SwiftUI) |
| Android | `loaded.display(activity)` | `loaded.buildView(context) { outcome -> }` or `loaded.getFragment { outcome -> }` |
| React Native | `request.display()` (on the built `PresentationRequest`) | `<PLYPresentationView placementId=… />` component |
| Flutter | `request.display(const Transition.fullScreen())` | `PLYPresentationView(request: ...)` widget |
| Cordova | `Purchasely.presentPresentation(presentation, isFullscreen, backgroundColor, success, error)` | no general-purpose inline bridge in the public JS API |

## See also

- [presentation-cache.md](presentation-cache.md) — caching fetch results to avoid stuck-paywall issues
- [paywall-actions.md](paywall-actions.md) — what happens when the user interacts with the displayed presentation
