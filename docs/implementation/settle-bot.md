# The settle bot — issue #11

The CLI watches `UpDownRounds` and `ThresholdPots`, captures their pinned Readings and calls permissionless `settle(roundId)`. It never opens a Player position, claims, withdraws, funds a Campaign or changes settings. Its dedicated wallet needs ETH for gas and no contract role. It works with ETH or ERC-20 stakes because the bot never transfers the stake asset.

## Run during a pilot or after handover

Install this repo's dependencies with `yarn install` and compile the matching contracts with `yarn foundry:compile`. Keep the resulting `packages/foundry/out/UpDownRounds.sol/UpDownRounds.json` and `ThresholdPots.sol/ThresholdPots.json` alongside the script; the CLI reads their ABIs. Use Node 20.18.3 or later and the existing Foundry workspace dependencies. Supply the following environment variables to the process, then run `yarn settle:bot` from the repository root. No account/deployment command is run by the bot.

| Variable                     | Meaning                                                                                             | Default   |
| ---------------------------- | --------------------------------------------------------------------------------------------------- | --------- |
| `SETTLE_RPC_URL`             | HTTP(S) RPC for the contracts' chain; required                                                      | none      |
| `SETTLE_PRIVATE_KEY`         | Dedicated, gas-funded bot wallet's private key; required                                            | none      |
| `SETTLE_UPDOWN_ADDRESS`      | Deployed `UpDownRounds`; required                                                                   | none      |
| `SETTLE_THRESHOLD_ADDRESS`   | Deployed `ThresholdPots`; required                                                                  | none      |
| `SETTLE_FROM_BLOCK`          | Earliest deployment block of either contract; must include all `RoundSeeded` events                 | `0`       |
| `SETTLE_REQUEST_INTERVAL_MS` | Minimum wait after each RPC response before starting the next request                               | `50`      |
| `SETTLE_POLL_MS`             | Delay between polling passes                                                                        | `200`     |
| `SETTLE_LOG_BLOCK_RANGE`     | Maximum historical block range requested per contract per pass                                      | `2000`    |
| `SETTLE_GAS_LIMIT`           | Explicit transaction gas ceiling, including captures that cannot be estimated before their boundary | `1500000` |

Supply secrets through the process environment or your service manager's secret store. The script does not load `.env` automatically. Run one instance per wallet, and give it a key separate from the payer/owner wallet and other transaction senders. RPC responses, URLs and private keys are never included in its JSON logs. `SIGINT`/`SIGTERM` finishes the current bounded RPC operation and stops polling; it does not cancel transactions already submitted.

The request interval covers reads, log scans, simulation, broadcasting and receipt checks. The default allows at most roughly 20 RPC requests/second before network latency; increasing it lowers that ceiling and can make exact boundaries impossible to catch. Set the polling and request intervals to suit the provider and monitor actual successful captures. This setting is a ceiling on request rate, not a promise of two-second liveness.

Base's [throughput and limits documentation](https://docs.base.org/specifications/transactions/throughput-and-limits) identifies the public mainnet and Sepolia endpoints as rate limited and unsuitable for production systems. It publishes no universal numeric requests-per-second allowance. Use a dedicated provider for a live Campaign, follow that provider's current plan limits and decrease `SETTLE_LOG_BLOCK_RANGE` if its log-query limits demand it. A public endpoint is suitable for an initial connectivity check, not an assurance that these deadlines will be met. Base's [Flashblocks documentation](https://docs.base.org/specifications/flashblocks) describes faster preconfirmations; this CLI follows ordinary full blocks and the contracts' explicit two-second boundary rule, not a different cadence inferred from preconfirmations.

## Captures, settlement and recovery

Up/down requires `captureBoundary` at both the exact trading cutoff and the exact Window end; threshold requires it at the Window end. Calling `settle` late without captures cannot recreate those prices. The bot submits a capture while the latest full-block timestamp is exactly two seconds before its target and uses an explicit gas limit because simulation at the latest block would be too early. It checks the current Round pointer and latest timestamp again before submitting. Both contracts can capture the same reader in one block; each Round still needs its own pointer transaction.

Transaction inclusion, RPC latency, a missing pool observation or an unexpected block cadence can make a capture fail or miss its target. The bot cannot guarantee inclusion in that exact next block and cannot safely substitute a later price. Such Rounds follow the existing contract rules: retry settlement, finalize eligible outage refunds after the 60-second Reading grace period, and finalize the 24-hour unsettled expiry. Market-cap threshold Readings also require settlement in a later block than the captured end block. Simulation naturally defers that call until it succeeds.

The bot rechecks stored `round.result` and simulates settlement before sending. A Round already settled when checked spends no gas. Another sender can still settle between simulation and inclusion; no offchain bot can eliminate that competing-transaction race. `phase()==Refunded` alone is not a stored settlement, so the bot still finalizes an eligible refund when `round.result` is zero.

Discovery combines the current scheduled Round with a chunked replay of `RoundSeeded` logs from `SETTLE_FROM_BLOCK`. Unmaterialized historical schedule slots hold no escrow and are left alone. Captures take priority over the bounded rotating historical settlement queue. No local file is authoritative: restarting replays the chain and finds old escrow even after a Campaign stops and `currentRound()` returns zero. Starting from too late a block can hide old unsettled escrow. Large backlogs take multiple full blocks to scan.

The bot tracks signed transaction hashes and nonces until receipts arrive. On restart it waits for an existing wallet queue to drain before sending fresh work. An uncertain broadcast is checked against receipts, the sender nonce and transaction lookup; after three absent-block observations it may rebroadcast the identical signed settlement, whose nonce prevents duplicate execution. An absent expired capture is removed instead of being rebroadcast too late. Known RPC rejections clear their pending entry for future retry. A transaction still present in the provider's mempool is left pending; the CLI does not cancel or replace it. If the wallet queue remains stuck, inspect that wallet's pending transactions with the provider, resolve the stuck transaction and restart. A restart cannot remove a pending transaction from the chain's mempool.

JSON events include `ready`, `submitted`, `confirmed`, `reverted`, `broadcast_rejected`, `broadcast_uncertain`, `missed_boundary`, `capture_not_found` and `retry`. Inspect transaction hashes on the configured chain and watch for persistent retries or absent successful captures. RPC failures retry at the configured pace without terminating the long-running process. Use the same deployment block and addresses after restarting.

## Local smoke verification

Run `yarn settle:bot:smoke`, or from `packages/foundry` run `forge build` then `node scripts-js/settleBot.smoke.js`. The smoke script spawns its own isolated Anvil on a local port, deploys both real Round contracts with `BasePoolReader` and the existing deterministic pool/token mocks, and uses a separate unprivileged Anvil wallet for the actual CLI child process. It adds no JS test runner.

The smoke checks successful UpDown Tie and threshold Yes settlement without Player settlement; a process restart while capture transactions are pending; recovery of both stopped Campaigns through historical events; a different wallet skipping already-settled Rounds with its nonce still zero; configurable RPC use through a local forwarding server; observed request pacing; and rejection of an invalid request interval. It asserts actual stored results, not just phases or log messages. Anvil timestamps advance explicitly in two-second blocks, so this demonstrates correct scheduling under controlled inclusion, not production network reliability.

Red/green evidence: the first on-chain smoke failed because `settleBot.js` did not exist, then passed with the CLI. The request-pacing assertion initially failed when spacing was measured from request start, because initial connection latency compressed server-observed arrivals. Waiting after response completion fixed the failure. No Solidity contract, generated deployment manifest or challenge test is changed by this ticket.
