# What Zalo lets a group app do

Label: wayfinder:research
Type: research
Status: closed

## Question

What can a third-party app do inside a Zalo group chat, and what will Zalo refuse to host?

Cover:

- The integration surfaces: Zalo Mini App, Zalo Official Account (OA), any bot or group-chat API. For each: can it be shared into a group, know which group it was opened from and who its members are, post messages or cards back into the group, and send notifications (for example "result proposed, 24h to dispute")?
- Identity: what user ID a mini app gets (Zalo user ID, phone number with consent), and whether it's stable across groups.
- Policy: Zalo's rules on betting, gambling, wagers, points with prizes, and crypto or wallets inside mini apps, plus how the review works and how long it takes.
- Webview limits that matter for an onchain version: can a mini app run a wallet SDK, passkeys, or WalletConnect deep links?
- Costs and requirements: a business entity, a Vietnamese company, fees.

Use Zalo's own developer docs (developers.zalo.me, mini.zalo.me) first. Rank nothing; just give the facts the stake-model and prototype tickets need.

## Resolution

The Mini App can learn the group id when opened from a chat's menu (Android documented, iOS unconfirmed), but there is no member-list API and no API to post into a group; notifications go to individuals only. Policy bans gambling, prize payouts and unlicensed crypto; prediction markets and free points games are unmentioned. Review takes 3 working days. Open: wallets in the webview, individual publishing, unpublished-app testing with 3 groups.

Findings: `.scratch/group-markets/research/01-what-zalo-lets-a-group-app-do.md` on local branch `research/zalo-group-app-surfaces` (no remote, no PR).
