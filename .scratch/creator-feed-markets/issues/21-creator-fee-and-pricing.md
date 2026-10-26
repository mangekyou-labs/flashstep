# Creator fee and pricing

Label: wayfinder:grilling
Type: grilling
Status: closed
Blocked by: none

## Question

How should a creator market price trades and pay its creator so seeding a market is worth it? The Speedrun AMM prices on average probability with a fixed token value, which lets informed traders drain the creator's liquidity. Decide: keep the Speedrun pricing, switch to LMSR or a constant-product curve, or use pari-mutuel; the creator fee and protocol fee; minimum seed; how the creator's liquidity is returned at settlement; window lengths; and how the market settles when the feed is down or the price ties.

## Resolution

**Pari-mutuel pot, not the Speedrun AMM** ([ADR 0003](../../../docs/adr/0003-creator-markets-use-a-pari-mutuel-pot.md)). The Speedrun AMM only reprices on trades, so on threshold or coin questions anyone watching the feed drains the creator's seed. It is only safe on up/down questions, which is too narrow to be worth it. A pot is safe for every question type under consideration.

- **Fees**: the contract charges zero protocol or developer fee (required by the legal path). The creator fee is a fixed 2% of the pot, paid straight to the creator at settlement. Nothing is paid on a refund.
- **Opening stake** (replaces "seed"): required, at least 0.002 ETH, on both sides at a split the creator chooses from 1–99%. It is settled like any other stake, which is how the creator's money comes back. It deters spam, keeps the board from opening empty, and subsidises early bettors.
- **Stakes**: the minimum is 0.0001 ETH. Repeat stakes and stakes on both sides are allowed. There is no exit before the Cutoff, so the sell feature is dropped.
- **Timing**: the Cutoff falls at the start of the window, and the start reading is taken there. Windows are 5, 15 or 60 minutes. Staking is open for as long as the window before the Cutoff.
- **Settlement**: anyone may settle by submitting the first Pyth update at or after each pinned time (`parsePriceFeedUpdatesUnique`, band of about +60s). Taking the first update means whoever settles can't pick a price.
- **Refunds, no fee**: a Tie (the end reading equals the start reading or the threshold), an Unmatched pot (one side empty; kept as a safety rule, though the opening stake prevents it), or Expired (nobody settled within 24h of the window's end, after which anyone may trigger the refund). The window is never extended.
- **Money out**: the fee is paid straight to the creator at settlement. Winners and refunded bettors claim their own money. Claims never expire, nothing is swept, and rounding dust stays in the contract.

Considered and rejected: the Speedrun AMM restricted to up/down questions (safe, but too narrow); LMSR and constant-product AMMs (the creator is the counterparty to informed traders). Which question types launch with (up/down, thresholds) is left to the launch plan; the pot supports both.
