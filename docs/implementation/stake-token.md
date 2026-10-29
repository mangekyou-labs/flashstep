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

The new real-USDC tests initially failed compilation against the old ETH-only constructor, funding and staking signatures. Final verification results and review findings are recorded below after integration.
