# Purchasely Debug Mode

> **Source:** [docs.purchasely.com/docs/debug-mode](https://docs.purchasely.com/docs/debug-mode)

Debug Mode is the Purchasely-side tool to **preview draft Screens, Flows, and audiences on a real device** without exposing them to production users. Use it together with sandbox testing — they solve different problems.

## What it enables

- Preview any draft In-App Experience (Paywalls, Screens, Flows) — the **draft** version, not the published one
- Simulate how a Screen integrates with any Placement by targeting the built-in `Internal Testers` audience and giving it the highest priority
- Validate Flows step by step before publishing
- Test multi-language and multi-theme variants

**Scope.** Debug Mode affects only the device on which it is activated. **Zero impact on real audiences or production exposure.**

## SDK debug logging vs Debug Mode

These are two different things — both important for debugging tickets:

| Tool | What it is | When to use |
|------|------------|-------------|
| **SDK debug logging** (`setLogLevel(.debug)`) | Verbose `[Purchasely]` log stream from the SDK at runtime | First thing to enable when diagnosing any integration bug — it shows the symptom→cause chain |
| **Debug Mode** (this doc) | Console-side preview of drafts on an activated device | When validating Screens / Flows / audience targeting **before** publishing |

Enable both together when investigating "the wrong paywall appears" tickets.

### Enabling SDK debug logging

| Platform | Code |
|----------|------|
| iOS (Swift) | `Purchasely.logLevel = .debug` (or pass `logLevel: .debug` to `start`) |
| Android (Kotlin) | `.logLevel(LogLevel.DEBUG)` on the `Purchasely.Builder` |
| React Native (v6) | `.logLevel('debug')` on the `Purchasely.builder(...)` |
| Flutter | `.logLevel(LogLevel.debug)` on the `PurchaselyBuilder` |
| Cordova | `Purchasely.LogLevel.DEBUG` as the 4th argument to `Purchasely.start(...)` |

> **Gate behind a build flag.** Ship `LogLevel.ERROR` (or omit the parameter) in production. Debug logs include placement IDs, audience matches, and presentation IDs — keep them out of production binaries.

## Enabling Debug Mode

> ⚠️ **Deeplink handling is required.** Your app must implement `Purchasely.handleDeeplink(...)` and call `Purchasely.readyToOpenDeeplink(true)` once the app's UI is ready. Without it, the QR code does nothing. See [campaigns.md](../concepts/campaigns.md#sdk-setup--readytoopendeeplink).

### Step 1 — Get the preview QR code

In the Purchasely Console, when editing a Screen, click the **Preview QR Code** button. The QR encodes a Purchasely deeplink carrying the Screen ID and a debug token.

### Step 2 — Scan it on the device

Scan the QR with the device camera (or any QR reader). The OS asks to open the deeplink in your app — confirm.

### Step 3 — The Purchasely Debug Panel opens

The Debug Panel lets you:

- Preview the draft Screen with the current device's language, theme, audience matches
- Switch language / theme / dark-light to validate variants
- Toggle eligibility conditions (e.g. simulate "Active subscriber" / "Lapsed subscriber" / "Trial user")
- Activate Debug Mode on the device — this sets the built-in attribute `debug mode = true`

### Step 4 — Test in your real placements

While Debug Mode is on, the device matches the **Internal Testers** built-in audience. Configure your draft Screen or Campaign to target this audience with the highest priority, then trigger the placement / event in your app. The draft Screen shows up — only on this device.

### Step 5 — Deactivate when done

From the Debug Panel, toggle Debug Mode off. The device is immediately removed from the Internal Testers audience (`debug mode` reverts to `false`). The device is now back to its normal user behaviour.

## `Internal Testers` audience — usage

`Internal Testers` is a **built-in audience** you can use as a targeting condition for:

- A **Placement** — override the default Screen with the draft for testers only
- A **Campaign** — schedule the draft Screen to testers before going live
- An **A/B test** — restrict the experiment to testers

Set its **priority** higher than any other audience the device might match — otherwise the production Screen wins.

## Anti-patterns

- ❌ **Forgetting to deactivate Debug Mode.** Devices left in Debug Mode keep matching Internal Testers — leading to "this user sees the test paywall in production" tickets.
- ❌ **Skipping deeplink setup.** The QR is a deeplink. If `handleDeeplink` isn't wired and `readyToOpenDeeplink(true)` hasn't been called after the splash, nothing happens.
- ❌ **Using Debug Mode to bypass purchase validation.** Debug Mode previews draft Screens; it does **not** simulate purchases. Use [sandbox testing](../testing/README.md) for that.
- ❌ **Testing Debug Mode in a release build with `logLevel = ERROR`.** The Debug Panel works either way, but the SDK debug log stream — your primary diagnostic tool — won't be visible.

## See also

- [testing/README.md](../testing/README.md) — sandbox purchases (Apple / Google)
- [error-codes.md](error-codes.md) — what `PLYError` cases mean
- [common-issues.md](common-issues.md) §0 — reading the SDK log stream
- [screen-issue-report.md](screen-issue-report.md) — escalating a Screen Composer bug to Purchasely Support
- [campaigns.md](../concepts/campaigns.md) — pairing Debug Mode with the Campaigns workflow
