"use client";

import { CSSProperties, SyntheticEvent, useState } from "react";
import Image from "next/image";
import { useSearchParams } from "next/navigation";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Address, BaseError, erc20Abi, formatUnits, parseUnits, zeroAddress } from "viem";
import { useAccount, usePublicClient, useSwitchChain, useWriteContract } from "wagmi";
import { BrandGate } from "~~/components/rounds/BrandGate";
import { NoExplorerNote, ProofPanels, SettleTxCell } from "~~/components/rounds/ProofPanels";
import { ReadingChart, readingLabel } from "~~/components/rounds/ReadingChart";
import { ThresholdRoundPage } from "~~/components/rounds/ThresholdRoundPage";
import { type Payer } from "~~/config/payers";
import { roundsAbi } from "~~/utils/rounds/abi";
import { useSettleTxs } from "~~/utils/rounds/proof";
import { phaseNames, resultNames, useRound } from "~~/utils/rounds/useRound";

function amount(value: bigint | undefined, decimals = 18) {
  if (value === undefined) return "—";
  // Exact decimal strings preserve small ETH values and all order/claim precision.
  return formatUnits(value, decimals);
}
function message(error: unknown): string {
  const text =
    error instanceof BaseError ? error.shortMessage : error instanceof Error ? error.message : "Transaction failed.";
  if (/StakeCapExceeded/.test(String(error))) return "This buy exceeds your Round Stake cap, including earlier buys.";
  if (/OutsideTrading/.test(String(error))) return "Trading has ended for this Round. Choose the current Round.";
  if (/SlippageExceeded|IncorrectPayment/.test(String(error)))
    return "The quote changed. Review the fresh quote and try again.";
  if (/PayerCannotBuy/.test(String(error))) return "The payer cannot trade. Connect a Player wallet.";
  if (/InsufficientReserve|InsufficientFunding/.test(String(error)))
    return "This Round has insufficient available liquidity for this trade.";
  if (/rejected|denied/i.test(text)) return "Request declined in your wallet. You can try again.";
  return text;
}

export function RoundPage() {
  const params = useSearchParams();
  return (
    <BrandGate>
      {payer =>
        params.get("market") === "threshold" ? (
          <ThresholdRoundPage key={payer.ticker} payer={payer} />
        ) : (
          <UpDownRoundPage key={payer.ticker} payer={payer} />
        )
      }
    </BrandGate>
  );
}

