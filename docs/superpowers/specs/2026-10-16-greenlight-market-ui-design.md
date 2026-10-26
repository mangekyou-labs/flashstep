# Greenlight market UI

Date: 2026-10-16

The public app uses Kalshi's page grammar for the one onchain prediction market, with the car-race voice kept to a single joke on each public surface. Prices on the board are cents of the payout. The trade ticket quotes the bonding-curve integral in ETH. The Solidity contract stays as it is.

## Pages and shell

Four public routes and two crew tools:

| Route | Role |
| --- | --- |
| `/` | Market board. One card for the deployed market. |
| `/market` | Question, cent prices, time chart, trade ticket or closed panel, rules. |
| `/portfolio` | Connected wallet's Yes and No shares, marks, and redeem. |
| `/live` | The existing car race, and nothing from the contract. |
| `/oracle` | Report Yes or No. Absent from the main nav. |
| `/liquidity-provider` | Collateral, trade cash, reserves, add and remove liquidity, resolve and withdraw. Absent from the main nav. |

`/user` redirects to `/market`.

The header is the wordmark **Greenlight**, then Markets, Portfolio, and Live. A light/dark control sits in the header. It follows the system preference until the reader changes it. Oracle and Liquidity sit in a Crew menu. The nav label stays Markets for the one market. On the local chain (31337), that menu also shows Debug Contracts and Block Explorer. The wallet sits on the right. The existing faucet stays beside it and only on Anvil. The document title is Greenlight.

Home no longer shows the Scaffold-ETH challenge intro. Crew pages use the same header and a plainer body, with no race widget and no jokes.

## Board and market

The board has one hero card. The title is the onchain question, verbatim. Under it, one joke line: "The crowd calls the race. The cars just run it." Yes and No show as cents of the payout, written `62¢` for a 62% chance. No is `100 − Yes`. The status is Open or Closed. Closed means the oracle has reported. The card links to `/market`.

The market page is two columns. The left column holds the question, the cent prices, and the time chart. The right column is the trade ticket. On a narrow viewport the ticket stacks under the chart.

The page headline is one joke: "Lap money, priced in cents." The question under it stays verbatim.

The chart plots the Yes chance against block time, on a fixed scale from 0 to 100. A 62¢ chance sits at 62. The line is green. The axis has no percent sign. Each point is the Yes chance after a buy or a sell. Trades that share a timestamp are a vertical step, drawn in log order. Before any trade the chart is a flat line at the current chance. Adding or removing liquidity does not move the line. After the oracle reports, the line stops. The chart does not name the winner.

The ticket offers Yes or No, buy or sell, and a share size. The size is entered in decimal token units and converted with the token's 18 decimals before it is quoted or sent. Displayed share counts round half away from zero to 4 decimal places, then trailing zeros are trimmed, so 1.23456 reads 1.2346 and 1.2000 reads 1.2. Max fills the exact reserve on a buy and the exact wallet balance on a sell. The field and the transaction use that exact count. The rounded readout is not what gets sent. The existing bonding-curve drawing shows how that size moves the price. The ticket shows the ETH paid or received. A buy also shows the max payout in ETH: the share size times `initialTokenValue`. Cents stay off the button. Cents are the chance. ETH is the money. Cost and proceeds come from `getBuyPriceInEth` and `getSellPriceInEth`. The market owner cannot trade. After the report, the ticket is replaced by a closed panel. The panel names the winner only when the winning token is the Yes token or the No token. If that address matches neither, the panel omits the name. It still shows the payout per winning share and the link to `/portfolio`. It does not call the winner No. There is no size field. The winner is named only in that panel. Winning shares redeem at `initialTokenValue`. Losing shares pay nothing.

The rules block states the payout per winning share, the 50 bps trading fee, and that the oracle address reports the result. The block stays straight.

## Portfolio, live, and crew

`/portfolio` reads the connected wallet's Yes and No balances.

While the market is open, each row shows the share count and a mark in ETH: shares × current chance × `initialTokenValue`. The mark uses the unrounded sold-share chance. It is a board reading, not a fill. It shows up to 8 decimal places, trailing zeros trimmed, and may disagree with a later trade. The headline joke is "Your garage."

After the report, winning shares show redeemable ETH (`amount × initialTokenValue`). Losing shares show zero. One control redeems the full winning balance. The liquidity provider can see the locked shares and cannot sell or redeem them. Those shares are a different pile from the pool. The portfolio does not send them to the liquidity page to cash out.

