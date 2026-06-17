# Purchasely AI Plugin is available

This project is using the **Purchasely AI Plugin**. You have access to five auto-invoked skills and the `purchasely-sdk-expert` Claude Code agent for free-form Purchasely SDK questions across iOS, Android, React Native, Flutter, and Cordova.

## Skills (auto-invoked when relevant)

- **`purchasely-sdk-expert`** — free-form SDK Q&A: APIs, paywalls, purchases, subscriptions, campaigns, identity, deeplinks, privacy, and SDK behavior.
- **`purchasely-integrate`** — step-by-step SDK integration: install, `Purchasely.start(...)`, paywall display, action interceptor, user login/logout, Restore, Manage Subscription, plus campaigns / promo offers / analytics.
- **`purchasely-review`** — checklist review that audits an existing integration for missing interceptor completions, deprecated APIs, identity ordering, `PrivacyInfo.xcprivacy`, Google Play Billing v8, log-level gating, and more.
- **`purchasely-debug`** — diagnostic flow for blank paywalls, frozen UI, purchase failures, and deeplinks. Includes SDK debug logging, `PLYError` decoding, and the screen-issue-report escalation template.
- **`purchasely-migrate`** — v5 → v6 migration for native iOS, native Android, and Flutter integrations.

## Expert agent

- **`purchasely-sdk-expert`** — Claude Code subagent wrapper around the portable `purchasely-sdk-expert` skill. Use it directly when a subagent is available and the user asks a free-form Purchasely SDK question that is not an integration, review, debug, or migration workflow.

When the user mentions Purchasely, paywalls, subscriptions, `PLYPresentation`, `userLogin`, or related concepts, load the matching skill or route to `purchasely-sdk-expert` before answering. The wrapper class pattern (`PurchaselyService`, `IAPManager`, …) is a **recommendation**, not a requirement — direct `Purchasely.*` calls anywhere in the app are fully supported.
