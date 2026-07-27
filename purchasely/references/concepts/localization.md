# Localization — Screen Content vs SDK System Strings

Applies to: **iOS, Android, React Native, Flutter, Cordova**.

Official docs: <https://docs.purchasely.com/docs/localizing-your-app>

There are **two separate localization layers**, edited in two different places. Almost every "my string is not translated" ticket is a confusion between them.

| Layer | What it covers | Where it is edited |
|-------|----------------|--------------------|
| **Screen content** | Everything typed in the Screen Composer — titles, CTA labels, benefit lists, FAQ blocks, tags | Console, per Screen, language tab by language tab, or in bulk with **Smart Localization** (CSV of keys × languages) |
| **SDK system strings** | Error alerts, the Restore button, "Already subscribed? Sign in", the Ask to Buy "Waiting for approval" screen | **In the app**: override the `ply_*` keys in `Localizable.strings` (iOS) / `strings.xml` (Android) |

## Consequences that come up in support

- A string that stays in **English while the rest of the Screen is translated** is almost always an **SDK system string** in a language the SDK does not ship. The SDK ships **17 languages** and falls back to English. Screen content supports far more languages.
- A missing translation on a Screen means that **language tab was not filled in** for that component. There is **no automatic per-component fallback** to the default language.
- **Prices, durations and renewal terms are formatted by the store**, not by Purchasely. `{{PRICE}}`, `{{AMOUNT}}`, `{{DURATION}}` and the other tags resolve at display time from the store's localized data — so wording legitimately differs between iOS and Android.
- The app's **default language is chosen at app creation in the Console and cannot be changed afterwards**.
- On React Native / Flutter / Cordova, `ply_*` overrides still go into the **native** iOS and Android projects — there is no JS/Dart-side string table.

## Overriding a system string

```xml
<!-- Android: res/values-fr/strings.xml -->
<string name="ply_modal_alert_in_app_deferred_title">En attente d\'approbation</string>
```

```swift
// iOS: fr.lproj/Localizable.strings
"ply_modal_alert_in_app_deferred_title" = "En attente d'approbation";
```

Keys keep the `ply_` prefix and must match exactly; a typo silently falls back to the SDK's own value.

## Forcing a language instead of following the OS

| Platform | API |
|----------|-----|
| iOS | `Purchasely.setLanguage(from: Locale(identifier: "es"))` |
| Android | `Purchasely.language = Locale("es")` |
| React Native | `Purchasely.setLanguage('es')` |
| Flutter | `Purchasely.setLanguage('es')` |
| Cordova | `Purchasely.setLanguage('es')` |

Set it **before** fetching or displaying a presentation — the language is resolved at fetch time, so changing it afterwards does not relabel an already-loaded Screen. Re-fetch after a language switch.

## Anti-patterns

- ❌ Expecting the Console to translate SDK system strings — they live in the app bundle.
- ❌ Expecting a per-component fallback on a Screen — an empty language tab renders empty.
- ❌ Reporting a store-formatted price or duration as a translation bug.
- ❌ Calling `setLanguage` after `display()` and expecting the visible Screen to change.

## See also

- [screen-resolution.md](screen-resolution.md) — custom fonts, and clipped text caused by font substitution
- [rendering-engine.md](rendering-engine.md) — how a Screen is rendered natively
- [monthly-commitment.md](monthly-commitment.md) — `{{MONTHLY_AMOUNT}}` / `{{PRICE}}` pricing tags
