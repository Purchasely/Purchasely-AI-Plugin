# Screen Resolution & Rendering Prerequisites

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

Two questions this file answers: **"why does this user see that Screen?"** and **"why does the Screen render wrong on one platform?"**

## Placement resolution order

A Placement resolves in a strict order, and the **first match wins**:

1. The SDK walks the Audiences attached to the Placement **from the highest priority down** (top of the list = highest).
2. The first Audience the user belongs to determines the Screen.
3. If no Audience matches, the Screen attached to ***Everyone else*** is served.
4. A running **A/B test overrides** that result with one of its variants.

So a user can belong to several Audiences and still see only one Screen — the highest-priority one. If the wrong Screen appears, **reorder the Audiences on the Placement** (`⋮` → *Prioritize audiences*) rather than editing the Audiences themselves.

Two distinctions that regularly cause false bug reports:

- **Audience ≠ conditional visibility.** An Audience picks *which Screen* is served; conditional visibility shows or hides *components inside* a Screen. A component that must appear only for some users is conditional visibility, not an Audience.
- **Expired-subscription attributes are only populated for subscriptions Purchasely knows about.** For a user who churned before the integration — or whose subscription was never imported — only `Has expired subscription` is set, computed from the local receipt. Audiences built on the finer expired attributes will not match those users.

To see what actually resolved on a device, use [Debug Mode](../troubleshooting/debug-mode.md): the Debug Panel names the Placement, Audience, A/B test and variant applied. That usually ends the investigation immediately.

> Identity ordering matters: audiences are evaluated with the identity and attributes known **at fetch time**. Call `userLogin` and set attributes **before** fetching — see [user-identity.md](user-identity.md) and [user-attributes-targeting.md](user-attributes-targeting.md).

## No Screen at all

`preload` returns without a presentation, or returns a `DEACTIVATED` type:

1. **The Placement has no Screen assigned**, or the assigned Screen is still a draft.
2. **A higher-priority Audience matches and points to nothing.**
3. **The Placement identifier does not match the Console** — Placement IDs are exact, case-sensitive strings.
4. **The SDK was not started, or started with a blank API key** — in that state it stays inert: no Screen, no analytics, no purchase, and no crash.
5. **It is a draft.** Draft Screens are only visible with Debug Mode enabled on the device.
6. **An A/B test variant intentionally serves no Screen** (paywall vs no-paywall test) — a `DEACTIVATED` presentation is the expected result. See [presentation-types.md](presentation-types.md).

## A published change is not visible in the app

In order of likelihood:

1. **Saved but not published** — drafts are only visible in Debug Mode.
2. **The SDK cached the previous version.** Screens are cached per session: fully close and reopen the app, or dismiss and re-open the paywall so the SDK re-fetches. A screenshot taken without reopening the Screen may predate the change entirely.
3. **The Placement resolves to a different Screen than expected** — an Audience or a running A/B test overrides the default.
4. **A/B test in progress** — a user already bucketed keeps their variant, by design.

## Custom fonts — the font must exist in the native project

Screens are rendered with **native** iOS and Android components, so the font has to be in the **native project**. The font file uploaded in the Console is used **only for the Composer preview** — it is never shipped to the device.

A custom font works only if all three are true:

1. The font is added to the **iOS project** (registered in `Info.plist` under `UIAppFonts`) **and** to the **Android project** (`main/assets` or, preferably, `res/font`).
2. The **iOS font name** field in the Console matches the font's internal **PostScript name** — *not* the filename. Renaming the file does nothing: iOS resolves fonts by internal metadata. Read the real name with `UIFont.familyNames` then `UIFont.fontNames(forFamilyName:)`.
3. The **Android font name** field matches the resource name (verify with `ResourcesCompat.getFont(context, R.font.myfont)`).

If one platform is missing the font, the OS **silently substitutes a fallback** — which changes line height and wrapping, and is the usual cause of **multiline text clipped on one platform only**.

On React Native / Flutter / Cordova, the font still has to be added to the underlying **iOS and Android host projects**.

## Prices render as a dash or empty

The Screen renders but the price placeholder cannot resolve. Work down this list:

1. **The Plan is not mapped to a store product** for the platform under test — a Plan mapped only to iOS shows nothing on Android.
2. **The store product is not purchasable yet.** App Store: at least "Ready to Submit", with a completed price schedule and an accepted paid apps agreement. Google Play: product **active** and app published on at least one track.
3. **The tester's account is not eligible** — a sandbox account on another storefront resolves no price (and often returns USD, see [testing/README.md](../testing/README.md)).
4. **Android only — a Google Play Billing dependency conflict.** Prices fine on iOS but not Android is the classic signature; on SDK 5.x this is the `billing` vs `billing-ktx` conflict. On React Native / Flutter / Cordova, the main package and the Google package must be on the **exact same version**.
5. **The SDK failed to start.** Prices come from the store, but the Plan mapping comes from Purchasely — check the `start()` error and enable debug logs.

## Expected platform differences (not bugs)

- **Font metrics** — same font, different line heights and fallback behavior per platform.
- **Store-formatted strings** — prices, durations, renewal terms are formatted by the store.
- **Safe area / notch handling**, nav bar and status bar treatment follow each platform's conventions.

A layout that is wrong on **one platform only** is worth reporting with the [screen issue report template](../troubleshooting/screen-issue-report.md), including screenshots from both platforms in light and dark mode.

## See also

- [localization.md](localization.md) — Screen content vs `ply_*` system strings
- [rendering-engine.md](rendering-engine.md) — native component tree, image cache, Lottie bridge
- [presentation-types.md](presentation-types.md) — `DEACTIVATED` / `FALLBACK` guards
- [user-attributes-targeting.md](user-attributes-targeting.md) — attributes used for audience matching
- [../console-and-data.md](../console-and-data.md) — Audiences, A/B tests and dashboards on the Console side
