# Legal exposure as a game supplier from Vietnam

Research for a decision record. **Not legal advice.** A Vietnamese criminal-law practitioner must confirm everything here before any contract is signed. Date: 2026-10-26.

Labels: **sourced** = stated by an official or first-party document I opened and read; **sourced (secondary)** = law-firm, news or consultant report of a primary source I could not open; **inferred** = my reasoning.

Builds on, and does not repeat: [Vietnam law for points and real-money group markets](../../group-markets/issues/02-vietnam-law-for-points-and-real-money-group-markets.md) and [Legal path for real-money creator markets](../../creator-feed-markets/research/20-legal-path-for-real-money-creator-markets.md). Those established that real money staked on an uncertain event very likely fits Penal Code Art. 321/322, that the developer's location matters more than the wrapper, and that no case of a pure code author was found. This note asks whether *selling the game to someone else and never touching bettor money* changes that.

## Summary

- **Not taking bettor money helps but does not clear you.** The Penal Code makes anyone who "creates material conditions" for a crime an accomplice (Art. 17), and Art. 322 itself lists "installing equipment" and "using means to assist gambling" as organising conduct. A supplier is not exempt on the text (sourced + inferred). What decides it is **intent and knowledge**: Art. 17 requires two or more people to act "intentionally" together (sourced). A developer who knowingly builds a real-money game for a gambling operator is poorly placed on that test (inferred).
- **Residence in Vietnam is the problem, not the buyer's licence.** Vietnamese territorial jurisdiction applies to acts done in Vietnam; Art. 6 adds that Vietnamese citizens abroad "may" be prosecuted (sourced). An operator's offshore licence is a defence in Curacao or Malta, not in Vietnam, where no online gambling is licensed (sourced, secondary).
- **Closest real cases are all operations, not sole contractors.** Da Nang, Nov 2025: 63 people in "tech companies" building betting sites for a Cambodian customer, charged under Art. 288 (sourced, secondary). Hung Yen, indictment 21 Oct 2026: 74 defendants in the Xoilac TV streaming ring, charged with organising gambling and copyright infringement; one coder and one "knew the project earned money from gambling advertising" (sourced, secondary). Neither charged a lone freelancer. Absence of a case is not safety (inferred).
- **Revenue share versus flat fee:** neither is a defence. A share tied to bettor losses is stronger evidence of knowledge and of a stake in the operation; a flat fee is weaker evidence but still "profit" if the buyer is a gambling operator. Art. 322 jumps to 5-10 years where unlawful profit reaches VND 50m or the internet is used, and a software fee alone can clear VND 50m (about US$2,000) (sourced for thresholds, inferred for application).
- **Payers that are not operators** (sponsors, streamers, crypto projects) change the risk only if the product handled by the dev is *not* real-money gambling. Prizes funded by a sponsor to non-paying players is the lower-risk shape; a token-marketing game where players stake money is not (inferred).
- **Cheapest next step:** a one-hour paid consult with a Vietnamese criminal lawyer, about VND 0.5-5m (sourced, secondary). Bring the questions at the bottom.

## 1. Does supplying gambling software count as organising or abetting?

### Statute (sourced: Consolidated Penal Code VBHN 135/2025/VBHN-VPQH, official government file, https://datafiles.chinhphu.vn/cpp/files/vbpq/2025/9/135-vbhn-vpqh.pdf, read in Vietnamese; incorporates Law 12/2017 and Law 86/2025 in force 1 Jul 2025)

- **Art. 321(2)(c):** gambling using "the internet, computer or telecom network or electronic means" is 3-7 years. **Art. 322(2)(b)-(c):** organising gambling with profit of VND 50,000,000 or more, or using the internet or electronic means, is 5-10 years, plus fines of VND 20-100m or confiscation (cl. 3). Confirms the prior notes.
- **Art. 322(1)(d)** (basic offence, no stake threshold): organisers who have "installed equipment serving gambling", assigned lookouts or attendants, arranged escape routes, or "used means to assist gambling". Nothing says "software", but "means to assist gambling" is the textual hook for a supplier (inferred).
- **Art. 17:** accomplices are the organiser, perpetrator, instigator and "helper" (người giúp sức), defined as one who "creates spiritual or material conditions for the commission of the crime". Accomplice requires two or more persons who "intentionally" commit the offence together. An accomplice is not liable for the perpetrator's excess (cl. 4). Sourced.
- **Art. 6(1):** Vietnamese citizens (and stateless permanent residents) who commit a crime outside Vietnam "may" (có thể) be prosecuted in Vietnam. The prior note recorded that some translations say "shall"; the official text says "may". Sourced.
- **Art. 285** (making or trading software for unlawful purposes) covers only software with "network attack" capability, not game software. Not a fit (sourced text, inferred conclusion).
- **Art. 288** (unlawful use of network information) is what Da Nang police actually used against the contract-programming ring; see section 2. Thresholds: profit VND 50m to under 200m (1st tier), 2-7 years above that or if organised (sourced text).

