# What this forecast competes on

Label: wayfinder:grilling
Type: grilling
Status: resolved
Assignee: MrSufferer
Blocked by: 12

## Question

Given what [How Seer and TRUEO serve a funded decision](12-how-seer-and-trueo-serve-a-funded-decision.md) finds, what single wedge does this forecast compete on for a sponsor tied to a funded decision? The candidates the human raised are the token lock, LP rewards, the pricing mechanism, and the oracle, plus anything the research surfaces.

Some candidates are already constrained:

- The Notes rule out LP rewards, "AMM versus order book", "anyone can create markets", and automatic objective resolution as competitive claims.
- The token lock went when the destination was redrawn.
- The decided oracle (one named resolver with no dispute window) is weaker on trust than an optimistic oracle with arbitration, so it is a trust assumption, not a wedge.

That leaves sponsor-side packaging and accounting as the likely ground: a hard subsidy ceiling with a known worst-case loss, depth stated at publish, the influence line, and an embedded panel. Is that enough? If Seer already serves this buyer with the same shape, the answer may redraw the destination: for example, a sponsor layer on top of Seer instead of a separate market. It may also rule parts of the map out of scope.

## Before building

Apply https://ethskills.com/SKILL.md and follow it before writing Solidity or shipping anything onchain. Do not POST to its feedback endpoint without asking the human.

## Answer

The wedge is **a forecast with a price tag**. Before publishing, the sponsor knows the most the forecast can cost: the subsidy ceiling plus the resolution cost. The sponsor also knows what that money buys: the ETH a trader must spend at the open to move the probability 5 points. Depth at publish is part of the wedge, not a second claim, because it is derived from the same ceiling. Neither Seer nor TRUEO offers this. In Seer's Zcash pilot, Seer funded the liquidity itself, took open-ended pool exposure, and published no loss bound. The grant program never paid for the forecast or knew what it would cost.

- **Supporting, not the wedge:** the influence line and the embedded panel.
- **Means, not a claim:** prior-based LMSR. It is how the price tag is delivered.
- **Separate market, not a layer on Seer.** A Seer layer would bring along decisions this map rejected: a tradable Invalid token that pays in full, Reality.eth bond escalation and its timing, and outside concentrated-liquidity pools. In those pools, depth and worst-case loss depend on each LP's chosen range, not on one number fixed at publish. Ruled out of scope on the map.
- **Oracle is a stated weakness.** The spec says openly that one named resolver with no dispute window is weaker than Seer (Reality.eth + Kleros) and TRUEO (bonded optimistic + council). A stronger oracle can be swapped in later without changing the wedge.
- **Discarded as claims (added to Notes):** the pricing mechanism and the oracle.
- **Positioning sentence:** the handoff spec opens with one sentence filled from the values set at publish: *"This forecast costs you at most X ETH plus Y ETH to resolve, and at open a trader must spend Z ETH to move it 5 points."* If that sentence can't be written for a forecast, the forecast isn't ready to publish. The sentence also answers "why not Seer".

## Amended 2026-10-20 (candidate F)

The wedge, a forecast with a price tag, carries over to the forecast buyer unchanged. It now competes with forecaster panels, which are priced per engagement and state no depth, and with thin public AI markets ($3–7K of liquidity). "Why not Seer" becomes "why not a panel, and why not the thin Polymarket market".

The ruling that the oracle is a stated weakness is reopened for fuzzy questions in [Which oracle AI capability and release questions need](16-which-oracle-ai-capability-and-release-questions-need.md). The out-of-scope Seer layer now also covers layers on Polymarket and Kalshi.
