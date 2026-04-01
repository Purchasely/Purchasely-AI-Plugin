# Purchasely AI Skill

AI-powered assistant for integrating, reviewing, debugging, and migrating the [Purchasely](https://www.purchasely.com) SDK across **iOS**, **Android**, **React Native**, **Flutter**, and **Cordova**.

Works with: **Claude Code** | **Cursor** | **GitHub Copilot** | **Windsurf** | **OpenAI Codex** | **Google Gemini** | **JetBrains AI**

## What It Does

| Command | Description |
|---------|-------------|
| `/purchasely:integrate` | Step-by-step SDK integration from scratch — installation, initialization, paywall display, action interceptor, user management |
| `/purchasely:review` | Automated 24-point checklist review of your existing integration — finds bugs, deprecated APIs, and missing best practices |
| `/purchasely:debug` | Diagnostic trees for common issues — blank paywalls, frozen UI, purchase failures, deeplink problems |
| `/purchasely:migrate` | Guided migration from SDK v5.x to v6.0 — scans for breaking changes, shows before/after code, applies fixes |
| `/purchasely:question` | Ask any question about the Purchasely SDK |

## Quick Install

### Option 1: Claude Code Plugin (best experience)

```bash
# Inside Claude Code, add the marketplace:
/plugin marketplace add Purchasely/purchasely-ai-skill

# Then enable the plugin from the /plugin manager (Discover tab)
```

Once installed, you get 5 slash commands:

```
/purchasely:integrate          # Start a new SDK integration
/purchasely:review             # Review your existing integration
/purchasely:debug              # Debug an issue
/purchasely:migrate            # Migrate from v5.x to v6.0
/purchasely:question           # Ask any SDK question
```

Plus an `sdk-expert` agent and 4 skills that the AI invokes automatically when relevant.

### Option 2: Install Script (all tools)

```bash
git clone https://github.com/Purchasely/purchasely-ai-skill.git
cd purchasely-ai-skill

# Auto-detect installed AI tools and install configs
./install.sh

# Or install for a specific tool
./install.sh --tool cursor --project /path/to/your/app

# Install for all detected tools without prompting
./install.sh --all --project /path/to/your/app
```

### Option 3: Manual Setup Per Tool

<details>
<summary><strong>Cursor</strong></summary>

Copy the rules file into your project:

```bash
mkdir -p .cursor/rules
cp configs/cursor/purchasely.mdc .cursor/rules/purchasely.mdc
```

The rules activate automatically when you edit Swift, Kotlin, TypeScript, Dart, or JavaScript files.
</details>

<details>
<summary><strong>GitHub Copilot</strong></summary>

Copy the instructions file:

```bash
mkdir -p .github
cp configs/copilot/copilot-instructions.md .github/copilot-instructions.md
```

If you already have a `copilot-instructions.md`, append the content:

```bash
echo -e "\n---\n" >> .github/copilot-instructions.md
cat configs/copilot/copilot-instructions.md >> .github/copilot-instructions.md
```
</details>

<details>
<summary><strong>Windsurf / Codeium</strong></summary>

Copy the rules file to your project root:

```bash
cp configs/windsurf/.windsurfrules .windsurfrules
```
</details>

<details>
<summary><strong>OpenAI Codex</strong></summary>

Copy the agents file to your project root:

```bash
cp configs/codex/AGENTS.md AGENTS.md
```
</details>

<details>
<summary><strong>Google Gemini CLI</strong></summary>

Copy the context file to your project root:

```bash
cp configs/gemini/GEMINI.md GEMINI.md
```
</details>

<details>
<summary><strong>JetBrains AI Assistant</strong></summary>

1. Open **Settings > Tools > AI Assistant > Project-Level Prompt**
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
    WARN  Using deprecated presentationView() — migrate to fetchPresentation()
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

### Migrate to v6

```
You: /purchasely:migrate android
AI: Scans for deprecated patterns, finds 8 occurrences across 3 files,
    shows before/after for each, applies changes with your confirmation.
```

### Ask a question

```
You: /purchasely:question how do I display a paywall in SwiftUI?
AI: Provides a complete SwiftUI example with fetchPresentation + display,
    presentation type handling, and action interceptor setup.
```

## Project Structure

```
purchasely-ai-skill/
├── .claude-plugin/
│   ├── plugin.json              # Claude Code plugin manifest
│   └── marketplace.json         # Marketplace definition
├── skills/                      # AI-invoked skills (automatic)
│   ├── integrate/SKILL.md       # SDK integration guide
│   ├── review/SKILL.md          # Integration review checklist
│   ├── debug/SKILL.md           # Debugging diagnostic trees
│   └── migrate/SKILL.md         # v5.x → v6.0 migration
├── agents/
│   └── sdk-expert.md            # Purchasely SDK expert agent
├── commands/                    # User-invoked slash commands
│   ├── integrate.md             # /purchasely:integrate
│   ├── review.md                # /purchasely:review
│   ├── debug.md                 # /purchasely:debug
│   ├── migrate.md               # /purchasely:migrate
│   └── question.md              # /purchasely:question
├── references/                  # SDK documentation (used by skills)
│   ├── ios/                     # iOS: init, API ref, patterns
│   ├── android/                 # Android: init, API ref, patterns
│   ├── react-native/            # React Native integration
│   ├── flutter/                 # Flutter integration
│   ├── cordova/                 # Cordova integration
│   ├── troubleshooting/         # Common issues & solutions
│   └── migrations/              # Migration guides (5.x → 6.0)
├── configs/                     # Pre-generated configs for other tools
│   ├── cursor/purchasely.mdc
│   ├── copilot/copilot-instructions.md
│   ├── windsurf/.windsurfrules
│   ├── codex/AGENTS.md
│   └── gemini/GEMINI.md
├── install.sh                   # Auto-installer (detects tools)
├── package.json
├── LICENSE                      # MIT
└── README.md
```

## Supported Platforms

| Platform | Install | Init | Paywalls | Interceptor | Deeplinks | User Mgmt |
|----------|---------|------|----------|-------------|-----------|-----------|
| iOS (Swift) | CocoaPods / SPM | `Purchasely.start()` | `fetchPresentation` | `setPaywallActionsInterceptor` | `handleDeeplink` | `userLogin` / `userLogout` |
| Android (Kotlin) | Gradle (Maven) | `Purchasely.Builder()` | `fetchPresentation` | `interceptAction` (v6) | `handleDeeplink` | `userLogin` / `userLogout` |
| React Native | yarn / npm | `Purchasely.start()` | `presentPresentationForPlacement` | `setPaywallActionInterceptorCallback` | `isDeeplinkHandled` | `userLogin` / `userLogout` |
| Flutter | pub.dev | `Purchasely.start()` | `presentPresentationForPlacement` | `setPaywallActionInterceptorCallback` | `isDeeplinkHandled` | `userLogin` / `userLogout` |
| Cordova | cordova plugin | `Purchasely.start()` | `presentPresentationForPlacement` | `onPurchaselyEvent` | `isDeeplinkHandled` | `userLogin` / `userLogout` |

## Requirements

- A [Purchasely](https://www.purchasely.com) account with an API key
- An app configured in the Purchasely Console with at least one placement
- Products/plans configured in your store (App Store Connect, Google Play Console, etc.)

## Contributing

1. Fork the repository
2. Create a feature branch (`feat/my-improvement`)
3. Update the relevant files in `skills/`, `references/`, or `configs/`
4. Test with Claude Code: `claude --plugin-dir ./purchasely-ai-skill`
5. Submit a pull request

## Updating for New SDK Versions

When a new SDK version is released:

1. Update `references/` with new/changed APIs
2. Update `skills/migrate/SKILL.md` with new migration paths
3. Update `configs/` with new patterns and rules
4. Bump `version` in `plugin.json` and `package.json`
5. Tag and release

## License

MIT - see [LICENSE](LICENSE)

## Resources

- [Purchasely Documentation](https://docs.purchasely.com)
- [Purchasely Console](https://console.purchasely.com)
- [Claude Code Plugins](https://docs.anthropic.com/en/docs/claude-code/plugins)
- [Cursor Rules](https://docs.cursor.com/context/rules-for-ai)
- [GitHub Copilot Instructions](https://docs.github.com/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot)
