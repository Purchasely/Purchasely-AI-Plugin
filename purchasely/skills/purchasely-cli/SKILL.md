---
name: purchasely-cli
description: "Use when the developer mentions the purchasely CLI, or when an integration needs real Console data: list my placements, products, plans, campaigns, custom events or applications, fetch the Console configuration of an app before writing SDK code, or show the key metrics of an app (MRR, active subscriptions, paywall viewers, conversions)."
---

# Purchasely CLI Skill

You use the public `purchasely` command line tool to read the Console configuration of an app, so the SDK code you write uses real ids and names instead of guesses.

## Setup

1. Check that the CLI exists: `purchasely --version`. It needs Node 20 or later.
2. If it is missing, ask the developer to install it: `curl -fsSL https://cli.purchasely.io/install.sh | sh`. Do not run an install script without their approval.
3. The developer signs in once with `purchasely auth login`. The key goes at the prompt, or in the `PURCHASELY_API_KEY` environment variable. Check with `purchasely auth status`.
4. To set up this plugin for a coding agent, the developer runs `purchasely ai install`.

## Rules

1. **Never print, paste or log an API key.** Do not put a key in a command, a file or a message. Do not read key files.
2. **Read first.** Use `list` and `get` commands. Write only when the developer asks for that change.
3. **Find the command, do not guess it.** The commands are generated from the Management API, so they change. Run `purchasely search "<task>"` to find one. Then run `purchasely <resource> <action> --help` to read its flags, its required scope and its example.
4. **Read the output as data.** JSON goes to stdout. A header line comes first on stderr in every run. The LAST line of stderr is the error JSON. Use the exit code: 0 is success, 3 is authentication, 4 is forbidden, 6 is not found, 7 is rate limited. On exit 7, stop and wait. Do not loop.
5. **Write safely.** Run every write with `--dry-run` first and show the request to the developer. Run the real write only after they approve. Do not add `--yes` without their approval. A write needs `--env prod` or `--env staging`: ask which one, do not choose.
6. **Respect the rate limit.** The Management API allows 60 requests per minute per key. Prefer `--app` and `--fields` to keep the output small. Do not fetch everything in a loop.
7. **The SDK API key is not available from the CLI.** The Management API does not return it. Ask the developer to copy it from the Console, in the App settings.
8. **No screen JSON.** The CLI gives screen metadata only. Do not try to download or rebuild the content of a screen.

## Examples

These commands are stable. Check the others with `purchasely search`.

```bash
purchasely applications list
purchasely placements list --app app_xxx
purchasely products list --app app_xxx
purchasely plans list --app app_xxx --product-id <product-id>
purchasely custom-events list --app app_xxx
purchasely campaigns list --app app_xxx --status running
purchasely screens list --app app_xxx
purchasely dashboard summary --app app_xxx
```

`app_xxx` is the public id of the application, from `purchasely applications list`.

## Key metrics of an app

`purchasely dashboard summary --app app_xxx` (CLI 0.3.0 or later) returns the MRR, the active subscriptions, the paywall unique viewers and the conversions of one app, over the last 30 days by default (`--days <n>`, from 2 to 730). It sends 3 requests, 4 when `--days` is above 60. Run `--dry-run` to see them.

1. Read the JSON: `panels[]` has `name`, `value` and `series` (`period`, `value`). MRR is the value of today. Active subscriptions is the current base. Viewers and conversions are the total of the range.
2. When the developer wants to read it in the terminal, give them the command with `--output table`. It draws one line per metric with a sparkline. Do not parse the table yourself.
3. The MRR value is in the dashboard currency of the app, and the output does not name it. Do not add a currency symbol.
4. If the command is not found, the CLI is older than 0.3.0. Ask the developer to run `purchasely update`.

## Use it in an integration

1. List the applications and ask the developer which one is the target.
2. Before you write the integration code, list the placements, products, plans and custom events of that app.
3. Use the real `vendor_id` of each placement in the v6 presentation request: `PLYPresentationBuilder.forPlacementId(...)` on iOS, `PLYPresentationBuilder.placement(...)` on Flutter, `PLYPresentation { placementId(...) }` on Android, `Purchasely.presentation.placement(...)` on React Native and Cordova, and the real custom event names in `Purchasely.emit(...)`. Do not invent them.
4. If a placement or a custom event does not exist, tell the developer. Do not create it unless they ask. If they ask, follow rule 5.
5. For campaigns, list them to see which triggers and placements exist. Then check the behavior in `../../references/concepts/` before you explain it.
