# The product and the payer

Label: wayfinder:grilling
Type: grilling
Status: closed
Blocked by: 25, 26, 27, 28, 29
Assignee: MrSufferer

## Question

Which one payer, and which product does it pay for?

Pick from the findings of [Who you can reach and how much time](25-who-you-can-reach-and-how-much-time.md), [Which events settle in 30 seconds without a person](26-which-events-settle-in-30-seconds-without-a-person.md), [How crypto operators buy game content](27-how-crypto-operators-buy-game-content.md), [Who already sells fast rounds to operators](28-who-already-sells-fast-rounds-to-operators.md) and [Legal exposure as a game supplier from Vietnam](29-legal-exposure-as-a-game-supplier-from-vietnam.md). Settle: the payer segment (crypto operators by default), the event domain, the shape (embeddable game, widget, API or feed), what is onchain or provably fair and why the payer cares, the price and deal type asked for, and what the Speedrun code still contributes.

Non-operator payers (crypto projects funding prize Rounds as marketing, streamers, trading-group admins) are candidates on equal footing with operators: the reach ranking in [Who you can reach and how much time](25-who-you-can-reach-and-how-much-time.md) and the legal findings both point away from the operator default.

## Resolution

Grilled with the user on 2026-10-26. A first pass settled on free-to-play prize Campaigns. The user then rejected it ("how this should be a prediction market if it's free-to-play?") and chose real money stakes, so this resolution replaces that one.

- **Payer:** crypto projects, either token teams (Rounds on their own coin) or launchpads and communities on Base (Rounds on many coins, Pumpcade-style memecoin markets), reached first through the user's Vietnamese and Asian crypto communities. Fallback: streamers and trading-group admins. Licensed operators are dropped as payer (supplier-licence wall, cold reach only).
- **Operator and roles, white-label:** the payer deploys and owns the market contract, so the payer is the Operator and the Liquidity provider. It seeds each Round and absorbs the LP's profit or loss as marketing spend. The stake and liquidity token is the payer's choice per Campaign: its own token, ETH or USDC. The Oracle is no person: each Round settles itself from pool TWAP Readings on Base (anyone, or a small bot, calls settle). The payer is never a bettor; the developer is a vendor.
- **Product:** a real-money prediction market, the Speedrun AMM adapted to back-to-back Rounds on any token with a qualifying Base pool. Market types in the pilot, on two mechanisms:
  - **Up/down over the Window** runs on the AMM, with the start Reading taken when trading closes, so nothing is known while trading.
  - **Price threshold** and **market cap threshold** (pool price times total supply) run on a pari-mutuel pot: players stake Yes or No, and winners split the pot. The AMM only reprices on trades, so on a threshold a bot that sees the pool cross the line would buy the already-won side and drain the payer's liquidity, the reason [ADR 0003](../../../docs/adr/0003-creator-markets-use-a-pari-mutuel-pot.md) used a pot for creator markets. In a pot, late stakers on the likely side only dilute each other; the payer's liquidity isn't the counterparty. The payer puts a fixed Opening stake on both sides of every threshold Round (set per Campaign, settled like any player's stake) in place of AMM liquidity, so Rounds open with odds and rarely end Unmatched. Unmatched pots refund every stake.
  - Head-to-head ("does $A beat $B") is later.
- **Timing:** each Round has a trading phase, then a Window with trading stopped. The payer sets the Window from 1 to 30 seconds and the trading phase from 5 to 30 seconds per Campaign; Rounds overlap so a new one opens continuously. Sub-2-second Windows wait for 200 ms blocks on Base mainnet (targeted Nov 2026, unverified); the demo uses 2-30 seconds.
- **Manipulation:** buys-vs-sells counting was dropped as trivially rigged once money is at stake. A payer-set Stake cap per player per Round stays below the cost of moving the pool price over the Window, and shrinks with shorter Windows (near-single-block Readings are cheaper to move). Payers qualify on pool depth.
- **Tie:** an unchanged Reading refunds each player exactly what they paid in that Round.
- **Shape:** a payer-branded Round page the developer hosts during the pilot (embeddable and linkable from X, Telegram, Discord), handed over afterwards. Telegram mini app is a later upsell.
- **Deal:** a flat fee per Campaign, US$300 list for a 7-day pilot, in USDC or ETH. No cut of stakes and no trading fee for now; a fee share can follow a paid commitment. The minimum ask is left to [The outreach plan](32-the-outreach-plan.md).
- **Legal:** money stakes accepted by the user, who will operate worldwide and handle legal later. Recorded as a known, accepted risk: [Legal exposure as a game supplier from Vietnam](29-legal-exposure-as-a-game-supplier-from-vietnam.md) found supplying a money-staked game carries accomplice risk for a Vietnam resident, and Art. 6 reaches citizens' acts abroad. Not a blocker.
- **Speedrun code:** the PredictionMarket AMM, Yes/No shares and LP role return as the core, with the oracle replaced by self-settling pool Readings and the single market replaced by back-to-back Rounds.
- **Resolved reference:** "TAPL" is a Chainlink hackathon PoC; see [What TAPL teaches the pitch](36-what-tapl-teaches-the-pitch.md).

Glossary: Round (trading phase then Window), Player, Campaign and Stake cap; Tie, Pot, Unmatched and Opening stake carry over from earlier maps. A Tie refunds stakes in a pot and refunds what each player paid on the AMM.
