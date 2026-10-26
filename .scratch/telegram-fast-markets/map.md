# Fast group markets in Telegram

> **Superseded on 2026-10-24** by [Grant-ready fast markets on Base](../base-grant-markets/map.md): the goal became retro and builder grants, which need onchain usage. The two research tickets moved there.

Label: wayfinder:map

## Destination

A decision record for **fast group markets in Telegram**: members of one Telegram group start a market that closes in minutes, stake points in a pari-mutuel pot, and a data feed settles it with no dispute. The record fixes what Telegram allows, the settlement feeds and manipulation limits, the stake and window design, the chat flow, and a first test: 3 real groups, 2 weeks, points only. The map ends at the decision. Building is the next effort.

## Notes

- Redrawn on 2026-10-24 from [Live group markets in Zalo](../group-markets/map.md), which is superseded. Zalo was dropped because a Mini App can't post into a group or read its members. Telegram bots can do both (to be confirmed by a ticket).
- Direction: the fast road of Pumpcade (1–30 minute pari-mutuel markets) but not a clone. The difference is a private pot scoped to one group, not public markets, and majors (BTC, ETH) and sports scores, not memecoin market caps, which can be pumped in the last minute.
- Feed-settled only for the first version, so no human dispute game. Human-settled questions come later, if groups use it.
- Points or testnet only. Real money is out until a lawyer says otherwise: short-window crypto bets are the riskiest legal category.
- Farcaster mini app comes after Telegram, and grants after real usage numbers.
- Reuse, don't reopen: [Stake model for the first test](../group-markets/issues/05-stake-model-for-the-first-test.md) (no-value points, pari-mutuel, hard Cutoff, refunds when nothing settles). The prior-based LMSR and the Greenlight code stay untouched.
- The Speedrun challenge gets submitted first. It is separate from this map.
- Skills every session should consult: grilling, domain-modeling, research, prototype.
- Research tickets run on Sonnet at medium effort.
- Plan, don't do. Don't build the bot, contracts or app while this map is open.

## Decisions so far

- [How friend and group prediction markets fared](../group-markets/issues/03-how-friend-and-group-prediction-markets-fared.md): no product publishes traction, and none lets a group run its own questions at scale. Pumpcade is the closest: pari-mutuel, time-weighted shares, one settler reading an API, testnet beta.
- [Why group betting products stalled](../group-markets/issues/09-why-group-betting-products-stalled.md): no postmortems exist; the likely causes are groups not creating questions and a separate app people forget, so the first test measures question creation.
- [Stake model for the first test](../group-markets/issues/05-stake-model-for-the-first-test.md): no-value points, pari-mutuel pot with no fee, hard Cutoff, stakes returned when nothing settles. Revisit only the window length and time weighting for minute-scale markets.
## Not yet specified

- Whether the first test is onchain (Base testnet) or fully offchain, and what that costs in onboarding inside Telegram.
- Real money after the first test: legal wrapper, currency, and who runs it.
- Abuse inside a group: several accounts per person, and a member who can move the underlying (small-cap tokens).
- Farcaster mini app and grants: which program, and what usage proof it needs.
- What happens to the Greenlight code and the Speedrun contracts.

## Out of scope

- Building or deploying the bot or app.
- Zalo, and any surface other than Telegram.
- Memecoin market-cap markets and tap trading.
- Human-settled questions and the dispute game ([Resolution and dispute game](../group-markets/issues/06-resolution-and-dispute-game.md) stays on file for later).
- Public markets open to strangers, and competing with Polymarket or Kalshi.
- Real money in the first test.
