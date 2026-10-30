# Payer deploy and Campaign setup

Resolution and runbook for ticket 12 (issue #12, parent spec #1).

The Payer deploys `UpDownRounds` and `ThresholdPots` from its own wallet, so the Payer owns both contracts and the developer holds nothing. The same script sets every Campaign setting and funds the seeded liquidity and the Opening stakes. See ADR 0004 and [GLOSSARY.md](../../GLOSSARY.md) for the roles.

Wording: the **Payer** is the business that pays; in a white-label Campaign it is also the **Operator** (GLOSSARY). In this runbook "owner" means the contract's `Ownable` owner, which is the Payer acting as Operator. It holds the powers the **Liquidity provider** holds in the challenge contracts: it funds and seeds, changes the settings of later Rounds and withdraws what is unreserved.

## What ships

| Piece | Path |
| --- | --- |
| Deploy script (`preflight`, `run`, `fundAndSeed`) | `packages/foundry/script/DeployPayerCampaign.s.sol` |
| Stake cap rule of thumb | `packages/foundry/script/lib/StakeCapRule.sol` |
| Driver (human yes gates, live gas pricing, verify hints) | `packages/foundry/scripts-js/payerDeploy.js` |
| Gate rules (signer refusal, skip-only-local, pricing) | `packages/foundry/scripts-js/payerDeployGate.js` |
| Local end-to-end run | `packages/foundry/scripts-js/payerDeploy.smoke.js` |
| Dated pool evidence | `docs/implementation/base-pool-volume-evidence.json`, `docs/implementation/base-readings.md` |

The script deploys `BasePoolReader`, `UpDownRounds` and `ThresholdPots` (and a `MarketCapReader` only when the Threshold metric is `MarketCap`), all as the broadcaster. Both Round contracts take the Payer as `Ownable` owner in their constructors. No contract has any other role. The script asserts that the broadcaster equals the configured Payer and that the Payer owns both contracts before it funds anything. Forge scripts use a default sender, not the signer, so the script reads the real broadcaster with `vm.readCallers()` after `startBroadcast()`.

No file under `packages/foundry/contracts/` changed.

## Before you start

1. A Payer wallet: a Safe (recommended, see below), or an EOA behind a hardware wallet or an encrypted keystore.
2. If you sign with a keystore, create it yourself. This asks for a password, so nothing in this repo runs it:
   ```
   cast wallet import payer --interactive
   ```
   Then `--account payer` selects it. For a hardware wallet use `--ledger`.
3. An RPC. The `base` alias in `packages/foundry/foundry.toml` is the public `https://mainnet.base.org`. For a dedicated RPC, put the URL in `packages/foundry/.env` (gitignored) and never commit it. The driver refuses a raw remote URL; a network must be a `foundry.toml` alias, or a loopback URL for a local chain.
4. The Payer holds the stake token for `updown.funding` plus `threshold.funding`, and enough ETH for gas. The Threshold Opening stake is not extra: it is paid out of `threshold.funding`, so `threshold.funding` must be at least twice `threshold.openingStake` (one Opening stake on each side). The same holds for the UpDown `seed`, which comes out of `updown.funding`.
5. A settings file (see the schema below). Keep it outside the repo or commit only a copy with no secrets; it holds addresses and amounts, never keys.

## The settings file

Big integers are decimal strings in the stake token's raw units. `durationSeconds` of 0 means open-ended; above 0 it must outlast the Trading phase, and a new Round starts only while now is before the end time. See "Extras" for why `allowStakeCapAboveRule`, `durationSeconds` and the `MarketCap` metric are in the file.

```json
{
  "payer": "0xPAYER_ADDRESS",
  "stakeToken": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
  "pool": "0xd0b53D9277642d899DF5C87A3966A349A798F224",
  "baseToken": "0x4200000000000000000000000000000000000006",
  "poolFee": 500,
  "lookbackSeconds": 30,
  "allowStakeCapAboveRule": false,
  "updown": {
    "payout": "1000000",
    "seed": "20000000",
    "stakeCap": "17000000",
    "tradingSeconds": 6,
    "windowSeconds": 30,
    "durationSeconds": 0,
    "funding": "60000000"
  },
  "threshold": {
    "metric": "Price",
    "threshold": "3000000000000000000000000000000000000000",
    "openingStake": "1000000",
    "stakeCap": "17000000",
    "tradingSeconds": 10,
    "windowSeconds": 30,
    "durationSeconds": 0,
    "funding": "20000000",
    "supplyMode": "Unsupported",
    "fixedSupply": "0"
  }
}
```

### Reading each setting back

Each setting is set by the script. Not every one has a getter, so the table says how each is read and which are derived. Round 1 is the Round the script seeds.

| Setting | How it is read back | Kind |
| --- | --- | --- |
| Stake token | `cast call <contract> "i_stakeToken()(address)"` on both contracts | direct |
| Pool, base token, lookback | `i_reader()` on each contract, then the reader's own views | direct |
| Stake cap | `stakeCap` in `round(1)` | direct |
| Seed (UpDown) | `seededLiquidity` in `round(1)` | direct |
| Opening stake (Threshold) | `openingStake` in `round(1)`; `yesTotal` and `noTotal` both equal it | direct |
| Metric and threshold (Threshold) | `metric` and `threshold` in `round(1)` on ThresholdPots; UpDown is the up or down market and has no metric | direct |
| Payout (UpDown) | `cast call <contract> "PAYOUT()(uint256)"` | direct |
| Owner and Round payer | `owner()`, and `payer` in `round(1)` | direct |
| Funding | `balanceOf` of the contract in the stake token, and `fundingBalance()` (what is left after the seed or the Pot) | direct |
| Trading phase length | `cutoff` in `round(1)` minus the seed time | derived: the contracts store only the absolute `cutoff` |
| Window length | `windowEnd` minus `cutoff` in `round(1)` | derived: the contracts store only the absolute `windowEnd` |
| End time (`durationSeconds` above 0), UpDown | `endTime` in the `SettingsScheduled` event the script triggers | event only: `endTime` has no getter |
| End time (`durationSeconds` above 0), Threshold | `seedRound` emits no event that carries it, so it is read by behaviour: `currentRound()` is above 0 at `endTime - 1` and 0 at `endTime` | behaviour only |

The seed time is the block timestamp of the `fundAndSeed` transaction. The local end-to-end run and the Foundry tests read the direct and derived settings back from the contracts and assert them, and decode the `SettingsScheduled` event for the UpDown end time.

## Commands

All commands run from the repository root. Substitute your keystore name. These are listed for the Payer to run; they need a password or a hardware wallet, so they were not run during the build.

```
yarn payer:deploy --config /path/to/settings.json --network base --account payer
yarn payer:deploy --config /path/to/settings.json --network base --ledger
```

Exactly one signer flag is accepted: `--account NAME` or `--ledger`. The driver refuses `--private-key`, `--private-keys`, `--mnemonic`, `--mnemonics`, `--interactive` and `-i`, so a raw key can never reach a command line or a committed file.

To rehearse on Base Sepolia first, use `--network baseSepolia`. The script knows the Uniswap V3 factory for chain 8453 and 84532 and refuses any other chain except the local 31337.

### What the driver does, in order

1. `preflight` (a read-only simulation) vets the config onchain, see "Vetting" below. Any failure stops before anything is signed.
2. It prints a "What will happen" table: network, Payer, stake token, pool, every Campaign setting.
3. It dry-runs the deploy, prices the gas, prints the estimate and waits for a typed yes (gate 1).
4. It broadcasts `run()`, then reads the real receipts, reprices with actual gas and checks `owner()` of both contracts equals the Payer.
5. It dry-runs `fundAndSeed()`, prints amounts, checksummed destinations and the cost, then waits for a typed yes (gate 2). This is the pre-funding gate.
6. It broadcasts `fundAndSeed()`: `forceApprove` of the exact amounts, `fund`, `seedRound`, and the Threshold `fund` and `seedRound`.
7. It prints the verify commands and the env hints for the settle bot and the page.

A "no" at either gate sends nothing further. Deploying and funding are two separate broadcasts on purpose, so a mistake in the deploy table costs only deploy gas. After a "no" at gate 2 the two contracts exist and are owned by the Payer, but hold no stake token and have no Round; the local end-to-end run checks this.

The gates live in the driver, not in the Solidity script. `fundAndSeed()` run directly, for example with `forge script --sig "fundAndSeed()"`, has no human yes: it asks nothing, shows nothing and sends. It does not repeat the vetting below, which runs in `preflight()` and `run()`. Use the driver for any real network. The script still refuses the worst mistakes by itself, before any transfer: a signer that is not the configured Payer, a contract the signer does not own, and a balance below the total funding.

### Gas pricing

The gate prices cost live as `(gas_used x gas_price + l1_fee + operator_fee) x eth_usd`.

- The L1 data fee is read from the receipt (`cast receipt --json`, field `l1Fee`). Before sending, the estimate uses the `GasPriceOracle` at `0x420000000000000000000000000000000000000F` (`getL1Fee`).
- On Base mainnet the ETH/USD price comes from the Chainlink feed `0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70` ("ETH / USD", 8 decimals). On any other network the driver shows ETH only and says there is no live USD price.
- Pre-send figures are gas-limit upper bounds from the dry run. The post-send figures are actual.

### Skipping the gate (local chain only)

The human yes can be skipped only with `--skip-confirmation`, and only when the chain id is 31337 and the RPC is a loopback address. A skip against a chain-id 8453 loopback (a fork pretending to be Base) is refused, and the local-chain smoke checks this. There is no skip for any other network.

## Extras beyond the ticket, and why each is there

Each of these goes a little past the bare ticket. None can be used on a real network without the Payer choosing it.

| Extra | Why it is here |
| --- | --- |
| `allowStakeCapAboveRule` | The rule is a rule of thumb built on an assumed volatility. A Payer who has read the derivation and decided to go over needs a way to say so on purpose; without it the script would be the only thing standing between the Payer and their own decision. It skips only the cap comparison. Stake token identity is still checked. It is also the only way to use ETH as the stake token, where the rule cannot price anything. |
| `--local-sender` | The smoke test needs a signer with no password on a throwaway chain. It is accepted only on chain 31337 against a loopback RPC and only when it equals the configured Payer, so it cannot be used to sign for a real wallet. |
| `durationSeconds` | A Campaign is "a fixed time" in the GLOSSARY, so the end time has to be set somewhere. It is set at the same moment as everything else, so the Payer does not need a second transaction to stop new Rounds. It is checked to outlast the Trading phase, otherwise no Round would ever start. |
| Optional `MarketCapReader` | The Threshold metric can be `MarketCap`, which needs a supply reader. It is deployed only for that metric, wraps the same price reader, so the Payer is not forced to deploy it by hand. |
| Base Sepolia factory | A rehearsal on a testnet costs nothing and shows the gates and the gas pricing. The factory for chain 84532 is known to the script so the vetting works there; any other chain except local 31337 is refused. |

## Vetting before anything is signed

The pool and stake token addresses are checked before use. `preflight` fails with a named error if any of these do not hold:

- `cast code` equivalent: pool, stake token and base token must have code (`NotAContract`).
- `pool.factory()` equals the Uniswap V3 Factory for the chain, `0x33128a8fC17869897dcE68Ed026d694621f6FDfD` on Base (`WrongFactory`).
- `pool.token0()` or `pool.token1()` is the configured base token (`PoolTokensMismatch`).
- `pool.fee()` equals the configured `poolFee` (`PoolFeeMismatch`).
- `factory.getPool(token0, token1, fee)` returns the same pool (`PoolNotRegistered`).
- An ERC-20 stake token is the pool's quote token (`StakeTokenIsNotThePoolQuote`). This check always runs, including when `allowStakeCapAboveRule` is true, because a Stake cap in some other token would be meaningless against this pool. A stake token of ETH (the zero address) is allowed only together with `allowStakeCapAboveRule`, since the rule cannot price it.
- Each Stake cap is at or under the rule of thumb (`StakeCapAboveRule`). `allowStakeCapAboveRule` skips only this cap comparison, nothing else in the list.

You can repeat the identity checks by hand:

```
cast code 0xd0b53D9277642d899DF5C87A3966A349A798F224 --rpc-url base
cast call 0xd0b53D9277642d899DF5C87A3966A349A798F224 "factory()(address)" --rpc-url base
cast call 0xd0b53D9277642d899DF5C87A3966A349A798F224 "fee()(uint24)" --rpc-url base
cast call 0x33128a8fC17869897dcE68Ed026d694621f6FDfD "getPool(address,address,uint24)(address)" \
  0x4200000000000000000000000000000000000006 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 500 --rpc-url base
```

The pinned-fork test `PayerStakeCapRule` and `StakeCapRule.fork.t.sol` run this vetting against the real Base pool at block 35,000,000.

## Stake cap rule of thumb

A Stake cap is the most one Player can stake in a Round. It must stay low enough that moving the pool price during a Window to win costs more than the most it can win. The cap depends on how deep the pool is and how long the Window is. A shorter Window gives a lower cap, because there is less time for the price to move naturally, so an attacker needs less capital to look like a trend.

### Derivation

A Round is decided by two Readings of `BasePoolReader`: one at the start of the Window and one at its end. Each is a geometric TWAP, the average of the log price over the last `lookback` seconds. The worst case is one address that stakes the cap on one side and also pushes the pool price. With W the Window and L the lookback, both in seconds, the rule (`StakeCapRule.maxStakeCap(poolDepth, windowSeconds, lookbackSeconds, poolFee)`) is:

1. **Natural noise.** The price is assumed to be a driftless random walk with sigma = 1e-4 per square root of a second. The difference between two lookback averages taken W seconds apart then has variance `var = W - L/3` when W is at least L, and `var = W^2 (L - W/3) / L^2` when W is shorter than L, in units of sigma squared seconds.
2. **Reading shift to beat.** `r = 2 x sigma x sqrt(var)`: the pusher must move the Reading by two standard deviations of that natural difference to flip the outcome reliably.
3. **Seconds a push counts.** `h = min(W, L)`: a push made after the start Reading can sit inside the end Reading's lookback for at most this long.
4. **Spot push.** `d = r x L / h`: held for h seconds, a spot push of d moves a Reading averaged over L seconds by `d x h / L = r`. A longer lookback dilutes the same push, so it needs a bigger d.
5. **Blocks held.** `n = ceil(h / 2)`, at a 2 second block time. Arbitrageurs undo the push every block, so the pusher pays again each block.
6. **Volume.** `t = depth x d / 2`: the quote token volume that moves a constant-product pool by d. Here depth is the quote token balance of the pool.
7. **Cost.** `cost = n x t x (2 x fee + d / 2)`: fees in and out plus average slippage, once per held block.
8. **Cap.** `cap = cost / 4`, a safety divisor of 4.

A shorter Window holds the push for fewer blocks, so the cost and the cap fall: a shorter Window means a lower cap. A longer lookback dilutes a push, so a bigger and dearer push is needed for the same Reading shift, and the cap rises with L.

### Evidence, dated

All figures are from Base mainnet at block 35,000,000, timestamp 1756789347, 2025-09-02 05:02:27 UTC, for the WETH/USDC fee-500 pool `0xd0b53D9277642d899DF5C87A3966A349A798F224`.

- The pool holds 13,633,808.2112 USDC (`balanceOf` at the pinned block). The virtual USDC reserve at the current price is about 367M, much deeper.
- Volume, lower bound: 60,683.852190 USDC per day, summed from six `Swap` logs found in blocks 34,961,200 and 34,962,300. The raw logs are in `docs/implementation/base-pool-volume-evidence.json`. This is a sampled lower bound, not a full-day total.
- The 30 second Reading at that block is 4387.36 USDC per WETH (`docs/implementation/base-readings.md`).

### Caps this gives (lookback 30 s, fee 500, depth 13,633,808.2112 USDC)

| Window | Max Stake cap (raw, 6 decimals) | In USDC |
| --- | --- | --- |
| 30 s | 33,089,948 | 33.09 |
| 10 s | 13,345,188 | 13.35 |
| 6 s | 8,273,850 | 8.27 |
| 2 s | 2,845,839 | 2.85 |

The cap depends on the Reading's lookback as well as the Window. A longer lookback dilutes a push, so the cap grows (same pool, fee 500, Window 2 s unless stated):

| Lookback | Max Stake cap (raw) |
| --- | --- |
| 4 s | 735,910 |
| 10 s | 1,359,421 |
| 30 s | 2,845,839 |
| 60 s | 4,647,815 |
| 60 s, Window 30 s | 61,715,484 |

The cap scales linearly with the pool's quote token balance: at half the depth the 30 s Window allows 16,544,974. The unit tests pin these values to within 0.1 percent and assert that a cap of `max + 1` is rejected. Re-derive the cap if the pool is thinner now than at the dated block.

### What the fork check covers, and what it does not

`StakeCapRule.fork.t.sol` runs against the real pool at the pinned block, through the real `BasePoolReader` TWAP Reading and the pool's own `swap`. For each of the 30 s, 10 s and 2 s Windows it takes the start Reading, buys the base token with exactly the quote volume the rule prices for the push, lets the Window pass at the pushed price, and takes the end Reading. At 30 s the rule prices about 6,097 USDC of volume for a 0.0894 percent spot push held 30 seconds.

It verifies:

- **The real spot response to the rule-priced volume.** The real pool moved 0.0033 percent for that volume, well under the 0.0894 percent the rule assumes, so the real cost of the assumed push is higher than the rule's.
- **The dilution model, to one tick.** The real Reading move is no more than the spot move times `min(W, L) / L`, plus one tick (0.01 percent, the finest step a TWAP over integer ticks can show).
- **A lower bound on the cost.** Scaling the real response up to the assumed push, the real pool supports a cap of about 891.7 USDC at 30 s (359.6 at 10 s, 76.7 at 2 s) against the rule's 33.09 (13.35, 2.85): about 27 times as much. The rule is conservative for this pool because the pool is deeper at the current price than the quote balance the rule uses.

It does not verify:

- **Sigma.** The 1e-4 per square root of a second drift is an assumption, not a measurement. It sets how large a push has to be.
- **Arbitrage reversion and holding cost across blocks.** The test pushes once and lets time pass; it does not simulate arbitrageurs undoing the push block by block, nor the fees the pusher would pay to keep it. The rule charges fees and slippage once per held block, and that charge is modelled, not observed.
- **The daily volume evidence.** The 60,683.852190 USDC per day lower bound above is context for how busy the pool is. No test uses it.

The script enforces the rule only when the stake token is the pool's quote token. Any other ERC-20 stake token is refused (`StakeTokenIsNotThePoolQuote`) whether or not `allowStakeCapAboveRule` is set, because the rule would not be meaningful. If the pool is thin or the figures above are stale, re-read the pool balance and re-derive the cap before deploying. `allowStakeCapAboveRule` is for a Payer who has decided to go over; leave it false by default.

## Owner powers and what they can do to Players

Recommended owner: a Safe controlled by the Payer's signers, not a single hot EOA. The deploy script requires the signer to equal the configured Payer, so there are two ways to get a Safe as owner:

1. Set `payer` to the Safe, and sign the script with a signer the Safe accepts (the Safe's execution path is outside this script; use the Safe's transaction builder with the same calldata the dry run prints), or
2. Deploy from an EOA, check everything, then call `transferOwnership(safe)` on both contracts and have the Safe confirm the state. Until then the EOA is the owner. A Round records the owner at the time it is materialized as its `payer`, and unused liquidity from that Round is refunded to that address, so Round 1, seeded by the script, refunds to the deploying EOA even after a transfer. Keep that EOA under the Payer's control, or use option 1. Do not renounce ownership: it removes `stopCampaign` and the ability to withdraw.

What each owner power can do, from [updown-campaign.md](updown-campaign.md):

| Power | Effect on Players |
| --- | --- |
| `fund` | Adds stake token for payouts. Cannot hurt a Player. |
| `seedRound` (once only, on both UpDownRounds and ThresholdPots; ThresholdPots tracks it with `s_seeded`) | Seeds the first Round. A second call reverts, so the script's call is the only one. Cannot touch a live Round. |
| Change next-Round seed, Stake cap, Window, Trading phase, end time | Applies only to Rounds that start later. A live Round keeps the settings it started with. |
| Change the reader | Applies to later Rounds. A malicious or wrong reader could settle later Rounds unfairly, so this is a trust risk and the reason for a Safe with more than one signer. |
| `stopCampaign` | Schedules a stop at the current Round's cutoff, so no new Rounds start after it. Players in live Rounds can still claim. |
| `withdrawLiquidity` on UpDown, `withdrawFunding` on Threshold | Takes back only unreserved funding. Reserved collateral for live Rounds and claims cannot be withdrawn. |
| `transferOwnership` / `renounceOwnership` | Moves or drops control. It does not move Player funds. |

There is no result override, no sweep of unclaimed winnings, no upgrade and no edit of a live Round. The settle bot (`settle-bot.md`) holds no contract role: use a dedicated key separate from the Payer's.

## Verify right after deploy

The driver prints these with the real addresses. Run them in the same session:

```
VERIFY_SCRIPT=DeployPayerCampaign.s.sol yarn verify base
```

`VERIFY_SCRIPT` makes the existing `yarn verify` target use the payer deployment instead of the default one (see `script/VerifyAll.s.sol`). Then verify on Sourcify:

```
forge verify-contract <address> <path>:<Contract> --chain 8453 --verifier sourcify \
  --constructor-args "$(cast abi-encode 'constructor(...)' ...)"
```

The driver fills in the address, contract path and constructor arguments for `BasePoolReader`, `UpDownRounds`, `ThresholdPots` (and `MarketCapReader` when deployed). `yarn verify` may ask for an explorer key in `.env`; keep that out of version control.

`deployedContracts.ts` is not regenerated and not hand-edited. The page reads addresses from env, see below.

## After deploy: settle bot and page

The driver prints these hints with the real addresses.

Settle bot (`settle-bot.md`), with its own dedicated key:

```
SETTLE_RPC_URL, SETTLE_PRIVATE_KEY, SETTLE_UPDOWN_ADDRESS, SETTLE_THRESHOLD_ADDRESS, SETTLE_FROM_BLOCK
```

Page (`packages/nextjs/config/payers.ts`):

```
NEXT_PUBLIC_ROUNDS_ADDRESS=<UpDownRounds>
NEXT_PUBLIC_THRESHOLD_ADDRESS=<ThresholdPots>
```

Then open `/rounds?brand=DEGEN`. The BASE brand also accepts `NEXT_PUBLIC_BASE_*`.

Deployment output (addresses, block numbers) is written to `packages/foundry/deployments/payer-<chainid>.json`, which is gitignored. Do not commit it with an RPC URL.

## Local-chain end-to-end run

```
yarn payer:deploy:smoke
```

This spawns its own anvil (chain 31337) and uses unlocked well-known test accounts. No password, no live network. It runs:

1. Gate negatives: a raw `--private-key` is refused; a skip on a chain-id 8453 loopback is refused; a "no" at gate 1 deploys nothing; a "yes" at gate 1 followed by a "no" at gate 2 deploys both contracts but leaves them unfunded and unseeded, with the Payer's stake token balance untouched.
2. The driver, with `--local-sender <payer> --skip-confirmation`, against mocks of the pool and factory.
3. Ownership: `owner()` of both contracts equals the Payer and the developer account holds 0 stake token.
4. Funding: contract balances equal the configured fundings.
5. The settle bot with its own key: the UpDown Round settles (Tie) and the Threshold Round settles (Yes), with no reverts. The bot holds no role.
6. The page's views: `currentRound` of at least 2, `phase`, `chanceCents`, `PAYOUT` and `i_stakeToken`.

To look at the real page against that chain, hold it open with `SMOKE_PORT` and `SMOKE_HOLD_SECONDS`, point `NEXT_PUBLIC_ROUNDS_ADDRESS` and `NEXT_PUBLIC_THRESHOLD_ADDRESS` at the printed addresses, and open `/rounds?brand=DEGEN` with the wallet on chain 31337. The page rendered the Payer's contract with its Stake cap and Window, with no console errors.

The Node gate rules run on their own: `yarn payer:deploy:test`.

## Before the first non-local deploy

Run each of these on the commit you deploy from. Test counts are not recorded here because they go stale; read the pass and fail lines.

| Check | What to expect |
| --- | --- |
| `forge test` in `packages/foundry` (unit, fuzz, invariant) | No failures outside `test/PredictionMarket.t.sol`. That file is the unimplemented Speedrun challenge skeleton and fails on every branch of this repo until the challenge is solved; it is unrelated to this deploy. The pinned-fork tests skip unless `BASE_RPC_URL` is set. |
| `BASE_RPC_URL=https://mainnet.base.org forge test --match-path test/deploy/StakeCapRule.fork.t.sol -vv` | The fork tests pass at Base block 35,000,000 and log the numbers quoted in "What the fork check covers". The public endpoint needs a cached or archive-capable node for that block. |
| `slither .` | No unaddressed high or medium. The one high is the OpenZeppelin `mulDiv` false positive. The medium findings in the contracts were already triaged before this ticket. |
| `slither script/DeployPayerCampaign.s.sol`, run separately | Slither skips `script/` by default. In the script itself only benign cheatcode `unused-return` (`vm.readCallers`, `vm.serialize*`) and the intentional uninitialized `marketCapReader` (zero address when absent) show up. The run also reports the already-triaged `divide-before-multiply` and `incorrect-equality` findings in `UpDownRounds` and `ThresholdPots`, because the script imports them. |
| `yarn payer:deploy:test` | The Node gate rules pass. |
| `yarn payer:deploy:smoke` | Passes on a local anvil. |

## What could not be run during the build

- `yarn deploy`, `yarn verify`, `--account` and `--ledger` all need a password or a device. They were not run, and nothing was broadcast to any live network.
- Sourcify verification, which needs live deployed addresses.
- The real L1 fee and the USD line on Base. The local chain has no L1 fee and no Chainlink feed, so it prints "no live USD price" and a zero L1 fee. The pricing formula is covered by the Node tests, and the oracle and feed addresses were read from Base.
- A run against Base Sepolia.

## ETHSKILLS checklist

| Item | How it is met |
| --- | --- |
| Sign with `--account` or `--ledger`; no `--private-key` or RPC keys in committed files | The driver accepts only those two signers (or the local-only `--local-sender`) and refuses raw keys. Settings files hold no secrets. RPC URLs come from `foundry.toml` aliases and the gitignored `.env`. |
| Pre-funding print and human yes | Gate 2 prints amounts, checksummed destinations and a live-priced cost including the receipt-read L1 fee, then waits for a typed yes. |
| Pool and stake token checked before use | See "Vetting before anything is signed". Tested with mocks and against the real Base pool at block 35,000,000. |
| Pool liquidity and volume cited with dated evidence | See "Evidence, dated". |
| Safe recommended; owner powers vs Players | See "Owner powers and what they can do to Players". |
| Verify right after deploy | See "Verify right after deploy". |
| Slither, fuzz, invariant and fork suites before the first non-local deploy | See "Before the first non-local deploy". |
