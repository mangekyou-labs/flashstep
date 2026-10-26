# Greenlight

One onchain prediction market. People buy and sell Yes and No shares. Public pages show the chance in cents and the money in ETH.

## Language

**Market**:
The one question and its Yes and No shares.
_Avoid_: book, listing

**Share**:
The unit a person holds and types, in token units.
_Avoid_: wei

**Sold shares**:
Shares that have left the market, including the opening lock.

**Reserve**:
Outcome shares the market still holds.
_Avoid_: supply

**Lock**:
Shares given to the liquidity provider at deployment to set the opening chance. That address cannot transfer, sell, or redeem them.
_Avoid_: stake

**Chance**:
The sold-share probability. The Yes chance is the Yes shares sold divided by all shares sold.
_Avoid_: odds, price

**Cents**:
The Yes chance rounded half away from zero to a whole number of cents of the payout. No cents are 100 minus Yes cents.
_Avoid_: a percent sign on the board

**Quote**:
The ETH charged or paid for a chosen share size.
_Avoid_: price, when chance is meant

**Payout**:
The ETH one winning share redeems for.
_Avoid_: prize

**Max payout**:
The share size times the payout. What a buy returns if that side wins.
_Avoid_: quote

**Mark**:
While the market is open, shares times the unrounded chance times the payout. A reading, not a fill.
_Avoid_: quote, fill

**Collateral**:
ETH backing redemptions.
_Avoid_: pool, trade cash

**Trade cash**:
ETH taken in on buys and not yet paid out on sells. The trading fee stays inside this balance. It is not itself the fee.
_Avoid_: trading revenue, fees

**Open**:
The oracle has not reported.
_Avoid_: live, active

**Closed**:
The oracle has reported a winner. Trading is finished.
_Avoid_: reported, resolved

**Resolved**:
The liquidity provider has withdrawn the pool. Shown only on the crew liquidity page, and only when that withdrawal is known.
_Avoid_: closed, reported

**Winner**:
The outcome the oracle reported.
_Avoid_: resolution

**Liquidity provider**:
The address that seeds the market, changes the reserves, and withdraws the pool.
_Avoid_: market maker

**Oracle**:
The address that may report the winner.

**Crew**:
The oracle and liquidity-provider tools. They sit outside the main nav.
_Avoid_: admin

## Budgeted forecast

Terms settled by the budgeted-forecast map. They do not change the Greenlight terms above.

**Invalid**:
A published result: the resolver applied the question's invalid-result rule to the named source. It has no shares and no price.
_Avoid_: void, cancelled, N/A

**Awaiting result**:
The observation window has ended and trading has stopped, but the resolver has not yet published a result.
_Avoid_: closed, pending

**Depth**:
The ETH a trade must spend at the open to move the probability five points, stated for each direction.
_Avoid_: liquidity, TVL

**Unpublished**:
The deadline has passed and the resolver has published no result.
_Avoid_: invalid, expired

**Withdrawn**:
The forecast buyer took the forecast down before anyone traded and got the subsidy and resolution cost back. No question was tested.
_Avoid_: cancelled, invalid, void

**Interested party**:
A person or team whose actions can change the result, or who already knows it, such as a lab whose staff set the release date the question asks about.
_Avoid_: insider, influencer

**Remainder**:
What the forecast buyer receives when a result is published: the subsidy plus trade cash, minus what holders can claim. It may exceed the subsidy.
_Avoid_: refund, unspent subsidy, profit

## Buyer and wedge

Terms settled by the buyer-and-wedge map.

**Forecast buyer**:
A funder that already pays for forecasts on its own questions and would buy one produced by a market.
_Avoid_: sponsor, customer

## Group markets

Terms settled by the group-markets map.

**Group market**:
A question created by a member of one chat group, staked on and resolved by that group's members.
_Avoid_: private market, friend bet

**Points**:
What members stake in a group market. They have no value outside the app: they cannot be bought, cashed out, traded or exchanged for prizes.
_Avoid_: tokens, coins, credits

**Pot**:
All the points staked on one group market. When the market settles, the members who backed the winning outcome split it in proportion to their stakes.
_Avoid_: pool, collateral, liquidity

