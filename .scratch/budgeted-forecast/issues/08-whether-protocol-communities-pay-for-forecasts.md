# Whether protocol communities pay for forecasts

Label: wayfinder:research
Type: research
Status: resolved

## Question

Is there evidence that protocol communities (DAOs, protocol teams, grant programs) will pay a capped subsidy for a forecast on their own operational question, rather than reading a free price on Polymarket?

Use primary sources: governance forum posts, treasury proposals and their votes, published retrospectives, and the docs or onchain data of the programs themselves. Cover:

- Communities that have already funded forecasts or decision markets. Examples to check: Optimism's futarchy grants experiment, MetaDAO, Gnosis/Omen conditional markets, Butter, Uniswap or Arbitrum governance markets. For each: what was asked, how much was spent, who traded, and whether the result was used in a decision and funded again.
- Whether Polymarket or Kalshi already serve this buyer, for example through liquidity rewards, market subsidies, or sponsored markets on protocol-specific questions. Name the price and the minimum market size where they are published.
- Questions protocol communities publicly say they need forecast (utilization, emissions, parameter changes, launches), and how they decide those today.
- Any evidence against demand: abandoned experiments, low participation, subsidy that was spent without being used.

Give a verdict on the gate this map relies on (one team funds a pilot, uses the output in a real decision, and wants another round): supported, mixed, or unsupported by public evidence. Name the most likely first sponsor types. Do not run interviews; the pilot interview is out of scope.

If the verdict is unsupported, say which part of the destination the evidence contradicts so the map can be redrawn.

## Answer

Verdict on the gate: **mixed, weak for the exact form.** Public evidence supports protocol sponsors funding forecasts attached to a grant or allocation decision they already make. It does not show a sponsor spending a non-returned ETH subsidy purely for information on its own operational question (e.g. lending utilization).

- Uniswap Foundation (Butter, real USDC): closest match. 29 forecasters, over $70K traded in five days, winner got a $100K grant; $20K liquidity mining on top. UF says it will keep experimenting; no second round found. Insider influence was higher than expected.
- Optimism (Butter, play money): 430 forecasters after removing 4,122 suspected bots; result used to pick 5 projects. Total cost unpublished; v2 only "under consideration".
- Gnosis GIP-145 (Futarchy Labs): DAO lends $100K liquidity, returned afterward; no fee. Vote tally should be re-checked.
- MetaDAO and other futarchy DAOs: median 4.5 participants per proposal (secondary source, Coindoo); trading itself drives the decision, no information subsidy.
- Arbitrum: no forecast proposals found. Aave and lenders: utilization and caps set by paid risk providers; no stated need for a market forecast.
- Polymarket Sponsor Market Rewards: anyone can deposit USDC (min $0.10/day) to pay liquidity on an existing market; capped, unearned part refunded, sponsor gets nothing back. Same shape as a capped subsidy. Kalshi's incentive program does not say third parties can fund it. No protocol community found sponsoring a protocol-specific operational market on either.
- Counter-evidence: thin participation, insider/manipulation worries, subsidies either returnable or part of a grant already being paid, no confirmed funded repeat.

Likely first sponsors: grant-making foundations with a grant to allocate; DAOs running advisory pilots with returnable liquidity; (speculative) protocols whose parameters are forecast by paid risk providers.

Contradicts: the destination's sponsor buying information on an operational question with a non-returned subsidy. Does not contradict the capped-subsidy form. Suggested redraw: aim the first spec at a grant or allocation decision the sponsor already funds, subsidy as part of that program's budget.

Caveats: Galaxy report read via summaries; 4.5 median and MetaDAO 0.25% fee are secondary/unconfirmed; Optimism/Uniswap total costs and Butter fees unpublished.

Findings: `docs/research/protocol-forecast-demand.md` on branch `research/protocol-forecast-demand`, commit `d5a40c0`. Branch is local; no origin remote. Worktree at /tmp/pfd-wt.

## Superseded 2026-10-20

The buyer changed. Protocol communities (candidate A) were killed in [One buyer and one wedge](../../buyer-and-wedge/issues/06-one-buyer-and-one-wedge.md), and the forecast buyer is now Coefficient Giving and similar funders, asking AI capability and release-timing questions. Demand for that buyer is tested in [Whether forecast buyers answer the demand test](14-whether-forecast-buyers-answer-the-demand-test.md). These findings are kept as prior art only.
