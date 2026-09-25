# iOS UIKit action dispatch and simultaneous gestures

Use this reference for iOS UIKit questions about component taps, nested actions, and label highlights.

## What the source establishes directly

`GenericComponent.view()` attaches an iOS `UILongPressGestureRecognizer` when that component has actions. `PLYZStackComponentView` creates each child by calling the child's `view()`. `GestureDelegate.shouldRecognizeSimultaneouslyWith` returns `true`. Together these code paths support an inference that an action-bearing container and an action-bearing descendant can both recognize a touch in their shared hit area. Treat both actions as possible; do not assume which one runs first or that one overrides the other. The source does not directly specify dispatch order for nested parent/child actions, and this inference should be checked against the affected app and SDK build.

The renderer documentation's explicit example is narrower: a label can have a component-level action recognizer and a separate inline-highlight tap recognizer. When both are configured, both can fire from one physical tap because the recognizers are independent and simultaneous recognition is allowed. The component-level recognizer has a one-second re-tap cooldown; the highlight recognizer does not. This label example is direct documentation; the nested container conclusion above is an inference from the UIKit implementation.

## How to investigate a reported tap

1. Use the action inventory to inspect the tapped component and each action-bearing ancestor. Read each component's full action object; visual nesting alone does not identify which configured actions can recognize the tap.
2. Confirm the public screen ID served by the app's relevant placement and compare it with the screen ID edited or retested. A change to a test copy does not establish that the runtime screen changed.
3. Reproduce on the affected app and SDK build. Report what fired without claiming a deterministic order unless the reproduction establishes it.

Do not conclude that removing one component's action disables an ancestor's action. Check both configurations and retest the screen actually served by the app.

## Source

Internal SDK-renderer provenance: `iOS/Sources/Purchasely/common/Model/UI/GenericComponent.swift` (`view()` action recognizer and `GestureDelegate`), `iOS/Sources/Purchasely/uikit/View/UI/PLYZStackComponentView.swift` (child views), and `iOS/docs/renderer/uikit-rendering-engine.md`, §6.2 and §10 item #13. The documentation's #13 is the label-highlight case; it does not itself prove the nested parent/child inference or an action order.

This provenance note is for internal grounding. Do not cite private SDK file paths to clients. Use the conclusions above with the stated distinction between direct documentation and implementation-based inference.
