# Grant-ready fast markets on Base

> **Superseded on 2026-10-24** by [Creator markets in the feed](../creator-feed-markets/map.md): the user asked for a product form, not a grant plan. The grants and feed-settlement tickets moved there.

Label: wayfinder:map

## Destination

A decision record that names the **retro or builder grant programs** to target and fixes the smallest product and usage plan that qualifies for them: fast markets that close in minutes, settled by a price feed, played from Telegram groups, onchain on Base mainnet with stakes of no cash value. The record fixes which programs and what proof each needs, the onchain stake design, the Telegram flow, and a usage plan with a target number, a deadline and a stop rule. The map ends at the decision. Building is the next effort.

## Notes

- Redrawn on 2026-10-24 from [Fast group markets in Telegram](../telegram-fast-markets/map.md), which is superseded. The user chose option B: retro and builder grants, not hackathons or raising money. The points-only test was dropped because offchain points don't count as onchain usage for any grant.
- Core tension: retro grants measure real onchain usage (mainnet), but real-money betting is very likely illegal in Vietnam ([Vietnam law for points and real-money group markets](../group-markets/issues/02-vietnam-law-for-points-and-real-money-group-markets.md)). The default way out is free-to-play onchain stakes: mainnet transactions, gas sponsored by a paymaster, tokens with no cash value. Whether that counts as usage is a ticket, not an assumption.
- Direction stays the fast road of Pumpcade but not a clone: a pot scoped to one group, majors (BTC, ETH) settled by a feed, no memecoins, no human dispute game.
- Least work wins: reuse the Speedrun contracts and frontend where they fit, and pick the program whose bar is lowest.
- The Speedrun challenge gets submitted first. It is separate from this map.
- Skills every session should consult: grilling, domain-modeling, research, prototype.
- Research tickets run on Sonnet at medium effort. The user delegates them; don't fire them unasked.
- Plan, don't do. Don't build the bot, contracts or app while this map is open.

## Decisions so far

- [How friend and group prediction markets fared](../group-markets/issues/03-how-friend-and-group-prediction-markets-fared.md): no product publishes traction, and none lets a group run its own questions at scale. Pumpcade is the closest.
- [Why group betting products stalled](../group-markets/issues/09-why-group-betting-products-stalled.md): the likely causes are groups not creating questions and a separate app people forget, so the usage plan should measure markets started.
- [Vietnam law for points and real-money group markets](../group-markets/issues/02-vietnam-law-for-points-and-real-money-group-markets.md): points with no cash-out, no bought points and no prizes looks legal; real money very likely isn't. Grant money paid to the builder is not a prize to players, but the plan must keep stakes worthless.
- [Stake model for the first test](../group-markets/issues/05-stake-model-for-the-first-test.md): pari-mutuel pot with no fee, hard Cutoff, stakes returned when nothing settles. Reused as the starting point for the onchain design.
- [What Telegram lets a group bot and mini app do](issues/10-what-telegram-lets-a-group-bot-and-mini-app-do.md): a bot covers the chat flow but can't list members and a Mini App doesn't get the group ID; Mini App wallets must use TON Connect, so a Base wallet in a Mini App likely breaks the rules and no-value tokens aren't exempt; the safe route is a plain bot linking out, untested.
- [How a feed can settle a fast market safely](issues/11-how-a-feed-can-settle-a-fast-market-safely.md): settle majors with Pyth on Base via `parsePriceFeedUpdatesUnique` at a pinned timestamp, start value captured the same way; about a cent per settlement (estimate); hard Cutoff, majors only; refund on tie, one-sided pot or outage.

## Not yet specified

- Which identity the grant programs need (KYC, a public name, a team) and whether an anonymous solo dev qualifies at all; this may reshape the destination.
- Abuse that inflates usage: one person with many wallets, bots, and whether grant programs filter it out.
- What happens to the Greenlight code and the Speedrun contracts once the onchain design is fixed.
- A Farcaster or Base App mini app as a second surface, if a grant program weights it.

## Out of scope

- Building or deploying the bot, contracts or app.
- Hackathons and raising money from investors (options A and C, not chosen).
- Real-money stakes, and any token with cash value.
- Zalo; memecoin market-cap markets and tap trading; human-settled questions and the dispute game.
- Public markets open to strangers, and competing with Polymarket or Kalshi.
