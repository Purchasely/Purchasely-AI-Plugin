# CLAUDE.md — purchasely-ai-skill

Repository conventions for anyone (human or LLM) editing this skill.

## Wrapper pattern: name and scope

The "wrapper" pattern (a single dedicated class that owns every call into the Purchasely SDK) is a **recommendation**, not a requirement. The Purchasely SDK is fully usable when called directly from ViewModels, UI code, or anywhere else.

**Rules for any documentation, skill, command, or agent prompt in this repo:**

1. **Mention the wrapper pattern only as a recommendation.** Never present it as mandatory and never frame a direct integration as "wrong" or "broken".
2. **Mention the `PurchaselyWrapper` name only in the dedicated recommendation section** of `references/architecture-patterns.md` (and in similarly explicit "if you adopt the wrapper pattern" contexts). Make it clear the name is just an example — `PurchaselyService`, `PurchaselyGateway`, `IAPManager`, `BillingService`, … any name works. The **concept** is what matters.
3. **Outside those recommendation sections, refer to Purchasely SDK APIs directly** (`Purchasely.fetchPresentation(...)`, `Purchasely.setUserAttribute(...)`, `Purchasely.synchronize(...)`, `PLYPresentation`, etc.). Do not write `purchaselyWrapper.X(...)` or `wrapper.X(...)` in code samples or prose.
4. **Checklists must split** "universal" items (apply regardless of architecture) from "recommended when adopting the wrapper pattern" items. Adoption-conditional items must never appear in the universal section.
5. **The same rule applies to the optional reactive Observer-mode flow and the in-memory presentation cache** — recommendations only, never required.
6. **Code reviewers (the `review` skill) must skip wrapper-related checks when the project does not use a wrapper class** and must not suggest adding one unless the user explicitly asks for an architecture review.

When in doubt, lean on the language: "recommended", "optional pattern", "consider", "best practice for testability and SDK isolation". Avoid: "rule", "must", "always", "required".
