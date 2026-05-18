# Contributing to Purchasely AI Plugin

Thanks for helping make Purchasely easier to integrate. This guide covers how to propose changes.

## Ways to contribute

- **Bug reports** — open an issue with a reproducible scenario (which AI tool, which command, what happened)
- **Documentation fixes** — correct or improve any file under `references/`
- **New troubleshooting recipes** — add diagnostic trees to `references/troubleshooting/common-issues.md` or extend `skills/debug/SKILL.md`
- **New AI tool support** — add a config under `configs/<tool>/` and wire it up in `install.sh`
- **SDK API updates** — keep `references/<platform>/api-reference.md` in sync with the latest public SDK

## Development workflow

1. **Fork** the repository
2. **Branch** off `main` with a descriptive name:
   - `feat/<scope>` for new content
   - `fix/<scope>` for corrections
   - `docs/<scope>` for documentation-only changes
3. **Edit** the relevant files. Skill front-matter and structure are explained inline.
4. **Test** locally:
   - Claude Code: `claude --plugin-dir ./AI-Plugin` then invoke `/purchasely:integrate`, `/purchasely:review`, etc.
   - Other tools: copy the relevant `configs/<tool>/` file into a small test project and ask the AI a Purchasely question
5. **Commit** atomically using [Conventional Commits](https://www.conventionalcommits.org/):
   ```
   feat(android): document Huawei IAP setup
   fix(ios): correct fetchPresentation signature
   docs(readme): mention Mistral support
   ```
6. **Open a pull request** against `main`. Describe what changed and how to verify it.

## Style guide

- Keep examples **runnable**. If a snippet references an API, the API must exist in the current public SDK.
- Use **placeholders** (`YOUR_API_KEY`, `PLACEMENT_ID`) — never commit real keys.
- Prefer **direct SDK calls** in examples (`Purchasely.fetchPresentation(...)`). The wrapper pattern is recommended but optional — see `CLAUDE.md` for the full rule.
- One concept per file when possible; cross-link with relative paths.
- Markdown headings: `##` for sections, `###` for subsections; no `#` (reserved for the document title).

## Adding a new AI tool

To add support for a new AI coding tool (e.g. a new vendor):

1. Create `configs/<tool>/` with the tool's native config format (e.g. `AGENTS.md`, `.windsurfrules`, `.mdc`)
2. Add a `detect_<tool>` and `install_<tool>` function in `install.sh`
3. Add the tool to the help text, valid tools list, and the detection/install loops
4. Update the README "Manual Setup Per Tool" section
5. Test the installer: `./install.sh --tool <tool> --project /tmp/test`

## Reporting security issues

Please do **not** open public issues for security problems. See [SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions are licensed under the MIT License (see [LICENSE](LICENSE)).
