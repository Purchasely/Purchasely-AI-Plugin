# Purchasely AI Plugin

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-D97757)](https://docs.anthropic.com/en/docs/claude-code/plugins)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20Android%20%7C%20React%20Native%20%7C%20Flutter%20%7C%20Cordova-lightgrey)](#supported-platforms)

> AI-powered assistant for integrating, reviewing, and debugging the [Purchasely](https://www.purchasely.com) SDK across **iOS**, **Android**, **React Native**, **Flutter**, and **Cordova**.

A cross-harness plugin that bundles:

- **4 slash commands** — `/purchasely:integrate`, `/purchasely:review`, `/purchasely:debug`, `/purchasely:question`
- **3 auto-invoked skills** — `integrate`, `review`, `debug`
- **1 expert agent** — `sdk-expert`
- **Cross-vendor manifests** — `AGENTS.md`, `GEMINI.md`, `gemini-extension.json`, `.claude-plugin/`, `configs/`

Works with **Claude Code**, **Codex CLI**, **Codex App**, **Cursor**, **Gemini CLI**, **OpenCode**, **GitHub Copilot CLI**, **Mistral `vibe`**, **Windsurf**, **JetBrains AI**, and **VS Code + Continue**.

---

## Quickstart

Pick the block matching your harness. Each one is copy-paste-able as is.

### Claude Code

```text
/plugin marketplace add Purchasely/Purchasely-AI-Plugin
/plugin install purchasely@Purchasely-AI-Plugin
```

### Codex CLI

```bash
cp configs/codex/AGENTS.md AGENTS.md
```

`AGENTS.md` is the cross-vendor [agents.md](https://agents.md) standard. Codex CLI auto-detects it at the project root.

### Codex App

Open the project in Codex App, then drop the same `AGENTS.md` at the project root (or symlink the one from this repo). No further setup.

### Cursor

```bash
mkdir -p .cursor/rules
cp configs/cursor/purchasely.mdc .cursor/rules/purchasely.mdc
```

Rules activate automatically on Swift, Kotlin, TypeScript, Dart, and JavaScript files.

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

### GitHub Copilot CLI

```bash
mkdir -p .github
cp configs/copilot/copilot-instructions.md .github/copilot-instructions.md
```

If `.github/copilot-instructions.md` already exists, append rather than overwrite:

```bash
printf "\n---\n" >> .github/copilot-instructions.md
cat configs/copilot/copilot-instructions.md >> .github/copilot-instructions.md
```

### Mistral `vibe`

```bash
cp configs/mistral/AGENTS.md AGENTS.md
```

`vibe` shares the cross-vendor `AGENTS.md` format with Codex.

### Windsurf

```bash
cp configs/windsurf/.windsurfrules .windsurfrules
```

### JetBrains AI Assistant / VS Code + Continue

<details>
<summary><strong>JetBrains AI Assistant</strong></summary>

1. Open **Settings → Tools → AI Assistant → Project-Level Prompt**.
2. Paste the content of `configs/copilot/copilot-instructions.md`.
3. Click Apply.
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

---

## Installation (legacy / all-in-one)

Prefer the [Quickstart](#quickstart) above when one entry matches your harness. The installer below is a POSIX one-shot that auto-detects every supported tool — handy when bootstrapping a fresh project.

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
├── configs/                     # Pre-generated configs for legacy installs
│   ├── cursor/purchasely.mdc
│   ├── copilot/copilot-instructions.md
│   ├── windsurf/.windsurfrules
│   ├── codex/AGENTS.md
│   ├── gemini/GEMINI.md
│   └── mistral/AGENTS.md
├── install.sh                   # Auto-installer (detects tools)
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
3. Update the relevant files in `skills/`, `references/`, or `configs/`
4. Test with Claude Code: `claude --plugin-dir ./Purchasely-AI-Plugin`
5. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines.

## Updating for New SDK Versions

When a new SDK version is released:

1. **Update `references/sdk-versions.md`** — single source of truth for pinned versions.
2. Update version references in `skills/integrate/SKILL.md` and each platform's `references/<platform>/`.
3. Update `references/` with new/changed APIs.
4. Update `configs/` with new patterns and rules.
5. Bump `version` in `.claude-plugin/plugin.json` and `package.json`.
6. Add an entry to [CHANGELOG.md](CHANGELOG.md).
7. Tag and release.

## Security

If you find a security issue, please follow the **responsible disclosure process in [SECURITY.md](SECURITY.md)** — do not open a public GitHub issue.

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
- [Gemini extensions](https://github.com/google-gemini/gemini-cli)
