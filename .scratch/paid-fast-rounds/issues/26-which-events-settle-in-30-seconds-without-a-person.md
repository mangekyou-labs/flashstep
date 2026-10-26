# Which events settle in 30 seconds without a person

Label: wayfinder:research
Type: research
Status: closed
Blocked by: none
Assignee: MrSufferer

## Question

Beyond coin prices, which event domains can run 30-second Rounds back to back and be settled automatically from a data feed, with no human reporter?

Cover, for each domain (sports points and possessions, esports kills and rounds, livestream events, onchain events such as blocks, gas, mempool or DEX volume, social signals such as Farcaster casts or likes, and any others found):

- The data source, its latency, its cost and its licence terms (is commercial betting use allowed?).
- Whether a Round can be settled within seconds of its Window ending, and what happens on a delay or a dispute.
- How easy a bettor or the operator can manipulate the outcome inside 30 seconds.
- Whether an operator already offers it, and who supplies it.

Start from [How a feed can settle a fast market safely](../../creator-feed-markets/issues/11-how-a-feed-can-settle-a-fast-market-safely.md) and [Window and stake design for minute-scale markets](../../telegram-fast-markets/issues/12-window-and-stake-design-for-minute-scale-markets.md). Rank the domains by fit for a solo dev with $0.

## Resolution

Only onchain events (Base) and public randomness (drand or a VRF) fit a solo dev with $0 and no human reporter. Ranking, best fit first: onchain, randomness, Farcaster social, Twitch/YouTube live, esports, sports.

Licences block esports and sports: PandaScore's stats plans bar betting use and its Live tier starts at 1,000 EUR per game per month; Riot's policy says "Your product cannot feature betting or gambling functionality"; Sportradar's terms reportedly bar gambling use without written approval (seen only in a search snippet). Sports data also has human scouts at the source.

Manipulation is the bigger risk at 30 seconds: social and livestream outcomes can be produced by the bettor or the streamer. Polymarket's 5-minute crypto markets moved to a 60-second Chainlink TWAP in Aug 2026 after an attack on single-price snapshots. Operators already sell short Rounds on crypto prices (Polymarket 5-minute, Pumpcade 1-30 minute) and sports micro-markets; none was found selling 30-second onchain-event Rounds, but the search was shallow. Base 200ms blocks (Denim) are live on Sepolia and only targeted for mainnet in Nov 2026.

Unverified: the Twitch terms, the exact Sportradar clause, current Steam/GSI terms, drand period and cost, Base RPC limits, Neynar latency and terms, and who supplies Stake's and BC.Game's esports data.

Details and sources: [research/26-event-domains-for-30-second-rounds.md](../research/26-event-domains-for-30-second-rounds.md)
