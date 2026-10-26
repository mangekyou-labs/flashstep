# Creator markets use a pari-mutuel pot, not the Speedrun AMM

Creator markets in the feed settle on a pari-mutuel pot: everyone stakes Yes or No, and the winners split the pot minus a 2% creator fee. The creator puts in an opening stake on both sides instead of seeding AMM liquidity, so the creator is never the counterparty to trades. We left the Speedrun AMM, which this project grew out of, because it only reprices when someone trades. On threshold questions and Zora or Clanker coin questions, anyone watching the feed picks off stale quotes and drains the creator's seed. The AMM is only safe on up/down questions (start reading at the Cutoff), which is too narrow to justify it. The markets where an AMM pays off are long-horizon ones, which are out of scope. A pot is safe for every question type under consideration, needs no curve math, and matches the refund rules (Tie, Unmatched, Expired).

## Consequences

- Traders cannot sell before the Cutoff. The Speedrun sell feature is dropped.
- The board's chance comes from the share of the pot on each side, not from sold shares, so the Greenlight **Chance** and **Quote** terms don't carry over unchanged.
