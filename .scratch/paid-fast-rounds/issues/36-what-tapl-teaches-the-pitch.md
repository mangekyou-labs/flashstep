# What TAPL teaches the pitch

Label: wayfinder:research
Type: research
Status: resolved
Blocked by: none
Assignee: MrSufferer

## Question

What does TAPL, a Chainlink hackathon winner, actually do, and does anything in it change [The product and the payer](30-the-product-and-the-payer.md) or the pitch to token teams in [The outreach plan](32-the-outreach-plan.md)?

Sources: the [hackathon page](https://chain.link/hackathon/winners/tapl) and the [contracts repo](https://github.com/tapl-chainlink/smart-contracts-cre). A first, unverified skim (via a summarizer) found a consumer tap-trading PoC on BTC/USDT: 5-second windows on a $20 price grid, offchain resolution, Chainlink CRE committing 15-minute Merkle-rooted settlement batches onchain, and a house-vs-LP pool. Verify against source, don't trust that skim.

Settle with primary sources: (1) how rounds are priced, resolved and settled, and what is onchain versus offchain; (2) who pays whom (house edge, LP yield, any fee or sponsor), and whether anyone buys it as a product; (3) whether the batched-commit design or the "LP as the house" framing is something to borrow or avoid in the pitch to token teams; (4) any claim of traction, users or deployment.

## Resolution

Findings: [research/36](../research/36-what-tapl-teaches-the-pitch.md).

TAPL is a hackathon proof of concept for a consumer tap-trading game on BTC, ETH and LINK, on Sepolia, with no stated users, revenue, customers or fee. Rounds are priced, resolved and credited offchain by the app backend; onchain it only holds a pool and receives 15-minute Merkle-root settlement commitments, a price-integrity report and a daily solvency report. The contracts do not verify proofs or move per-bet payouts. Players lose to a house of LPs ("Be the House"); nobody buys it as a product.

- [The product and the payer](30-the-product-and-the-payer.md): unchanged. "TAPL" is this project; keep self-settling onchain Readings and the pari-mutuel pot as differentiators.
- [The outreach plan](32-the-outreach-plan.md): unchanged. Don't pitch "LP as the house" or batched offchain settlement; don't cite TAPL's hackathon win as demand. Check pitch drafts for the word "house".
- Optional, no scope change: a pool balance and a per-Round settle-transaction link on the Round page.
