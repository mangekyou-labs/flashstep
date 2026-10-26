# 01: Readings from a Base pool

**Source:** [the spec](../../paid-fast-rounds/spec.md).

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

**What to build:** one Reading module that both Round contracts use. Given a Base pool and a block, it returns a TWAP price over a short lookback, and a market cap (that price times the token's total supply at that block). It also builds the mock Base pool every later Foundry test uses: it serves observations at chosen blocks and timestamps, with time moved by `vm.warp` and `vm.roll`. A mainnet-fork test reads one real qualifying pool, so the pool type (Uniswap v3/v4 or Aerodrome) and the shortest usable lookback at 2 s blocks are settled before any Round contract depends on them.

- [ ] A Reading is pinned to a block and is a TWAP, never one instant's price
- [ ] A one-block price spike moves the Reading by much less than the spike
- [ ] A missing observation yields "no valid Reading" (a custom error or flag), never a guessed price
- [ ] Market cap Reading = TWAP price × total supply at the end block
- [ ] The mock pool can script prices per block for later tests
- [ ] A fork test against a real qualifying Base pool returns a sane Reading; the pool type and lookback it confirms are written in the resolution
- [ ] The challenge `PredictionMarket` contract and its tests are untouched
