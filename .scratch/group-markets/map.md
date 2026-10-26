# Live group markets in Zalo

> **Superseded on 2026-10-24** by [Fast group markets in Telegram](../telegram-fast-markets/map.md). Zalo was dropped because a Mini App can't post into a group or read its members. The closed tickets below stay as findings. (This file was rebuilt the same day after an accidental overwrite, from the original text and each ticket's resolution.)

Label: wayfinder:map

## Destination

A decision record for **live group markets in Zalo**: a member of one Zalo group creates a quick question, often during something the group is watching together, the group stakes on it within minutes and the group resolves it. The record fixes the stake model, the resolution and dispute game, how it lives inside Zalo, and a first test: 3 real groups, 2 weeks, no real money. The map ends at the decision. Building the app is the next effort.

## Notes

- Why this direction: an anonymous solo dev can't win trust, liquidity or a sponsor. In a group market, the members trust each other, not the dev. Stakes are small enough to need no LP. The questions are ones no public venue lists. Polymarket Squads (Sept 2026) only trades public markets together, and Friend Markets is fake points in iMessage.
- Speed is the hook (option C, chosen 2026-10-24): quick questions that close in minutes during a match, stream or event the group shares, settled by the group. Closest prior art is [Pumpcade](https://docs.cade.market/): 1–30 minute pari-mutuel markets on Solana, a 1% fee split with creator and streamer, time-weighted shares, bets from stream chat or a browser extension, settlement by a single settler reading an API.
- Zalo first. Telegram, Discord and Farcaster come later, if ever.
- No real money in the first test (points or testnet).
- The optimistic-oracle interest lives here, scaled down: the creator proposes a result, there is a challenge window, and the group decides a dispute.
- Prior art to reuse, not reopen: Invalid paying half and the Unpublished rule from the [budgeted-forecast map](../budgeted-forecast/map.md). The Greenlight code stays untouched.
- Rejected on the way here: a Seer/TRUEO-style protocol clone, futarchy, memecoin and tap-trading speed markets like [Tapl](https://chain.link/hackathon/winners/tapl), tokenized writing on Twitter, Polymarket builder apps.
- Skills every session should consult: grilling, domain-modeling, research, prototype.
- Research tickets run on Sonnet at medium effort.
- Plan, don't do.

## Decisions so far

- [What Zalo lets a group app do](issues/01-what-zalo-lets-a-group-app-do.md): a Mini App can learn the group id when opened from a chat's menu, but it can't list members or post into the group, and notifications go to individuals only. Policy bans gambling and unlicensed crypto, and doesn't mention prediction markets or free points games.
- [Vietnam law for points and real-money group markets](issues/02-vietnam-law-for-points-and-real-money-group-markets.md): points only (no cash-out, no bought points, no prizes) looks legal; real money is very likely illegal today, and Zalo betting groups are prosecuted. A lawyer is needed before any real-money stage.
- [How friend and group prediction markets fared](issues/03-how-friend-and-group-prediction-markets-fared.md): no product publishes traction, and none lets a group both create and settle its own questions at scale. Pumpcade is the closest. No evidence either way on pari-mutuel versus LMSR at 5–30 people.
- [How a small group can settle a disputed result](issues/04-how-a-small-group-can-settle-a-disputed-result.md): a proposer bond, a challenge window, a single resolver and an Invalid fallback work at group scale; a large pool of uninvolved voters doesn't. Ten candidate designs listed, none picked.
- [Stake model for the first test](issues/05-stake-model-for-the-first-test.md): offchain no-value points, a pari-mutuel pot with no fee, 2–6 outcomes, a hard creator-set Cutoff with no time weighting, and all stakes returned when a market is Unmatched, Invalid or Unpublished.
- [Resolution and dispute game](issues/06-resolution-and-dispute-game.md): the creator proposes within 10 minutes of the Cutoff, then any staker can; a 15-minute challenge window; stakers dispute with no bond; a dispute opens a 15-minute member vote needing two thirds, else the market ends Invalid; Unpublished after 24 hours; no appeal or dev override.
- [Why group betting products stalled](issues/09-why-group-betting-products-stalled.md): no postmortems exist; the likely causes are groups not creating questions and a separate app people forget, not disputes or stakes. Any real-money version is capped by law.

## Not yet specified

- Real-money stakes after the first test, which depends on the law ticket and on how the first test goes.
- Question templates for groups, and how to stop vague questions from turning into disputes.
- Abuse inside a group: several accounts per person, or the subject of a question staking on it.
- What happens to the Greenlight code now that group markets use a pari-mutuel pot.

## Out of scope

- Building or deploying the app.
- Surfaces other than Zalo.
- Markets on token prices or memecoin market caps, and tap trading.
- Public markets open to strangers, and competing with Polymarket or Kalshi.
- A standalone optimistic-oracle protocol, and futarchy.
- Real money in the first test.