### Administrative route (sourced, secondary)

Decree 282/2025/ND-CP, in force 15 Dec 2025, replaces Decree 144/2021; Art. 36 fines unlawful gambling activity (VND 200,000-20m) with suspension of 6-12 months and expulsion for foreigners. A programmer "who only builds the website on another's instructions and does no other step" is, per one law firm, only administratively fined, while taking any role in running the gambling makes them an accomplice under Art. 322(2) (law-firm commentary; the FXX88 article, which I could not reopen at the end of the run; treat as one lawyer's view). Another consultant source says people who run agencies, ads or app-download guidance for online gambling "may be treated as helpers if they knowingly" do so. I did not read Decree 282's text.

### How the pieces combine (inferred)

For a lone developer who sells a game to an operator and never touches bettor funds:
1. Perpetrator: the operator, not you.
2. You are exposed only as "helper": you supplied a means, knowing the use.
3. The two defence points are **knowledge/intent** and **minor role**. Both weaken fast if the game is plainly a casino/betting game, the buyer says so in the contract, or you tune the game to the operator's house edge.
4. The practical risk is less a prosecution of freelancers than being swept into an operation's investigation when the buyer is raided and your contract, chats and payments are in the file (inferred; consistent with the cases below).

## 2. Known cases involving Vietnamese developers and offshore gaming

All reports below are news or law-firm sources (sourced, secondary). Nothing found in English or Vietnamese is a lone freelancer selling to a licensed operator.

| Case | Facts | Charge | Relevance |
|---|---|---|---|
| Da Nang, announced 27 Nov 2025 (Tuoi Tre; SGGP) | Police raided "Penta" and four other offices on 19 Nov 2025. About 63 staff (analysts, developers, testers) built and upgraded sports-betting, casino and lottery sites with VND, USDT and ETH deposit/withdrawal for a Cambodian customer "Torres"; code was on staff computers; staff used pseudonyms and company computers only. | Art. 288 (unlawful use of network information); article number not stated in reports | A paid outsourced dev house for an offshore gambling buyer was charged. Not Art. 322, though. Reports do not say what individual programmers knew or how they were paid. |
| Hung Yen, indictment reported 21 Oct 2026 (Kenh14) | 74 defendants in the "90 Phut"/Xoilac TV and Cakhia sites; collected over 2.7m USDT plus 2.5m USDT via betting ads. Site developer Nguyen Cong Dinh split profit with the owner; the programming team leader built further sites carrying betting ads; one defendant allegedly "knew the project earned money from gambling advertising". | Organising gambling and copyright infringement (article numbers not stated in report) | Closest to an Art. 322 helper charge against developers, but they ran the sites and shared profit. Shows profit-share plus knowledge is what prosecutors allege. Not yet tried. |
| Ha Noi, verdict 17 Aug 2023 (VnExpress) | A Chinese game developer who agreed to write games for a profit share was kidnapped and tortured for four months to force him to write an online gambling game. | Kidnappers convicted of injury and unlawful detention, 12-24 years | Not a legal-exposure case. Shows how gambling-software commissions attract organised crime; due diligence on the buyer matters physically. |
| Wider ring cases (Malay Mail/AFP via prior note; Bong X9) | Builders of gambling sites sentenced up to 13 years | Art. 322 | Covered in the prior note; builders ran or co-owned the operation. |

Not found (unverified): a Vietnamese conviction of a contractor who only delivered a game to a *licensed* foreign B2C operator; any prosecutorial guidance on supplier-only liability.

## 3. Revenue share versus flat fee

No source addresses this directly. My reading of the text (inferred):

- **Art. 322 doesn't distinguish.** Profit matters in two places: it is an aggravator at VND 50m ("thu loi bat chinh", unlawful profit), and the Hung Yen allegations tie knowledge to income from gambling advertising.
- **Revenue share:** your income rises with bettor losses. That makes you look like a co-beneficiary of the operation, not a vendor, and gives prosecutors a direct line from stakes to your bank account. It also makes the "I didn't know" defence harder, because you can see volumes (inferred).
- **Flat fee or licensing fee for a delivered build:** you are paid regardless of play. It supports the "supplier, not organiser" story (the same story the prior notes use for ownerless contracts) but does not remove "helper" status if you knew the use (inferred).
- **Both:** payments from a gambling operator into a Vietnamese bank account or Vietnamese-held wallet are traceable proceeds. I did not research Art. 324 (money laundering) or tax reporting for crypto income received from gambling firms. Flag for the lawyer.

## 4. What operators' supplier licences would ask of a Vietnamese resident

Mostly through the operator's compliance, not yours, and all from consultant or trade summaries; the regulators' own pages were not reached (sourced, secondary).

- **Curacao (LOK regime, regulator now Curacao Gaming Authority):** A supplier *established in Curacao* needs a CGA supplier licence. A *foreign* critical supplier (platforms, RNG engines, game studios) must **register** with the CGA by 24 Dec 2026; the operator may not use unregistered suppliers (Art. 5.16(4)). Registration portal expected October 2026. Due diligence reportedly covers every UBO holding 10% or more, directors and key persons, with apostilled criminal checks, police certificates, and source of funds/wealth; a EUR 150 fee per UBO registration. Details of foreign registration (documents, fees, definition of "critical") were not found.
- **Malta (Critical Gaming Supply licence):** applicant must be a Malta or EU company; reported minimum share capital EUR 40,000; shareholders/UBOs (one source says 5% and above) and key persons are probed with other regulators and law enforcement; criminal records, source of funds and wealth; RNG/system certification by an approved lab; 4-6 months.
- **What that means for a Vietnamese individual (inferred):** if you contract to a licensed operator without holding equity, you are likely only asked for ordinary KYC and a contract. If you become a key person or a 5-10% holder in a supplier entity, expect a Vietnamese criminal record certificate and a question about your home jurisdiction's treatment of gambling. Most licensed operators bar or restrict Vietnam in their terms, and Vietnam-based staff are an operational red flag for a licensed buyer (not verified; ask the buyer). Offshore labels such as Anjouan, Kahnawake or unlicensed crypto casinos ask for less and carry more risk for you (inferred).

## 5. Payers who are not operators

Matters only if their risk to you differs (inferred except where stated).

- **Sponsor-funded prize rounds, non-paying players:** no stake means no Art. 321/322 "wager" element; the product is closer to the points-only analysis in the prior note. Lowest-risk shape. Reservation: prizes in cash or tradable tokens may re-introduce "winning money for chance" in some readings; ask the lawyer.
- **Streamer/entertainment buyers:** if viewers stake money in your game, the streamer is the organiser and you are the helper, same as an operator. If it's free-to-play with prizes, less so. Note that Vietnamese police are already charging people for hosting content that advertises betting (Hung Yen), so a gambling brand paying a streamer to run your game also carries advertising risk.
- **Crypto project marketing games:** the same stake question applies; Resolution 05/2025 and licensing of crypto assets in Vietnam are covered in prior notes. A token-incentive game that players buy into with crypto is a real-money game in substance (inferred).

## 6. Cheapest way to get a lawyer's view

- **Vietnamese advocate, one hour, online or by phone:** reported list prices for initial criminal consults are about VND 200,000-500,000 per hour by phone, VND 300,000-800,000 by email, and VND 500,000-5,000,000 per in-person hour, with fees set by agreement under Art. 55 of the Law on Lawyers; criminal defence itself starts around VND 10-30m (sourced, secondary: law-firm price lists). So roughly **US$20-200** for a first opinion. Written, signed opinion costs more (inferred).
- **How to buy it well (inferred):** pick a criminal-law lawyer with cyber or gambling experience (not a business-registration firm); send the three-line scenario and the questions below in advance; ask for a written one-page answer; keep the engagement under privilege. Do not name a real buyer in the first email.
- Offshore counsel (the Panama/Malta/Curacao side) cannot advise on Vietnamese criminal exposure. Treat their view as separate and later.

## Questions for the Vietnamese lawyer

1. A developer in Vietnam sells a finished game to an offshore, licensed operator for a flat fee, and takes no bettor money. Is that "helper" conduct under Art. 17 with Art. 322, or at most an administrative offence under Decree 282/2025?
2. Does the answer change for a revenue share, a revenue share capped below VND 50m, or payment in crypto to a personal wallet?
3. What facts do prosecutors use to show knowledge? Does a contract clause stating the game is for licensed jurisdictions only help?
4. Is Art. 6 jurisdiction a live risk if all work is done in Vietnam for a buyer abroad (the answer is probably territorial, but confirm)?
5. For a non-operator payer (sponsor prizes, streamer, token project), what design (no stake, no cash-out) keeps the product outside Art. 321/322?
6. Is there any registration, tax or foreign-exchange rule for income from a foreign gambling operator, and any money-laundering exposure under Art. 324?
7. Any 2026 draft amendments that would criminalise online-gambling suppliers specifically? (One result mentions a proposal on online-gambling offences; I did not read it.)

## Unverified

- Official text of Decree 282/2025 and Art. 36; I relied on summaries.
- Whether any Vietnamese court has convicted a sole contractor developer; searches were shallow, and the Vietnamese search surface (court judgments portal, Supreme People's Court bulletins) was not queried directly.
- Article numbers charged in the Da Nang and Hung Yen cases are not stated in the reports; the Da Nang charge is given as "unlawful use of network information" (consistent with Art. 288, not confirmed). Both are pre-trial.
- The FXX88-based commentary on "programmer only: administrative fine" is a single law-firm opinion that I could not reopen to quote; treat as unproven.
- Regulator-owned text for Curacao (portal.cga.cw) and Malta (mga.org.mt, Directive 3); all supplier-licence claims are consultant summaries.
- The 2026 online-gambling draft criminal proposals.
- Art. 324, tax and exchange-control treatment of income from gambling firms.
- Whether payers outside operator, streamer and token categories (such as brands) carry distinct risk.
