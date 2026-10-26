# Paid fast rounds are real-money markets the payer operates, not free-to-play contests

Paid fast rounds let players stake real money on the Speedrun AMM, and the payer (a crypto project or launchpad) deploys and owns the contract, so the payer is the Operator and the Liquidity provider. The developer is a vendor paid a flat fee per Campaign and takes no cut of stakes. We first chose free-to-play prize Campaigns, because research found any money-staked game carries accomplice risk for a developer living in Vietnam. The user rejected that: with nothing staked there are no prices and no trading, so it is a contest, not a prediction market. The user accepted the legal risk and will handle legal later. White-label keeps the developer from being the one holding stakes, and it fits the payer the user can actually reach.

## Considered Options

- **Free-to-play with a payer-funded Prize:** lowest legal risk, but not a market, and the Speedrun AMM is retired.
- **Free payer-issued points on the AMM (play money, as on Manifold):** a real market with low legal risk. The user chose real money instead.
- **The developer runs the platform:** makes the developer the Operator. Ruled out of scope.
- **Licensed operators as payer:** blocked by the supplier-licence wall and cold-only reach.

## Consequences

- No pure-randomness or buys-vs-sells Rounds: once money is at stake they are trivial to rig. Rounds settle from pool TWAP Readings on Base, and a Stake cap stays below the cost of moving the pool price.
- [Legal exposure as a game supplier from Vietnam](../../.scratch/paid-fast-rounds/issues/29-legal-exposure-as-a-game-supplier-from-vietnam.md) still applies to the developer personally. It is a known risk, not a resolved one.
- Two mechanisms: up/down Rounds use the AMM, with the start Reading taken when trading closes; price and market cap threshold Rounds use a pari-mutuel pot. The AMM reprices only on trades, so on thresholds it would reopen the stale-quote pick-off that [ADR 0003](0003-creator-markets-use-a-pari-mutuel-pot.md) dropped it over.
