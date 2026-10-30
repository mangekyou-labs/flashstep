# Payer deploy and Campaign setup

Resolution and runbook for ticket 12 (issue #12, parent spec #1).

The Payer deploys `UpDownRounds` and `ThresholdPots` from its own wallet, so the Payer owns both contracts and the developer holds nothing. The same script sets every Campaign setting and funds the seeded liquidity and the Opening stakes. See ADR 0004 and [GLOSSARY.md](../../GLOSSARY.md) for the roles.

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
4. The Payer holds the stake token for `updown.funding` plus `threshold.funding` plus the Threshold Opening stake, and enough ETH for gas.
5. A settings file (see the schema below). Keep it outside the repo or commit only a copy with no secrets; it holds addresses and amounts, never keys.

## The settings file

Big integers are decimal strings in the stake token's raw units. `durationSeconds` of 0 means open-ended.

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

Each setting is set by the script and readable from the contracts afterward:

| Setting | Where it lands | Read it with |
| --- | --- | --- |
| Stake token | `i_stakeToken` on both contracts | `cast call <contract> "i_stakeToken()(address)"` |
| Pool, base token, lookback | the `BasePoolReader` constructor; both contracts hold it as `i_reader` | `i_reader()` on each contract, then the reader's views |
| Trading phase | `cutoff` of the Round (and the scheduled settings) | `round(roundId)` on each contract, `SettingsScheduled` events |
| Window | `windowEnd` of the Round | `round(roundId)` |
| Stake cap | `stakeCap` of the Round | `round(roundId)` |
| Seed (UpDown) and Opening stake (Threshold) | `seededLiquidity` and `openingStake` of the Round | `round(roundId)` |
| Market types and thresholds | UpDown is the up or down market; ThresholdPots carries `metric` and `threshold` per Round | `round(roundId)` on ThresholdPots |
| Payout | `PAYOUT` on UpDown | `cast call <contract> "PAYOUT()(uint256)"` |
| Owner / Round payer | `owner()` and the Round's `payer` | `owner()`, `round(roundId)` |
| Funding | contract balance in the stake token | `balanceOf` of the contract |

The local end-to-end run reads each of these back from the contracts and asserts them.

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

A "no" at either gate sends nothing further. Deploying and funding are two separate broadcasts on purpose, so a mistake in the deploy table costs only deploy gas.

### Gas pricing

The gate prices cost live as `(gas_used x gas_price + l1_fee + operator_fee) x eth_usd`.

- The L1 data fee is read from the receipt (`cast receipt --json`, field `l1Fee`). Before sending, the estimate uses the `GasPriceOracle` at `0x420000000000000000000000000000000000000F` (`getL1Fee`).
- On Base mainnet the ETH/USD price comes from the Chainlink feed `0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70` ("ETH / USD", 8 decimals). On any other network the driver shows ETH only and says there is no live USD price.
- Pre-send figures are gas-limit upper bounds from the dry run. The post-send figures are actual.

### Skipping the gate (local chain only)

The human yes can be skipped only with `--skip-confirmation`, and only when the chain id is 31337 and the RPC is a loopback address. A skip against a chain-id 8453 loopback (a fork pretending to be Base) is refused, and the local-chain smoke checks this. There is no skip for any other network.

## Vetting before anything is signed

The pool and stake token addresses are checked before use. `preflight` fails with a named error if any of these do not hold:

- `cast code` equivalent: pool, stake token and base token must have code (`NotAContract`).
- `pool.factory()` equals the Uniswap V3 Factory for the chain, `0x33128a8fC17869897dcE68Ed026d694621f6FDfD` on Base (`WrongFactory`).
- `pool.token0()` or `pool.token1()` is the configured base token (`PoolTokensMismatch`).
- `pool.fee()` equals the configured `poolFee` (`PoolFeeMismatch`).
- `factory.getPool(token0, token1, fee)` returns the same pool (`PoolNotRegistered`).
- The stake token is the pool's quote token (`StakeTokenIsNotThePoolQuote`), which is what lets the Stake cap rule below be checked.
- Each Stake cap is at or under the rule of thumb, unless `allowStakeCapAboveRule` is true (`StakeCapAboveRule`).

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

The rule (`StakeCapRule.maxStakeCap(poolDepth, windowSeconds, lookbackSeconds, poolFee)`):

- sigma = 1e-4 per square root of a second (assumed price volatility).
- m = sigma x sqrt(Window) x lookback / 2, the relative price move the attacker must fake.
- t = depth x m / 2, the quote volume that moves the price by m in a constant-product pool.
- cost = t x (2 x fee + m / 2), what that move costs in fees and slippage.
- cap = cost / 4 (a safety divisor of 4).

Here depth is the quote token balance of the pool.

### Evidence, dated

All figures are from Base mainnet at block 35,000,000, timestamp 1756789347, 2025-09-02 05:02:27 UTC, for the WETH/USDC fee-500 pool `0xd0b53D9277642d899DF5C87A3966A349A798F224`.

- The pool holds 13,633,808.2112 USDC (`balanceOf` at the pinned block). The virtual USDC reserve at the current price is about 367M, much deeper.
- Volume, lower bound: 60,683.852190 USDC per day, summed from six `Swap` logs found in blocks 34,961,200 and 34,962,300. The raw logs are in `docs/implementation/base-pool-volume-evidence.json`. This is a sampled lower bound, not a full-day total.
- The 30 second Reading at that block is 4387.36 USDC per WETH (`docs/implementation/base-readings.md`).

### Caps this gives (lookback 30 s, fee 500, depth 13,633,808.2112 USDC)

| Window | Max Stake cap (raw, 6 decimals) | In USDC |
| --- | --- | --- |
| 30 s | 71,519,274 | 71.52 |
| 10 s | 27,256,397 | 27.26 |
| 6 s | 17,765,252 | 17.77 |
| 2 s | 7,449,718 | 7.45 |

The tests assert the 30 s and 2 s values to within 0.1 percent against the pinned block, and assert that a cap of `max + 1` is rejected.

### Checked against the fork Reading

The fork test `test_theRuleAssumesAPriceMoveTheRealPoolCannotBePushedAnywhereNear` takes the 30 s Window, where the rule assumes a 0.82 percent move costing about 55.9k USDC of volume. It then does a real swap of that volume against the pool at the pinned block. The real price moved 0.0305 percent, far less than the assumed 0.82 percent. So the rule is conservative for this pool: real depth is deeper than the balance the rule uses.

The script enforces the rule only when the stake token is the pool's quote token; any other stake token is refused (`StakeTokenIsNotThePoolQuote`), because the rule would not be meaningful.

If the pool is thin or the figures above are stale, re-read the pool balance and re-derive the cap before deploying. `allowStakeCapAboveRule` exists for a Payer who has decided to go over; leave it false by default.

## Owner powers and what they can do to Players

Recommended owner: a Safe controlled by the Payer's signers, not a single hot EOA. The deploy script requires the signer to equal the configured Payer, so there are two ways to get a Safe as owner:

1. Set `payer` to the Safe, and sign the script with a signer the Safe accepts (the Safe's execution path is outside this script; use the Safe's transaction builder with the same calldata the dry run prints), or
2. Deploy from an EOA, check everything, then call `transferOwnership(safe)` on both contracts and have the Safe confirm the state. Until then the EOA is the owner. A Round records the owner at the time it is materialized as its `payer`, and unused liquidity from that Round is refunded to that address, so transfer ownership before the Campaign is seeded if the Safe should receive all refunds. Do not renounce ownership: it removes `stopCampaign` and the ability to withdraw.

What each owner power can do, from [updown-campaign.md](updown-campaign.md):

| Power | Effect on Players |
| --- | --- |
| `fund` | Adds stake token for payouts. Cannot hurt a Player. |
| `seedRound` (once on UpDown) | Seeds the first Round. Cannot touch a live Round. |
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

1. Gate negatives: a raw `--private-key` is refused; a "no" at the gate sends nothing; a skip on a chain-id 8453 loopback is refused.
2. The driver, with `--local-sender <payer> --skip-confirmation`, against mocks of the pool and factory.
3. Ownership: `owner()` of both contracts equals the Payer and the developer account holds 0 stake token.
4. Funding: contract balances equal the configured fundings.
5. The settle bot with its own key: the UpDown Round settles (Tie) and the Threshold Round settles (Yes), with no reverts. The bot holds no role.
6. The page's views: `currentRound` of at least 2, `phase`, `chanceCents`, `PAYOUT` and `i_stakeToken`.

To look at the real page against that chain, hold it open with `SMOKE_PORT` and `SMOKE_HOLD_SECONDS`, point `NEXT_PUBLIC_ROUNDS_ADDRESS` and `NEXT_PUBLIC_THRESHOLD_ADDRESS` at the printed addresses, and open `/rounds?brand=DEGEN` with the wallet on chain 31337. The page rendered the Payer's contract with its Stake cap and Window, with no console errors.

The Node gate rules run on their own: `yarn payer:deploy:test` (9 tests).

## Before the first non-local deploy

| Check | Result when this ticket was built |
| --- | --- |
| `forge test` (unit, fuzz, invariant at 128 runs by depth 100, pinned-fork at Base block 35,000,000) | 295 passed, 0 failed. `PredictionMarket.t.sol` (the Speedrun challenge) is excluded. |
| `slither .` | No unaddressed high or medium. The one high is the OpenZeppelin `mulDiv` false positive. The medium findings in the contracts were already triaged before this ticket. In the new script, only benign cheatcode `unused-return` and the intentional uninitialized `marketCapReader` (zero address when absent) show up. Slither skips `script/` by default, so it was also run on the script directly. |
| `yarn payer:deploy:test` | 9 passed |
| `yarn payer:deploy:smoke` | passed on a local anvil |

Re-run all of these on the commit you deploy from. The pinned-fork tests need `base` RPC access in `packages/foundry/.env`.

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
