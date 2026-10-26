# How Seer and TRUEO serve a funded decision

Label: wayfinder:research
Type: research
Status: resolved

## Question

Two live prediction markets may already serve the sponsor this map targets: a protocol community that wants a forecast tied to a decision it already funds, such as a grant milestone. Describe each from primary sources (docs, contracts, governance posts, onchain data) along the axes this map has already decided, so the next ticket can name what is left to compete on.

- **Seer** (seer.pm). Check whether it is built on Gnosis Conditional Tokens, whether it resolves through Reality.eth with Kleros arbitration, and whether it is used for Deep Funding and GnosisDAO futarchy.
- **TRUEO.** The human believes it is another market with an optimistic oracle at its core. First confirm which product this is: name, URL, chain. If the name is ambiguous, list the candidates and say which one matches "prediction market with an optimistic oracle". Do not guess.

For each product, cover:

1. **Pricing mechanism.** AMM type (LMSR, FPMM, concentrated-liquidity pools, order book). Who supplies liquidity. Whether a sponsor can fund a **bounded, non-returned subsidy** with a known worst-case loss, as in [Prior-based LMSR subsidy bound](01-prior-based-lmsr-subsidy-bound.md).
2. **Opening probability.** How a market's starting price is set: a sponsor parameter, LP deposit ratios, or something else. Note any lock-up or token-lock mechanism.
3. **Liquidity incentives.** LP rewards, liquidity mining, and sponsored-market programs, with the published amounts.
4. **Oracle.** Who resolves, the dispute window, the bond, the arbitration, and how Invalid is handled. Is Invalid tradable, and what does it pay? Compare with [Whether invalid is tradable](02-whether-invalid-is-tradable.md) and [Who is paid the resolution cost](04-who-is-paid-the-resolution-cost.md).
5. **Who creates markets, and the cost.** Fees, minimum liquidity.
6. **Sponsor-facing output.** Does a sponsor get anything beyond the market page: an embeddable widget, a depth or slippage figure, a stated cost ceiling, disclosure of insider influence? Compare with [How the open forecast panel reads](06-how-the-open-forecast-panel-reads.md) and [What the forecast says when a trader can move the outcome](09-what-the-forecast-says-when-a-trader-can-move-the-outcome.md).
7. **Grant or decision use.** Named sponsors that used it for a grant, an allocation, or a governance decision. Amounts, participation, whether the result was used, and whether they came back for another round.

Finish with a table: rows are the axes above plus "token lock" and "LP rewards"; columns are Seer, TRUEO, and this map as decided. Mark each cell **same**, **different**, or **absent**. State facts only. The choice of where to compete belongs to the grilling ticket that this one blocks.

Do not use this repo's contracts as a source.

## Answer

Neither Seer nor TRUEO has a bounded, non-returned subsidy with a known worst-case loss, a sponsor-set opening probability, or a stated depth or influence line. Both lean on outside liquidity and an optimistic-style oracle.

- **Seer** is Conditional Tokens, Reality.eth and Kleros, with outcome tokens traded on external concentrated-liquidity DEX pools (Swapr, Uniswap). Anyone can create a market, and no creation fee was found. Reality.eth bonds at least double per answer; the Gnosis factory timeout read onchain is 3.5 days. Invalid is a tradable token that redeems the collateral. Grant and decision use is real. The Zcash Q3 2026 grants poll had 37 markets that Seer itself seeded; they resolved 17 Yes and 20 No. Deep Funding used Seer markets, and GnosisDAO's futarchy pilot (GIP-145) was proposed by Futarchy Labs on Seer infrastructure. The Zcash committee's use of the prices was not confirmed.
- **TRUEO** (trueo.com, Base, moving to Ethereum) uses Uniswap v4 hook pools, YES-TYD and NO-TYD. Opening odds come from contributors' YES/NO split in a crowd-funded pre-launch phase, with a 5% launch fee. The oracle is optimistic: 250 TYD bonds, 12-hour windows, then the Oracle Council, a TRUE vote and 11 attesters. Invalid is called Cancelled, and every token redeems at $0.50, matching this map's half-payout. No grant, DAO or sponsor use was found.
- Not found in either: a stated subsidy ceiling, depth at publish, or an influence disclosure.
- Unverified: see the Unverified section of the findings. The main items are the Kleros identity of Seer's arbitrator address, the Seer LP reward amounts, the GIP-145 vote result, and the TRUEO fees and bond handling on Cancelled.

| Axis | Seer | TRUEO | This map as decided |
|---|---|---|---|
| Pricing mechanism | different (external DEX pools) | different (Uniswap v4 hook pools) | prior-based LMSR |
| Bounded subsidy, known worst-case loss | absent | absent | hard ceiling |
| Opening probability | different (LP's initial price) | different (contributors' split) | sponsor parameter, 10-90% |
| Token lock | absent | absent | absent |
| LP rewards | different (SEER emissions, fees; amounts unofficial) | different (7.5% and 12.5% of TRUE; 5% launch fee) | absent |
| Oracle | different (Reality.eth, 2x bonds, Kleros) | different (optimistic, council, vote, attesters) | different (one named resolver, no dispute window) |
| Invalid | different (tradable token, full collateral) | same payout, different form (Cancelled is an outcome; every token pays half) | no shares; half the Payout per share |
| Resolution cost payee | different (bond transfer, no fee) | different (per-market reward plus bonds) | escrowed fee to the resolver |
| Who creates, cost | same (anyone, no fee found) | different (anyone; funding threshold and 5% fee) | sponsor publishes and funds |
| Trading fee | different (pool fees, unstated) | different (unstated) | absent |
| Sponsor-facing output | different (odds page, SDK quotes, TWAP widget) | absent | embedded panel with buy quote and depth line |
| Depth stated at publish | absent | absent | present |
| Influence disclosure | absent | absent | present |
| Grant or decision use | present (Zcash, Deep Funding, GnosisDAO via Futarchy Labs) | absent | target use |

Findings: docs/research/seer-trueo.md on branch research/seer-trueo, commit 4dd6180. Branch is local; no origin remote.

## Amended 2026-10-20 (candidate F)

For the forecast buyer, the market comparison stands. The panel incumbents (Metaculus Pro, FRI) are covered in [How Metaculus and FRI serve a forecast buyer](17-how-metaculus-and-fri-serve-a-forecast-buyer.md). The "Grant or decision use" row describes the old buyer.
