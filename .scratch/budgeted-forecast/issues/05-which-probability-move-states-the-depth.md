# Which probability move states the depth

Label: wayfinder:grilling
Type: grilling
Status: resolved
Assignee: MrSufferer
Blocked by: 01, 02

## Question

The subsidy and the opening probability fix the LMSR liquidity parameter (see [Prior-based LMSR subsidy bound](01-prior-based-lmsr-subsidy-bound.md)). Depth is a size-versus-probability-move relationship. Which single probability move does the spec use to state the supported trading depth at the open?

Also depends on [Whether invalid is tradable](02-whether-invalid-is-tradable.md), because the outcome count changes the cost function. Resolved: two outcomes, so the liquidity parameter is the subsidy divided by (Payout × ln(1/min(p, 1−p))), in shares; Payout is set at publish ([What traders and the sponsor are paid at resolution](03-what-traders-and-the-sponsor-are-paid-at-resolution.md)).

## Before building

Apply https://ethskills.com/SKILL.md and follow it before writing Solidity or shipping anything onchain. Do not POST to its feedback endpoint without asking the human.

## Answer

Depth is the ETH a trade must spend at the open to move the probability **5 percentage points**, stated **in each direction**. It is computed once at publish from the subsidy and the opening probability, and it never updates.

- **Formula:** cost to move up from p to p+0.05 = S × ln((1−p)/(0.95−p)) / ln(1/min(p, 1−p)). Cost to move down = S × ln(p/(p−0.05)) / ln(1/min(p, 1−p)). The Payout cancels out, so depth is a fixed fraction of the subsidy S.
- **Examples:** a 50% opening gives 15.2% of S in each direction. A 30% opening gives up 6.2%, down 15.1%. A 10% opening gives up 2.5%, down 30.1%.
- **Directions:** at exactly 50% the two figures are equal and shown as one. A direction that would cross 0% or 100% is left out.
- **Why 5 points:** 1 point (about 3% of S at 50%) is too small to say much. 10 points (about 32%) is close to the whole budget. 5 points is about the smallest move a reader would act on.
- **Rejected:** a fixed ETH size, which needs its own reference amount for each forecast, and log-odds or relative moves, which no sponsor reads.
- The live panel's quote for a size the reader enters is separate. Whether the panel also shows current depth belongs to [How the open forecast panel reads](06-how-the-open-forecast-panel-reads.md).

Glossary: added **Depth**.