function UpDownRoundPage({ payer }: { payer: Payer }) {
  const params = useSearchParams();
  const [selected, setSelected] = useState<bigint | null>(() => {
    const id = params.get("round");
    return id && /^[1-9]\d*$/.test(id) ? BigInt(id) : null;
  });
  const { address, chainId } = useAccount();
  const { switchChainAsync } = useSwitchChain();
  const client = usePublicClient({ chainId: payer.chainId });
  const cache = useQueryClient();
  const { writeContractAsync } = useWriteContract();
  const snapshot = useRound(payer, selected, address);
  const data = snapshot.data;
  const detail = data?.detail;
  const [side, setSide] = useState<0 | 1>(0);
  const [mode, setMode] = useState<"buy" | "sell">("buy");
  const [input, setInput] = useState("1");
  const [pending, setPending] = useState(false);
  const [notice, setNotice] = useState("");
  const [failure, setFailure] = useState("");
  let shares = 0n;
  try {
    if (/^\d*(\.\d{0,18})?$/.test(input)) shares = parseUnits(input, 18);
  } catch {
    /* Inline validation below. */
  }
  const quote = useQuery({
    queryKey: [
      "round-quote",
      payer.address,
      data?.id.toString(),
      data?.block.number.toString(),
      side,
      mode,
      shares.toString(),
    ],
    enabled: !!client && !!detail && shares > 0n,
    retry: false,
    queryFn: async () => {
      if (!client || !data) throw new Error("Round unavailable.");
      const contract = { address: payer.address, abi: roundsAbi, blockNumber: data.block.number };
      const [cost, payout] = await Promise.all([
        client.readContract({
          ...contract,
          functionName: mode === "buy" ? "quote" : "quoteSell",
          args: [data.id, side, shares],
        }),
        client.readContract({ ...contract, functionName: "payoutFor", args: [shares] }),
      ]);
      return { cost, payout };
    },
  });
  const remaining =
    detail && data
      ? Number(detail.round.cutoff > data.block.timestamp ? detail.round.cutoff - data.block.timestamp : 0n)
      : 0;
  const held = detail ? (side === 0 ? detail.position.up : detail.position.down) : 0n;
  const tooMuch =
    !!detail && !!quote.data && mode === "buy" && detail.position.bought + quote.data.cost > detail.round.stakeCap;
  const tradingEnded = !!detail && detail.phase !== 0;
  const payerWallet = address && detail && address.toLowerCase() === detail.round.payer.toLowerCase();
  const invalid = !shares
    ? "Enter a share size greater than zero (up to 18 decimals)."
    : tradingEnded
      ? "Trading has ended for this Round. Choose the current Round."
      : tooMuch
        ? "This buy exceeds your Round Stake cap, including earlier buys."
        : mode === "sell" && shares > held
          ? "You do not hold enough shares of this outcome."
          : payerWallet
            ? "The payer cannot trade. Connect a Player wallet."
            : quote.isError
              ? "No quote is available for this share size. Try a smaller size."
              : "";

  async function transact(action: "buy" | "sell" | "claim", id = data?.id) {
    if (!address || !client || !id || pending) return;
    setPending(true);
    setFailure("");
    setNotice("Confirm in your wallet…");
    try {
      if (chainId !== payer.chainId) await switchChainAsync({ chainId: payer.chainId });
      const contract = { address: payer.address, abi: roundsAbi, account: address };
      let hash;
      if (action === "claim") {
        const { request } = await client.simulateContract({ ...contract, functionName: "claim", args: [id] });
        hash = await writeContractAsync(request);
      } else {
        // Re-read phase and quote immediately before simulation; the contract still enforces both.
        const freshPhase = await client.readContract({ ...contract, functionName: "phase", args: [id] });
        if (freshPhase !== 0) throw new Error("Trading has ended for this Round. Choose the current Round.");
        if (action === "buy") {
          const token = await client.readContract({ ...contract, functionName: "i_stakeToken" });
          let cost = await client.readContract({ ...contract, functionName: "quote", args: [id, side, shares] });
          if (token !== zeroAddress) {
            const allowance = await client.readContract({
              address: token,
              abi: erc20Abi,
              functionName: "allowance",
              args: [address, payer.address],
            });
            if (allowance < cost) {
              setNotice("Approve the stake token in your wallet…");
              const approval = await writeContractAsync({
                address: token,
                abi: erc20Abi,
                functionName: "approve",
                args: [payer.address, cost],
                chainId: payer.chainId,
              });
              await client.waitForTransactionReceipt({ hash: approval });
              cost = await client.readContract({ ...contract, functionName: "quote", args: [id, side, shares] });
            }
          }
          // Require a new review when a displayed quote moved; never silently increase the payment.
          if (cost !== quote.data?.cost) throw new Error("The quote changed. Review the fresh quote and try again.");
          const { request } = await client.simulateContract({
            ...contract,
            functionName: "buy",
            args: [id, side, shares, cost],
            value: token === zeroAddress ? cost : 0n,
          });
          hash = await writeContractAsync(request);
        } else {
          const proceeds = await client.readContract({
            ...contract,
            functionName: "quoteSell",
            args: [id, side, shares],
          });
          if (proceeds !== quote.data?.cost)
            throw new Error("The quote changed. Review the fresh quote and try again.");
          const { request } = await client.simulateContract({
            ...contract,
            functionName: "sell",
            args: [id, side, shares, proceeds],
          });
          hash = await writeContractAsync(request);
        }
      }
      setNotice("Transaction sent. Waiting for confirmation…");
      const receipt = await client.waitForTransactionReceipt({ hash });
      if (receipt.status !== "success")
        throw new Error("Transaction reverted. Review the refreshed Round and try again.");
      setNotice(
        action === "claim"
          ? `Claim confirmed for Round #${id}.`
          : `${action === "buy" ? "Buy" : "Sell"} confirmed for Round #${id}.`,
      );
    } catch (error) {
      setNotice("");
      setFailure(message(error));
    } finally {
      setPending(false);
      void cache.invalidateQueries({ queryKey: ["round"] });
      void cache.invalidateQueries({ queryKey: ["round-quote"] });
      void cache.invalidateQueries({ queryKey: ["round-history"] });
    }
  }
  function findRound(event: SyntheticEvent<HTMLFormElement>) {
    event.preventDefault();
    const id = String(new FormData(event.currentTarget).get("round"));
    if (/^[1-9]\d*$/.test(id)) {
      setSelected(BigInt(id));
      setFailure("");
    }
  }
  return (
    <div
      className="round-page"
      style={{ "--round-accent": payer.accent, "--round-up": payer.up, "--round-down": payer.down } as CSSProperties}
    >
      <header className="round-top">
        <a href={`/rounds?brand=${payer.ticker}`} className="round-brand">
          <Image src={payer.logo} width={32} height={32} alt="" />
          <span>
            {payer.name} <span className="round-muted">Rounds</span>
          </span>
        </a>
        <ConnectButton showBalance={false} chainStatus="icon" />
      </header>
      <div className="round-content">
        <a className="round-current" href={`/rounds?brand=${payer.ticker}&market=threshold`}>
          Threshold Rounds →
        </a>
        <div className="round-kicker">Onchain · Up or down · {data?.id ? `Round #${data.id}` : "Campaign"}</div>
        {payer.address === zeroAddress ? (
          <div className="round-state" role="status">
            <h1>Campaign not configured</h1>
            <p>Set this payer’s Round contract address to connect the Campaign.</p>
          </div>
        ) : snapshot.isPending ? (
          <div className="round-state" role="status">
            Loading Round from the contract…
          </div>
        ) : snapshot.isError ? (
          <div className="round-state" role="alert">
            <h1>Round unavailable</h1>
            <p>Check the Campaign network and Round number, then retry.</p>
            <button onClick={() => void snapshot.refetch()}>Retry</button>
            <button onClick={() => setSelected(null)}>Current Round</button>
          </div>
        ) : !detail ? (
          <div className="round-state">
            <h1>No Round is trading</h1>
            <p>The Campaign has not started or has finished. Find a previous Round below to claim.</p>
          </div>
        ) : (
          <div className="round-grid">
            <section className="round-market">
              <div className="round-title">
                <Image src={payer.logo} width={48} height={48} alt="" />
                <h1>
                  Will ${payer.ticker} be higher in {String(detail.round.windowEnd - detail.round.cutoff)} seconds?
                </h1>
              </div>
              <div className="round-chance">
                <strong>{String(detail.chance)}¢</strong>
                <span>Up chance</span>
                <span className="round-down">Down {String(100n - detail.chance)}¢</span>
              </div>
              <ReadingChart
                reading={detail.reading}
                reference={detail.reference}
                roundId={data.id}
                ticker={payer.ticker}
                quoteTicker={payer.quoteTicker}
              />
              <div className="round-phase">
                <span className={detail.phase === 0 ? "round-dot" : "round-dot inactive"} />
                <strong>{phaseNames[detail.phase]}</strong>
                <span className="round-countdown">
                  {detail.phase === 0
                    ? `${remaining}s to trade`
                    : detail.phase === 3
                      ? resultNames[detail.round.result]
                      : detail.phase === 1
                        ? `${Number(detail.round.windowEnd - data.block.timestamp)}s in Window`
                        : "Trading has ended"}
                </span>
              </div>
              <dl className="round-rules">
                <div>
                  <dt>Settles from</dt>
                  <dd>Base pool TWAP</dd>
                </div>
                <div>
                  <dt>Start Reading</dt>
                  <dd>{readingLabel(detail.reference?.price)}</dd>
                </div>
                <div>
                  <dt>End Reading</dt>
                  <dd>
                    {detail.round.endReading.price ? readingLabel(detail.round.endReading.price) : "Not pinned yet"}
                  </dd>
                </div>
              </dl>
              {selected !== null && (
                <button className="round-current" onClick={() => setSelected(null)}>
                  Return to current Round{data.current ? ` #${data.current}` : ""} →
                </button>
              )}
            </section>
            <aside className="round-panel" aria-label="Trade Round">
              <div className="round-tabs">
                {(["buy", "sell"] as const).map(value => (
                  <button key={value} aria-pressed={mode === value} onClick={() => setMode(value)}>
                    {value === "buy" ? "Buy" : "Sell"}
                  </button>
                ))}
              </div>
              <div className="round-sides">
                {([0, 1] as const).map(value => (
                  <button
                    key={value}
                    className={value === 0 ? "up" : "down"}
                    aria-pressed={side === value}
                    onClick={() => setSide(value)}
                  >
                    {value === 0 ? "↑ Up" : "↓ Down"}
                    <strong>{String(value === 0 ? detail.chance : 100n - detail.chance)}¢</strong>
                  </button>
                ))}
              </div>
              <label className="round-input-label" htmlFor="round-shares">
                Shares
              </label>
              <input
                id="round-shares"
                className="round-input"
                inputMode="decimal"
                autoComplete="off"
                value={input}
                onChange={event => setInput(event.target.value)}
                aria-describedby="round-validation"
              />
              <div className="round-chips">
                {[1, 5, 10, 20].map(value => (
                  <button key={value} onClick={() => setInput(String(value))}>
                    {value} shares
                  </button>
                ))}
              </div>
              <dl className="round-summary">
                <div>
                  <dt>{mode === "buy" ? "You pay" : "You receive"}</dt>
                  <dd>
                    {amount(quote.data?.cost, detail.decimals)} {detail.symbol}
                  </dd>
                </div>
                <div>
                  <dt>Stake cap</dt>
                  <dd>
                    {amount(detail.round.stakeCap, detail.decimals)} {detail.symbol}
                  </dd>
                </div>
                <div>
                  <dt>Earlier buys</dt>
                  <dd>
                    {amount(detail.position.bought, detail.decimals)} {detail.symbol}
                  </dd>
                </div>
                {mode === "buy" && (
                  <div className="round-to-win">
                    <dt>To win</dt>
                    <dd>
                      {amount(quote.data?.payout, detail.decimals)} {detail.symbol}
                    </dd>
                  </div>
                )}
              </dl>
              <p id="round-validation" className="round-validation" aria-live="polite">
                {invalid ||
                  (quote.isFetching
                    ? "Updating quote…"
                    : mode === "buy"
                      ? "Payout if your outcome wins. Gas is extra."
                      : "Proceeds protected by the displayed quote.")}
              </p>
              {address ? (
                <button
                  className={`round-cta ${side === 1 ? "down" : ""}`}
                  disabled={!!invalid || !quote.data || quote.isFetching || pending}
                  onClick={() => void transact(mode)}
                >
                  {pending
                    ? "Waiting for confirmation…"
                    : `${mode === "buy" ? "Buy" : "Sell"} ${side === 0 ? "Up" : "Down"}`}
                </button>
              ) : (
                <div className="round-connect">
                  <ConnectButton.Custom>
                    {({ openConnectModal }) => (
                      <button className="round-cta" onClick={openConnectModal}>
                        Connect to trade
                      </button>
                    )}
                  </ConnectButton.Custom>
                </div>
              )}
              <div className="round-position">
                <h2>Your position · #{String(data.id)}</h2>
                {address ? (
                  <>
                    <p>
                      Up <strong>{amount(detail.position.up)} shares</strong>
                    </p>
                    <p>
                      Down <strong>{amount(detail.position.down)} shares</strong>
                    </p>
                    <p>
                      Net paid{" "}
                      <strong>
                        {amount(detail.position.paid, detail.decimals)} {detail.symbol}
                      </strong>
                    </p>
                    {detail.position.claimed ? (
                      <p>Claimed</p>
                    ) : detail.claimable > 0n ? (
                      <button className="round-claim" disabled={pending} onClick={() => void transact("claim")}>
                        Claim {amount(detail.claimable, detail.decimals)} {detail.symbol}
                      </button>
                    ) : (
                      <p className="round-muted">
                        {detail.phase < 3 ? "Claimable after settlement." : "Nothing to claim."}
                      </p>
                    )}
                  </>
                ) : (
                  <p className="round-muted">Connect your wallet to see your shares.</p>
                )}
              </div>
            </aside>
          </div>
        )}
        <div className="round-feedback" aria-live="polite" role="status">
          {notice}
        </div>
        {failure && (
          <div className="round-error" role="alert">
            {failure}
          </div>
        )}
        <ProofPanels payer={payer} market="updown" roundId={data?.id || undefined} />
        {data?.current ? (
          <RecentRounds payer={payer} current={data.current} account={address} onSelect={id => setSelected(id)} />
        ) : null}
        <form className="round-find" onSubmit={findRound}>
          <label htmlFor="find-round">Find a previous Round</label>
          <input id="find-round" name="round" type="number" min="1" step="1" required placeholder="Round number" />
          <button type="submit">View Round</button>
        </form>
        <footer className="round-footer">
          Operated by {payer.name}. Rounds settle from pinned onchain Readings. A Tie refunds net paid. Claims never
          expire.
        </footer>
      </div>
    </div>
  );
}

