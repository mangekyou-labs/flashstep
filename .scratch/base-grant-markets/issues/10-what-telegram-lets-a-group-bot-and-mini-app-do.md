# What Telegram lets a group bot and mini app do

Label: wayfinder:research
Type: research
Status: closed

## Question

What can a Telegram bot plus Mini App do inside a group chat, and what do Telegram's rules allow for a free-to-play onchain prediction game (sponsored gas, stakes with no cash value)?

Cover:

- Bot capabilities in groups: reading commands like `/predict 10 yes`, posting and editing messages, inline buttons, group privacy mode, reading who is in the group, and rate limits.
- Mini App capabilities: launching from a group message or button, identifying the user and the group, payments, and wallet connection (TON Connect, and whether an EVM wallet on Base works, such as an embedded or smart wallet with a paymaster).
- Telegram's terms and Mini App rules on gambling, betting and crypto, and whether free points games and prediction markets are allowed. Include any app review or listing rules.
- Costs and requirements: hosting, entity or verification, fees.
- Examples of Telegram betting or prediction bots that exist, and whether any were banned.

## Resolution

A group bot covers the chat flow: `/predict@bot 10 yes` commands work under privacy mode, it edits its own pot message and buttons in place, and it can check one named user (reliably only as admin) but cannot list members. About 20 messages per minute per group. A Mini App opened by direct link gets the user and a `chat_instance`, not the group chat ID, so pass a market ID in `startapp` and map it to the group on the server.

The blocker for Base is Telegram's bot developer terms 7.1/7.2: Mini App wallets must connect through TON Connect, with carve-outs only for multichain wallet apps and bridging. An embedded or smart wallet on Base likely conflicts (a reading; the text doesn't mention embedded wallets), and the rules have no exemption for no-value tokens, so onchain Base stakes probably still count. Passkey wallets such as Coinbase Smart Wallet are reportedly broken in Telegram's webview (secondary source). Plain bots without a Mini App are exempt, but linking out to a Base dapp is untested, and clause 5.2(h) ("regulated or questionable services") plus Telegram's ban powers remain the risk. No gambling or betting text exists; no review or entity requirement; Bot API is free. TG.Casino Portal was reportedly banned (secondary source); no prediction-market bot ban found.

Unverified: inline `web_app` buttons in groups; Privy and passkey claims come from search summaries, not fetched pages.

Details and sources: [research/10-telegram-group-bot-and-mini-app.md](../research/10-telegram-group-bot-and-mini-app.md)

## Out of scope

After this was resolved, the product became creator markets in the Farcaster / Base App feed, so Telegram is out of scope in [Creator markets in the feed](../../creator-feed-markets/map.md). The TON Connect finding above is one of the reasons.
