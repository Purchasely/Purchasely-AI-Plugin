# Installing Purchasely AI Plugin in OpenCode

This guide walks you through adding the Purchasely AI Plugin to your [OpenCode](https://opencode.ai) setup. Once installed, OpenCode loads the Purchasely skills (`integrate`, `review`, `debug`) and the `sdk-expert` agent automatically.

## Prerequisites

- OpenCode installed and configured (`opencode --version`).
- Node.js ≥ 18 (OpenCode plugin loader requirement).
- Git available on `PATH` (the plugin is fetched directly from the GitHub repository).
- An OpenCode project — i.e. a directory with an `opencode.json` (or willingness to create one).

## Installation

Add the plugin entry to your project's `opencode.json`:

```json
{
  "plugin": ["purchasely@git+https://github.com/Purchasely/Purchasely-AI-Plugin.git"]
}
```

If you already have other plugins listed, append the entry to the existing `"plugin"` array — do not overwrite it.

The next time you launch OpenCode in this project, the plugin is fetched, cached, and loaded automatically. No manual `cp` of configs, no symlinks.

## Usage

After installation, ask OpenCode anything about the Purchasely SDK:

```
You: Tell me about your Purchasely skills.
OpenCode: I have three task-scoped skills (integrate, review, debug)
          and a free-form Q&A command (/purchasely:question) for the
          Purchasely SDK on iOS, Android, React Native, Flutter, and Cordova.
```

Other examples:

- `Integrate the Purchasely SDK into this iOS app.`
- `Review my Purchasely integration for common mistakes.`
- `Debug why my paywall shows blank.`
- `How do I display a Purchasely paywall in SwiftUI?`

## Updating

OpenCode honors the version pin in `opencode.json`. To pull the latest changes from `main`:

```bash
# Re-fetch the plugin (clears the cache for this entry)
opencode plugin update purchasely
```

If your version of OpenCode does not expose `plugin update`, remove the plugin cache directory (`~/.opencode/plugins/purchasely/`) and relaunch.

To pin to a specific tag or commit, change the spec to:

```json
{ "plugin": ["purchasely@git+https://github.com/Purchasely/Purchasely-AI-Plugin.git#v1.0.0"] }
```

## Troubleshooting

### Plugin not loading

1. Confirm `opencode.json` is valid JSON (no trailing commas, no comments).
2. Run OpenCode with verbose logging: `opencode --log-level debug` and look for `plugin: purchasely` lines.
3. Make sure git can reach `github.com` from the machine running OpenCode — `git ls-remote https://github.com/Purchasely/Purchasely-AI-Plugin.git` should print refs.

### Windows install issues

The `git+` spec requires git on `PATH` and write access to the user-level OpenCode cache. If install fails with `EACCES` or `EPERM`:

```powershell
# Install the plugin into a writable location explicitly
npm install --prefix %USERPROFILE%\.opencode\plugins git+https://github.com/Purchasely/Purchasely-AI-Plugin.git
```

Then point `opencode.json` at the local copy:

```json
{ "plugin": ["purchasely@file:%USERPROFILE%/.opencode/plugins/node_modules/purchasely"] }
```

### Skills not found

If `/purchasely:integrate` (or asking "use the integrate skill") returns "skill not found":

1. Check that OpenCode loaded the plugin (see verbose logs above).
2. Confirm the cached plugin contains `skills/integrate/SKILL.md`, `skills/review/SKILL.md`, `skills/debug/SKILL.md`. If the cache looks empty or stale, remove it and relaunch.
3. Verify the plugin version in `opencode.json` is recent enough to include the skill set (≥ `1.0.0`).

## See also

- [Purchasely AI Plugin README](../README.md) — overview and per-harness Quickstart.
- [Purchasely SDK documentation](https://docs.purchasely.com).
- [OpenCode documentation](https://opencode.ai/docs).
