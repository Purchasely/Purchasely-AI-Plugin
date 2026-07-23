# Rendering Engine — How Purchasely Renders a Screen

Applies to: **iOS and Android native paywall rendering**. React Native, Flutter and Cordova paywalls are rendered by whichever native engine (iOS or Android) is hosting them — there is no cross-platform rendering code to configure.

A Screen Composer paywall arrives from the backend as JSON and is turned into on-screen UI by a native rendering engine. Knowing how that engine decodes, caches and renders a screen is useful when debugging blank paywalls, missing components, stale images, or silent Lottie failures.

## iOS (UIKit, current engine)

The JSON payload decodes into a recursive tree of `PLYComponent` — a Swift enum covering the **13 component types** a Screen can contain (containers, labels, images, buttons, video, carousel, Lottie, etc.). Each node in that tree lazily builds (or returns a cached) UIKit view via a `view()` call; the whole tree is built recursively in one synchronous pass when the presentation is configured.

### Tolerant decoding (`Safe<T>`)

Most fields decode through a `Safe<T>` wrapper: a malformed value degrades to `nil` for that one field instead of failing the enclosing decode, so one bad node doesn't take down the rest of the screen. This tolerance does **not** apply everywhere — three exceptions matter for debugging:

| Exception | Behavior when malformed |
|-----------|--------------------------|
| Root component (unrecognized `type`) | The **entire paywall** fails to decode — the root is the one node that isn't wrapped in `Safe<T>` |
| Scroll container content / direction | Not tolerant — a malformed value fails that container |
| Video / Lottie animation URLs | Not tolerant — a malformed URL fails that field, not just degrades |

Everything else (colors, gradients, enum strings, nested styles) silently drops to a default or `nil` on a bad value, with no error surfaced to the Screen author beyond "the field didn't apply."

### View memoization

Each component memoizes its built UIKit view behind a **weak** reference — first call builds it, later calls on the same model instance return the cached view. Only the currently-displayed presentation holds a **strong** reference to the root view, which is what keeps the whole tree alive across in-place reconfigures (e.g. rotation) without leaking across a full re-fetch.

### Image cache

- **Memory cache** — holds compressed image *data*, not decoded `UIImage`s.
- **Disk cache** — a dedicated `URLCache` at `10 MB` memory / `100 MB` disk, isolated from `URLCache.shared` so it never competes with the host app's own networking.
- **Request dedup** — concurrent requests for the same URL are coalesced.

Gotchas:

- **DEBUG builds on iOS 18.4 / 18.5**: the session is forced to `.ephemeral` on that specific OS/build-config combination, which ignores the configured `URLCache` entirely — disk persistence silently stops applying. Release builds and other OS versions are unaffected.
- **Cache hits decode synchronously on the main thread.** A memory/disk cache hit still decodes the image data into a bitmap on the main thread every time that state is applied — on a screen with many cached images this can show up as UI hitches, not just cold-load latency.

### Lottie bridge

The SDK never links `lottie-ios` — it resolves an integrator-supplied `PLYLottieBridge` class at runtime via `NSClassFromString("PLYLottieBridge")`. If the class is missing or doesn't implement the expected bridge methods, the Lottie component **renders nothing** — no crash, no placeholder, only an error log. See [lottie-animations.md](lottie-animations.md) for the bridge implementation.

### Known rendering bugs (6.0.0)

Useful when debugging a specific symptom against this SDK version:

| Symptom | Cause |
|---------|-------|
| Video ignores `"autoplay": false` | The field is decoded but never read — the player always calls `.play()` unconditionally |
| Spinner stuck after canceling a purchase | Happens when the `purchase` action is configured on **both** a container and a child label — one tap fires two `PURCHASE_TAPPED` events. Configure the purchase action once, on the element that owns the loader |

### Future: SwiftUI renderer

A SwiftUI rendering engine is planned but **not started**. UIKit remains the default and only shipping engine — there is no integrator-facing impact today, and no timeline to plan around yet.

## Android (Views, current engine)

Android renders paywalls with plain **Android Views / Fragments** — there is no Jetpack Compose rendering path in 6.0.1.

### Fat-AAR distribution

Internal modules (`:common`, `:network`, `:storage`, etc.) are folded into the single published artifact, `io.purchasely:core` — there is no new Maven coordinate to add, and every public `io.purchasely.*` FQN stays stable across the modularization. The on-disk storage format is also unchanged, so upgrading does not put cached data or stored subscriptions at risk.

A Compose rendering engine is in active development for a future release — don't rely on it or design around it yet.

## Events & rendering

Since **6.0.0-rc.3**, `PRESENTATION_VIEWED` is protected from the SDK's local event-eviction: the local event cap was raised from 100 to 200, and `PRESENTATION_VIEWED` is exempted from FIFO eviction specifically. Builds before rc.3 could silently drop this event under high-volume Flows (many steps viewed in quick succession) once the local cap was hit.

## See also

- [lottie-animations.md](lottie-animations.md) — Lottie bridge setup (iOS `PLYLottieBridge`, Android `PLYLottieInterface`)
- [presentation-cache.md](presentation-cache.md) — app-side presentation caching, separate from the engine's internal image cache
- [presentation-types.md](presentation-types.md) — guarding `NORMAL` / `FALLBACK` / `DEACTIVATED` before display
- [../troubleshooting/common-issues.md](../troubleshooting/common-issues.md) — blank paywall / frozen UI diagnostic trees
