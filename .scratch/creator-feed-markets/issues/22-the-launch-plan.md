# The launch plan

Label: wayfinder:grilling
Type: grilling
Status: closed
Blocked by: 21
Assignee: MrSufferer

## Question

What ships first and how do we know it's working? Decide the first version's scope (question types, chain, testnet or mainnet), the first creators and how to reach them, the number that counts (markets created per week, weekly traders) with a target and deadline, the grant to apply to and when, and the stop rule. Write the decision record that ends the map.

## Resolution

**Testnet v1 only. Mainnet, the lawyer and the offshore operator are moved out of this effort** because there is no money for them (about $2-5k plus legal review). Mainnet stays blocked until a Vietnamese lawyer clears it, per [Legal path for real-money creator markets](20-legal-path-for-real-money-creator-markets.md).

- **Scope:** up/down markets on BTC and ETH, settled with Pyth, on 5, 15 and 60-minute windows, using the pot from [Creator fee and pricing](21-creator-fee-and-pricing.md). Base Sepolia only.
- **Surface:** a Farcaster mini app with wagmi and SIWE for wallets and sign-in, so Base App can be added cheaply later ([Does Base App still run Farcaster mini apps](24-does-base-app-still-run-farcaster-mini-apps.md)). The Base.dev listing waits for mainnet.
- **Drip:** each new wallet gets about 0.02 testnet ETH once, funded by the developer, so faucets don't decide the result.
- **Live by:** 2026-12-06.
- **The number that counts:** taken markets per week, plus distinct wallets staking on markets they didn't create.
- **Target:** 20 taken markets a week and at least 15 such wallets, held for 2 weeks in a row, within 6 weeks of going live.
- **First creators:**
  - The developer opens and casts at least one market a day.
  - The developer recruits about 10 creators directly from Farcaster's crypto-trading channels and the BuidlGuidl / Speedrun community.
  - Every share cast tags its creator.
  - No paid promotion and no points.
- **Grant:** apply for the Base Builder Grant once the target is hit, presenting the open-source contracts and the testnet app. Whether the developer may take a grant for a real-money app someone else operates stays a question for the lawyer.
- **Stop rule:**
  - **Demand:** if the target is missed by the deadline, stop. The app stays a testnet demo and portfolio piece.
  - **Legal:** no mainnet without a lawyer's clearance, whatever the numbers say.
- **Abuse:** handled for v1. Nobody can pump BTC or ETH, and wash trading a creator's own market pays the fee back to themselves. Questions are built from asset plus window, so fake markets can't exist, and the opening stake prices out spam. Revisit when thresholds or coins are added.

Testnet ETH is worthless, so v1 can show that people will open and stake on markets, but not that creators care about the fee. That waits for mainnet.

Considered and rejected: mainnet from day one (legal risk); testnet with a lawyer consult running at the same time as the build (no budget).
