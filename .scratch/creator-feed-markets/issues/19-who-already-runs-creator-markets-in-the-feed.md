# Who already runs creator markets in the feed

Label: wayfinder:research
Type: research
Status: closed

## Question

Does any product already let anyone create a prediction market, seed its liquidity and earn its fees, with settlement only by a price feed or onchain state, traded inside the Farcaster or Base App feed?

Cover:

- Products in the feed: Swipen, Ponder, Bracky, the unnamed prediction mini app in [FORKOFF's 2026 audit](https://forkoff.xyz/blog/ecosystem/farcaster-mini-apps-distribution-2026), Limitless's own mini app, and any others. For each: who creates markets, who earns fees, how it settles, weekly users, and launch date.
- Permissionless creators elsewhere: Opinion (BNB), Melee Markets and Path Protocol (Solana), Zeitgeist, CeloCaster, Pumpcade. How creator incentives work and what traction they publish.
- Markets on Zora or Clanker coins (market cap or price targets): does anyone run them on Base?
- Known failures: rugged or abandoned community markets, and why.

Required output: a table per product (surface, chain, who creates, creator fee, settlement, weekly users, source), then apply the kill rule in the map's Notes and state the verdict: keep, narrow to Zora and Clanker coins, or neither.

## Resolution

Verdict: **keep** the pick. Nobody runs creator-seeded, chain-settled markets natively in the Farcaster / Base App feed at 1,000+ weekly users. The nearest competitor is Limitless User-Generated Markets (live on Base since 2026-06-02): any user can create a market and earn a share of taker fees, and price markets settle via Pyth or Chainlink. It is a web app with no official mini app found. First-month traction (162 creators, 1,611 markets, $2.2M volume) is second-hand and unsourced, with no weekly-user number. Community markets are creator-reported, so not purely feed-settled. The only feed wrapper found is Swipen (0 stars, no usage data). Feed-native apps with traction are crowd-vote or token games: Ponder (25k+ active, not weekly) and the unnamed FORKOFF app (5,840 WAU; settlement and creators undisclosed). Base App reportedly dropped Farcaster mini-app spec support on 2026-04-09 (second-hand). No markets on Zora or Clanker coins found. No documented rugs; main risk is creator-reported outcomes. Re-open the narrow-to-coins branch if Limitless or a wrapper ships a feed-native UGM surface. Many first-party pages wouldn't fetch, so some rows rest on search snippets.

Details and sources: [research/19-who-already-runs-creator-markets-in-the-feed.md](../research/19-who-already-runs-creator-markets-in-the-feed.md)