**Outcome**:
One of the 2 to 6 named answers a group market offers. Yes and No are the default pair.
_Avoid_: side, option

**Unmatched**:
A group market where, when staking stopped, fewer than two outcomes held any stake. Every stake is returned and no result is needed.
_Avoid_: void, cancelled, one-sided

**Cutoff**:
The moment staking stops on a group market. The creator sets it when posting, and may bring it forward but never push it back. After the Cutoff, the market is Awaiting result.
_Avoid_: close, lock, deadline

**Proposed result**:
The Outcome, or Invalid, that the creator (or, if the creator is late, a staker) says a group market ended with. It stands unless a staker disputes it during the challenge window.
_Avoid_: report, resolution, answer

**Challenge window**:
The fixed time after a proposed result during which any staker may dispute it.
_Avoid_: dispute period, liveness

**Dispute**:
A staker's objection to a proposed result. It sends the market to a group vote, where an Outcome or Invalid needs two thirds of the votes cast; otherwise the market ends Invalid.
_Avoid_: challenge, appeal

## Creator feed markets

Terms settled by the creator-feed-markets map. **Pot**, **Cutoff** and **Unmatched** carry over from group markets, but the pot here is ETH, not points.

**Creator**:
The person who opens a feed market and earns its creator fee. The creator never reports the result.
_Avoid_: liquidity provider, host, owner

**Opening stake**:
ETH the creator stakes on both sides at a split they choose, when they open the market. It is settled like any other stake.
_Avoid_: seed, liquidity

**Creator fee**:
The cut of the pot paid to the creator when a market settles with a winner. Nothing is paid on a refund.
_Avoid_: trading fee, revenue

**Window**:
The time between the start reading and the end reading. Staking has stopped for the whole window.
_Avoid_: period

**Reading**:
A feed price the market stores at a pinned time: the start reading at the Cutoff, the end reading when the window ends.
_Avoid_: snapshot, oracle answer

**Tie**:
The end reading equals the start reading, or the threshold. Every stake is refunded.
_Avoid_: draw, push

**Expired**:
Nobody settled the market within 24 hours of the window's end. Anyone may then refund every stake.
_Avoid_: void, invalid, unpublished

**Taken market**:
A market where someone other than its creator staked. The opening stake alone never makes a market taken.
_Avoid_: matched, active

## Paid fast rounds

Terms settled by the paid-fast-rounds map. **Window**, **Reading** and **Tie** carry over from creator feed markets. **Pot** and **Unmatched** carry over from group markets for threshold Rounds, with real money instead of points, and **Opening stake** from creator feed markets, put up by the payer instead of a creator.

**Round**:
One automatic market in a back-to-back series: a trading phase of 5 to 30 seconds, then a Window of 1 to 30 seconds, both set by the payer. Nobody opens it; Rounds overlap, so one trades while the last one's Window runs.
_Avoid_: market, game, creator market

**Payer**:
The business that pays the developer for the product. A payer is never a bettor.
_Avoid_: customer, buyer, sponsor

**Operator**:
The business that runs the Rounds and holds the players' stakes, with or without a gambling licence. In a white-label Campaign the payer is the operator; the developer never is.
_Avoid_: house, platform, partner

**Paid commitment**:
Money or a signed promise of money from a payer before building: a pilot fee, a deposit or a signed LOI.
_Avoid_: interest, traction, lead

**Player**:
A person who buys and sells Yes and No shares in a Round with real money, in the stake token the payer picked.
_Avoid_: bettor, user, staker

**Campaign**:
A run of back-to-back Rounds on tokens the payer picks, for a fixed time (about 7 days). The unit the payer pays for.
_Avoid_: season, tournament, event

**Paid commitment**:
Money a payer hands over for a Campaign, at least a non-refundable deposit, or a signed letter that names a price and a start date. A promise without either is interest, not a commitment.
_Avoid_: deal, yes, LOI (when unpriced)

**Stake cap**:
The most one player may stake in one Round, set by the payer below what it costs to move the pool price over the Window.
_Avoid_: limit, max bet
