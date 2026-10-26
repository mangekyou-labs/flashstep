# 09: Proof and sharing on the page

**Source:** [the spec](../../paid-fast-rounds/spec.md). Building is gated: start only after a payer makes a Paid commitment in [Run the outreach](../../run-the-outreach/task.md).

**Blocked by:** 07

**Status:** ready-for-agent

**What to build:** the trust and sharing parts of the Round page: a recent-Rounds table with results, a link to each Round's settle transaction, the payer's pool balance (so Players know winners can be paid), an iframe embed for the payer's site, and share links for X, Telegram and Discord.

- [ ] Recent Rounds show their result and both Readings
- [ ] Each settled Round links to its settle transaction on the block explorer
- [ ] The pool balance shown matches the contract
- [ ] The page works inside an iframe and its share links open the right Round
- [ ] Covered by the `playwright-cli` smoke run
