# What traders and the sponsor are paid at resolution

Label: wayfinder:grilling
Type: grilling
Status: resolved
Assignee: MrSufferer
Blocked by: 02

## Question

When the resolver publishes Yes, No, or invalid, what does a trader who holds shares receive, and what does the sponsor receive of the subsidy that was not paid out in trades? Cover a trader who sold as well as a trader who only bought.

Depends on [Whether invalid is tradable](02-whether-invalid-is-tradable.md).

## Answer

- **Yes or No published:** each share of the winner pays a fixed ETH Payout, set at publish and never changed; losing shares pay nothing. The liquidity parameter in shares is the subsidy divided by (Payout × ln(1/min(p, 1−p))).
- **Invalid published:** every Yes and every No share pays half the Payout (50/50, as Polymarket does). Shares stay fungible; no per-account records. For any fixed split r, the sponsor's loss is at most b × KL(r‖opening probability), which never exceeds the subsidy ceiling; at a 50/50 opening the sponsor loses nothing. Rejected: paying at the opening probability (the sponsor always gains, so ambiguous pins profit the sponsor), last price (buyable once Invalid is evident, draining the subsidy), and refunding net cost (needs per-account tracking and non-transferable shares; negative for traders who sold at a profit).
- **Sellers and buyers:** only shares held at publication are paid. Earlier sells were paid at the LMSR quote and are final; no clawback or top-up.
- **Sponsor:** at publication the contract sets aside exactly what holders can claim (Payout × outstanding winning shares, or ½ Payout × all outstanding shares on Invalid) and releases the Remainder (subsidy plus trade cash minus the set-aside) to the sponsor at once.
- **Gains:** the sponsor keeps the whole Remainder, even above the subsidy. The subsidy caps loss, not gain.
- **Claims:** never expire; unclaimed set-aside is never swept to the sponsor.

Unpublished is not covered here; it belongs to [Who is paid the resolution cost](04-who-is-paid-the-resolution-cost.md).

## Before building

Apply https://ethskills.com/SKILL.md and follow it before writing Solidity or shipping anything onchain. Do not POST to its feedback endpoint without asking the human.
