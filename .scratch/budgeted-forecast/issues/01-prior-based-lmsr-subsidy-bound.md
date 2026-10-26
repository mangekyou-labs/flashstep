# Prior-based LMSR subsidy bound

Label: wayfinder:research
Type: research
Status: resolved

## Question

For a prior-based LMSR, cite the primary source for the cost function, the price of an outcome, the cost to buy or sell a quantity, and the worst-case sponsor loss as a function of the liquidity parameter and the opening probability. State how to invert that loss so a maximum subsidy and an opening probability determine the liquidity parameter. Give the binary Yes/No case and the three-outcome case. Do not choose which case this product uses.

Do not use this repo’s bonding-curve integral as a source.

## Answer

Cost, price, and trade cash are owned by Chen and Pennock, UAI 2007 (arXiv:1206.5252), equation (15) and §5.1, and by Hanson, “Book Orders for Market Scoring Rules,” 2 April 2003, p. 1. Opening probability π weights the cost; the price of an outcome is the gradient; a buy or sell of any bundle costs the difference of that cost. The printed hard bound is the uniform case b log n. The prior-based hard loss is derived from those equations: on the worst outcome it is b log(1/min π_i), approached as that outcome’s price goes to 1. Invert a subsidy ceiling S by b = S / log(1/min π_i). Binary uses min(p, 1−p); three outcomes use the smallest of the three probabilities that sum to 1. Hanson’s entropy is the worst-case expected loss, not this ceiling. No choice between the two cases.

Findings: `docs/research/lmsr-subsidy-bound.md` on branch `research/lmsr-subsidy-bound`, commit `354dc123bcc1ccce398a61b619733b048378e415`. Branch is local; no origin remote.
