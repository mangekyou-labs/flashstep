# Who already runs conviction markets

Label: wayfinder:research
Type: research
Status: resolved

## Question

This is candidate B. Find what exists under each meaning of "conviction market", and who pays for it:

- (a) Markets that never resolve to an outside fact: settled by later traders, peer prediction, or self-resolving designs.
- (b) **Time-locked stakes**, the leading meaning: holding or locking longer counts as stronger conviction and is rewarded or weighted (for example time-weighted positions, or vote-escrow-style weighting applied to forecasts).
- (c) Conviction-voting-style funding: stake builds up over time and releases funds to a proposal (1Hive/Gardens, Commons Stack, and any successors).
- (d) Any product that calls itself a "conviction market", with its definition.

For each: product name and URL, chain, live or dead, usage (volume, participants, markets), who pays for liquidity and rewards, and known failure modes from research or post-mortems (for example beauty-contest drift and manipulation). Use primary sources and papers.

Verdict: is there a meaning of "conviction market" that no one serves, and does any payer exist for it (kill rule (i) in the map's Notes)? Do not recommend a direction; state facts and the gap.

## Answer

**Verdict:** Yes, there is a gap, but no payer for it. No live product was found where lock duration is rewarded or weights a forecast (variant b); the nearest implementations are governance or ownership mechanisms, not forecasting. No third-party buyer who paid for conviction-weighted forecasting in the last 12 months was found, so candidate B fails kill rule (i) on current evidence. Polymarket also gives holders a 4% reward for free, which touches rule (ii).

- (a) Self-resolving/peer-prediction: only academic (Srinivasan, Karger, Chen, arXiv:2306.04305, EC 2025). No deployment, no payer.
- (b) Time-locked stakes: Bittensor BIT-0011 locks (proposal, Apr 2026) decide subnet ownership, not forecasts. ve-tokens are governance. Polymarket Holding Rewards (4% APY, long-dated political markets, from its own treasury) reward holding but not lock length.
- (c) Conviction voting: 1Hive Gardens (Gnosis Chain, since 2020) is a treasury-funding tool; DAO treasuries are the payer. Status unclear, reportedly low funding by late 2022. Not forecasting.
- (d) Self-labelled: convictionmarkets.io (Outlier Ventures manifesto, Mar 2026, milestone-funded work, no usage); XO Market (open market creation on USDC, Alpha test claims 19k users and about $1.3B test volume, no lock mechanism); a ZetaChain "Conviction" waitlist.

**Caveats:** Mostly secondary sources for usage and failure modes; Gardens forum unreachable; XO figures are test volume from a media article; Polymarket third-party reward sponsorship (from Feb 2026) rests on one guide. See the Unverified section in the findings.

Findings: docs/research/conviction-markets.md on branch research/conviction-markets, commit 8d733e4. Branch is local; no origin remote.
