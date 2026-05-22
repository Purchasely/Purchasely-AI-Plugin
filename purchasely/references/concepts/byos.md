# Bring Your Own Screen (BYOS) — Universal Concept

Applies to: **iOS (Swift/SwiftUI) and Android (Kotlin)** — SDK **v5.6.0+** mandatory, **`display()` method required**. React Native / Flutter / Cordova support is planned but not shipped yet.

**BYOS** lets you embed your own native screens directly inside Purchasely Flows (or as standalone steps), so you keep Purchasely's orchestration, navigation, A/B tests and analytics while rendering UI that the Screen Composer cannot build (sign-in, sign-up, text-field forms, legacy paywalls, anything with platform-specific UI).

## When to use BYOS

| Scenario | Why BYOS |
|----------|----------|
| A **login / sign-up step inside a Flow** | The Composer cannot host secure text fields or social SDKs. BYOS lets the app own that step. |
| **A/B test** between an existing native paywall and a Purchasely paywall | Plug the legacy paywall as a BYOS variant — no need to rebuild it. |
| **A/A test** between an existing paywall and its Composer port | Compare the two under identical conditions. |
| **Reorder onboarding steps without code** | Move native screens around in the Console between Purchasely Screens. |
| You want to **show your own screen instead of the Purchasely paywall** for a given placement | BYOS is the supported way to do this. Do **not** push a controller over the Purchasely VC, close the Purchasely VC manually, or skip `display()` — BYOS exists exactly for this. |

## How it works (handover model)

1. The app fetches a Screen / Flow as usual (`fetchPresentation(...)` then `display()`).
2. When the SDK reaches a step whose layout is **Bring Your Own Screen**, it does **not** render it. Instead it invokes your delegate (iOS) / provider (Android) with a `PLYPresentation` carrying:
   - `id` — the Screen ID configured in the Console.
   - `connections` — the list of exit points (each `PLYConnection` has an `id` like `login_successful`, `signup`, `cancel`).
3. Your code instantiates the matching native `UIViewController` / `View` / `Fragment` and returns it.
4. The SDK inserts that view into its navigation layer with the **transition configured in the Console** (modal, push, drawer, full screen, pop-in…). You do **not** present it yourself.
5. While the screen is visible, your app owns all interactions (text input, API calls, validation).
6. When the user completes the step, your code calls **`executeConnection(...)` / `execute(connection)`** on the `PLYPresentation`, passing the matching connection. The SDK then resumes the Flow at the mapped next step.

## Console configuration (recap)

1. Screen Composer → **Create Screen** → layout **Bring Your Own Screen**.
2. Set a **Screen ID** (e.g. `login`, `signup`, `legacy_paywall`) — communicate it to mobile engineers verbatim.
3. Attach a screenshot as the background image so the screen is recognisable in Flow diagrams.
4. Define **Connections** (e.g. `login_successful`, `signup`, `cancel`) — these are the exit points. Mobile engineers need the exact IDs.
5. Insert the Custom Screen anywhere in a Flow and configure transitions on incoming/outgoing connections.

A single Flow can chain multiple Custom Screens (e.g. a multi-step sign-up).

📚 Console guide: <https://docs.purchasely.com/docs/byos-configuration>

## iOS implementation

You can serve either a `UIViewController` (UIKit) **or** a SwiftUI `View`. Both delegates can coexist — the UIKit delegate is called first; if it returns `nil`, the SDK falls back to the SwiftUI one. If neither returns a view, the SDK closes the screen.

### Delegate protocols

```swift
@objc public protocol PLYCustomScreenViewControllerDelegate {
    @objc func viewController(for presentation: PLYPresentation) -> UIViewController?
}

public protocol PLYCustomScreenViewDelegate {
    associatedtype Content: View
    @ViewBuilder func view(for presentation: PLYPresentation) -> Content
}
```

### Registering (after `Purchasely.start(...)`)

```swift
Purchasely.setCustomScreenViewControllerDelegate(myUIKitDelegate)   // UIKit
Purchasely.setCustomScreenViewDelegate(mySwiftUIDelegate)           // SwiftUI

// Clearing
Purchasely.removeCustomScreenViewControllerDelegate()
Purchasely.removeCustomScreenViewDelegate()
```

### Example (SwiftUI + executeConnection)

```swift
public class CustomScreenViewDelegate: PLYCustomScreenViewDelegate {
    @ViewBuilder
    public func view(for presentation: PLYPresentation) -> some View {
        switch presentation.id {
        case "login":
            VStack {
                Spacer()
                Text("Hello Purchasely!")
                Spacer()
                Button("Sign in") {
                    let connection = presentation.connections.first(where: { $0.id == "login_successful" })
                    presentation.executeConnection(connection)
                }
            }
        default:
            EmptyView()  // SDK closes the screen
        }
    }
}
```

### Example (UIKit)

```swift
final class CustomScreenDelegate: NSObject, PLYCustomScreenViewControllerDelegate {
    func viewController(for presentation: PLYPresentation) -> UIViewController? {
        switch presentation.id {
        case "login":
            let vc = LoginViewController()
            vc.onSuccess = {
                let connection = presentation.connections.first(where: { $0.id == "login_successful" })
                presentation.executeConnection(connection)
            }
            return vc
        default:
            return nil
        }
    }
}
```

