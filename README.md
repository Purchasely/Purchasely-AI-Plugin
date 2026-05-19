# Purchasely AI Plugin

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-D97757)](https://docs.anthropic.com/en/docs/claude-code/plugins)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20Android%20%7C%20React%20Native%20%7C%20Flutter%20%7C%20Cordova-lightgrey)](#supported-platforms)

> AI-powered assistant for integrating, reviewing, and debugging the [Purchasely](https://www.purchasely.com) SDK across **iOS**, **Android**, **React Native**, **Flutter**, and **Cordova**.

A **Claude Code plugin** that bundles:

- **4 user-invoked slash commands** — `/purchasely:integrate`, `/purchasely:review`, `/purchasely:debug`, `/purchasely:question`
- **3 auto-invoked skills** — `integrate`, `review`, `debug` (Claude loads them automatically when relevant; `/purchasely:question` is a slash command only, not a skill — it routes any free-form SDK question to the expert agent)
- **1 expert agent** — `sdk-expert`
- **Pre-built configs** for other AI coding tools (Cursor, Copilot, Windsurf, Codex, Gemini, Mistral)

Works with: **Claude Code** · **Cursor** · **GitHub Copilot** · **Windsurf** · **OpenAI Codex** · **Google Gemini** · **Mistral `vibe`** · **JetBrains AI** · **VS Code + Continue**

---

## What It Does

| Command | Description |
|---------|-------------|
| `/purchasely:integrate` | Step-by-step SDK integration from scratch — installation, initialization, paywall display, action interceptor, user management |
| `/purchasely:review` | Automated 24-point checklist review of your existing integration — finds bugs, deprecated APIs, and missing best practices |
| `/purchasely:debug` | Diagnostic trees for common issues — blank paywalls, frozen UI, purchase failures, deeplink problems |
| `/purchasely:question` | Ask any question about the Purchasely SDK |

## Quick Install

### Option 1 — Claude Code Plugin (best experience)

Inside Claude Code, run the two slash commands below — the first registers the GitHub marketplace, the second installs the `purchasely` plugin from it:

```text
/plugin marketplace add Purchasely/Purchasely-AI-Plugin
/plugin install purchasely@Purchasely-AI-Plugin
```

You get 4 slash commands (`/purchasely:integrate`, `/purchasely:review`, `/purchasely:debug`, `/purchasely:question`), an `sdk-expert` agent, and 3 skills that Claude invokes automatically when relevant.

To update later, re-run `/plugin marketplace update Purchasely-AI-Plugin` then `/plugin update purchasely`.

### Option 2 — Install Script (all tools)

Clone the repo and run the POSIX-compatible installer. It auto-detects which AI coding tools you have and installs the right config for each one:

```bash
git clone https://github.com/Purchasely/Purchasely-AI-Plugin.git
cd Purchasely-AI-Plugin

# Auto-detect installed AI tools and install configs in the current directory
./install.sh

# Install for a specific tool in a target project
./install.sh --tool cursor --project /path/to/your/app

# Install for every detected tool without prompting
./install.sh --all --project /path/to/your/app
```

Supported `--tool` values: `claude`, `cursor`, `copilot`, `windsurf`, `codex`, `gemini`, `mistral`.

### Option 3 — Manual Setup Per Tool

<details>
<summary><strong>Cursor</strong></summary>

```bash
mkdir -p .cursor/rules
cp configs/cursor/purchasely.mdc .cursor/rules/purchasely.mdc
```

The rules activate automatically when you edit Swift, Kotlin, TypeScript, Dart, or JavaScript files.
</details>

<details>
<summary><strong>GitHub Copilot</strong></summary>

```bash
mkdir -p .github
cp configs/copilot/copilot-instructions.md .github/copilot-instructions.md
```

If you already have a `copilot-instructions.md`, append the content instead:

```bash
printf "\n---\n" >> .github/copilot-instructions.md
cat configs/copilot/copilot-instructions.md >> .github/copilot-instructions.md
```
</details>

<details>
<summary><strong>Windsurf / Codeium</strong></summary>

```bash
cp configs/windsurf/.windsurfrules .windsurfrules
```
</details>

<details>
<summary><strong>OpenAI Codex (and any tool reading <code>AGENTS.md</code>)</strong></summary>

```bash
cp configs/codex/AGENTS.md AGENTS.md
```

`AGENTS.md` is the emerging cross-vendor standard ([agents.md](https://agents.md)). Tools like Codex, Cursor, Zed, and others read it automatically.
</details>

<details>
<summary><strong>Google Gemini CLI</strong></summary>

```bash
cp configs/gemini/GEMINI.md GEMINI.md
```
</details>

<details>
<summary><strong>Mistral <code>vibe</code></strong></summary>

Mistral's coding agent (`vibe`) reads the cross-vendor `AGENTS.md` format:

```bash
cp configs/mistral/AGENTS.md AGENTS.md
# If AGENTS.md already exists (e.g. from Codex), no further action needed —
# `vibe` shares the same file.
```
</details>

<details>
<summary><strong>JetBrains AI Assistant</strong></summary>

1. Open **Settings → Tools → AI Assistant → Project-Level Prompt**
2. Paste the content of `configs/copilot/copilot-instructions.md`
3. Click Apply
</details>

<details>
<summary><strong>VS Code + Continue</strong></summary>

Add to your `.continue/config.json`:

```json
{
  "systemMessageFile": "configs/copilot/copilot-instructions.md"
}
```
</details>

## Usage Examples

### Integrate the SDK into a new app

```
You: /purchasely:integrate ios
AI: Detects Swift project, adds CocoaPods dependency, writes initialization code
    in AppDelegate, sets up paywall display, configures the action interceptor,
    and verifies the integration.
```

### Review an existing integration

```
You: /purchasely:review
AI: Scans your codebase, runs 24 checks, reports:
    PASS  SDK initialized correctly
    FAIL  processAction() not called in LOGIN branch — UI will freeze
    WARN  Using deprecated presentationView() — use fetchPresentation() instead
    PASS  Deeplinks configured correctly
    ...
    Result: 20/24 passed, 2 critical, 2 warnings
```

### Debug an issue

```
You: /purchasely:debug my paywall shows briefly then disappears
AI: Searches for the presentation display code, identifies missing strong
    reference to the view controller, provides the fix.
```

### Ask a question

```
You: /purchasely:question how do I display a paywall in SwiftUI?
AI: Provides a complete SwiftUI example with fetchPresentation + display,
    presentation type handling, and action interceptor setup.
```

## Project Structure

```
Purchasely-AI-Plugin/
├── .claude-plugin/
│   ├── plugin.json              # Claude Code plugin manifest
│   └── marketplace.json         # Marketplace definition
├── skills/                      # AI-invoked skills (automatic)
│   ├── integrate/SKILL.md       # SDK integration guide
│   ├── review/SKILL.md          # Integration review checklist
│   └── debug/SKILL.md           # Debugging diagnostic trees
│                                # (no skill for /purchasely:question — it's
│                                #  a slash command only; see commands/)
├── agents/
│   └── sdk-expert.md            # Purchasely SDK expert agent
├── commands/                    # User-invoked slash commands
│   ├── integrate.md             # /purchasely:integrate
│   ├── review.md                # /purchasely:review
│   ├── debug.md                 # /purchasely:debug
│   └── question.md              # /purchasely:question (free-form Q&A)
├── references/                  # SDK documentation (used by skills)
│   ├── concepts/                # 🌐 Universal SDK concepts (all 5 platforms)
│   ├── testing/                 # Sandbox setup (Apple, Google)
│   ├── troubleshooting/         # Common issues, error codes, debug mode,
│   │                            #  screen-issue-report template
│   ├── ios/                     # iOS: init, API ref, patterns
│   ├── android/                 # Android: init, API ref, patterns
│   ├── react-native/            # React Native integration
│   ├── flutter/                 # Flutter integration
│   ├── cordova/                 # Cordova integration
│   ├── diagrams/                # Architecture diagrams (SVG)
│   ├── architecture-patterns.md
│   ├── cross-platform-subscriptions.md
│   ├── purchasely-architecture.md
│   └── sdk-versions.md          # 📌 Latest stable SDK versions (single source of truth)
├── configs/                     # Pre-generated configs for other tools
│   ├── cursor/purchasely.mdc
│   ├── copilot/copilot-instructions.md
│   ├── windsurf/.windsurfrules
│   ├── codex/AGENTS.md
│   ├── gemini/GEMINI.md
│   └── mistral/AGENTS.md
├── install.sh                   # Auto-installer (detects tools)
├── package.json
├── CHANGELOG.md                 # Keep up to date with every release
├── CONTRIBUTING.md
├── SECURITY.md                  # Vulnerability disclosure process
├── CODE_OF_CONDUCT.md
├── LICENSE                      # MIT
└── README.md
```

### Skill vs slash command

| Trigger | Surface | Description |
|---------|---------|-------------|
| `/purchasely:integrate` | Slash command + matching `integrate` skill | The command launches the skill; the skill is also auto-invoked when Claude detects an SDK integration task |
| `/purchasely:review` | Slash command + matching `review` skill | Same as above |
| `/purchasely:debug` | Slash command + matching `debug` skill | Same as above |
| `/purchasely:question` | **Slash command only** | Free-form SDK Q&A routed to the `sdk-expert` agent — no auto-invoked skill (use the command explicitly) |

## Supported Platforms

| Platform | Install | Init | Paywalls | Interceptor | Deeplinks | User Mgmt |
|----------|---------|------|----------|-------------|-----------|-----------|
| iOS (Swift) | CocoaPods / SPM | `Purchasely.start()` | `fetchPresentation` | `setPaywallActionsInterceptor` | `handleDeeplink` | `userLogin` / `userLogout` |
| Android (Kotlin) | Gradle (Maven) | `Purchasely.Builder()` | `fetchPresentation` | `setPaywallActionInterceptor` | `handleDeeplink` | `userLogin` / `userLogout` |
| React Native | yarn / npm | `Purchasely.start()` | `presentPresentationForPlacement` | `setPaywallActionInterceptorCallback` | `isDeeplinkHandled` | `userLogin` / `userLogout` |
| Flutter | pub.dev | `Purchasely.start()` | `presentPresentationForPlacement` | `setPaywallActionInterceptorCallback` | `isDeeplinkHandled` | `userLogin` / `userLogout` |
| Cordova | cordova plugin | `Purchasely.start()` | `presentPresentationForPlacement` | `onPurchaselyEvent` | `isDeeplinkHandled` | `userLogin` / `userLogout` |

## Requirements

- A [Purchasely](https://www.purchasely.com) account with an API key
- An app configured in the Purchasely Console with at least one placement
- Products/plans configured in your store (App Store Connect, Google Play Console, …)

## Discoverability

This plugin is also published on:

- 🤖 **[agentskill.sh](https://agentskill.sh)** — community marketplace for AI agent skills (search `purchasely`)
- 📦 **Claude Code marketplace** — `/plugin marketplace add Purchasely/Purchasely-AI-Plugin`

## Contributing

Contributions welcome — bug reports, new troubleshooting recipes, platform improvements, and translations to other AI tools.

1. Fork the repository
2. Create a feature branch (`feat/my-improvement`)
3. Update the relevant files in `skills/`, `references/`, or `configs/`
4. Test with Claude Code: `claude --plugin-dir ./Purchasely-AI-Plugin`
5. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines.

## Updating for New SDK Versions

When a new SDK version is released:

1. **Update `references/sdk-versions.md`** — this is the single source of truth for pinned versions. Update the table, the pinned snippets, and the `_Last updated_` date.
2. Update version references in `skills/integrate/SKILL.md` (install section + Step 8 version requirements) and in each platform's `references/<platform>/initialization.md` or `integration.md`.
3. Update `references/` with new/changed APIs (and `references/concepts/` if a universal behavior changed).
4. Update `configs/` with new patterns and rules.
5. Bump `version` in `.claude-plugin/plugin.json` and `package.json`.
6. Add an entry to [CHANGELOG.md](CHANGELOG.md).
7. Tag and release.

## Security

If you find a security issue, please follow the **responsible disclosure process in [SECURITY.md](SECURITY.md)** — do not open a public GitHub issue. The file lists the supported versions, the disclosure contact, and the expected response timeline.

## Changelog

Notable changes to this plugin are tracked in [CHANGELOG.md](CHANGELOG.md). Every PR that adds, changes, or removes user-visible behaviour should update the `[Unreleased]` section.

## License

MIT — see [LICENSE](LICENSE).

## Resources

- [Purchasely Documentation](https://docs.purchasely.com)
- [Claude Code Plugins](https://docs.anthropic.com/en/docs/claude-code/plugins)
- [Cursor Rules](https://docs.cursor.com/context/rules-for-ai)
- [GitHub Copilot Instructions](https://docs.github.com/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot)
- [AGENTS.md spec](https://agents.md)
