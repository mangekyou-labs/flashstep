# Branded Round page

The Player page is `/rounds?brand=DEGEN`. `/rounds?brand=BASE` uses the second example brand. Addresses, name, ticker, logo, accent and outcome colours come from `brand.json`, not from editing `config/payers.ts` or `NEXT_PUBLIC_ROUNDS_ADDRESS` in `.env.local`. Query parameters select a known book key; they cannot replace a contract address. Unknown brands use DEGEN. The two included logos are local sample marks, replaceable via config.

The current page uses the repository's configured local chain (31337). To target another network, set `chainId` in `brand.json`. Base (8453) and Base Sepolia (84532) are already on the static page's client list. The contract's stake-token address, symbol and decimals determine payment units. ETH buys send the exact quote; ERC-20 buys request allowance before buying. Sell minimum proceeds equal the displayed quote. A changed quote requires another review; a new Round cannot receive an order intended for the old one.

## Local fixture

Use a fresh disposable Anvil instance, with the standard unlocked local accounts, and installed workspace dependencies. These scripts refuse non-local RPC URLs and chain IDs other than 31337. They are test fixtures, not payer deployment scripts.

```sh
anvil --port 8545
# In another terminal at the repo root:
forge build --root packages/foundry
node scripts/rounds-local.mjs setup
```

Put the printed address into `brand.json` as `address` (not `NEXT_PUBLIC_ROUNDS_ADDRESS` in `.env.local`, and not `config/payers.ts`), then start the frontend with `yarn start`. Fixture state is saved to `output/rounds-local.json`. Open `http://localhost:3000/rounds?brand=DEGEN`, connect a Player wallet, and fund that address:

```sh
node scripts/rounds-local.mjs fund-player <wallet-address>
```

The payer is the first unlocked Anvil account and cannot trade. Use a different wallet, such as the existing local Burner Wallet. Setup fixes automatic block timestamps at one-second steps so browser interactions do not race a 30-second trading phase. This clock control is local testing only; production timing comes from the chain.

Buy Up, verify its position, sell some shares, then buy Down. Enter `20` shares to see the cumulative Stake cap refusal with the fixture's 0.1 ETH cap (a fresh 20-share Up quote is 0.125 ETH). Return to a smaller size before buying. Test cutoff and rollover:

```sh
node scripts/rounds-local.mjs cutoff 1
```

The page follows `currentRound()` to Round #2. Find Round #1 using the lookup below the recent-Rounds table and verify that trading is refused. Settle through the mock pool's actual TWAP captures:

```sh
node scripts/rounds-local.mjs settle 1
```

The fixture captures the exact start/end boundaries, moves the mock pool tick upward, then settles Up. View Round #1 and claim the winning shares; the position changes to Claimed, and the claim button disappears. Recheck `/rounds?brand=BASE`, widths 375/768/1280, keyboard focus, and reduced motion. Use `playwright-cli` snapshots before selecting element references. Browser artifacts belong under `output/playwright/`.

A previous claim remains accessible through `/rounds?brand=DEGEN&round=1` or the Round-number lookup, even when it has left the recent table. The contract decides claimability and double-claim behavior.

## Data and display

`currentRound`, `round`, `phase`, `chanceCents`, `quote`/`quoteSell`, `payoutFor`, `positionOf` and `claimable` are contract views. Related values read the same block. Cents are rounded onchain; Down is the complement. No AMM or payout calculation runs in TypeScript. Polls follow the contract schedule and preserve a selected historical Round.

The chart samples `BasePoolReader.preview()` while the page is open. It is a live TWAP display, not a stored history or settlement input. Before cutoff its dashed guide is the first displayed TWAP and is labelled as such. Once captured, the actual start Reading replaces that guide. A start Reading is never invented before trading stops. Settlement still uses captured, pinned Readings. Without a valid pool Reading the chart shows a waiting state.

This ticket adds the Player flow only. A production settle bot, proof links, embeddings, threshold Rounds and payer analytics have separate tickets. The local fixture is the explicit settlement driver for this smoke run.

## Validation record

Issue #8 was verified against the disposable local fixture with `playwright-cli`. The Player bought 1 Up and 1 Down share, sold 0.5 Down and 0.25 Up, and saw both positions update. A 20-share order was blocked by the cumulative Stake cap. At cutoff the page followed Round #2; the historical Round #1 blocked trading. After real TWAP boundary capture and Up settlement, the Player claimed 0.0075 ETH and the page showed Claimed.

The BASE configuration changed the name, ticker, logo and colours. Browser checks at widths 375, 768 and 1280 found no horizontal overflow and no console errors. Local screenshots are under `output/playwright/` (including `round-page-trading.png` and `round-page-cutoff.png`); generated browser artifacts are not committed.

Automated checks passed: 71 Foundry tests across the Round and Reading suites, with one opt-in Base mainnet fork test skipped; Next.js TypeScript checking; and ESLint for the changed frontend files. Standards and spec reviews found no outstanding findings.
