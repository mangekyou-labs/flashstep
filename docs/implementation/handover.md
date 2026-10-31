# Handover build

A payer hosts the static `out/` directory and edits one JSON file. Changing a brand does not need a Node server or a rebuild.

## Deploy

Deploy with `docs/implementation/payer-deploy.md`.

After deploy, put the printed addresses into the served `brand.json` fields `address` (up/down) and `thresholdAddress` (threshold pots). Not into env vars.

In that same brand.json entry, set:

- `chainId`: `8453` on Base, `84532` on Base Sepolia. The shipped sample stays `31337` for local Anvil.
- `explorerUrl`: the page links each Round's settle transaction. Empty means no link.
- `campaignCost`: the payer view shows Campaign cost and net only when this is set.

## Settle bot

Run the settle bot as described in `docs/implementation/settle-bot.md`.

## Hosting

```sh
yarn workspace @se-2/nextjs export
```

`yarn handover:export` runs the same export. It writes `packages/nextjs/out`. Serve that directory as static files. Edit `brand.json` and re-upload that one file. `?brand=TICKER` selects a key. Addresses never come from the query string.

## frame-ancestors

Next `headers()` is omitted from the static export. Set `Content-Security-Policy: frame-ancestors` at the host (Cloudflare `_headers` or nginx). The dev server still sends that header when not exporting.

## Handover

The developer hosts during the pilot. Hand the payer `out/`, `brand.json`, and this runbook.
