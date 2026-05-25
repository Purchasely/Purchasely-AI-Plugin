# Purchasely AI Plugin is available

This project is using the **Purchasely AI Plugin**. You have access to three task-scoped skills and one free-form Q&A command that cover the Purchasely SDK across iOS, Android, React Native, Flutter, and Cordova.

## Skills (auto-invoked when relevant)

- **`purchasely-integrate`** — step-by-step SDK integration: install, `Purchasely.start(...)`, paywall display via `fetchPresentation(...)`, action interceptor, user login/logout, Restore, Manage Subscription, plus campaigns / promo offers / analytics.
- **`purchasely-review`** — 24-point checklist that audits an existing integration for missing `processAction(true)` branches, deprecated APIs, identity ordering, `PrivacyInfo.xcprivacy`, Google Play Billing v8, log-level gating, and more.
- **`purchasely-debug`** — diagnostic flow for blank paywalls, frozen UI, purchase failures, and deeplinks. Includes SDK debug logging (Step 0), `PLYError` decoding (Step 6), and the screen-issue-report escalation template (Step 5).

## Slash command

- **`/purchasely:question`** — free-form SDK Q&A. Routes to the `sdk-expert` agent for anything that doesn't fit the three skills above.

When the user mentions Purchasely, paywalls, subscriptions, `PLYPresentation`, `userLogin`, or related concepts, load the matching skill before answering. The wrapper class pattern (`PurchaselyService`, `IAPManager`, …) is a **recommendation**, not a requirement — direct `Purchasely.*` calls anywhere in the app are fully supported.
