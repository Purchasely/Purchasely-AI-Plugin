# Purchasely AI Skill

AI-powered assistant for integrating, reviewing, debugging, and migrating the [Purchasely](https://www.purchasely.com) SDK across **iOS**, **Android**, **React Native**, **Flutter**, and **Cordova**.

Works with: **Claude Code** | **Cursor** | **GitHub Copilot** | **Windsurf** | **OpenAI Codex** | **Google Gemini** | **JetBrains AI**

## What It Does

| Skill | Description |
|-------|-------------|
| **integrate** | Step-by-step SDK integration from scratch — installation, initialization, paywall display, action interceptor, user management |
| **review** | Automated 24-point checklist review of your existing integration — finds bugs, deprecated APIs, and missing best practices |
| **debug** | Diagnostic trees for common issues — blank paywalls, frozen UI, purchase failures, deeplink problems |
| **migrate** | Guided migration from SDK v5.x to v6.0 — scans for breaking changes, shows before/after code, applies fixes |

## Quick Install

### Option 1: Automatic (recommended)

```bash
# Clone the repo
git clone https://github.com/Purchasely/purchasely-ai-skill.git
cd purchasely-ai-skill

# Run the installer — auto-detects your AI tools
./install.sh

# Or install for a specific tool
./install.sh --tool cursor --project /path/to/your/app
```

### Option 2: Claude Code Plugin (best experience)

```bash
# Inside Claude Code, open the plugin manager
/plugin

# Then search for "purchasely" in the Discover tab
# Or add the marketplace manually:
/plugin marketplace add Purchasely/purchasely-ai-skill
```

Once installed, you get 4 skills and a slash command:

```
> /purchasely:integrate          # Start a new SDK integration
> /purchasely:review             # Review your existing integration
> /purchasely:debug              # Debug an issue
> /purchasely:migrate            # Migrate from v5.x to v6.0
> /purchasely                    # Quick help — ask any question
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
  "systemMessage": "... paste content of configs/copilot/copilot-instructions.md ..."
}
```

Or reference the file:

```json
{
  "systemMessageFile": "configs/copilot/copilot-instructions.md"
}
```
</details>

## Usage Examples

### Integrate the SDK into a new app

```
You: "Integrate the Purchasely SDK into my iOS app"
AI: Detects Swift project, adds CocoaPods dependency, writes initialization code in AppDelegate,
    sets up a paywall display function, configures the action interceptor, and verifies the integration.
```

### Review an existing integration

```
You: "Review my Purchasely integration"
AI: Scans your codebase, runs 24 checks, reports:
    ✅ SDK initialized correctly
    ❌ processAction() not called in LOGIN branch — UI will freeze
    ⚠️ Using deprecated presentationView() — migrate to fetchPresentation()
    ✅ Deeplinks configured correctly
    ...
    Result: 20/24 passed, 2 critical, 2 warnings
```

### Debug an issue

```
You: "My paywall shows briefly then disappears"
AI: Searches for the presentation display code, identifies missing strong reference
    to the view controller, provides the fix.
```

### Migrate to v6

```
You: "Migrate my Android app from Purchasely SDK v5 to v6"
AI: Scans for deprecated patterns, finds 8 occurrences across 3 files,
    shows before/after for each, applies changes with your confirmation.
```

## Project Structure

```
purchasely-ai-skill/
├── .claude-plugin/
│   └── plugin.json              # Claude Code plugin manifest
├── skills/
│   ├── integrate/SKILL.md       # SDK integration guide
│   ├── review/SKILL.md          # Integration review checklist
│   ├── debug/SKILL.md           # Debugging diagnostic trees
│   └── migrate/SKILL.md         # v5.x → v6.0 migration
├── agents/
│   └── sdk-expert.md            # Purchasely SDK expert agent
├── commands/
│   └── purchasely.md            # /purchasely slash command
├── references/                  # Detailed SDK documentation
│   ├── ios/                     # iOS: init, API ref, patterns
│   ├── android/                 # Android: init, API ref, patterns
│   ├── react-native/            # React Native integration
│   ├── flutter/                 # Flutter integration
│   ├── cordova/                 # Cordova integration
│   ├── troubleshooting/         # Common issues & solutions
│   └── migrations/              # Migration guides
├── configs/                     # Pre-generated configs
│   ├── cursor/                  # .mdc rules file
│   ├── copilot/                 # copilot-instructions.md
│   ├── windsurf/                # .windsurfrules
│   ├── codex/                   # AGENTS.md
│   └── gemini/                  # GEMINI.md
├── install.sh                   # Auto-installer script
├── package.json                 # npm package metadata
├── LICENSE                      # MIT
└── README.md                    # This file
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
