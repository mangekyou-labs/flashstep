# How the open forecast panel reads

Label: wayfinder:prototype
Type: prototype
Status: resolved
Assignee: MrSufferer
Blocked by: 05

## Question

How should the open embedded forecast panel read? It has to show the current probability, participation as the total amount traded, the subsidy ceiling, the resolution cost, and a size the reader enters. For that size, show the executable quote and the probability after the trade. Decide whether buy and sell are both quoted. Use the depth figure from [Which probability move states the depth](05-which-probability-move-states-the-depth.md). Open state only.

## Before building

Apply https://ethskills.com/SKILL.md and follow it before writing Solidity or shipping anything onchain. Do not POST to its feedback endpoint without asking the human.

## Answer

Decided 2026-10-19 by reacting to a three-variant UI prototype hosted inside a mock grants dashboard (headline, size ladder, full-width gauge). The human accepted the recommended mix.

**Layout: the headline variant, with the size ladder as an optional fold-out.**

- The current probability is the headline, with "opened at X%" beside it.
- Below it, three facts sit in one row: traded so far (participation), subsidy ceiling, resolution cost. All in ETH.
- One depth line uses the figure from [Which probability move states the depth](05-which-probability-move-states-the-depth.md): "Depth at open: A ETH moves it 5 pts up · B ETH moves it 5 pts down."
- The quote: the reader picks Yes or No and enters an ETH size, and gets one sentence: "Spending S ETH on Yes gets N shares and moves the chance from P% to Q%." That sentence is the executable quote and the probability after the trade together.
- A collapsed "More sizes" fold-out holds the ladder table (preset sizes; shares and probability after, for Yes and No). It's for frequent traders and stays collapsed by default.
- The resolver is named in the panel footer (consistent with [Who is paid the resolution cost](04-who-is-paid-the-resolution-cost.md)).
- It fits a narrow (about 380px) column next to the host's own content. The full-width gauge was rejected because it takes over the host page.

**Buy only in the panel.** Most readers hold no shares, so a sell quote would be noise for them. Sell quotes (ETH received and probability after) appear where a wallet's holdings are shown, not in the open panel.

**Depth shown is the figure fixed at the open, not live depth.** Ticket 05 fixed depth at publish. A second, changing "current depth" number would invite comparing two figures that mean different things. The reader already sees live price impact through the quote sentence for any size they enter.

Rejected: quoting buy and sell side by side in the panel (the ladder variant's default); the full-width gauge with ghost markers (strip variant); showing depth recomputed at the current probability.

Prototype (primary source): branch `prototype/forecast-panel`, route `packages/nextjs/app/prototype/forecast-panel/` (`?variant=headline|ladder|strip`). Throwaway, never merged.
