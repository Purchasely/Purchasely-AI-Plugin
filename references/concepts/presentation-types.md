# `PLYPresentationType` — Universal Type Guard

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

Every call to `Purchasely.fetchPresentation(...)` resolves with a `PLYPresentation` whose `type` field tells you what the dashboard returned. **You must check the type before displaying** — calling `display(...)` on a `DEACTIVATED` presentation is undefined behaviour and a `CLIENT` presentation isn't a real paywall at all.

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
| React Native | `Purchasely.PresentationType.NORMAL` / `.FALLBACK` / `.DEACTIVATED` / `.CLIENT` |
| Flutter | `PLYPresentationType.normal` / `.fallback` / `.deactivated` / `.client` |
| Cordova | String values: `'NORMAL'`, `'FALLBACK'`, `'DEACTIVATED'`, `'CLIENT'` |

## Fetch + guard pattern

### iOS (Swift)

```swift
Purchasely.fetchPresentation(for: "PREMIUM_PAYWALL") { presentation, error in
    guard let presentation = presentation else { return }
    switch presentation.type {
    case .normal, .fallback:
        guard let controller = presentation.controller else { return }
        UIApplication.shared.topViewController()?.present(controller, animated: true)
    case .deactivated:
        // Dashboard disabled this presentation — skip
        return
    case .client:
        // Build your own UI from presentation.plans
        showCustomPaywall(plans: presentation.plans)
    @unknown default:
        break
    }
} completion: { result, plan in
    // purchase outcome
}
```

### Android (Kotlin)

```kotlin
Purchasely.fetchPresentation("PREMIUM_PAYWALL") { presentation, error ->
    if (presentation == null) return@fetchPresentation
    when (presentation.type) {
        PLYPresentationType.NORMAL,
        PLYPresentationType.FALLBACK -> presentation.display(activity)
        PLYPresentationType.DEACTIVATED -> { /* skip */ }
        PLYPresentationType.CLIENT -> showCustomPaywall(presentation.plans)
    }
}
```

### React Native (TypeScript)

```ts
const presentation = await Purchasely.fetchPresentation({
  placementId: 'PREMIUM_PAYWALL',
});

switch (presentation.type) {
  case Purchasely.PresentationType.NORMAL:
  case Purchasely.PresentationType.FALLBACK: {
    const result = await Purchasely.presentPresentation({ presentation });
    handleResult(result);
    break;
  }
  case Purchasely.PresentationType.DEACTIVATED:
    return; // skip silently
  case Purchasely.PresentationType.CLIENT:
    showCustomPaywall(presentation.plans);
    break;
}
```

### Flutter (Dart)

```dart
final presentation = await Purchasely.fetchPresentation(
  placementId: 'PREMIUM_PAYWALL',
);

switch (presentation.type) {
  case PLYPresentationType.normal:
  case PLYPresentationType.fallback:
    final result = await Purchasely.presentPresentation(presentation);
    handleResult(result);
    break;
  case PLYPresentationType.deactivated:
    return;
  case PLYPresentationType.client:
    showCustomPaywall(presentation.plans);
    break;
}
```

### Cordova (JavaScript)

```js
Purchasely.fetchPresentation(
  { placementId: 'PREMIUM_PAYWALL' },
  presentation => {
    switch (presentation.type) {
      case 'NORMAL':
      case 'FALLBACK':
        Purchasely.presentPresentation(
          { presentation },
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

## See also

- [presentation-cache.md](presentation-cache.md) — caching fetch results to avoid stuck-paywall issues
- [paywall-actions.md](paywall-actions.md) — what happens when the user interacts with the displayed presentation
