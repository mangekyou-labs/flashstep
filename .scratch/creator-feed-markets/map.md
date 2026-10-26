# Creator markets in the feed

> **Superseded on 2026-10-25** by [A business that pays for 30-second rounds](../paid-fast-rounds/map.md): the user asked for 30-second rounds and a real payer beyond coin-price bettors. The decisions here stay as prior art.

Label: wayfinder:map

## Destination

A decision record for **creator markets in the Farcaster / Base App feed**: anyone opens a prediction market in one tap with an opening stake and earns its creator fee, the market is settled only by a price feed or onchain state (no human reporter), and it is traded from a mini app embed in the feed. The record either confirms this is still open or narrows it (to markets on Zora and Clanker coins), and fixes the settlement sources, the creator fee and pricing, the legal path, the grant target and a launch plan with a stop rule. The map ends at the decision. Building is the next effort.

## Notes

- Chosen on 2026-10-24 by the user after redrawing from [Grant-ready fast markets on Base](../base-grant-markets/map.md). The user wants a unique product inspired by the Speedrun challenge, worth implementing; grants come after it ships.
- Speedrun mapping: the challenge's LP becomes the market creator, its oracle becomes an automatic resolver reading a feed or the chain, and `PredictionMarket.sol` becomes a template deployed by a factory.
- Why: creators earn fees, which answers "groups don't create questions" ([Why group betting products stalled](../group-markets/issues/09-why-group-betting-products-stalled.md)); every shared market is a tradable ad; chain settlement means nobody has to trust the dev, and answers the rug-pull risk of open community markets.
- A quick check on 2026-10-24 found neighbours but not this exact combination: Opinion (BNB) and Melee (Solana) let anyone create markets; Limitless runs short crypto markets on Base; Swipen, Ponder and Bracky put markets in the feed; Clanker pays creators fees for tokens. The prior-art ticket decides.
- Kill rule for the prior-art ticket: keep the pick if nobody runs creator-seeded, chain-settled markets in the feed, or those who do have under ~1,000 weekly users. If a large player does, narrow to markets on Zora and Clanker coins settled onchain.
- Real money is the product, so the legal path is a ticket. Build and demo on testnet until a lawyer clears mainnet.
- Skills every session should consult: grilling, domain-modeling, research, prototype.
- Research tickets run on Sonnet at medium effort. The user delegates them; don't fire them unasked.
- Plan, don't do. Don't build contracts or the mini app while this map is open.

## Decisions so far

- [How friend and group prediction markets fared](../group-markets/issues/03-how-friend-and-group-prediction-markets-fared.md): no product publishes traction; Pumpcade is the closest prior art for fast, API-settled markets.
- [Why group betting products stalled](../group-markets/issues/09-why-group-betting-products-stalled.md): the likely causes are nobody creating questions and a separate app people forget; creator fees and in-feed trading are this map's answers.
- [How a feed can settle a fast market safely](issues/11-how-a-feed-can-settle-a-fast-market-safely.md): settle majors with Pyth on Base by reading the price at a pinned time, with a hard Cutoff before it; refund on a tie or one-sided pot, and void and refund after a bounded retry on an outage. Onchain-state settlement for coins wasn't covered.
- [Vietnam law for points and real-money group markets](../group-markets/issues/02-vietnam-law-for-points-and-real-money-group-markets.md): real money is very likely illegal in Vietnam today; the legal-path ticket starts here.
- [Who already runs creator markets in the feed](issues/19-who-already-runs-creator-markets-in-the-feed.md): keep the pick; Limitless UGM is the nearest rival (web app, fee-sharing creators) but nobody runs it natively in the feed at 1,000+ weekly users.
- [Which retro and builder grants fit a solo dev](issues/15-which-retro-and-builder-grants-fit-a-solo-dev.md): first pick is the Base Builder Grant (up to $5,000, prediction markets a focus area); Optimism Retro Funding is paused and other programs are gone or off-chain.
- [Legal path for real-money creator markets](issues/20-legal-path-for-real-money-creator-markets.md): immutable no-admin contracts plus an independent offshore frontend operator with geoblocking (about $2-5k); personal risk reduced not removed, a Vietnamese lawyer must confirm.
- [Creator fee and pricing](issues/21-creator-fee-and-pricing.md): a pari-mutuel pot, not the Speedrun AMM; fixed 2% creator fee, zero protocol fee, a required opening stake of at least 0.002 ETH on both sides, Cutoff at the window start, 5/15/60-minute windows, refunds with no fee on a Tie, Unmatched or Expired market.
- [How the in-feed flow looks](issues/23-how-the-in-feed-flow-looks.md): a one-card mini app, one market per cast; the embed is a poster with the pot split and an absolute Cutoff time (no countdown, since it is cached), and staking with Yes/No payout buttons, settling and claiming all happen on the opened card.
- [Does Base App still run Farcaster mini apps](issues/24-does-base-app-still-run-farcaster-mini-apps.md): partially no; Base App dropped the Farcaster spec on 2026-04-09 (second-hand sourcing), but the grant and Builder Codes don't need Base App, so a Farcaster-first v1 with wagmi/SIWE wallet auth loses only store placement, notifications and auto attribution.
- [The launch plan](issues/22-the-launch-plan.md): testnet-only v1 (BTC/ETH up/down on Pyth, Farcaster mini app with wagmi/SIWE, a testnet ETH drip) live by 2026-12-06; the target is 20 taken markets a week from 15+ outside wallets for 2 weeks in a row within 6 weeks, or stop; apply for the Base grant once the target is hit; no mainnet without a lawyer.

## Not yet specified

Nothing left. The map is done; building testnet v1 is the next effort, specified in [Creator markets in the feed: testnet v1](spec.md).

## Out of scope

- Building or deploying contracts or the mini app.
- Markets settled by a person, including the creator, and any dispute game.
- Group-only and private markets, Zalo and Telegram as surfaces, and the points-only test. Telegram's developer terms require TON Connect for Mini App wallets, which likely rules out Base wallets ([What Telegram lets a group bot and mini app do](../base-grant-markets/issues/10-what-telegram-lets-a-group-bot-and-mini-app-do.md)).
- Hackathons and raising money from investors.
- Competing with Polymarket or Kalshi on mainstream events.
- Mainnet, the Vietnamese lawyer and the offshore operator: no money for them (about $2-5k plus legal review). Mainnet stays blocked until a lawyer clears it ([The launch plan](issues/22-the-launch-plan.md)).
- Markets on Zora and Clanker coins, and settling on onchain state: the prior-art ticket kept the broad pick, and v1 launches on BTC and ETH only.
- Whether the Greenlight UI is reused: a build choice for the next effort.
