# Whether subsidy and opening probability can change after publish

Label: wayfinder:grilling
Type: grilling
Status: resolved
Assignee: MrSufferer

## Question

At publish the sponsor sets one maximum subsidy and one opening probability. After publish, may either figure change? May a second sponsor add funds? Which opening probabilities are allowed? Context from [Which probability move states the depth](05-which-probability-move-states-the-depth.md): an opening far from 50% makes the market shallow toward the centre. At 10%, a 5-point move up costs only 2.5% of the subsidy, and a 5-point move down is impossible from anything below 5%.

## Before building

Apply https://ethskills.com/SKILL.md and follow it before writing Solidity or shipping anything onchain. Do not POST to its feedback endpoint without asking the human.

## Answer

Decided 2026-10-19 in one grilling round. The human accepted every recommendation.

1. **Everything set at publish is fixed.** That covers the opening probability, maximum subsidy, resolution cost, Payout, resolver, and the four question pins (data source, observation window, deadline, invalid-result rule). Any change after a trade would alter prices traders already accepted. It would also invalidate the depth figure fixed at publish ([Which probability move states the depth](05-which-probability-move-states-the-depth.md)) and the loss ceiling ([Prior-based LMSR subsidy bound](01-prior-based-lmsr-subsidy-bound.md)). A sponsor who wants different settings fills in the same template again for a later window, as a new forecast.
2. **No one adds funds after publish,** neither the sponsor nor a second sponsor. Co-sponsors pool their money before publishing; one sponsor address publishes and receives the Remainder. How co-sponsors split it is their own arrangement, outside the contract. Rejected: top-ups with recomputed depth and a pro-rata Remainder, which would add a second funder role and a changing depth figure.
3. **The subsidy can't be reduced or withdrawn early.** It's locked until a result is published or the forecast is settled as Unpublished. Money reaches the sponsor only as the Remainder ([What traders and the sponsor are paid at resolution](03-what-traders-and-the-sponsor-are-paid-at-resolution.md)), plus the resolution cost back if the forecast ends Unpublished ([Who is paid the resolution cost](04-who-is-paid-the-resolution-cost.md)).
4. **The sponsor may withdraw before the first trade.** Only while total traded is zero, the sponsor can withdraw the forecast and get the subsidy and resolution cost back. The resolver is paid nothing. The forecast then reads **Withdrawn**, which is distinct from Invalid: no question was tested and nothing was learned. This is the escape hatch for a mistake at publish, like a typo in the opening probability.
5. **Opening probability: whole points from 10% to 90%, inclusive.** Below 5%, a 5-point move down doesn't exist, so the depth line breaks. Between 5% and 10%, the move toward the centre costs under 2.5% of the subsidy. At the 10% limit, depth is 2.5% of the subsidy up and 30.1% down: lopsided but stated honestly on both sides (90% mirrors it). A sponsor whose honest prior is more extreme opens at the limit and lets traders move the price further.
