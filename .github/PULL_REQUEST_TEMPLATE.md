## Summary

<!-- 1-3 sentences describing what this PR changes and why. -->

## Type of change

- [ ] Bug fix (corrects wrong guidance, deprecated API, broken example)
- [ ] New content (skill, recipe, reference doc, new platform)
- [ ] New AI tool integration (added a `configs/<tool>/` and wired `install.sh`)
- [ ] Documentation / README / governance
- [ ] Refactor (no functional change)

## How was this tested?

<!--
Examples:
- Loaded the plugin in Claude Code and ran `/purchasely:integrate ios`
- Copied configs/cursor/purchasely.mdc into a test project and confirmed Cursor picked it up
- Ran `./install.sh --tool mistral --project /tmp/test`
-->

## Checklist

- [ ] Code examples reference APIs that exist in the current public Purchasely SDK
- [ ] No real API keys or credentials committed (placeholders only)
- [ ] Updated `CHANGELOG.md` under `[Unreleased]`
- [ ] If a new AI tool was added: README, `install.sh`, and `configs/<tool>/` are all updated
- [ ] If a public-facing description changed: `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` are still consistent
