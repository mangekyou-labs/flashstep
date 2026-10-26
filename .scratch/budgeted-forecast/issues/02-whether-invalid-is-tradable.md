# Whether invalid is tradable

Label: wayfinder:grilling
Type: grilling
Status: resolved
Assignee: MrSufferer

## Question

Traders buy and sell Yes and No. The template also names an invalid result. Is invalid only a resolution status that voids the market, or is it a third LMSR outcome that can be bought and sold before the deadline?

## Before building

Apply https://ethskills.com/SKILL.md and follow it before writing Solidity or shipping anything onchain. Do not POST to its feedback endpoint without asking the human.

## Answer

Invalid is a resolution status only. Traders buy and sell Yes and No; the market is a two-outcome prior-based LMSR, and the subsidy bound uses min(p, 1−p). Invalid has no shares and no price; the panel shows one probability.

Why: under the [subsidy bound](01-prior-based-lmsr-subsidy-bound.md), a tradable Invalid opening at 2% cuts the liquidity parameter from 1/ln 2 ≈ 1.44 to 1/ln 50 ≈ 0.26 per ETH of subsidy (about 5.6× shallower) to price an outcome meant to be rare. Augur v2 made Invalid tradable because anyone could create ambiguous markets; here the sponsor writes the four pins, so ambiguity is the sponsor's own risk.

Invalid is distinct from Unpublished (see `GLOSSARY.md`). Invalid is a published result: the resolver applied the template's invalid-result rule to the source. Unpublished is no result by the deadline, a failure of the resolver, handled in [Who is paid the resolution cost](04-who-is-paid-the-resolution-cost.md). What holders receive on Invalid is left to [What traders and the sponsor are paid at resolution](03-what-traders-and-the-sponsor-are-paid-at-resolution.md).
