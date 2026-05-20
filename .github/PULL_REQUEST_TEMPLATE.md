## Summary

<!-- 1-3 sentences describing what this PR changes and why. -->

## Type of change

- [ ] Bug fix (corrects wrong guidance, deprecated API, broken example)
- [ ] New content (skill, recipe, reference doc, new platform)
- [ ] New AI tool integration (added/updated a plugin manifest or bootstrap pointing to `skills/`)
- [ ] Documentation / README / governance
- [ ] Refactor (no functional change)

## How was this tested?

<!--
Examples:
- Loaded the plugin in Claude Code and ran `/purchasely:integrate ios`
- Installed the plugin/extension in a test project and confirmed the tool picked up `skills/`
- Confirmed root `AGENTS.md`/`GEMINI.md` imports the matching skill instead of duplicating SDK guidance
-->

## Checklist

- [ ] Code examples reference APIs that exist in the current public Purchasely SDK
- [ ] No real API keys or credentials committed (placeholders only)
- [ ] Updated `CHANGELOG.md` under `[Unreleased]`
- [ ] If a new AI tool was added: README, manifests/bootstrap files, and validation workflow are updated
- [ ] If a public-facing description changed: `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` are still consistent
