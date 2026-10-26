# AGENTS.md

A Scaffold-ETH 2 (Foundry) repo that started as the Speedrun Ethereum Prediction Markets challenge. Current work is product wayfinding: maps and tickets in `.scratch/`, plus throwaway UI prototypes.

## Where things are

- **Maps and tickets**: `.scratch/<effort>/map.md` and `issues/NN-*.md`. Read [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md) before touching one; it has the ticket header, the claim/resolve steps and the frontier rule.
- **Domain language**: [GLOSSARY.md](GLOSSARY.md). Use its terms in tickets, specs and code.
- **Decisions**: `docs/adr/`. Check them before proposing something an ADR already settled.
- **Prototype UI**: `packages/nextjs/app/prototype/*`. Throwaway sales assets, not product code.
- **Challenge contracts, tests and the SE-2 pages**: [docs/challenge.md](docs/challenge.md). Read it when editing `packages/foundry` or `packages/nextjs/app/{user,oracle,liquidity-provider}`, or when the user says `/start`, `check` or `hint`.

## Rules that hold everywhere

- `PredictionMarketToken.sol` and `deployedContracts.ts` are not hand-edited.
- Deploy, verify and account commands need an interactive password prompt; leave them to the user.
- Import alias in `packages/nextjs` is `~~`.
