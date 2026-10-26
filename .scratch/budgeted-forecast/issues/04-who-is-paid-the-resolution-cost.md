# Who is paid the resolution cost

Label: wayfinder:grilling
Type: grilling
Status: resolved
Assignee: MrSufferer

## Question

Who is allowed to publish the outcome? At what moment is the resolution cost moved, and who receives it? If the deadline passes and no outcome is published, what does the forecast show, and what happens to the resolution cost?

May the resolver publish Invalid before the deadline (for example, the source goes dark mid-window), ending trading early? [Whether invalid is tradable](02-whether-invalid-is-tradable.md) made Invalid an unpriced status, so once it is evident, trading on Yes and No only matters through the Invalid payout rule. That rule is now 50/50 ([What traders and the sponsor are paid at resolution](03-what-traders-and-the-sponsor-are-paid-at-resolution.md)).

The sponsor keeps any Remainder above the subsidy, so the sponsor gains when traders lose. May the sponsor also be the resolver? If not, how is that enforced? What do holders receive if the result is Unpublished?

## Before building

Apply https://ethskills.com/SKILL.md and follow it before writing Solidity or shipping anything onchain. Do not POST to its feedback endpoint without asking the human.

## Answer

- **Who publishes:** one resolver address, named by the sponsor at publish and never changed. It can be a person, a multisig, or a committee contract; the spec doesn't care which. Anyone with a challenge period was rejected (optimistic oracle, already discarded in the Notes).
- **Sponsor as resolver:** barred. The contract rejects resolver == sponsor, and the forecast always names the resolver. The spec says this is a trust assumption, not a guarantee: the sponsor could still use a second wallet or a friendly multisig.
- **Resolution cost:** escrowed at publish beside the subsidy. Paid to the resolver when a result is published. The amount is the same for Yes, No, and Invalid, so the resolver gains nothing by picking one.
- **Timing:** trading closes when the observation window ends (**Awaiting result** until publication). Yes or No may be published only after the window ends and before the deadline. Invalid may be published any time after open (for example, the source goes dark), and publishing it ends trading at once.
- **Finality:** a published result is final. There is no correction or dispute window. Readers rely on the resolver's identity.
- **Unpublished:** the deadline is hard. After it, the resolver can't publish, and anyone can call to settle as Unpublished. Holders are paid exactly as for Invalid (half the Payout per share), and the set-aside and Remainder rules from [What traders and the sponsor are paid at resolution](03-what-traders-and-the-sponsor-are-paid-at-resolution.md) apply unchanged. The resolution cost goes back to the sponsor. The forecast shows Unpublished with the last probability frozen; the rest of that panel stays in the fog.

Glossary: added **Awaiting result**.

## Amended 2026-10-20 (candidate F)

The mechanics stand. Whether one named resolver with final results is enough for fuzzy AI capability and release-timing questions is reopened in [Which oracle AI capability and release questions need](16-which-oracle-ai-capability-and-release-questions-need.md). The "sponsor" here is now the forecast buyer.
