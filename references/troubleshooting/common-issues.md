# Troubleshooting: Common Issues

## 1. Paywall Not Showing

**Symptoms:** `presentationController` or `fetchPresentation` returns nil/null, paywall never appears.

**Causes and Solutions:**

- **SDK not initialized:** Ensure `Purchasely.start()` has completed successfully before calling any presentation method. Wait for the `success == true` callback.
- **Invalid placement ID:** Verify the placement vendor ID in the Purchasely dashboard matches exactly (case-sensitive).
- **Presentation type is DEACTIVATED:** Always check `presentation.type` before displaying. A deactivated presentation returns valid data but should not be shown.
- **Wrong thread (iOS):** On iOS, `Purchasely.start()` must be called on the main thread. Calling from a background queue can silently fail.
- **No active presentation:** Ensure a presentation is assigned to the placement in the dashboard.

```swift
// iOS: Verify initialization before presenting
Purchasely.start(withAPIKey: "KEY", storekitSettings: .storeKit2) { success, error in
    guard success else {
        print("SDK not ready: \(error?.localizedDescription ?? "")")
        return
    }
    // Now safe to present
}
```

## 2. UI Frozen / Paywall Stuck

**Symptoms:** Paywall buttons stop responding, spinner never dismisses, app appears frozen.

**Cause:** `processAction` (or `onProcessAction` in cross-platform SDKs) was not called in all code paths of the action interceptor.

**Solution:** Ensure every branch in your interceptor calls `processAction(true/false)`:

```swift
// BAD: Missing processAction in error path
Purchasely.setPaywallActionsInterceptor { action, parameters, info, proceed in
    if action == .login {
        showLogin { success in
            if success {
                proceed(true)
            }
            // BUG: proceed() never called when success == false
        }
    }
}

// GOOD: All paths call proceed()
Purchasely.setPaywallActionsInterceptor { action, parameters, info, proceed in
    if action == .login {
        showLogin { success in
            proceed(success)  // Always called
        }
    } else {
        proceed(true)  // Default path covered
    }
}
```

## 3. Purchases Fail

**Symptoms:** Purchase flow starts but fails, error in callback, transaction not completed.

**Causes and Solutions:**

- **Wrong running mode:** In `.observer` / `Observer` mode, the SDK does not process purchases. Either switch to `.full` / `Full` mode, or handle purchases in your action interceptor.
- **Store configuration:** Verify your products are configured correctly in App Store Connect / Google Play Console and match the plan IDs in the Purchasely dashboard.
- **Sandbox account (iOS):** On iOS, ensure you are signed in with a Sandbox Apple ID in Settings > App Store > Sandbox Account.
- **Google Play test track:** On Android, ensure the app is published to at least an internal test track and the test account is added to the testers list.
- **Missing store dependency (Android):** Verify the correct store artifact is included (e.g., `io.purchasely:google-play`).

## 4. Events Fire Twice

**Symptoms:** Analytics events are duplicated, purchase callbacks trigger multiple times.

**Cause:** Event listener registered in a lifecycle method that is called multiple times (e.g., `onResume`, `viewWillAppear`).

**Solution:** Register the listener once, in a method that is called only once:

```kotlin
// BAD: Registered in onResume (called every time activity resumes)
override fun onResume() {
    super.onResume()
    Purchasely.setEventListener { event -> trackEvent(event) }  // DUPLICATE!
}

// GOOD: Registered in onCreate (called once)
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    Purchasely.setEventListener { event -> trackEvent(event) }
}
```

## 5. Wrong Paywall Displayed

**Symptoms:** A different paywall shows than expected, or a fallback paywall appears.

**Causes and Solutions:**

- **Audience targeting:** The user may not match the audience criteria for the expected presentation. Check user attributes and audience rules in the dashboard.
- **A/B test:** The user may be in a different A/B test variant. Check the active A/B test configuration.
- **Placement vs presentation:** A placement can have multiple presentations assigned (audiences, A/B tests). Verify which presentation is active for the target audience.
- **Fallback presentation:** If the primary presentation fails to load (network issue), the SDK shows the fallback. Check `presentation.type == .fallback`.
- **Cache:** The SDK caches presentations. Call `Purchasely.synchronize()` to force a refresh.

