# Distribution roadmap — official marketplaces

Public roadmap for getting the Purchasely AI Plugin onto every relevant first-party marketplace. Each entry lists the **current status**, the **user-facing install command** we want to ship, and the **work to do** to get there. Contributions welcome — open an issue or PR if you want to drive one of these forward.

Legend: ✅ live · ⏳ in progress · 📋 planned

## Anthropic Official Marketplace (`claude-plugins-official`)

**Status:** 📋 planned

**Target command:**

```text
/plugin install purchasely@claude-plugins-official
```

**Work to do:**

1. Open a PR on [`anthropics/claude-plugins`](https://github.com/anthropics/claude-plugins) listing Purchasely under the appropriate category (`sdk-integration` / `monetization`).
2. Pin to a tagged release (`v1.0.0`+) so the marketplace can refer to a stable artifact.
3. Coordinate with Anthropic on listing review and visibility.

**Tracking issue:** _to be filed_

## OpenAI Codex plugin marketplace (`openai/plugins`)

**Status:** 📋 planned

**Target experience:** Codex CLI `/plugins` browser and Codex App Plugins sidebar surface a `purchasely` entry.

**Work to do:**

1. Add a `scripts/sync-to-codex-plugin.sh` adapted from [`obra/superpowers`](https://github.com/obra/superpowers) — generates a `.codex-plugin/` directory derived from `AGENTS.md`, `skills/`, `commands/`, and `agents/`.
2. Wire the sync script into CI so the generated artifact stays in sync with `main`.
3. Open a PR on [`openai/plugins`](https://github.com/openai/plugins) referencing the synced repo (or a dedicated `Purchasely-AI-Plugin-codex` mirror).

**Tracking issue:** _to be filed_

## Factory Droid marketplace

**Status:** 📋 planned

**Target command:**

```bash
droid plugin marketplace add Purchasely/Purchasely-AI-Plugin-marketplace
droid plugin install purchasely
```

**Work to do:**

1. Decide between a dedicated `Purchasely/Purchasely-AI-Plugin-marketplace` repo and reusing the marketplace already published on this repo (`/.claude-plugin/marketplace.json`).
2. Verify Factory Droid's plugin schema requirements (`droid.json` / equivalent manifest).
3. Submit the marketplace URL to Factory's plugin index.

**Tracking issue:** _to be filed_

## GitHub Copilot CLI marketplace

**Status:** 📋 planned

**Target command:**

```bash
copilot plugin marketplace add Purchasely/Purchasely-AI-Plugin-marketplace
copilot plugin install purchasely
```

**Work to do:**

1. Create `Purchasely/Purchasely-AI-Plugin-marketplace` (mirroring this repo's `.claude-plugin/marketplace.json` structure) **or** confirm Copilot CLI accepts the existing marketplace manifest from `Purchasely/Purchasely-AI-Plugin`.
2. Validate end-to-end with `copilot plugin install` against a clean repo.
3. Submit to GitHub's plugin index when the marketplace API stabilizes.

**Tracking issue:** _to be filed_

## Anthropic Skill Marketplace

**Status:** ⏳ under investigation — verify whether a Skill-only listing (separate from the Plugin marketplace above) is offered, and whether it makes sense to publish the three skills (`integrate`, `review`, `debug`) individually.

**Target command:** TBD.

**Work to do:**

1. Confirm the existence and policy of an Anthropic Skill marketplace distinct from `claude-plugins-official`.
2. If it exists and accepts third-party skills, mirror the skills with appropriate `.skill/manifest.json` files.

**Tracking issue:** _to be filed_

---

## Already shipped

| Channel | Status | Install |
|---|---|---|
| GitHub-backed Claude Code marketplace | ✅ live | `/plugin marketplace add Purchasely/Purchasely-AI-Plugin` then `/plugin install purchasely@Purchasely-AI-Plugin` |
| Cross-vendor `AGENTS.md` (Codex, Cursor, Zed, Mistral `vibe`, …) | ✅ live | Copy `configs/codex/AGENTS.md` (or use the root `AGENTS.md` once #3 lands) |
| Cursor rules | ✅ live | Copy `configs/cursor/purchasely.mdc` to `.cursor/rules/` |
| GitHub Copilot instructions file | ✅ live | Copy `configs/copilot/copilot-instructions.md` to `.github/` |
| Windsurf | ✅ live | Copy `configs/windsurf/.windsurfrules` |
| Mistral `vibe` (`AGENTS.md`) | ✅ live | Copy `configs/mistral/AGENTS.md` |
| Gemini CLI extension | ⏳ pending #3 | `gemini extensions install https://github.com/Purchasely/Purchasely-AI-Plugin` |
| OpenCode | ⏳ pending #6 | See `.opencode/INSTALL.md` |

## How to help

1. Pick one of the 📋 / ⏳ entries above.
2. Open an issue on this repo titled `marketplace: <channel>` describing what you intend to do.
3. Submit the PR (here for the sync script / manifest, on the marketplace repo for the listing).
4. Update this file moving the entry's status forward.
