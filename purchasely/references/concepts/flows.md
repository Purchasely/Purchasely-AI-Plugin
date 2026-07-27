# Flows — Multi-Step Journeys, Transitions & Outcome

Applies to: **iOS, Android, React Native, Flutter, Cordova** (BYOS steps: native iOS / Android only).

Official docs: <https://docs.purchasely.com/docs/flows>

A Flow is a sequence of Screens built in the Screen Composer and linked by **Transitions** on the Flow Composer canvas. Everything is configured in the Console — there is **no Flow-specific display API**.

## The golden rule: the SDK must own the display

A Flow only navigates when you hand the presentation to the SDK's own display call.

| Platform | Display call |
|----------|--------------|
| iOS | `PLYPresentationBuilder.forPlacementId("id").build().preload { p, _ in p?.display(from: vc) }` |
| Android | `PLYPresentation { placementId("id") }.display(context)` |
| React Native | `Purchasely.presentation.placement("id").build().display()` |
| Flutter | `PresentationBuilder.placement("id").build().display()` |
| Cordova | `Purchasely.presentation.placement(id).build().display()` |

If you render the presentation yourself — your own container, your own navigation controller, an embedded view — **you lose the Flow navigation**: the journey stops at its first Screen.

Detecting a Flow is possible but rarely needed, since `display()` treats Flows and single Screens identically:

```swift
if presentation.isFlow { /* … */ }        // iOS
```
```kotlin
if (presentation.flowId != null) { /* … */ }   // Android
```

## Transitions only override four action types

A Transition configured in the Flow Composer can only override a component action that is already one of:

- **Open Screen**
- **Open Placement**
- **Deeplink**
- **Web Page**

Any other action value (`purchase`, `close`, `restore`, `login`, `promoCode`, `none`, …) **ignores the Transition**. That is why some components show no transition handle on the canvas.

Two consequences seen in support:

- A button that looks like it should navigate does nothing — its Screen-level action is not in the list above.
- The same Screen shows **unexpected or duplicated buttons** across Flows: Transitions override the Screen-level action, which is exactly what allows a Screen to be reused in several Flows. Check the Screen's own actions, not only the Flow canvas.

## Display Mode vs Transition Type

| Setting | Scope | Configured on |
|---------|-------|---------------|
| **Flow Display Mode** | How the **first** Screen of the Flow opens in the app. Applies only at launch. Defaults to **Full screen**. | The Flow |
| **Screen Transition Type** | Navigation **between** Screens inside the Flow. | Default at Flow level, overridable per Transition |

Available transition types: **Push**, **Modal**, **Drawer**, **Pop-in**, **Full screen**. Drawers and pop-ins take a configurable height.

> ⚠️ **`Push` requires a navigation bar in the parent view.** Without one, the SDK falls back to **Modal on iOS** and **Full screen on Android**. A Screen that appears to sit on top of the previous one instead of pushing is usually this.

> The Display Mode is **not** reflected in the Console preview — the preview always renders the Screen itself. Test Flow opening and navigation on a device with [Debug Mode](../troubleshooting/debug-mode.md).

## Flow outcome — `PLYPresentationOutcome`

There is no Flow-specific result API: a Flow reports through the standard presentation outcome.

| Field | Meaning |
|-------|---------|
| `purchaseResult` | `purchased` / `restored` / `cancelled` (absent or `none` when no purchase action happened) |
| `plan` | The plan involved, when there is one |
| `presentation` | The presentation handle; absent if display was never reached |
| `closeReason` | `button` (close/back button rendered by the paywall), `backSystem` (Android back, iOS swipe-down or nav pop), `programmatic` (your app closed it) |
| `error` | Mutually exclusive with `closeReason` |

Two delivery paths:

- **`onDismissed`** on a specific presentation (local handler), or
- **`setDefaultPresentationDismissHandler`** (global fallback).

> **The local handler wins.** The deciding factor is the *presence* of a local `onDismissed`, not whether you awaited the display call. With a local handler set, the global default does not fire for that presentation.

> **Register the global handler right after `start()`.** Presentations the **SDK opens itself** — deeplinks, Campaigns, promoted in-app purchases — have no display call to await and nowhere to attach `onDismissed`. Their outcome always goes to the global handler; without it, you never learn what happened.

Minimum SDK versions for `PLYPresentationOutcome`: **iOS 6.0.0**, **Android 6.0.1**, **Flutter 6.0.0**, **React Native 6.0.0-rc.2** (GA `6.0.0`). On React Native the global handler covers only SDK-opened presentations, not the ones you display yourself.

## Why a Flow freezes or goes blank

Work through this in order:

1. **`display()` was not used** — see the golden rule above.
2. **A step's action is not overridable**, so the Transition never fires and the Flow has nowhere to go.
3. **The Flow was opened by a deeplink and displayed twice.** Handling the deeplink yourself *and* letting the SDK display it stacks two presentations. Pick one.
4. **A BYOS step never handed control back** — the Custom Screen must call `executeConnection(...)` (iOS) / `execute(connection)` (Android). See [byos.md](byos.md).
5. **A BYOS step returned no view.** On iOS, if the UIKit delegate returns `nil` and there is no SwiftUI delegate (or it returns an empty view), the presentation closes — which reads as a black screen.
6. **`close` vs `closeAll` inside a Flow** — see [common-issues.md § 11](../troubleshooting/common-issues.md).

## Flow analytics

The Flow analysis dashboard renders the journey as a Sankey diagram (date, platform, country filters).

At event level the SDK attaches `flow_id`, `flow_version`, `step_id`, `from_step_id`, `from_action_id` and `flow_session_id`, so the path can be rebuilt in your own warehouse.

## Quiz answers inside a Flow

There is **no dedicated Quiz API**. Enable *Save answer(s) as an Insight Attribute* on the Quiz component, and the answers arrive through the **custom user attribute listener**:

- `key` = the **Quiz ID**
- value = a single `String` (single-answer quiz) or an array of strings (multi-answer)
- `source` = `purchasely`, telling you the attribute came from the SDK rather than from your own code

No per-Quiz SDK code is needed. Forwarding answers to your backend or a third-party tool is entirely app-side — there is no server-to-server integration for Quiz insights.

## Anti-patterns

- ❌ Fetching a Flow presentation and rendering it in your own container "to control the layout" — Flow navigation is lost.
- ❌ Intercepting `open_presentation` / `open_placement` to implement navigation yourself — it breaks A/B test, Audience and Campaign tracking.
- ❌ Relying only on `onDismissed` when Campaigns or deeplinks are enabled — SDK-opened presentations need the global handler.
- ❌ Branching on `isFlow` / `flowId` in normal display code — `display()` already handles both.

## See also

- [presentation-types.md](presentation-types.md) — guard `DEACTIVATED` / `CLIENT` before displaying
- [byos.md](byos.md) — native Custom Screen steps inside a Flow
- [paywall-actions.md](paywall-actions.md) — action kinds, interceptor results, action chaining
- [screen-resolution.md](screen-resolution.md) — which Screen a Placement actually serves
- [campaigns.md](campaigns.md) — Campaign Flows opened by the SDK
- [presentation-cache.md](presentation-cache.md) — preload and `FlowsManager.flowSteps` accumulation
