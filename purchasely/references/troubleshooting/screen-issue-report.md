# Screen Issue Report — Support Escalation Template

> **Source:** [docs.purchasely.com/docs/screen-issue-report-template](https://docs.purchasely.com/docs/screen-issue-report-template)

When a paywall, in-app message, or Flow created in the **Purchasely Screen Composer** behaves incorrectly in your app, the fastest route to a fix is to package the information below before opening a Support ticket. Most "blank paywall" / "missing component" / "wrong offer displayed" tickets are resolved in one round-trip when the report is complete.

## Before escalating — self-checks

Run these first; they catch ~70% of Screen issues without a ticket:

- [ ] **Enable SDK debug logging** — `LogLevel.DEBUG`. Re-run the failing scenario. Grep for `[Purchasely]`. See [debug-mode.md](debug-mode.md) for platform syntax.
- [ ] **Read the log around the failing event** — the SDK announces which placement / presentation / template it resolves to. See [common-issues.md §0](common-issues.md#0-diagnostic-logs--read-before-patching).
- [ ] **Check the Console** — is the Screen published or still draft? Is the placement targeting the right audience? Is there a Campaign overriding the placement?
- [ ] **Activate Debug Mode on the device** — see [debug-mode.md](debug-mode.md). If the issue reproduces in Debug Mode, the Screen itself is at fault. If it doesn't reproduce, the issue is on the integration / targeting side.
- [ ] **Try a sandbox tester** — see [testing/README.md](../testing/README.md). Eliminates production-receipt confusion.

If the issue still reproduces after these steps, fill in the template below.

## Template

Copy the section below into your support request. Don't skip fields — empty fields force a round-trip.

---

```markdown
## 🔗 Screen Reference

- **Link to the Screen in the Purchasely Console:**
  (https://console.purchasely.io/screens/...)

## 👀 Observed Behavior

(What you see — layout misalignment, missing component, wrong offer displayed, blank screen, app crash, stuck modal, etc.)

## 🎯 Expected Behavior

(What you expected to see / happen.)

## 🪄 Steps to Reproduce

1. (Open app → Tap "Subscribe" → Screen fails to load → Error appears)
2. ...
3. ...

## 📸 Visual Evidence

(Attach screenshots and/or a screen recording — both light and dark mode if relevant.)

## 📱 Display Configuration

- **Display method:** (Placement / deeplink / programmatic call / inline paywall / SDK UIHandler / Campaign trigger)
- **Detailed information:**
  - Placement name or ID: ...
  - Deeplink used (if any): ...
  - Campaign name (if any): ...
  - Inline / Flow / full-screen: ...

## 🛠 SDK Configuration

- **Platform:** (iOS / Android / React Native / Flutter / Cordova)
- **SDK version:** (e.g. iOS 5.7.5 — check `references/sdk-versions.md`)
- **For cross-platform — all package versions:**
  - core: ...
  - google: ...
  - player: ...
- **Running mode:** (Full / Observer / paywallObserver)
- **StoreKit version (iOS):** (StoreKit 1 / StoreKit 2)
- **Stores configured (Android):** (Google / Huawei / Amazon)

## 📲 Device & OS

- **Device model:** (e.g. iPhone 15 Pro)
- **OS version:** (e.g. iOS 17.4, Android 14)
- **Build context:** (Debug build / TestFlight / Internal track / Production)

## 🔑 User context

- **App User ID:** (the value passed to `Purchasely.userLogin(...)`, or "anonymous")
- **Subscription state at the time:** (Active / Lapsed / Never subscribed)
- **Active Offer Type:** (None / Free Trial / Intro Offer / Promotional Offer / Promo Code)
- **Relevant user attributes:** (key/value pairs you set via `setUserAttribute`)
- **Audience matches expected:** (which audience defined in the Console you believe the user should match)

## 🔍 Logs

Attach a grep of `[Purchasely]` over the failing run. If the issue involves a Flow or a Campaign, also grep `flow_id`, `campaign_id`, `placement_id`, `displayed_presentation`, `is_fallback_presentation`.

(Paste the relevant lines here.)

## 🌐 Environment

- **Sandbox / TestFlight / Production:** ...
- **Recent changes:** (Did this work before? What changed — SDK upgrade, Screen edit, audience update, etc.)
- **Frequency:** (Always / intermittent / first launch only / specific device only)
```

---

## Why these fields matter

| Field | Why Support asks |
|-------|------------------|
| Screen link | Lets Support inspect the exact Screen build (draft vs published, version history) |
| Observed vs Expected | Disambiguates "bug" from "design decision the Console operator made" |
| Steps to reproduce | Tells Support whether to look at SDK code, Console targeting, or store config |
| Screenshots / recording | Shows whether the issue is rendering (missing component) or logic (wrong offer) |
| Display method | A bug that reproduces via Placement but not via direct presentationId narrows down to audience / targeting |
| SDK version | Many "missing API" tickets are version pins below the feature's minimum (see [sdk-versions.md](../sdk-versions.md)) |
| Plugin alignment | Cross-platform: a `react-native-purchasely 6.0.0-rc.2` + `@purchasely/react-native-purchasely-google 5.6.0` mismatch produces silent rendering bugs — pin every Purchasely package to the exact same version |
| User context | Targeting bugs reproduce only for users matching the broken audience |
| Logs | The SDK log stream usually contains the root cause — see [common-issues.md §0](common-issues.md#0-diagnostic-logs--read-before-patching) |
| Recent changes | An issue that started at a specific date correlates with an SDK upgrade or a Console edit |

## What NOT to send

- ❌ **Production API keys.** Support never needs them. If asked, hand the App ID, not the key.
- ❌ **End-user credentials.** Send the App User ID and the anonymized user attributes — never raw email/password.
- ❌ **Full debug logs without filtering.** Grep `[Purchasely]` first; verbose system logs add noise.
- ❌ **A vague description.** "It doesn't work" cannot be triaged. Use the template.

## See also

- [debug-mode.md](debug-mode.md) — enabling SDK debug logging + Debug Mode preview
- [error-codes.md](error-codes.md) — what each `PLYError` means
- [common-issues.md](common-issues.md) — first-pass self-diagnosis
- [testing/README.md](../testing/README.md) — sandbox setup
- [sdk-versions.md](../sdk-versions.md) — version requirements per API
