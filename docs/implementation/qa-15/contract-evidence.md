# Flashstep QA #15: contract evidence

Checked commit `ff6a588e321b3ab2eaa59e5151329c2ea0a1d77a` from `/private/tmp/flashstep-qa-15` on 2026-11-02 UTC. No tracked Solidity edits. Installed Foundry libraries copied from original checkout because clean checkout submodule directories were empty. Forge 1.5.1 stable; Solc 0.8.36, repository optimizer/via-IR settings. Raw logs are preserved in [logs/](logs/).

## Product tests

Final integrated command, from `packages/foundry`:

```sh
BASE_RPC_URL=https://mainnet.base.org FOUNDRY_INVARIANT_RUNS=128 FOUNDRY_INVARIANT_DEPTH=100 FOUNDRY_INVARIANT_FAIL_ON_REVERT=true forge test --offline --no-match-path 'test/PredictionMarket.t.sol' -vv
```

**302 passed, 0 failed, 0 skipped, 50 suites**. See `forge-integrated-strict.log`. This explicitly excludes the unfinished original challenge grading file; it does not claim an unrestricted repository test pass.

22 fuzz properties each ran 256 cases (5,632 generated cases). 13 invariant properties each ran 128 runs × 100 calls = 12,800 calls, with zero reverts and zero discards in every selector table (166,400 calls total). Includes ETH/ERC-20 versions of Round backing, conservation, Campaign escrow/claims/funding partition, observed sources/destinations, Threshold claims/dust, and reader immutability/missing captures. Handler no-op actions exist; successful-action counters and afterInvariant final drains supply additional evidence. Exact property lines retained in `fuzz-invariant-stats.txt`.

Additional baseline `forge test --offline --no-match-path 'test/PredictionMarket.t.sol' -vv` without RPC: 283 pass, 0 fail, 11 skip markers. Setup skips collapse multi-test fork classes, so its total differs from integrated run. That run also searched ten invariant properties at 256×500 = 128,000 calls each and three reader properties at 128×100, all zero reverts. See `forge-local.log`.

## Pinned Base mainnet forks

```sh
BASE_RPC_URL=https://mainnet.base.org forge test --offline --match-path 'test/*/*.fork.t.sol' -vvvv
```

**19 passed, 0 failed, 0 skipped across seven suites**. See `forge-base-fork.log` for actual traces, not skipped/mock-only results. Public archive response saved in `rpc-probe.json`: chain 8453, block 35,000,000 (`0x2160ec0`), timestamp 1756789347, hash `0x9048f68cfd29ae6ce36647ace74ebdf5bffcef8528dd8183df6e3a01a92f2d18`.

Real pool is WETH/USDC Uniswap v3 500-tier `0xd0b53D9277642d899DF5C87A3966A349A798F224`. Suites: reader (1); Round ETH/ERC-20 (2+2); Threshold ETH/ERC-20 (2+2); Stake cap rule/pool vetting (5); native USDC claims/refunds/blocked-player isolation (5). Native-USDC custody suite intentionally uses deterministic mock price observations, while separate real-pool suites exercise historical observations and missed-boundary refunds. These are Base mainnet archive forks; they provide no Base Sepolia deployment evidence.

Stake cap test readings, raw six-decimal USDC:

| Window | Rule cap | Cap supported by real pool response |
| --- | ---: | ---: |
| 2 seconds | 2,845,838 | 76,688,224 |
| 10 seconds | 13,345,188 | 359,619,527 |
| 30 seconds | 33,089,947 | 891,692,685 |

This checks the specific deterministic push/model assumptions at that historical state. It does not establish present-day depth, model sigma, arbitrage reversion, daily volume, or blanket economic manipulation resistance.

## Slither

Executed actual `slither .` via `UV_CACHE_DIR=/private/tmp/flashstep-uv-cache uvx --from slither-analyzer slither .`, not merely checked availability. It analyzed **29 contracts with 102 detectors, 161 findings**, exiting 255 because findings were reported. Raw `slither.log` includes full locations and detector text. Slither compiles contracts while skipping test/script by default; this evidence does not cover a separate script-target scan.

High finding: OpenZeppelin `Math.mulDiv` intentional XOR inverse seed `(3 * denominator) ^ 2`, consistent with existing documented false-positive triage.

Medium families inspected against source and existing implementation triage: divide-before-multiply in discrete Round-slot flooring and dependency arithmetic; strict equality in discrete enums, zero sentinels, accounting zero checks and exact boundary timestamps; `BasePoolReader.preview` cumulative ticks assigned in try success branch with catch reverting; intentionally ignored low word of `mul512` overflow checks. Untouched `PredictionMarket` skeleton reports locked ether and remains outside product scope. No reentrancy detector finding appeared. Low/informational/style findings remain recorded. These findings were reviewed against existing explanations, not independently audited or silently treated as a clean scanner exit.

## Settle bot

Existing `node scripts-js/settleBot.smoke.js` passed on disposable local Anvil with random dedicated localhost ports. `settle-bot-smoke.log` records: unprivileged CLI captures/settles both contracts; restart handles older Rounds and pending captures; settled Rounds produce no further transactions; request pacing works; invalid request-rate configuration fails at startup. Local fixture contracts were created by the existing test harness; no public-network transaction, deploy, verify or account command was sent.

## Limits

No Base Sepolia Campaign exists yet according to user; no deployed testnet claim is made. Current onchain campaign wiring, public-chain bot uptime and a complete real-wallet testnet flow remain unavailable until the user deploys/configures contracts. Original challenge suite was excluded as documented. No secrets were accessed or included in logs.
