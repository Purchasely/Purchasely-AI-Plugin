# CLAUDE.md — Purchasely-AI-Plugin

Repository conventions for anyone (human or LLM) editing this plugin.

## CHANGELOG must be kept up to date

Every PR that adds, changes, removes, or deprecates anything user-visible **must** update `CHANGELOG.md`:

1. Add the entry under the top-level `## [Unreleased]` section, in the appropriate sub-section: `Added`, `Changed`, `Removed`, `Deprecated`, `Fixed`, `Security`.
2. Keep entries short, factual, and user-facing. Example: `Added references/concepts/promotional-offers.md — covers Apple promo offers, Google developer-determined offers, offer codes` — not `Reworked the references directory`.
3. When cutting a release, rename `[Unreleased]` to `[X.Y.Z] — YYYY-MM-DD`, bump `version` in `.claude-plugin/plugin.json` + `package.json`, then add a fresh empty `[Unreleased]` section at the top.
4. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning follows [SemVer](https://semver.org/spec/v2.0.0.html).

**Rule of thumb:** if you wouldn't write the change in the release notes a client reads, you probably don't need a CHANGELOG entry. Otherwise, write one.

## Wrapper pattern: name and scope

The "wrapper" pattern (a single dedicated class that owns every call into the Purchasely SDK) is a **recommendation**, not a requirement. The Purchasely SDK is fully usable when called directly from ViewModels, UI code, or anywhere else.

**Rules for any documentation, skill, command, or agent prompt in this repo:**

1. **Mention the wrapper pattern only as a recommendation.** Never present it as mandatory and never frame a direct integration as "wrong" or "broken".
2. **Mention the `PurchaselyWrapper` name only in the dedicated recommendation section** of `references/architecture-patterns.md` (and in similarly explicit "if you adopt the wrapper pattern" contexts). Make it clear the name is just an example — `PurchaselyService`, `PurchaselyGateway`, `IAPManager`, `BillingService`, … any name works. The **concept** is what matters.
3. **Outside those recommendation sections, refer to Purchasely SDK APIs directly** (`Purchasely.fetchPresentation(...)`, `Purchasely.setUserAttribute(...)`, `Purchasely.synchronize(...)`, `PLYPresentation`, etc.). Do not write `purchaselyWrapper.X(...)` or `wrapper.X(...)` in code samples or prose.
4. **Checklists must split** "universal" items (apply regardless of architecture) from "recommended when adopting the wrapper pattern" items. Adoption-conditional items must never appear in the universal section.
5. **The same rule applies to the optional reactive Observer-mode flow and the in-memory presentation cache** — recommendations only, never required.
6. **Code reviewers (the `purchasely-review` skill) must skip wrapper-related checks when the project does not use a wrapper class** and must not suggest adding one unless the user explicitly asks for an architecture review.

When in doubt, lean on the language: "recommended", "optional pattern", "consider", "best practice for testability and SDK isolation". Avoid: "rule", "must", "always", "required".

## Publishing / refreshing on agentskill.sh

The three skills are published on [agentskill.sh](https://agentskill.sh) as `@purchasely/purchasely-integrate`, `@purchasely/purchasely-review`, `@purchasely/purchasely-debug`.

**Force a re-scan** (after a push, a skill rename, or a description change) — agentskill.sh runs a daily background sync, but you can trigger it on demand by POSTing the GitHub repo URL to the public submit endpoint:

```bash
ctx_execute(language: "javascript", code: `
  const r = await fetch("https://agentskill.sh/api/skills/submit", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ url: "https://github.com/Purchasely/Purchasely-AI-Plugin" }),
  });
  console.log(JSON.stringify(await r.json(), null, 2));
`)
```

The call is idempotent: first import returns `status: imported`, subsequent calls return `status: updated`. Response shape:

```json
{
  "success": true,
  "data": {
    "owner": "Purchasely",
    "repo": "Purchasely-AI-Plugin",
    "skills": [
      { "slug": "purchasely/purchasely-debug",     "status": "updated", "securityScore": 95 },
      { "slug": "purchasely/purchasely-integrate", "status": "updated", "securityScore": 100 },
      { "slug": "purchasely/purchasely-review",    "status": "updated", "securityScore": 100 }
    ],
    "summary": { "found": 3, "imported": 0, "updated": 3, "failed": 0 }
  }
}
```

The endpoint only accepts the key `url` — not `githubUrl`, `repo`, or `owner+repo`. Anything else returns 400 *"A URL is required"*.

**Don't rerun this for every commit.** Only call it when:
- A skill is added, renamed, or removed (directory rename or new `SKILL.md`).
- A `name:` or `description:` field changes in a `SKILL.md` frontmatter.
- The body of a `SKILL.md` has a substantial update you want surfaced before the next daily sync (≤ 24h).

For push-time sync without manual calls, set up a GitHub webhook → `https://agentskill.sh/api/webhooks/github`, content type `application/json`, events `push` only (Settings → Webhooks → Add webhook on the GitHub repo).

