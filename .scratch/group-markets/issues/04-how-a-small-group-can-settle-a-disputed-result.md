# How a small group can settle a disputed result

Label: wayfinder:research
Type: research
Status: closed

## Question

Which resolution and dispute designs work when the "crowd" is a 5–30 person group whose members may hold stakes in the result?

Cover:

- How UMA's optimistic oracle, TRUEO, Reality.eth (with Kleros arbitration), Kleros alone, and Manifold's creator-resolves model work: who proposes, bonds, challenge windows, escalation, final arbiter.
- Which parts survive at group scale, and which assume a large, disinterested crowd of disputers.
- Failure cases for small groups: the proposer holds a stake, a majority of holders votes itself the win, nobody votes, ties, the subject of the question is in the group.
- Light-weight options: excluding stakers from the vote, a creator bond, Invalid as the fallback, escalation to an external oracle for high-stake markets.

Give designs and their failure cases. Don't pick one; the grilling ticket does.

## Resolution

Proposer bond, challenge window, single resolver and Invalid fallback survive at group scale; a large disinterested slashable voter pool and cheap escalation do not. File lists 10 candidate designs (A-J) and 12 failure cases, no pick. Reality.eth and TRUEO only secondary-sourced.

Findings: `.scratch/group-markets/research/04-how-a-small-group-can-settle-a-disputed-result.md` on local branch `research/small-group-dispute-designs` (no remote, no PR).
