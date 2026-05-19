---
description: "Ask any question about the Purchasely SDK — integration, paywalls, purchases, deeplinks, user attributes, etc."
argument-hint: "<your question>"
---

The user has a question about the Purchasely SDK: **$ARGUMENTS**

Delegate this to the dedicated expert agent: invoke the `Task` tool with `subagent_type: "purchasely:sdk-expert"`. Pass the user's question verbatim, plus any relevant context from this conversation (the user's current platform if known, files they're working on, prior decisions). The agent owns the references in this plugin and will return a focused answer with code samples for the right platform.

Once the agent returns, relay its answer directly to the user — do not re-summarize or paraphrase. If the user asks a follow-up, you may either continue the conversation in the main session (for quick clarifications) or re-invoke the agent (for new questions that need fresh references).