An empty wallet says "The garage is empty. Buy a car on the market." A disconnected wallet says "Connect a wallet to see your shares." The empty state replaces the headline joke, so the page still has one.

`/live` renders the existing race animation only. Speeds stay random. The page does not read the contract and does not settle the market. Start and reset stay. The headline is "Exhibition lap. The market keeps the real score."

The oracle page shows the question, the cent prices, and Yes/No report controls. Its cents follow the same chance rules as the board. The report button is enabled only for the oracle address. The liquidity page shows collateral, trade cash, reserves, add and remove liquidity, and resolve-and-withdraw. Trade cash is the ETH taken in on buys and not yet paid out on sells. Buys add to it, sells pay out of it, and the 50 bps fee is what remains. Resolved appears on this page only, and only when a `MarketResolved` log is present. If that log is missing, the page does not say Resolved. A wallet in the wrong role still sees the page. The button stays disabled, and one line names the address that can send the transaction.

## Look and voice

Public pages are paper white with ink text and hairline rows. Cards and inputs use a 6px radius. Prices use tabular figures. Buttons are at least 40px tall and show a visible focus ring.

Yes is the green car, `#2ecc71`. No is the red car, `#e74c3c`. Those colors mark the outcome label, a side bar on the selected ticket side, and the chart line. The cent digits stay ink so they remain readable on paper. The outcome color does not fill the page. Scaffold blue (`#93bbfb`) leaves the public chrome. Primary actions use ink on paper, or paper on ink.

DaisyUI light tokens move to a neutral paper: base `#ffffff`, ink `#1c1c1a`, hairline surfaces off-white. Dark mode uses the same green and red on a dark paper (`#171a18`) with ink reversed (`#f3f4f2`). Pure black stays out. Radius tokens for field, box, and selector are 6px.

Navigation labels stay plain: Markets, Portfolio, Live, Crew. Buy, sell, redeem, prices, and errors stay straight. A joke never replaces an action.

Motion stays small. The time chart draws in with a stroke, without a bounce. The live page keeps the car animation. `prefers-reduced-motion` shows the chart and the race as a still frame. Nothing uses `transition-all`.

The chart is an inline SVG. No chart library is added.

## Data flow

One shared read of `getPrediction()` feeds the board, the market page, the portfolio, and the crew pages. The snapshot is the question, payout, Yes and No reserves, reported flag, winning token, collateral, trade cash, owner, oracle, initial Yes probability, and the two token addresses. Each outcome token's `totalSupply()` is read beside it. Sold shares are `totalSupply − reserve`. The constructor lock is a transfer to the liquidity provider, so those shares count as sold.

While the market is open:

```
yesCents = round(yesSold × 100 / (yesSold + noSold))
noCents = 100 − yesCents
```

Half rounds away from zero, so 50.5 becomes 51. If the sold total is zero, Yes cents use `initialYesProbability`.

While the market is open, cents come from the current sold shares. They do not wait on trade history. Until buy and sell logs load, the chart is the flat current chance. If those logs fail, the chart stays that flat line and offers a retry. The cents stay. An open market has no redemption to reconstruct.

After the oracle reports, cents freeze at the last open chance. Redemptions burn winning shares and must not move the board. Cents and the chart wait until redemption history has loaded. If that history fails, the board, the market page, and the oracle page hide every cent figure and the chart line, and say "Chance unavailable." That line is the retry. The page does not draw the drifted chance. The closed panel stays. It names the winner only when the winning token is Yes or No, and omits the name otherwise.

Public status is Open when the oracle has not reported, and Closed when the oracle has reported. Resolved is not a public status. It appears only on the liquidity page, and only when a `MarketResolved` event is in the history. A missing log leaves every public page Closed. It does not guess Resolved. Trader actions change at the report.

The time chart uses `useScaffoldEventHistory` for `TokensPurchased` and `TokensSold`, with block timestamps, from `deployedOnBlock` (local block 4, Sepolia block 11906482). The series walks those events backward from the current sold amounts. A buy is undone by subtracting the amount from that outcome. A sell is undone by adding it. The leftmost point is the opening chance at the deploy block. Events that share a timestamp stay in log order and connect in that order. Liquidity events are ignored. No trades produce one flat point. After the report, `WinningTokensRedeemed` amounts are added back to the winning side before the walk. History is kept and no new points are added. No indexer is introduced. The ticket still quotes from the chain. An open market whose trade history fails keeps its cents and a flat chart with a retry. A closed market whose redemption history fails hides the cents and the line instead.

