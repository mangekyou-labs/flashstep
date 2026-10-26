# Whether AI-agent trading arenas have a payer

Label: wayfinder:research
Type: research
Status: resolved

## Question

This is candidate E's AI branch. Do AI-agent trading or competition arenas, and markets on them, have a payer? Cover both readings:

- **Arenas where AI agents trade:** for example LLMs trading real or paper capital head to head (Nof1 Alpha Arena and successors), agent tournaments, and agents trading on Polymarket or Kalshi. Who funds the capital, who earns, and what the volume and audience are.
- **Markets where humans bet on AI agents or models:** which agent wins an arena, benchmark or leaderboard outcomes (LMArena, Polymarket model-ranking markets), and agent-vs-agent matches. Volume, liquidity, and who pays.

Also cover how AI agents already participate as traders on onchain prediction markets (share of volume where published), and known problems: resolution on self-reported leaderboards, manipulation by the lab being bet on, and wash trading by bots.

Apply the map's kill rule, reading the payer as bettors, sponsors, or labs:
- (i) Someone paid for this in the last 12 months.
- (ii) An incumbent already offers it free or at depth.

Build on the AI-market liquidity in `docs/research/long-tail-niches.md` (branch `research/long-tail-niches`) and the attention-market notes in `docs/research/futarchy-niches.md` (branch `research/futarchy-niches`). Rank what you find. Do not pick; [Which candidates survive the kill rule](04-which-candidates-survive-the-kill-rule.md) does.

## Answer

Ranked findings (kill rule, payer read as bettors, sponsors, or labs):

1. **Bettors on AI-model outcomes** (Polymarket Alpha Arena winner, about $1.0M for Season 1; "top AI model" monthly markets about $0.9M to $4M each). Rule (i) passes, rule (ii) fails: Polymarket already runs them at depth. Killed.
2. **Labs paying for evaluation.** LMArena's paid AI Evaluations passed about $30M annualized within about 4 months (labs pay). Real payer, but it buys evaluation, not market liquidity or resolution. Fails (i) for a market product.
3. **Sponsors funding trading arenas.** Nof1 $15M raise (May 2026), LTP Liquidity Arena $300K+ pool, Recall token prizes. Rule (i) passes as marketing/benchmark spend; rule (ii) fails because arenas are free to enter and the money is equity or tokens. Killed.
4. **AI agents as traders.** More than 30% of Polymarket wallets reportedly use agents (wallets, not volume). They are participants, not a payer. No distinct payer.

- Interest is fading: Alpha Arena Season 1.5 winner market had $58K versus $1.0M for Season 1; Nof1 Season 2 not visible publicly as of Aug 2026.
- Wash trading: a Columbia preprint says about 25% of Polymarket volume was wash trading, so AI-market volumes may be inflated.
- Insider bets on model-release dates are documented (GPT-5.2, Gemini 3 claims); no documented lab gaming of an arena ranking was found.
- Structural conflict: LMArena resolves the markets and the labs being bet on are its paying customers.

Caveats: most sources are news or aggregator pages; Polymarket volumes came from search summaries (a direct fetch failed); no primary dataset for AI-agent volume share; Kalshi AI markets and Recall funding not checked.

Findings: docs/research/ai-agent-arenas.md on branch research/ai-agent-arenas, commit 405f37a. Branch is local; no origin remote.
