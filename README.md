# Purchasely AI Plugin

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-D97757)](https://docs.anthropic.com/en/docs/claude-code/plugins)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20Android%20%7C%20React%20Native%20%7C%20Flutter%20%7C%20Cordova-lightgrey)](#supported-platforms)

> AI-powered assistant for integrating, reviewing, and debugging the [Purchasely](https://www.purchasely.com) SDK across **iOS**, **Android**, **React Native**, **Flutter**, and **Cordova**.

A cross-harness plugin that bundles:

- **4 slash commands** — `/purchasely:integrate`, `/purchasely:review`, `/purchasely:debug`, `/purchasely:question`
- **3 auto-invoked skills** — `integrate`, `review`, `debug`
- **1 expert agent** — `sdk-expert`
- **Cross-vendor manifests** — `.claude-plugin/`, `.cursor-plugin/`, `.agents/plugins/`, `purchasely/.claude-plugin/`, `purchasely/.codex-plugin/`, `AGENTS.md`, `GEMINI.md`, `gemini-extension.json`

Works with **Claude Code**, **Codex CLI**, **Codex App**, **Cursor**, **Gemini CLI**, **OpenCode**, and **AGENTS.md-compatible harnesses**.

---

## Quickstart

Pick the block matching your harness. Each one is copy-paste-able as is.

### Claude Code

```text
/plugin marketplace add Purchasely/Purchasely-AI-Plugin
/plugin install purchasely@Purchasely-AI-Plugin
```

Claude reads `.claude-plugin/marketplace.json`, which points at the self-contained `purchasely/` plugin folder.

### Codex CLI

```text
codex plugin marketplace add Purchasely/Purchasely-AI-Plugin
```

Start Codex, run `/plugins`, search for `purchasely`, and install it. Codex reads `.agents/plugins/marketplace.json` and `purchasely/.codex-plugin/plugin.json` from this repository.

### Codex App

Install the same marketplace first:

```bash
codex plugin marketplace add Purchasely/Purchasely-AI-Plugin
```

Then open **Plugins** in the Codex App, select the Purchasely marketplace, and install `purchasely`.

### Cursor

Add this repository as a Cursor plugin marketplace, then install the `purchasely` plugin. Cursor reads `.cursor-plugin/marketplace.json`, `.cursor-plugin/plugin.json`, and `skills/` from this repository.

For local testing before marketplace publication:

```bash
mkdir -p ~/.cursor/plugins/local/purchasely
cp -R . ~/.cursor/plugins/local/purchasely
```

Restart Cursor or run **Developer: Reload Window**.

### Gemini CLI

```bash
gemini extensions install https://github.com/Purchasely/Purchasely-AI-Plugin
```

Backed by `gemini-extension.json` + `GEMINI.md` at the repository root. To update later:

```bash
gemini extensions update purchasely
```

### OpenCode

See [`.opencode/INSTALL.md`](.opencode/INSTALL.md). TL;DR — add to your `opencode.json`:

```json
{ "plugin": ["purchasely@git+https://github.com/Purchasely/Purchasely-AI-Plugin.git"] }
```

### AGENTS.md-compatible harnesses

Tools that read the repository-level `AGENTS.md` should use this repository directly. `AGENTS.md` is intentionally only a bootstrap that points to the canonical `skills/` playbooks.

## What It Does

| Command | Description |
|---------|-------------|
| `/purchasely:integrate` | Step-by-step SDK integration from scratch — installation, initialization, paywall display, action interceptor, user management |
| `/purchasely:review` | Automated 24-point checklist review of your existing integration — finds bugs, deprecated APIs, and missing best practices |
| `/purchasely:debug` | Diagnostic trees for common issues — blank paywalls, frozen UI, purchase failures, deeplink problems |
| `/purchasely:question` | Ask any question about the Purchasely SDK |

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
├── .cursor-plugin/
│   ├── plugin.json              # Cursor plugin manifest
│   └── marketplace.json         # Cursor marketplace definition
├── .agents/plugins/
│   └── marketplace.json         # Codex repo marketplace definition
├── AGENTS.md                    # Cross-vendor agents.md (Codex, Cursor, Zed, Mistral, …)
├── GEMINI.md                    # Gemini CLI context (imports skills via @./skills/...)
├── gemini-extension.json        # `gemini extensions install` manifest
├── skills/                      # AI-invoked skills (automatic)
│   ├── integrate/SKILL.md
│   ├── review/SKILL.md
│   └── debug/SKILL.md
├── agents/
│   └── sdk-expert.md            # Purchasely SDK expert agent
├── commands/                    # User-invoked slash commands
│   ├── integrate.md
│   ├── review.md
│   ├── debug.md
│   └── question.md
├── purchasely/
│   ├── .claude-plugin/
│   │   └── plugin.json          # Claude Code plugin manifest
│   ├── .codex-plugin/
│   │   └── plugin.json          # OpenAI Codex plugin manifest
│   ├── skills -> ../skills
│   ├── references -> ../references
│   ├── commands -> ../commands
│   ├── hooks -> ../hooks
│   └── agents -> ../agents
├── references/                  # SDK documentation (used by skills)
│   ├── concepts/                # 🌐 Universal SDK concepts (all 5 platforms)
│   ├── testing/                 # Sandbox setup (Apple, Google)
│   ├── troubleshooting/         # Common issues, error codes, debug mode
│   ├── ios/  android/  react-native/  flutter/  cordova/
│   ├── diagrams/                # Architecture diagrams (SVG)
│   ├── architecture-patterns.md
│   ├── cross-platform-subscriptions.md
│   ├── purchasely-architecture.md
│   └── sdk-versions.md          # 📌 Latest stable SDK versions (single source of truth)
├── package.json
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── CODE_OF_CONDUCT.md
├── LICENSE
└── README.md
```

### Skill vs slash command

| Trigger | Surface | Description |
|---------|---------|-------------|
| `/purchasely:integrate` | Slash command + matching `integrate` skill | The command launches the skill; the skill is also auto-invoked when Claude detects an SDK integration task |
| `/purchasely:review` | Slash command + matching `review` skill | Same as above |
| `/purchasely:debug` | Slash command + matching `debug` skill | Same as above |
| `/purchasely:question` | **Slash command → agent** | Free-form SDK Q&A — the command explicitly delegates to the `purchasely:sdk-expert` agent via the `Task` tool. No matching auto-invoked skill (use the command explicitly) |

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

See [`docs/distribution.md`](docs/distribution.md) for the public roadmap of every official marketplace we're targeting (Anthropic, OpenAI Codex, Factory Droid, GitHub Copilot CLI, …) and how to help land each one.

## Contributing

Contributions welcome — bug reports, new troubleshooting recipes, platform improvements, and translations to other AI tools.

1. Fork the repository
2. Create a feature branch (`feat/my-improvement`)
3. Update the relevant files in `skills/` or `references/`
4. Test with Claude Code: `claude --plugin-dir ./Purchasely-AI-Plugin`
5. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines.

## Updating for New SDK Versions

When a new SDK version is released:

1. **Update `references/sdk-versions.md`** — single source of truth for pinned versions.
2. Update version references in `skills/integrate/SKILL.md` and each platform's `references/<platform>/`.
3. Update `references/` with new/changed APIs.
4. Bump `version` in `.claude-plugin/plugin.json`, `purchasely/.claude-plugin/plugin.json`, `purchasely/.codex-plugin/plugin.json`, and `package.json`.
5. Add an entry to [CHANGELOG.md](CHANGELOG.md).
6. Tag and release.

## Security

If you find a security issue, please follow the **responsible disclosure process in [SECURITY.md](SECURITY.md)** — do not open a public GitHub issue.

## Changelog

Notable changes to this plugin are tracked in [CHANGELOG.md](CHANGELOG.md). Every PR that adds, changes, or removes user-visible behaviour should update the `[Unreleased]` section.

## License

MIT — see [LICENSE](LICENSE).

## Resources

- [Purchasely Documentation](https://docs.purchasely.com)
- [Claude Code Plugins](https://docs.anthropic.com/en/docs/claude-code/plugins)
- [AGENTS.md spec](https://agents.md)
- [Gemini extensions](https://github.com/google-gemini/gemini-cli)
