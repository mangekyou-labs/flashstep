# Stake token — issue #7

[Issue #7](https://github.com/mangekyou-labs/flashstep/issues/7) extends `UpDownRounds` and `ThresholdPots` with one immutable stake asset per deployment. `address(0)` selects ETH; another address selects an ERC-20 with code at deployment. The asset cannot change with Campaign settings or ownership. The challenge contracts and generated deployment artifacts are unchanged.

## Units and interface

All funding, Stake caps, Opening stakes, liquidity, quotes, claimables and withdrawals are raw stake-token units. Shares retain their existing `1e18` scale. Reading prices retain their independent `1e36` quote-token scale; selecting a stake asset does not change the measured pool or its threshold.

Constructors are `UpDownRounds(payer, reader, stakeToken, payout)` and `ThresholdPots(payer, reader, stakeToken)`. Up/down's fixed winning-share payout is an explicit positive deploy-time amount in stake-token units; `PAYOUT()` and `MIN_SEED()` expose it, with the minimum seed equal to one payout. For the former 0.01-token payout, use `10_000` for a 6-decimal asset and `10_000_000_000_000_000` for an 18-decimal asset. Token metadata is not needed for custody arithmetic.

`fund(amount)` and threshold `stake(roundId, side, amount)` now take explicit amounts. ETH calls attach exactly that amount as `msg.value`. ERC-20 calls attach zero ETH and require the caller to approve the Round contract first. Up/down `buy(roundId, side, shares, maxCost)` pulls the exact quoted cost for ERC-20, while ETH buys attach that cost. Selling, claiming and withdrawals pay the deployment's stake asset.

## Custody and token assumptions

Both contracts share a custody adapter using the installed OpenZeppelin `SafeERC20`. No-return transfers are supported, false-return transfers fail, and exact balance-change checks reject transfer fees or balance changes during a transfer. Transfers occur under reentrancy guards, and failed claims roll back accounting so they can be retried. Payouts remain pull-based: no settlement enumerates recipients or pushes their payments.

The supported asset must preserve balances between transfers. An issuer that can rebase, confiscate, pause, blocklist or upgrade can affect custody or claim availability. Transfer checks detect mismatches during calls; they cannot prevent a later issuer action against the escrow. No deposit-time probe can prove an arbitrary token will never rebase. Payers must select a non-rebasing, exact-transfer asset. A paused token prevents its transfers until resumed; a blocked Player cannot stop other Players' claims.

## Native Base USDC

Circle's [USDC deployment list](https://developers.circle.com/stablecoins/usdc-contract-addresses) identifies Base native USDC as `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`. This implementation does not substitute bridged USDbC. On 2026-10-29, `cast code`, `symbol()` and `decimals()` against `https://mainnet.base.org` at block **35,000,000** returned nonempty code, `USDC` and `6`. These historical calls also confirm that the endpoint serves the chosen archive state. `https://base-rpc.publicnode.com` rejected historical state without a personal token, so it was not used for validation.

The USDC fork tests transfer existing tokens from a funded pool under local impersonation; they do not replace USDC code or mint it with a balance-storage cheatcode. The reader uses deterministic pool observations on the fork to exercise both winning claims and Tie refunds for both contracts, and real USDC blocklisting to check isolation and retry. The existing pinned pool fork suites exercise real historical pool observations separately.

Before using real funds, recheck the asset address, code, identity and transfer behavior on the target chain. The historical checks here establish the deployment used by the tests; they do not establish the future state of an upgradeable token.

## Validation

The new real-USDC tests initially failed compilation against the old ETH-only constructor, funding and staking signatures. The integrated run passed **209 tests, zero failures, zero skips**, using `BASE_RPC_URL=https://mainnet.base.org FOUNDRY_INVARIANT_RUNS=128 FOUNDRY_INVARIANT_DEPTH=100 FOUNDRY_INVARIANT_FAIL_ON_REVERT=true forge test --offline --no-match-path 'test/PredictionMarket.t.sol' -vv`. This includes five native-USDC tests at block 35,000,000, existing real-pool forks with both stake kinds, and four 6/18-decimal payout fuzz tests at 256 runs each. The untouched, unfinished Speedrun challenge grading suite is excluded.

The implementer also ran the earlier market suites at 256 invariant runs × 500 calls: all ten invariant properties had 128,000 calls and zero handler reverts. These check escrow conservation, reserve backing and claim accounting across both assets. `forge fmt --check` on changed Solidity and `git diff --check` passed. Optimized deployed bytecode is 11,072 bytes for UpDownRounds and 10,997 bytes for ThresholdPots, below the EIP-170 limit.

### Independent review

- **Standards:** two findings, both fixed and re-reviewed: payout and seed fuzzing now cover the full accepted range (1 through `1e30`), and private `i_payout` preserves the public `PAYOUT()`/`MIN_SEED()` getters. Explicit constructor cases cover 0, 1, MAX−1, MAX and MAX+1. The four decimal fuzzers also passed 1,024 runs each after these fixes.
- **Spec:** zero findings against GitHub issue #7.

### Static analysis

Slither 0.11.6 analyzed 29 contracts with 102 detectors: 145 reports (1 high, 38 medium, 36 low, 68 informational, 2 optimization). The high report is OpenZeppelin `Math.mulDiv`'s intentional XOR seed for modular inversion. Medium reports in the market contracts are deliberate schedule floor division and discrete enum/index/accounting comparisons. The custody adapter's `amount == 0` early return is intentional; its exact transfer checks are required asset validation. Its low-level ETH call is checked and reached from guarded, effects-first entry points. The `i_` naming report follows this repository's documented convention.

Remaining medium reports concern unchanged dependency fixed-point math, reader sentinel checks/default-empty observation arrays and intentionally discarded overflow-check values, plus locked ETH in the unfinished challenge skeleton. No actionable finding was identified in the stake-asset change. This triage and the tests do not replace a deployment audit.