function RecentRounds({
  payer,
  current,
  account,
  onSelect,
}: {
  payer: Payer;
  current: bigint;
  account?: Address;
  onSelect: (id: bigint) => void;
}) {
  const client = usePublicClient({ chainId: payer.chainId });
  const history = useQuery({
    queryKey: ["round-history", payer.address, current.toString(), account],
    enabled: !!client,
    refetchInterval: 2000,
    queryFn: async () => {
      if (!client) return [];
      const blockNumber = await client.getBlockNumber();
      const ids = Array.from(
        { length: Number(current > 6n ? 6n : current - 1n) },
        (_, index) => current - 1n - BigInt(index),
      );
      return Promise.all(
        ids.map(async id => {
          const contract = { address: payer.address, abi: roundsAbi, blockNumber };
          const [round, phase, claimable] = await Promise.all([
            client.readContract({ ...contract, functionName: "round", args: [id] }),
            client.readContract({ ...contract, functionName: "phase", args: [id] }),
            client.readContract({ ...contract, functionName: "claimable", args: [id, account ?? zeroAddress] }),
          ]);
          return { id, round, phase, claimable };
        }),
      );
    },
  });
  const settleTxs = useSettleTxs(payer, "updown", history.data);
  return (
    <section className="round-history">
      <h2>Recent Rounds</h2>
      {history.isError ? (
        <p>
          Could not load recent Rounds. <button onClick={() => void history.refetch()}>Retry</button>
        </p>
      ) : !history.data?.length ? (
        <p className="round-muted">{history.isPending ? "Loading recent Rounds…" : "The first Round is trading."}</p>
      ) : (
        <>
          <table>
            <thead>
              <tr>
                <th>Round</th>
                <th>Result</th>
                <th>Start Reading → End Reading</th>
                <th>Settle tx</th>
                <th>
                  <span className="sr-only">Action</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {history.data.map(row => (
                <tr key={String(row.id)}>
                  <td>#{String(row.id)}</td>
                  <td>
                    {row.phase === 4
                      ? "Refunded"
                      : row.round.result
                        ? resultNames[row.round.result]
                        : phaseNames[row.phase]}
                  </td>
                  <td>
                    {row.round.startReading.price ? readingLabel(row.round.startReading.price) : "—"} →{" "}
                    {row.round.endReading.price ? readingLabel(row.round.endReading.price) : "—"}
                  </td>
                  <SettleTxCell payer={payer} round={row} txs={settleTxs} />
                  <td>
                    <button onClick={() => onSelect(row.id)}>
                      {row.claimable > 0n ? "View claim" : "View"}
                      <span className="sr-only"> Round {String(row.id)}</span>
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <NoExplorerNote payer={payer} />
        </>
      )}
    </section>
  );
}