## Android implementation

You implement a `PLYCustomScreenProvider` that returns a `PLYCustomScreen`, which can wrap either an Android `View` **or** a `Fragment`.

### Provider + sealed class

```kotlin
sealed class PLYCustomScreen {
    data class View(val view: android.view.View) : PLYCustomScreen()
    data class Fragment(val fragment: androidx.fragment.app.Fragment) : PLYCustomScreen()
}

interface PLYCustomScreenProvider {
    fun onCustomScreenRequested(presentation: PLYPresentation): PLYCustomScreen?
}
```

### Registering (after `Purchasely.start(...)`)

```kotlin
Purchasely.setCustomScreenProvider(myProvider)
// To clear: Purchasely.setCustomScreenProvider(null)
```

### Example (View + execute)

```kotlin
class MyProvider(private val context: Context) : PLYCustomScreenProvider {
    override fun onCustomScreenRequested(presentation: PLYPresentation): PLYCustomScreen? {
        return when (presentation.id) {
            "login" -> {
                val connection = presentation.connections.firstOrNull { it.id == "login_successful" }
                val loginView = TextView(context).apply {
                    text = "Sign in"
                    setOnClickListener { presentation.execute(connection) }
                }
                PLYCustomScreen.View(loginView)
            }
            else -> null
        }
    }
}
```

### Example (Fragment)

```kotlin
override fun onCustomScreenRequested(presentation: PLYPresentation): PLYCustomScreen? {
    return when (presentation.id) {
        "signup" -> PLYCustomScreen.Fragment(SignupFragment().apply {
            onComplete = { connection ->
                presentation.execute(presentation.connections.firstOrNull { it.id == connection })
            }
        })
        else -> null
    }
}
```

## `executeConnection(...)` — exiting the Custom Screen

| Platform | Signature |
|----------|-----------|
| iOS | `presentation.executeConnection(_ connection: PLYConnection?)` |
| Android | `presentation.execute(connection: PLYConnection? = null)` |

- Pass the matching connection (e.g. `login_successful`, `cancel`) and the SDK resumes the Flow at the next mapped step.
- Pass `nil` / omit the argument to fall back to the presentation's **default connection** if one is configured.
- **Inside a Flow** → the SDK transitions to the next Screen using the connection's configured transition.
- **Outside a Flow (standalone)** → the SDK runs the action attached to that connection: `Purchase`, `Open Screen`, `Open Placement`, `Deeplink`, `Close`, `Close all`, etc. This makes BYOS usable as a one-off custom paywall replacement, not just as a Flow step.

## Standalone usage (no Flow)

You can drive a Custom Screen on its own — display it via the normal `fetchPresentation(...)` + `display()` path. The delegate/provider is invoked, you build the view, the user taps a button, and you call `executeConnection(...)` with the matching connection. The connection's configured action runs (e.g. open the next placement, close the experience).

## Synchronizing purchases performed in a Custom Screen

If your Custom Screen runs its own billing flow (legacy paywall variant, etc.), call `Purchasely.synchronize()` after a successful transaction so the SDK refreshes its receipt cache and emits the correct events. **Critical for A/B and A/A tests** — without it, conversions are not attributed to the experiment.

```swift
Purchasely.synchronize()
```

```kotlin
Purchasely.synchronize()
```

## Analytics & tracking

- The SDK emits `PRESENTATION_DISPLAYED` for every Custom Screen, with the Screen ID in `displayed_presentation`. Drop-off, transitions, and Flow paths are tracked automatically.
- **Interactions inside the Custom Screen are not tracked by the SDK** — instrument them in your own analytics layer (Firebase, Amplitude, AppsFlyer, etc.).

## Common mistakes BYOS solves

| Anti-pattern | Why it breaks | Fix |
|--------------|---------------|-----|
| "Present my own VC over the Purchasely paywall" | The Purchasely VC is still in the navigation stack — back gestures, dismissals, deeplinks behave incorrectly; Console transitions are bypassed; tracking is missing. | Use BYOS so the SDK owns the navigation. |
| "Call `Purchasely.close()` then push my screen" | Closes the entire experience — the Flow ends, analytics lose context, A/B test sample is wrong. | Use BYOS; the SDK keeps the experience alive and resumes after `executeConnection(...)`. |
| "Skip `display()` and render the Composer screen myself from JSON" | Unsupported; you reimplement navigation, transitions, dismissals, deeplinks, tracking, A/B routing. | Use BYOS — the SDK still renders Purchasely screens, you only own the custom ones. |

## See also

- [paywall-actions.md](paywall-actions.md) — interceptor contract for **rendered** Purchasely Screens (BYOS has its own `executeConnection` contract instead)
- [presentation-types.md](presentation-types.md) — `PLYPresentationType` (BYOS Custom Screens flow through `display()` like any other presentation)
- [sdk-versions.md](../sdk-versions.md) — confirm the integrated SDK is ≥ 5.6.0
- [Official docs — BYOS overview](https://docs.purchasely.com/docs/byos)
- [Official docs — BYOS configuration](https://docs.purchasely.com/docs/byos-configuration)
- [Official docs — BYOS implementation](https://docs.purchasely.com/docs/byos-implementation)
