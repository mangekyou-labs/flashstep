# Which traditional betting formats are missing onchain

Label: wayfinder:research
Type: research
Status: resolved

## Question

This is candidate E, where the payer is bettors themselves: what do people bet on, and how, in traditional gambling that onchain prediction markets don't offer yet or offer only thinly?

Compare traditional books, exchanges, and casinos (Betfair, DraftKings, FanDuel, bet365, Pinnacle, PrizePicks, Underdog, Stake, and others) against onchain and crypto venues (Polymarket, Kalshi, Limitless, Myriad, Azuro, Overtime/Thales, SX Bet, Drift BET, Stake-style crypto casinos). Cover these:

- **Verticals:** F1 and motorsport (race winner, podium, head-to-heads, in-race, qualifying), sports below the top leagues, esports, horse racing (pari-mutuel), and any vertical with big traditional handle and little onchain volume.
- **Formats:** parlays and same-game parlays, player props and pick'em, live in-play betting, pari-mutuel pools, head-to-head matchups, futures and outrights, cash-out, and boosted odds.
- **Casino-style products:** where prediction markets touch them (for example crash games, or binary "markets" on random events). Note where this stops being a prediction market and becomes gambling licensing.

For each gap, give:
- Traditional handle or GGR, with a published source.
- What exists onchain and its volume.
- Why it's missing: the mechanism, for example parlays across correlated AMM markets, latency for in-play betting, or an oracle for live data. Or regulation: gambling licence versus CFTC event contract, with the summary-level US and non-US status.
- The structural edge an onchain version would have, if any.

Apply the map's kill rule, reading the payer as bettors:
- (i) Bettors paid for this format in the last 12 months, anywhere.
- (ii) An onchain or crypto incumbent already offers it at comparable odds.

Rank up to 5 gaps. Do not pick one; [Which candidates survive the kill rule](04-which-candidates-survive-the-kill-rule.md) does.

## Answer

Ranked gaps, kill rule read as bettors paying: (i) bettors paid for the format in the last 12 months, (ii) an onchain or crypto incumbent already offers it.

1. **Pari-mutuel horse racing.** US handle $11.04B in 2025 (Jockey Club). No onchain or crypto incumbent found; Polymarket pulled its 2026 Derby market at Churchill Downs' request. Passes (i) and (ii). The blocker is the Interstate Horseracing Act (track content rights), which an entrant would face too.
2. **F1 and motorsport per-race and in-race.** Passes (i). Partial on (ii): Polymarket's F1 volume (about $234M) is nearly all season championships ($204M for the drivers' title); a single race-winner market showed about $234K, and Kalshi is thinner. Weak pass; traditional F1 handle is not sourced.
3. **Live in-play on onchain rails.** Passes (i) (54% of DraftKings 2025 handle, unverified). Fails (ii) for top leagues, since Kalshi and Polymarket list live games; the onchain-native obstacle is latency.
4. **Casino-style short-horizon binaries.** Fails (ii): Polymarket 5-minute BTC about $4B cumulative, Stake GGR $4.7B (2024). Also the gambling-licence boundary.
5. **Parlays and same-game parlays.** Fails (ii): Kalshi Combos were 67.2% of weekly volume in mid-October 2026, Polymarket US launched parlays in Aug 2026, Overtime has onchain SGPs. Player props, pick'em, esports (Kalshi $1.73B in 12 months) and cash-out fail the same way. Boosted odds fail (i): operators fund them, bettors do not pay.

- Only the horse-racing and per-race F1 gaps survive, and both are thin or legally gated.
- US legal status is a live circuit split: Third Circuit pro-Kalshi preemption (Apr 2026), Sixth and Ninth reportedly against. Non-US licensing was not researched.

Caveats: Kalshi is off-chain but counted as an incumbent. Prediction-market volume counts contracts, not cash staked, so it is not comparable to handle (Kalshi combos are inflated by $1 notional counting). F1 handle share, DraftKings live share, Overtime, Azuro and SX Bet volumes, and the Sixth and Ninth Circuit holdings are secondary or unverified. "No incumbent" means none found. See the Unverified section of the findings file.

Findings: docs/research/betting-gaps.md on branch research/betting-gaps, commit d194934. Branch is local; no origin remote.
