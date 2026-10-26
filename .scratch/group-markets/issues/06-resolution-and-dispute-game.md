# Resolution and dispute game

Label: wayfinder:grilling
Type: grilling
Status: closed
Assignee: MrSufferer
Blocked by: 04, 05

## Question

Who proposes a group market's result, how long the challenge window is, who may dispute, how a dispute is decided (and whether stakers vote), and what happens when nobody decides? Reuse Invalid and Unpublished from the budgeted-forecast map unless this ticket finds a reason not to. What they pay is already fixed: every stake is returned (see [Stake model for the first test](05-stake-model-for-the-first-test.md)); this ticket decides when a market ends that way.

Also decide:

- Creators may stake on their own markets. Does that change who may propose the result, or should creators who propose be barred from staking?
- A stake placed after the answer was already known in the room, but before the Cutoff: is it voided, and who decides?

## Resolution

Decided in a grilling session on 2026-10-24.

- **Proposer.** The creator proposes a result within 10 minutes of the Cutoff. After that, any member who staked may propose. The proposed result is an Outcome or **Invalid** (the question can't be answered as written: the event was cancelled or the wording is too vague).
- **Creators stake and propose.** No bar on proposers staking: creators earn nothing else for creating. The check is the challenge window. Every case where the proposed result matches the proposer's own stake is logged.
- **Challenge window: 15 minutes, fixed.** Every staker is notified individually when a result is proposed (Zalo can't post into the group). If nobody disputes, the proposed result stands.
- **Who disputes: stakers only. No bonds.** Points are worth nothing, so a bond prices nothing. Dispute counts per member are recorded; whether people grief with disputes is something the first test measures.
- **How a dispute is decided.** A dispute only flags the result. It opens a 15-minute vote for every member who has opened the market, stakers included, one vote each, over every Outcome plus Invalid. A choice needs at least two thirds of the votes cast. Otherwise, including when nobody votes, the market ends Invalid. The risk that the bigger side votes itself the win is accepted while points are worthless; votes are compared with stakes afterwards to measure it.
- **What voters see.** While the vote is open, only the number of votes cast. After it closes, the tally per choice. Names are never shown; individual votes go to the test log only.
- **Unpublished.** If nobody has proposed a result 24 hours after the Cutoff, the market ends Unpublished.
- **Invalid and Unpublished** are reused from the budgeted-forecast map. Both return every stake (per [Stake model for the first test](05-stake-model-for-the-first-test.md)).
- **Finality.** A result is final once the challenge window passes without a dispute, or once the vote ends. One dispute per market, no appeal, no reversal, no dev override: the group trusts itself, not the dev, and a clawback habit wouldn't survive real money.
- **Late stakes are not voided.** Protection is the creator's "Cut off now". Stake times are logged against the moment the result was proposed; add a voiding rule only if the test shows late stakes are common.

New glossary terms: Proposed result, Challenge window, Dispute. No ADR: these rules are cheap to change after the first test.