## 6. Deeplinks Not Working

**Symptoms:** Tapping a Purchasely deeplink does nothing, or the app opens but no paywall appears.

**Causes and Solutions:**

- **`handleDeeplink` not called:** Ensure you call `Purchasely.handleDeeplink(url)` (iOS) or `Purchasely.handleDeeplink(uri, activity)` (Android) in your deeplink handler.
- **`allowDeeplink` not set:** The SDK queues deeplinks until `allowDeeplink` is set to `true`. Call this when your root view controller / main activity is ready.
- **URL scheme not configured:** Verify the URL scheme or universal link / app link is properly configured in your app settings.
- **SDK not initialized:** If the deeplink arrives before `start()` completes, it will be lost. Initialize the SDK as early as possible.

```swift
// iOS: Handle deeplink in SceneDelegate
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    Purchasely.handleDeeplink(url)
}

// Signal ready
Purchasely.allowDeeplink(true)
```

## 7. User Attributes Not Syncing

**Symptoms:** Audience targeting based on attributes does not work, attributes appear empty in the dashboard.

**Cause:** Attributes set before `start()` completes are lost.

**Solution:** Set attributes only after the SDK initialization callback confirms success:

```kotlin
Purchasely.Builder(applicationContext)
    .apiKey("KEY")
    .stores(listOf(GoogleStore()))
    .build()
    .start { success, error ->
        if (success) {
            // NOW safe to set attributes
            Purchasely.setUserAttribute("tier", "premium")
            Purchasely.setUserAttribute("articles_read", 42)
        }
    }
```

## 8. Paywall Disappears Immediately

**Symptoms:** Paywall flashes on screen and then vanishes.

**Cause:** The view controller or fragment is not strongly referenced and gets deallocated.

**Solutions:**

**iOS:** Hold a strong reference to the controller:

```swift
// BAD: Controller is deallocated immediately
func showPaywall() {
    let vc = Purchasely.presentationController(for: "ONBOARDING")
    present(vc!, animated: true)  // vc may be deallocated
}

// GOOD: Present modally (UIKit retains it) or store as property
var paywallController: UIViewController?

func showPaywall() {
    paywallController = Purchasely.presentationController(for: "ONBOARDING")
    present(paywallController!, animated: true)
}
```

**Android:** Ensure the Fragment is properly attached to a container and the Activity is not finishing:

```kotlin
// Ensure activity is not finishing
if (!isFinishing && !isDestroyed) {
    presentation.display(this)
}
```

## 9. ProGuard Stripping SDK Classes (Android)

**Symptoms:** App crashes on SDK initialization or paywall display in release builds, `ClassNotFoundException` or `NoSuchMethodError`.

**Solution:** Add ProGuard keep rules:

```proguard
# proguard-rules.pro
-keep class io.purchasely.** { *; }
-keep class io.purchasely.ext.** { *; }

# Google Play Billing
-keep class com.android.vending.billing.** { *; }

# Huawei IAP (if applicable)
-keep class com.huawei.hms.iap.** { *; }
```

Verify rules are applied by checking your `build.gradle`:

```kotlin
android {
    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

## 10. App Crashes on SDK Init

**Symptoms:** App crashes immediately on launch after adding the Purchasely SDK.

**Causes and Solutions:**

- **Missing store dependencies (Android):** Ensure you have at least one store artifact. Without `io.purchasely:google-play` (or another store), the SDK cannot initialize.
  ```kotlin
  // Must include at least one store
  implementation("io.purchasely:google-play:+")
  ```

- **Invalid API key:** A malformed or expired API key causes initialization failure. Verify the key in the Purchasely dashboard under Settings > API Keys.

- **Conflicting dependencies (Android):** Check for version conflicts with Google Play Billing or other in-app purchase libraries:
  ```bash
  ./gradlew app:dependencies | grep billing
  ```

- **Missing entitlements (iOS):** Ensure the In-App Purchase capability is enabled in your Xcode project under Signing & Capabilities.

- **Multidex (Android):** If your app exceeds the 64K method limit, enable multidex:
  ```kotlin
  android {
      defaultConfig {
          multiDexEnabled = true
      }
  }
  ```