**Public pages** — verify after a re-scan:
- https://agentskill.sh/@purchasely/purchasely-integrate
- https://agentskill.sh/@purchasely/purchasely-review
- https://agentskill.sh/@purchasely/purchasely-debug

## Publishing / refreshing on skills.sh

The same three skills are also installable through the [`skills` CLI](https://www.skills.sh/docs):

```bash
npx skills add Purchasely/Purchasely-AI-Plugin
```

skills.sh has **no submission step** — the leaderboard is populated automatically from anonymous install telemetry collected by the CLI. The badge `https://skills.sh/b/Purchasely/Purchasely-AI-Plugin` increments on real installs only.

To **validate the repo layout** locally before pushing (catches frontmatter / directory-name mismatches the CLI would reject):

```bash
npx --yes skills add . --list
```

Should report `Found 3 skills` with names `purchasely-debug`, `purchasely-integrate`, `purchasely-review`. The CLI auto-discovers `skills/` and the `.claude-plugin/` manifests — no extra config needed.

# context-mode — MANDATORY routing rules

You have context-mode MCP tools available. These rules are NOT optional — they protect your context window from flooding. A single unrouted command can dump 56 KB into context and waste the entire session.

## BLOCKED commands — do NOT attempt these

### curl / wget — BLOCKED
Any Bash command containing `curl` or `wget` is intercepted and replaced with an error message. Do NOT retry.
Instead use:
- `ctx_fetch_and_index(url, source)` to fetch and index web pages
- `ctx_execute(language: "javascript", code: "const r = await fetch(...)")` to run HTTP calls in sandbox

### Inline HTTP — BLOCKED
Any Bash command containing `fetch('http`, `requests.get(`, `requests.post(`, `http.get(`, or `http.request(` is intercepted and replaced with an error message. Do NOT retry with Bash.
Instead use:
- `ctx_execute(language, code)` to run HTTP calls in sandbox — only stdout enters context

### WebFetch — BLOCKED
WebFetch calls are denied entirely. The URL is extracted and you are told to use `ctx_fetch_and_index` instead.
Instead use:
- `ctx_fetch_and_index(url, source)` then `ctx_search(queries)` to query the indexed content

## REDIRECTED tools — use sandbox equivalents

### Bash (>20 lines output)
Bash is ONLY for: `git`, `mkdir`, `rm`, `mv`, `cd`, `ls`, `npm install`, `pip install`, and other short-output commands.
For everything else, use:
- `ctx_batch_execute(commands, queries)` — run multiple commands + search in ONE call
- `ctx_execute(language: "shell", code: "...")` — run in sandbox, only stdout enters context

### Read (for analysis)
If you are reading a file to **Edit** it → Read is correct (Edit needs content in context).
If you are reading to **analyze, explore, or summarize** → use `ctx_execute_file(path, language, code)` instead. Only your printed summary enters context. The raw file content stays in the sandbox.

### Grep (large results)
Grep results can flood context. Use `ctx_execute(language: "shell", code: "grep ...")` to run searches in sandbox. Only your printed summary enters context.

## Tool selection hierarchy

1. **GATHER**: `ctx_batch_execute(commands, queries)` — Primary tool. Runs all commands, auto-indexes output, returns search results. ONE call replaces 30+ individual calls.
2. **FOLLOW-UP**: `ctx_search(queries: ["q1", "q2", ...])` — Query indexed content. Pass ALL questions as array in ONE call.
3. **PROCESSING**: `ctx_execute(language, code)` | `ctx_execute_file(path, language, code)` — Sandbox execution. Only stdout enters context.
4. **WEB**: `ctx_fetch_and_index(url, source)` then `ctx_search(queries)` — Fetch, chunk, index, query. Raw HTML never enters context.
5. **INDEX**: `ctx_index(content, source)` — Store content in FTS5 knowledge base for later search.

## Subagent routing

When spawning subagents (Agent/Task tool), the routing block is automatically injected into their prompt. Bash-type subagents are upgraded to general-purpose so they have access to MCP tools. You do NOT need to manually instruct subagents about context-mode.

## Output constraints

- Keep responses under 500 words.
- Write artifacts (code, configs, PRDs) to FILES — never return them as inline text. Return only: file path + 1-line description.
- When indexing content, use descriptive source labels so others can `ctx_search(source: "label")` later.

## ctx commands

| Command | Action |
|---------|--------|
| `ctx stats` | Call the `ctx_stats` MCP tool and display the full output verbatim |
| `ctx doctor` | Call the `ctx_doctor` MCP tool, run the returned shell command, display as checklist |
| `ctx upgrade` | Call the `ctx_upgrade` MCP tool, run the returned shell command, display as checklist |

<!-- rtk-instructions v2 -->
# RTK (Rust Token Killer) - Token-Optimized Commands

## Golden Rule

**Always prefix commands with `rtk`**. If RTK has a dedicated filter, it uses it. If not, it passes through unchanged. This means RTK is always safe to use.

**Important**: Even in command chains with `&&`, use `rtk`:
```bash
# ❌ Wrong
git add . && git commit -m "msg" && git push

# ✅ Correct
rtk git add . && rtk git commit -m "msg" && rtk git push
```

## RTK Commands by Workflow

### Build & Compile (80-90% savings)
```bash
rtk cargo build         # Cargo build output
rtk cargo check         # Cargo check output
rtk cargo clippy        # Clippy warnings grouped by file (80%)
rtk tsc                 # TypeScript errors grouped by file/code (83%)
rtk lint                # ESLint/Biome violations grouped (84%)
rtk prettier --check    # Files needing format only (70%)
rtk next build          # Next.js build with route metrics (87%)
```

### Test (60-99% savings)
```bash
rtk cargo test          # Cargo test failures only (90%)
rtk go test             # Go test failures only (90%)
rtk jest                # Jest failures only (99.5%)
rtk vitest              # Vitest failures only (99.5%)
rtk playwright test     # Playwright failures only (94%)
rtk pytest              # Python test failures only (90%)
rtk rake test           # Ruby test failures only (90%)
rtk rspec               # RSpec test failures only (60%)
rtk test <cmd>          # Generic test wrapper - failures only
```

### Git (59-80% savings)
```bash
rtk git status          # Compact status
rtk git log             # Compact log (works with all git flags)
rtk git diff            # Compact diff (80%)
rtk git show            # Compact show (80%)
rtk git add             # Ultra-compact confirmations (59%)
rtk git commit          # Ultra-compact confirmations (59%)
rtk git push            # Ultra-compact confirmations
rtk git pull            # Ultra-compact confirmations
rtk git branch          # Compact branch list
rtk git fetch           # Compact fetch
rtk git stash           # Compact stash
rtk git worktree        # Compact worktree
```

Note: Git passthrough works for ALL subcommands, even those not explicitly listed.

### GitHub (26-87% savings)
```bash
rtk gh pr view <num>    # Compact PR view (87%)
rtk gh pr checks        # Compact PR checks (79%)
rtk gh run list         # Compact workflow runs (82%)
rtk gh issue list       # Compact issue list (80%)
rtk gh api              # Compact API responses (26%)
```

### JavaScript/TypeScript Tooling (70-90% savings)
```bash
rtk pnpm list           # Compact dependency tree (70%)
rtk pnpm outdated       # Compact outdated packages (80%)
rtk pnpm install        # Compact install output (90%)
rtk npm run <script>    # Compact npm script output
rtk npx <cmd>           # Compact npx command output
rtk prisma              # Prisma without ASCII art (88%)
```

### Files & Search (60-75% savings)
```bash
rtk ls <path>           # Tree format, compact (65%)
rtk read <file>         # Code reading with filtering (60%)
rtk grep <pattern>      # Search grouped by file (75%). Format flags (-c, -l, -L, -o, -Z) run raw.
rtk find <pattern>      # Find grouped by directory (70%)
```

### Analysis & Debug (70-90% savings)
```bash
rtk err <cmd>           # Filter errors only from any command
rtk log <file>          # Deduplicated logs with counts
rtk json <file>         # JSON structure without values
rtk deps                # Dependency overview
rtk env                 # Environment variables compact
rtk summary <cmd>       # Smart summary of command output
rtk diff                # Ultra-compact diffs
```

### Infrastructure (85% savings)
```bash
rtk docker ps           # Compact container list
rtk docker images       # Compact image list
rtk docker logs <c>     # Deduplicated logs
rtk kubectl get         # Compact resource list
rtk kubectl logs        # Deduplicated pod logs
```

### Network (65-70% savings)
```bash
rtk curl <url>          # Compact HTTP responses (70%)
rtk wget <url>          # Compact download output (65%)
```

### Meta Commands
```bash
rtk gain                # View token savings statistics
rtk gain --history      # View command history with savings
rtk discover            # Analyze Claude Code sessions for missed RTK usage
rtk proxy <cmd>         # Run command without filtering (for debugging)
rtk init                # Add RTK instructions to CLAUDE.md
rtk init --global       # Add RTK to ~/.claude/CLAUDE.md
```

## Token Savings Overview

| Category | Commands | Typical Savings |
|----------|----------|-----------------|
| Tests | vitest, playwright, cargo test | 90-99% |
| Build | next, tsc, lint, prettier | 70-87% |
| Git | status, log, diff, add, commit | 59-80% |
| GitHub | gh pr, gh run, gh issue | 26-87% |
| Package Managers | pnpm, npm, npx | 70-90% |
| Files | ls, read, grep, find | 60-75% |
| Infrastructure | docker, kubectl | 85% |
| Network | curl, wget | 65-70% |

Overall average: **60-90% token reduction** on common development operations.
<!-- /rtk-instructions -->