Writes:

- Buy calls `buyTokensWithETH(outcome, amount)` with `msg.value` exactly equal to `getBuyPriceInEth`.
- Sell reads the allowance. The button says Approve while the allowance is short of the size, and Sell once the allowance covers it. Confirming Approve does not send the sell. The sell calls `sellTokensForEth`.
- Portfolio calls `redeemWinningTokens` for the full winning balance.
- Report, add liquidity, remove liquidity, and resolve stay on the crew pages with their current signatures.

The curve inside the ticket may preview the path with the existing client integral quote. The button sends the chain quote's exact wei. A quote, a max payout, redeemable ETH, collateral, and trade cash show that exact wei, trailing zeros trimmed. An amount that is exact within 8 decimal places shows at that length. An amount that would round to a different figure, including 1 wei, shows the full trimmed value. An open-market mark shows up to 8 decimal places, trailing zeros trimmed, and may disagree with a later trade. Displayed share counts round half away from zero to 4 decimal places, then trailing zeros are trimmed. The submitted share count stays exact.

## Error handling

The action button stays disabled until the page can name a valid action.

- A disconnected wallet gets the connect prompt.
- The wrong chain uses the existing Scaffold network switch and sends nothing.
- A zero size stays disabled.
- The market owner sees shares and cannot buy, sell, or redeem.
- After the report, the ticket closes.
- Redeem and resolve stay disabled until the report.
- On crew pages, the wrong wallet keeps the form visible, the button stays disabled, and one line names the address that can send it.

Copy stays straight:

| Situation | Message |
| --- | --- |
| Buy size exceeds the reserve, or the quote reverts for lack of liquidity | Not enough liquidity |
| Sell size exceeds the wallet balance | Not enough shares |
| The chain quote changed before confirmation, so the exact ETH no longer matches | Price moved. Review the new quote |
| The wallet rejected the signature | Transaction cancelled |
| The caller is not the oracle | Only the oracle can report |
| The caller is not the liquidity provider | Only the liquidity provider can do this |
| A trade is attempted after the report | Market is closed |
| Redeem or resolve is attempted before the report | Market is still open |
| The winning balance is short | Not enough winning shares |
| An ETH or token transfer failed | Transfer failed |

Sell asks for allowance before `sellTokensForEth`. The button names only the next signature. A rejected approval never sends the sell and leaves the button on Approve. A pending transaction disables the button.

While `getPrediction()` is loading, prices and buttons show a quiet loading state. If no market is deployed, public pages say so in one line and hide the ticket. If the curve cannot be drawn, the ETH quote and the button remain. If event history fails, public status stays Open or Closed from the reported flag and does not guess Resolved.

## Testing

The Solidity stays unchanged. From `packages/foundry`, run the existing integral, buy, sell, and redeem Foundry tests once to confirm they still pass. No new contract tests.

Cents rounding, the No complement, and the backward walk are pure functions in a small Node test file that uses the built-in test runner. The file covers no trades, a buy and a sell walked back to the opening chance, a redemption added back so a burn cannot move the frozen chance, and a liquidity event left out of the series.

Browser checks run against Anvil with the current source, through `playwright-cli`:

- The board shows one card, the onchain question, cents that sum to 100, and a link to `/market`.
- The market chart is a flat line before any trade and gains a point after a buy.
- The ticket shows an ETH quote, and the submitted value matches that wei amount.
- Portfolio shows marks while open, and redeem after a report.
- The race appears on `/live` and is absent from the market, oracle, and liquidity pages.
- `/user` lands on `/market`.
- Oracle and liquidity are out of the main nav and still perform their actions.
- The owner cannot trade.
- A reported market replaces the ticket with the closed panel, freezes the cents, and names the winner once when the winning token is Yes or No. An unmatched winning token leaves the name off the panel.
- A closed market whose redemption history fails hides the cents and the chart and says "Chance unavailable."
- The market page is checked wide and narrow.
- With reduced motion, the chart and the race render as a still frame.

Sepolia is read-only. The deployed market should show its question and a quote. This work does not redeploy or verify Sepolia. Local Anvil is the chain the new screens are proven against.

## Unchanged

- `PredictionMarket.sol` and `PredictionMarketToken.sol`
- The integral price and the 50 bps fee
- Challenge progress in `.challenge-ai/progress.json`
- Deployed Sepolia bytecode
- Debug and block explorer pages, aside from when their links appear
- The race animation's random speeds and its disconnect from the contract
