# How a feed can settle a fast market safely

Label: wayfinder:research
Type: research
Status: closed

## Question

Which data feeds can settle a market that closes in 1–30 minutes, and how do you stop manipulation and bad data?

Cover:

- Price feeds for majors (BTC, ETH) on Base: Pyth, Chainlink Data Streams, exchange APIs. Latency, cost per settlement on Base, how a contract reads the price at an exact timestamp, and how to prove it.
- Sports scores and live events: free and cheap score APIs, delay, and licensing limits.
- How [Pumpcade](https://docs.cade.market/) settles (one settler reading an API) and what it leaves open: outages, how the start value is captured, ties.
- Attacks on short windows: last-second betting by someone who can see the feed, thin tokens being pumped, and feed delay. Which mitigations work (hard Cutoff before the window, using a feed price instead of the trade price).
- Rules for an outage or tie: refund, void or extend.

## Resolution

Settle majors (BTC, ETH) with Pyth on Base. A contract reads the price at an exact time with `parsePriceFeedUpdatesUnique` (min/max publish time), which reverts if no update falls in the window; anyone can submit the update, and the caller pays the fee (zero on Core, 1 wei on Pro). Capture the start value the same way at market creation: store the price and publish time. Base mainnet addresses (Pyth docs): Pro `0xACeA761c27A909d4D3895128EBe6370FDE2dF481`, Core `0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a`, Core Compatible `0xbC16aee60f64864882BC6C4E428e148Fc0E272F5`. Cost per settlement is roughly a cent or less (Base docs: about $0.002 for 200k gas at the fee floor; the total is an unsourced estimate, so measure on Base Sepolia). Chainlink Data Streams verifies via `VerifierProxy.verify` on a subscription; the Base verifier address wasn't retrievable, so Pyth is the default.

Attacks: a hard Cutoff before the read time, a pinned timestamp with staleness and confidence checks, majors only, a feed price rather than one venue's last trade, closed candles only. Recommended rules (not sourced conventions): refund on a tie or one-sided pot; on a feed outage retry the pinned timestamp for a bounded time, then void and refund, never extend the window. Pumpcade uses one settler job reading an API at the deadline and its docs say nothing on outages or a cutoff; its "final > start" rule seems to give ties to NO (a reading). Exchange candles (Coinbase, Binance, Kraken) are free but unprovable. Sports feeds: free tiers are delayed or tiny, live scores cost money (football-data.org about EUR 12/month), licensing terms unconfirmed, and open-ended events don't fit a fixed window.

Unverified: Pyth Hermes reference and rate limits (key required since 2026-08-26); Chainlink mainnet pricing; second-hand sports API limits.

Details and sources: [research/11-feed-settlement-for-fast-markets.md](../research/11-feed-settlement-for-fast-markets.md)
