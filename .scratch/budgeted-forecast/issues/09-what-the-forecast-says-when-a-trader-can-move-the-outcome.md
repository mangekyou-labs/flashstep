# What the forecast says when a trader can move the outcome

Label: wayfinder:grilling
Type: grilling
Status: resolved
Assignee: MrSufferer

## Question

The sponsor's question is tied to a decision it already funds, such as whether a grantee reaches a milestone. The grantee can move that outcome and can also trade on it, and the Uniswap Foundation's Butter round saw more insider influence than it expected (see [Whether protocol communities pay for forecasts](08-whether-protocol-communities-pay-for-forecasts.md)). May the people who can move the outcome trade? Does the panel say that they can? Is anything enforced, or only disclosed? Anyone with a wallet can trade (Notes), so an address check alone cannot stop an insider.

## Before building

Apply https://ethskills.com/SKILL.md and follow it before writing Solidity or shipping anything onchain. Do not POST to its feedback endpoint without asking the human.

## Answer

Decided 2026-10-19 in one grilling round. The human accepted every recommendation.

The risk is not that an interested party knows more. It's that they can bet No and then deliberately miss the milestone.

1. **Nothing is enforced onchain.** The contract puts no limit on who trades, including interested parties. A blocklist is cheap to dodge with a fresh wallet. The spec states this as a disclosed trust assumption, alongside the resolver assumption from [Who is paid the resolution cost](04-who-is-paid-the-resolution-cost.md).
2. **Influence line, set at publish.** Next to the four pins, the sponsor must write an influence line that names the interested parties and says whether their grant terms bar them from trading. Example: "The Lattice team can influence this outcome. Their grant terms bar them from trading it." It can't be left blank. "No one named can influence this outcome" is allowed only if true. Like everything set at publish, it can't change afterwards ([Whether subsidy and opening probability can change after publish](07-whether-subsidy-and-opening-probability-can-change-after-publish.md)). The panel always shows it next to the resolver, in every state.
3. **Recommended grant clause.** The spec recommends that the grant agreement bar the grantee's team from trading their own milestone forecast, in both directions. Enforcement belongs to the sponsor, for example by withholding the tranche. The sponsor chooses whether to adopt it, and the influence line discloses which applies. Rejected: banning only No shares. Yes buying lines up with doing the work, but it lets the grantee push the headline up on confidence that isn't evidence.
4. **A breach doesn't change the result.** If a barred interested party is found to have traded, the published result stands. Invalid stays reserved for the question's own rule ([Whether invalid is tradable](02-whether-invalid-is-tradable.md)), and results are final. Penalties go through the grant agreement.
5. **Sabotage guidance, no hard ratio.** The spec advises keeping the subsidy small next to what the interested party gains by hitting the milestone (e.g. 2 ETH subsidy against a 70,000 NWD tranche), so that betting No and missing on purpose is a losing move. The contract can't value the tranche, and any threshold would be arbitrary, so no ratio is enforced and the panel shows no extra figure.
6. Glossary: **Interested party** added (avoid: insider, influencer).

## Amended 2026-10-20 (candidate F)

The forecast buyer has no grant agreement with the labs, so points 3 and 5 no longer apply. Points 1, 2 and 4 stand.

- **Influence line:** it now names the labs whose staff can bring the result about (by shipping or holding back a model) or already know it (an internal release date). Example: "Staff at Lab L set this release date and may know it. Nothing bars them from trading."
- **No grant clause and no penalty route.** There is no contract through which the buyer could enforce one.
- **Sabotage guidance replaced.** Informed insiders move the price toward the truth at the buyer's expense, and the subsidy ceiling caps what that costs. The buyer sizes the subsidy as the price of the forecast, assuming the best-informed traders take most of it.

This was written into the spec rework at the human's request. Reopen this ticket if the human disagrees.
