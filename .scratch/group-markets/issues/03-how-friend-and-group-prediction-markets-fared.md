# How friend and group prediction markets fared

Label: wayfinder:research
Type: research
Status: closed

## Question

Which products have let a private group create, stake on and resolve its own questions, and what happened to them?

Cover:

- Manifold (private groups, creator-resolved markets), Friend Markets (iMessage), Polymarket Squads (public markets only), Kalshi social features, and older or defunct friend-betting apps (onchain or not). Include any Vietnamese or Southeast Asian ones. Also cover the fast, embedded ones: [Pumpcade](https://docs.cade.market/) (pari-mutuel, 1–30 minute markets, bets from stream chat and a browser extension) and [Tapl](https://github.com/tapl-chainlink/smart-contracts-cre) (tap trading, house vault). For these, report traction and how they handle late betting and settlement.
- For each: the stake model (points, money, pari-mutuel, AMM), who resolves, how disputes are handled, and any published numbers on retention or questions per group per week.
- Why the dead ones died, where it's known: retention, disputes, law, monetisation.
- Pari-mutuel versus an AMM or LMSR at group scale (5–30 people): what the prior art and literature say about which gives better prices and less confusion with that few traders.
- Fast markets at group scale: how often a group watching one event produces a question worth staking on, and whether markets that close in minutes keep a small group coming back.

## Resolution

No friend or group market has published retention or questions-per-group data, and none lets a group both create and resolve its own questions at scale. Pumpcade is the closest (pari-mutuel, time-weighted shares, settler reads an API, testnet beta). No head-to-head evidence for pari-mutuel vs LMSR at 5-30 traders.

Findings: `.scratch/group-markets/research/03-how-friend-and-group-prediction-markets-fared.md` on local branch `research/friend-group-markets-prior-art` (no remote, no PR).
