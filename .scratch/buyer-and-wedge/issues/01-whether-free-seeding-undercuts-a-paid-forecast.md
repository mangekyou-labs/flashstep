# Whether free seeding undercuts a paid forecast

Label: wayfinder:research
Type: research
Status: resolved

## Question

This checks candidate A against kill rule (ii) in the map's Notes. In the last 12 months, who has paid for liquidity on forecasts tied to a grant, allocation, or governance decision, and who received it free?

Use primary sources: governance posts, treasury transfers, program docs, onchain data. Cover:

- Seer seeding its own markets (Zcash Q3 2026 grants poll, Deep Funding, GnosisDAO futarchy via Futarchy Labs). Who funded the liquidity, how much, and whether it is a standing offer or a one-off launch subsidy.
- Butter (Uniswap Foundation, Optimism), Futarchy Labs, MetaDAO, and Polymarket Sponsor Market Rewards. For each, name any party *outside* the platform that paid, how much, and whether it paid again.
- Any grant program, foundation, or DAO that paid a forecast vendor out of its own budget.

Verdict: does a sponsor pay for this today, or do platforms give it away to win market share? If they give it away, how long is that likely to last, and what does it imply for a paid product? Prior findings to build on, not repeat: `docs/research/protocol-forecast-demand.md` on branch `research/protocol-forecast-demand`, and `docs/research/seer-trueo.md` on branch `research/seer-trueo`.

## Answer

**Kill rule (ii) applies to candidate A: platforms give liquidity away, and no outside party was found paying for a forecast in the last 12 months.** Seer funded the Zcash Q3 grants markets itself and Futarchy Labs charges GnosisDAO no fee. Free looks like launch marketing, so A cannot be sold as "we supply liquidity".

- Zcash Q3 (Aug 2026): "Seer will fully fund this pilot"; no payment to Seer, no stated second round. Per a Seer developer's repo, about 20,000 sUSDS across 74 pools, round-trip cost 0.58 sUSDS because only 4 of 37 markets traded. Seeded capital is mostly recovered, so the real cost to the giver is small.
- GnosisDAO GIP-145: the DAO lends $100k returnable liquidity; Futarchy Labs takes no fee; Seer is only technical partner.
- Butter: the one observed foundation-to-vendor payment is the Uniswap Foundation's $200k R&D grant (Oct 2024, outside the window). CFM 1 and the Optimism experiment (2025) are also outside the window. No CFM 2 result or second payment found.
- MetaDAO: platform earns a 0.25% trade fee (secondary source); DAOs fund their own liquidity from raises. Polymarket Sponsor Market Rewards: one unnamed sponsor added about $70k to one mainstream market (Feb 2026); no protocol or grant sponsor found.
- No grant program, foundation or DAO paid a forecast vendor from its own budget in the window.
- Implication: if A survives, what is sold cannot be liquidity. Candidate differentiators are a cost ceiling, stated depth at publish, a named resolver, and insider-resistant design. This evidence does not show anyone pays for those.

Caveats: no duration for free seeding is stated anywhere; my read of "launch marketing" is inference. GIP-145's final vote and Seer's Deep Funding, Octant and NU7 funders are unverified. Searches were not exhaustive.

Findings: docs/research/free-seeding.md on branch research/free-seeding, commit 4c31b68. Branch is local; no origin remote.
