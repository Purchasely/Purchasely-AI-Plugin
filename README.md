# Purchasely AI Plugin

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-D97757)](https://docs.anthropic.com/en/docs/claude-code/plugins)
[![skills.sh](https://skills.sh/b/Purchasely/Purchasely-AI-Plugin)](https://skills.sh/Purchasely/Purchasely-AI-Plugin)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20Android%20%7C%20React%20Native%20%7C%20Flutter%20%7C%20Cordova-lightgrey)](#supported-platforms)

> AI-powered assistant for integrating, reviewing, and debugging the [Purchasely](https://www.purchasely.com) SDK across **iOS**, **Android**, **React Native**, **Flutter**, and **Cordova**.

A cross-harness plugin with the richest experience on **Claude Code**, plus portable skills for other agents:

- **Claude Code full plugin** — 4 slash commands (`/purchasely:integrate`, `/purchasely:review`, `/purchasely:debug`, `/purchasely:migrate`), 5 auto-invoked skills, hooks, references, and the `purchasely-sdk-expert` agent for free-form Purchasely SDK questions.
- **5 portable skills** — `purchasely-sdk-expert`, `purchasely-integrate`, `purchasely-review`, `purchasely-debug`, `purchasely-migrate` (installable with `npx skills add ...`; skills-only installs do **not** include slash commands, hooks, or the Claude Code subagent).
- **Cross-vendor manifests** — `.claude-plugin/`, `.cursor-plugin/`, `.agents/plugins/`, `purchasely/.claude-plugin/`, `purchasely/.codex-plugin/`, `purchasely/.cursor-plugin/`, `AGENTS.md`, `GEMINI.md`, `gemini-extension.json`.

Works with **Claude Code**, **Codex CLI**, **Codex App**, **Cursor**, **Gemini CLI**, **OpenCode**, **GitHub Copilot CLI**, and **AGENTS.md-compatible harnesses**.

---

## Quickstart

Pick the block matching your harness. Each one is copy-paste-able as is.

### Claude Code — recommended full experience

Claude Code is the best-supported installation path. It installs the complete Purchasely plugin: skills, slash commands, hooks, bundled references, and the `purchasely-sdk-expert` agent. Use this if you want the strongest guidance and free-form Purchasely SDK questions to route to the expert automatically when relevant.

```text
/plugin marketplace add Purchasely/Purchasely-AI-Plugin
/plugin install purchasely@Purchasely-AI-Plugin
```

Claude reads `.claude-plugin/marketplace.json`, which points at the self-contained `purchasely/` plugin folder.

### Skills CLI (skills.sh) — portable skills only

The [`skills` CLI](https://www.skills.sh/docs) installs the five Purchasely skills (`purchasely-sdk-expert`, `purchasely-integrate`, `purchasely-review`, `purchasely-debug`, `purchasely-migrate`) into any AGENTS.md-compatible harness, Claude Code, Cursor, Codex, OpenCode, and 50+ others — pick where they go interactively, no marketplace setup required.

This is a **skills-only** installation path: it installs the portable `purchasely-sdk-expert` skill, but not the Claude Code `purchasely-sdk-expert` subagent, slash commands, hooks, or plugin manifests. Claude Code users should prefer the full plugin install above.

```bash
npx skills add Purchasely/Purchasely-AI-Plugin
```

Common variants:

```bash
# List the skills shipped by this repo without installing
npx skills add Purchasely/Purchasely-AI-Plugin --list

# Install one skill only (e.g. just the debug playbook)
npx skills add Purchasely/Purchasely-AI-Plugin --skill purchasely-debug

# Non-interactive — install all portable skills to Claude Code, globally
npx skills add Purchasely/Purchasely-AI-Plugin -g -a claude-code -y

# Update later (updates are not automatic)
npx skills update
```

The CLI discovers skills at [`skills/`](./skills) (a compatibility link to [`purchasely/skills/`](./purchasely/skills)). Skill names match their directory names — `purchasely-sdk-expert`, `purchasely-integrate`, `purchasely-review`, `purchasely-debug`, `purchasely-migrate`.

#### Updating Skills CLI installations

Skills installed through `npx skills add Purchasely/Purchasely-AI-Plugin` are not auto-updated by the agent or by `npx` itself. They stay at the version installed in the target agent until the developer runs an update command:

```bash
# Interactive update for the current scope
npx skills update

# Update global skills only
npx skills update -g

# Update project-local skills only
npx skills update -p

# Update only the Purchasely skills by name
npx skills update purchasely-sdk-expert purchasely-integrate purchasely-review purchasely-debug purchasely-migrate

# Non-interactive global update
npx skills update -g -y
```

To know when an update is available, watch this repository's [GitHub releases](https://github.com/Purchasely/Purchasely-AI-Plugin/releases) or [`CHANGELOG.md`](./CHANGELOG.md). We intentionally do not make the Purchasely skills check GitHub on every invocation: many agent environments run offline or with restricted network access, and automatic version checks would add latency and noise to normal SDK integration tasks. If you need an explicit check, run `npx skills update`.

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

Add this repository as a Cursor plugin marketplace, then install the `purchasely` plugin. Cursor reads `.cursor-plugin/marketplace.json`, which points at the self-contained `purchasely/` plugin folder.

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

### GitHub Copilot CLI

```bash
copilot plugin marketplace add Purchasely/Purchasely-AI-Plugin
copilot plugin install purchasely@Purchasely-AI-Plugin
```

Copilot CLI reads the repository marketplace and installs the self-contained `purchasely/` plugin folder, including the canonical `purchasely/skills/` playbooks.

### AGENTS.md-compatible harnesses

Tools that read the repository-level `AGENTS.md` should use this repository directly. `AGENTS.md` is intentionally only a bootstrap that points to the canonical `skills/` compatibility link.

## What It Does

| Trigger | Description |
|---------|-------------|
| Natural Purchasely SDK question | Free-form API / paywall / purchase / campaign guidance via `purchasely-sdk-expert` |
| `/purchasely:integrate` | Step-by-step SDK integration from scratch — installation, initialization, paywall display, action interceptor, user management |
| `/purchasely:review` | Automated checklist review of your existing integration — finds bugs, deprecated APIs, and missing best practices |
| `/purchasely:debug` | Diagnostic trees for common issues — blank paywalls, frozen UI, purchase failures, deeplink problems |
| `/purchasely:migrate` | Upgrade an existing native iOS, native Android, or Flutter integration from SDK v5 to v6 |

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

### Ask a Purchasely SDK question

```
You: How do I display a Purchasely paywall in SwiftUI?
AI: Routes the question to the Purchasely SDK expertise when available and
    provides a complete SwiftUI example with presentation loading/display,
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
├── skills -> purchasely/skills   # Root compatibility link for AGENTS.md/GEMINI.md users
├── agents -> purchasely/agents
├── commands -> purchasely/commands
├── references -> purchasely/references
├── hooks -> purchasely/hooks
├── purchasely/
│   ├── .claude-plugin/
│   │   └── plugin.json          # Claude Code plugin manifest
│   ├── .codex-plugin/
│   │   └── plugin.json          # OpenAI Codex plugin manifest
│   ├── .cursor-plugin/
│   │   └── plugin.json          # Cursor plugin manifest
│   ├── skills/                  # AI-invoked skills (automatic)
│   │   ├── purchasely-sdk-expert/SKILL.md
│   │   ├── purchasely-integrate/SKILL.md
│   │   ├── purchasely-review/SKILL.md
│   │   ├── purchasely-debug/SKILL.md
│   │   └── purchasely-migrate/SKILL.md
│   ├── agents/
│   │   └── purchasely-sdk-expert.md  # Claude Code subagent wrapper
│   ├── commands/                # User-invoked slash commands
│   │   ├── integrate.md
│   │   ├── review.md
│   │   ├── debug.md
│   │   └── migrate.md
│   ├── hooks/
│   └── references/              # SDK documentation (used by skills)
│       ├── concepts/            # Universal SDK concepts (all 5 platforms)
│       ├── testing/             # Sandbox setup (Apple, Google)
│       ├── troubleshooting/     # Common issues, error codes, debug mode
│       ├── ios/  android/  react-native/  flutter/  cordova/
│       ├── diagrams/            # Architecture diagrams (SVG)
│       ├── architecture-patterns.md
│       ├── cross-platform-subscriptions.md
│       ├── purchasely-architecture.md
│       └── sdk-versions.md      # Latest stable SDK versions (single source of truth)
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
| `/purchasely:integrate` | Slash command + matching `purchasely-integrate` skill | The command launches the skill; the skill is also auto-invoked when Claude detects an SDK integration task |
| `/purchasely:review` | Slash command + matching `purchasely-review` skill | Same as above |
| `/purchasely:debug` | Slash command + matching `purchasely-debug` skill | Same as above |
| `/purchasely:migrate` | Slash command + matching `purchasely-migrate` skill | Migrates native iOS, native Android, and Flutter integrations from SDK v5 to v6 |
| Natural Purchasely SDK question | Portable `purchasely-sdk-expert` skill + Claude Code `purchasely-sdk-expert` agent when available | No slash command needed — ask normally and the expert guidance can be used directly for free-form Purchasely SDK Q&A |

## Supported Platforms

| Platform | SDK line | Init | Paywalls | Interceptor | Deeplinks | User Mgmt |
|----------|----------|------|----------|-------------|-----------|-----------|
| iOS (Swift / Obj-C) | v6 (`6.0.0-rc.1`) | `Purchasely.apiKey(...).runningMode(...).start()` | `PLYPresentationBuilder...build().preload()` → `display(from:)` | per-action `interceptAction` returning `PLYInterceptResult` | `handleDeeplink` / `allowDeeplink` | `userLogin` / `userLogout` |
| Android (Kotlin / Java) | v6 (`6.0.0-rc.1`) | `Purchasely { ... }` or `Purchasely.Builder(...)` | `PLYPresentation { ... }.preload()` → `display(context)` | per-action `interceptAction` returning `PLYInterceptResult` | auto-intercept + `handleDeeplink` / `allowDeeplink` | `userLogin` / `userLogout` |
| Flutter | v6 (`6.0.0-rc.1`) | `PurchaselyBuilder.apiKey(...).start()` | `PresentationBuilder...build()` → `preload()` / `display(...)` | per-action `interceptAction` returning `InterceptResult` | `handleDeeplink` / `allowDeeplink` | `userLogin` / `userLogout` |
| React Native | v5 (`5.7.3`) | `Purchasely.start(...)` | `fetchPresentation` + `presentPresentation` | `setPaywallActionInterceptor` + `onProcessAction` | `handleDeeplink` + `readyToOpenDeeplink` | `userLogin` / `userLogout` |
| Cordova | v5 (`5.7.3`) | `Purchasely.start(...)` | `fetchPresentationForPlacement` + `presentPresentation` | `setPaywallActionInterceptor` + `onProcessAction` | `handleDeeplink` + `readyToOpenDeeplink` | `userLogin` / `userLogout` |

## Requirements

- A [Purchasely](https://www.purchasely.com) account with an API key
- An app configured in the Purchasely Console with at least one placement
- Products/plans configured in your store (App Store Connect, Google Play Console, …)

## Discoverability

This plugin is also published on:

- 🧠 **[skills.sh](https://skills.sh/Purchasely/Purchasely-AI-Plugin)** — open agent skills leaderboard powered by the `skills` CLI (`npx skills add Purchasely/Purchasely-AI-Plugin`)
- 🤖 **agentskill.sh** — individual skill pages, installable from any agent running the `/learn` command:
  - [`@purchasely/purchasely-sdk-expert`](https://agentskill.sh/@purchasely/purchasely-sdk-expert)
  - [`@purchasely/purchasely-integrate`](https://agentskill.sh/@purchasely/purchasely-integrate)
  - [`@purchasely/purchasely-review`](https://agentskill.sh/@purchasely/purchasely-review)
  - [`@purchasely/purchasely-debug`](https://agentskill.sh/@purchasely/purchasely-debug)
  - [`@purchasely/purchasely-migrate`](https://agentskill.sh/@purchasely/purchasely-migrate)
- 📦 **Claude Code marketplace** — `/plugin marketplace add Purchasely/Purchasely-AI-Plugin`

See [`docs/distribution.md`](docs/distribution.md) for the public roadmap of every official marketplace we're targeting (Anthropic, OpenAI Codex, Factory Droid, GitHub Copilot CLI, …) and how to help land each one.

## Contributing

Contributions welcome — bug reports, new troubleshooting recipes, platform improvements, and translations to other AI tools.

1. Fork the repository
2. Create a feature branch (`feat/my-improvement`)
3. Update the relevant files in `purchasely/skills/` or `purchasely/references/`
4. Test with Claude Code: `claude --plugin-dir ./Purchasely-AI-Plugin`
5. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines.

## Updating for New SDK Versions

When a new SDK version is released:

1. **Update `purchasely/references/sdk-versions.md`** — single source of truth for pinned versions.
2. Update version references in `purchasely/skills/purchasely-integrate/SKILL.md` and each platform's `purchasely/references/<platform>/`.
3. Update `purchasely/references/` with new/changed APIs.
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
