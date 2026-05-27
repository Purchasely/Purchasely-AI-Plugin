# Lottie Animations — Universal Concept

Applies to: **iOS and Android native paywall rendering**. React Native, Flutter and Cordova apps must configure the underlying iOS / Android host projects if their Purchasely Screens use Lottie blocks.

Purchasely supports Lottie animations in Screens, but Lottie is a **weak dependency**: the SDK does not bundle Airbnb Lottie to keep the SDK lightweight. If a Screen contains a Lottie block, the app must provide both:

1. the Lottie dependency in the app, and
2. a small bridge/interface with the stable methods Purchasely calls at runtime.

Official doc: <https://docs.purchasely.com/docs/lottie-animations>

## Console availability

The Lottie option is added template by template in the Purchasely Console. If a team needs Lottie in a template where the option is not visible, contact Purchasely Support rather than trying to fix it in app code.

## Runtime behavior

At runtime the SDK detects Lottie support and inserts the animation view into the paywall. The SDK can configure:

- animation URL,
- repeat vs play once,
- aspect behavior (`fill` / `fit`).

If the bridge is missing, the app can display the paywall but the Lottie animation will not render correctly.

## iOS setup

Add Airbnb Lottie to the app if it is not already present, for example via CocoaPods or SPM (`lottie-ios`, module `Lottie`). Then add a Swift class named `PLYLottieBridge` and expose it to Objective-C with `@objc(PLYLottieBridge)`.

```swift
import UIKit
import Lottie

@objc(PLYLottieBridge)
class PLYLottieBridge: NSObject {
    var animationView: LottieAnimationView?

    @objc class func bridge(with animationURL: URL) -> PLYLottieBridge? {
        let result = PLYLottieBridge()
        result.animationView = LottieAnimationView(url: animationURL, closure: { _ in
            result.animationView?.play()
        }, animationCache: nil)
        result.animationView?.loopMode = .loop
        return result
    }

    @objc func view() -> UIView? {
        return animationView
    }

    @objc func loop(_ loop: Bool) {
        animationView?.loopMode = loop ? .loop : .playOnce
    }

    @objc func fill(_ fill: Bool) {
        animationView?.contentMode = fill ? .scaleAspectFill : .scaleAspectFit
    }

    @objc func play() {
        animationView?.play { _ in }
    }

    @objc func pause() {
        animationView?.pause()
    }

    @objc func stop() {
        animationView?.stop()
    }
}
```

Notes:

- Keep the Objective-C name exactly `PLYLottieBridge`; the SDK looks for that stable bridge.
- If the app already has Lottie, reuse its pinned version unless there is a known incompatibility.

## Android setup

Android support requires Purchasely SDK **3.6.0+**; all current 5.x SDKs qualify. Add Airbnb Lottie to the app if needed:

```kotlin
dependencies {
    implementation("com.airbnb.android:lottie:<app-approved-version>")
}
```

Create a view implementing `PLYLottieInterface`:

```kotlin
import android.animation.ValueAnimator
import android.content.Context
import android.util.Log
import android.widget.ImageView
import androidx.annotation.Keep
import com.airbnb.lottie.LottieAnimationView
import com.airbnb.lottie.LottieDrawable
import io.purchasely.views.presentation.interfaces.PLYLottieInterface

private const val TAG = "PLYLottie"

@Keep
class AnimationView(context: Context) : LottieAnimationView(context), PLYLottieInterface {
    override fun setup(url: String, repeat: Boolean, scaleType: ImageView.ScaleType) {
        setAnimationFromUrl(url)
        enableMergePathsForKitKatAndAbove(true)
        repeatMode = LottieDrawable.RESTART
        repeatCount = if (repeat) ValueAnimator.INFINITE else 0
        this.scaleType = scaleType
        setFailureListener { error ->
            Log.e(TAG, "Unable to load Lottie animation", error)
        }
        play()
    }

    override fun play() {
        playAnimation()
    }

    override fun stop() {
        pauseAnimation()
    }
}
```

Register the factory during app initialization, before displaying paywalls:

```kotlin
Purchasely.lottieView = { context -> AnimationView(context) }
```

## Cross-platform apps

React Native, Flutter and Cordova paywalls are rendered by the native iOS / Android Purchasely SDKs. If a cross-platform app uses Screens with Lottie:

- add the iOS `PLYLottieBridge` + Lottie dependency in the iOS host project;
- add the Android `PLYLottieInterface` implementation + `Purchasely.lottieView` factory in the Android host project;
- keep the cross-platform Purchasely packages aligned with `../sdk-versions.md` as usual.

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Lottie area is blank / static | Native bridge missing or not loaded before the paywall display. |
| Crash or error while loading animation | Add Android `setFailureListener`, check device logs, verify the remote JSON URL is reachable. |
| Animation works in preview but not in app | Confirm the app includes Lottie and the bridge on the target platform. |
| Animation renders badly or not at all | Test the file in LottieFiles Preview and check for unsupported expressions/effects. |
| Memory / rendering issues | Keep Lottie JSON under **2 MB**; larger files can fail or cause memory pressure. |
| Lottie option missing in Console | Feature is enabled template-by-template; ask Purchasely Support for that template. |

## See also

- [screen-issue-report.md](../troubleshooting/screen-issue-report.md) — package a reproducible Composer issue for Support
- [debug-mode.md](../troubleshooting/debug-mode.md) — preview draft Screens on device
- [presentation-types.md](presentation-types.md) — guard `NORMAL` / `FALLBACK` / `DEACTIVATED` before display
