"use client";

import { CSSProperties, SyntheticEvent, useState } from "react";
import Image from "next/image";
import { useSearchParams } from "next/navigation";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { BaseError, erc20Abi, formatUnits, parseUnits, zeroAddress } from "viem";
import { useAccount, usePublicClient, useSwitchChain, useWriteContract } from "wagmi";
import { PoolBalance, SettleTx, ShareBar } from "~~/components/rounds/ProofPanels";
import { readingLabel } from "~~/components/rounds/ReadingChart";
import { payerFor } from "~~/config/payers";
import { useSettleTxs } from "~~/utils/rounds/proof";
import { thresholdAbi, thresholdResults } from "~~/utils/rounds/thresholdAbi";
import { phaseNames } from "~~/utils/rounds/useRound";
import { useThresholdRound } from "~~/utils/rounds/useThresholdRound";

export function ThresholdRoundPage() {
  const params = useSearchParams();
  const payer = payerFor(params.get("brand"));
  const [selected, setSelected] = useState<bigint | null>(() => {
    const id = params.get("round");
    return id && /^[1-9]\d*$/.test(id) ? BigInt(id) : null;
  });
  const { address, chainId } = useAccount();
  const client = usePublicClient({ chainId: payer.chainId });
  const { switchChainAsync } = useSwitchChain();
  const { writeContractAsync } = useWriteContract();
  const cache = useQueryClient();
  const snapshot = useThresholdRound(payer, selected, address);
  const data = snapshot.data;
  const detail = data?.detail;
  const [side, setSide] = useState<0 | 1>(0);
  const [input, setInput] = useState("0.01");
  const [pending, setPending] = useState(false);
  const [notice, setNotice] = useState("");
  const [failure, setFailure] = useState("");
  const decimals = detail?.decimals ?? 18;
  const units = (value?: bigint) => (value === undefined ? "—" : formatUnits(value, decimals));
  let stake = 0n;
  try {
    // parseUnits rounds extra decimals; reject them before conversion.
    if (/^\d+(\.\d*)?$/.test(input) && (input.split(".")[1]?.length ?? 0) <= decimals)
      stake = parseUnits(input, decimals);
  } catch {
    /* Inline validation below. */
  }
  const quote = useQuery({
    queryKey: [
      "threshold-quote",
      payer.thresholdAddress,
      payer.chainId,
      address,
      data?.id.toString(),
      data?.block.number.toString(),
      side,
      stake.toString(),
    ],
    enabled: !!client && !!detail && stake > 0n && detail.phase === 0,
    retry: false,
    queryFn: async () => {
      if (!client || !data) throw new Error("Round unavailable.");
      return client.readContract({
        address: payer.thresholdAddress,
        abi: thresholdAbi,
        blockNumber: data.block.number,
        functionName: "quoteStake",
        args: [data.id, address ?? zeroAddress, side, stake],
      });
    },
  });
  const invalid = !stake
    ? `Enter a stake greater than zero (up to ${decimals} decimals).`
    : detail?.phase !== 0
      ? "Staking has ended for this Round. Choose the current Round."
      : detail.position.paid + stake > detail.round.stakeCap
        ? "This stake exceeds your Round Stake cap, including earlier stakes."
        : quote.isError
          ? "Payout unavailable. Refresh the Round and try again."
          : "";
  const refunded = !!detail && (detail.phase === 4 || [3, 4, 5].includes(detail.round.result));

  async function transact(action: "stake" | "claim") {
    if (!address || !client || !data?.id || !detail || pending) return;
    // Freeze the intended Round and order while wallet/approval dialogs are open.
    const id = data.id;
    const amount = stake;
    const outcome = side;
    setPending(true);
    setFailure("");
    setNotice("Confirm in your wallet…");
    try {
      if (chainId !== payer.chainId) await switchChainAsync({ chainId: payer.chainId });
      const contract = { address: payer.thresholdAddress, abi: thresholdAbi, account: address };
      let hash;
      if (action === "claim") {
        const { request } = await client.simulateContract({ ...contract, functionName: "claim", args: [id] });
        hash = await writeContractAsync(request);
      } else {
        if (invalid || quote.data === undefined) throw new Error(invalid || "Wait for the payout preview.");
        if (detail.token !== zeroAddress) {
          const allowance = await client.readContract({
            address: detail.token,
            abi: erc20Abi,
            functionName: "allowance",
            args: [address, payer.thresholdAddress],
          });
          if (allowance < amount) {
            setNotice(`Approve ${detail.symbol} in your wallet…`);
            const approval = await writeContractAsync({
              address: detail.token,
              abi: erc20Abi,
              functionName: "approve",
              args: [payer.thresholdAddress, amount],
              chainId: payer.chainId,
            });
            const receipt = await client.waitForTransactionReceipt({ hash: approval });
            if (receipt.status !== "success") throw new Error("Approval reverted. Try again.");
          }
        }
        const phase = await client.readContract({ ...contract, functionName: "phase", args: [id] });
        if (phase !== 0) throw new Error("Staking has ended for this Round. Choose the current Round.");
        const fresh = await client.readContract({
          ...contract,
          functionName: "quoteStake",
          args: [id, address, outcome, amount],
        });
        if (fresh !== quote.data) throw new Error("The payout changed. Review the fresh preview and try again.");
        const { request } = await client.simulateContract({
          ...contract,
          functionName: "stake",
          args: [id, outcome, amount],
          value: detail.token === zeroAddress ? amount : 0n,
        });
        hash = await writeContractAsync(request);
      }
      setNotice("Transaction sent. Waiting for confirmation…");
      const receipt = await client.waitForTransactionReceipt({ hash });
      if (receipt.status !== "success") throw new Error("Transaction reverted. Refresh the Round and try again.");
      setNotice(`${action === "claim" ? "Claim" : "Stake"} confirmed for Round #${id}.`);
    } catch (error) {
      setNotice("");
      const text =
        error instanceof BaseError
          ? error.shortMessage
          : error instanceof Error
            ? error.message
            : "Transaction failed.";
      setFailure(
        /StakeCapExceeded/.test(String(error))
          ? "This stake exceeds your Round Stake cap, including earlier stakes."
          : /OutsideTrading/.test(String(error))
            ? "Staking has ended for this Round. Choose the current Round."
            : /InsufficientFunding/.test(String(error))
              ? "The payer has not funded this Round's Opening stakes."
              : /rejected|denied/i.test(text)
                ? "Request declined in your wallet. You can try again."
                : text,
      );
    } finally {
      setPending(false);
      void cache.invalidateQueries({ queryKey: ["threshold"] });
      void cache.invalidateQueries({ queryKey: ["threshold-quote"] });
      void cache.invalidateQueries({ queryKey: ["threshold-history"] });
    }
  }
  const history = useQuery({
    queryKey: ["threshold-history", payer.thresholdAddress, payer.chainId, data?.current.toString(), address],
    enabled: !!client && !!data?.current,
    refetchInterval: 2000,
    queryFn: async () => {
      if (!client || !data?.current) return [];
      const blockNumber = await client.getBlockNumber();
      const contract = { address: payer.thresholdAddress, abi: thresholdAbi, blockNumber };
      const ids = Array.from(
        { length: Number(data.current > 6n ? 6n : data.current - 1n) },
        (_, i) => data.current - 1n - BigInt(i),
      );
      return Promise.all(
        ids.map(async id => {
          const [round, phase, claimable] = await Promise.all([
            client.readContract({ ...contract, functionName: "round", args: [id] }),
            client.readContract({ ...contract, functionName: "phase", args: [id] }),
            client.readContract({ ...contract, functionName: "claimable", args: [id, address ?? zeroAddress] }),
          ]);
          return { id, round, phase, claimable };
        }),
      );
    },
  });
  const proof = useSettleTxs(payer, "threshold", history.data);
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
        <a href={`/rounds?brand=${payer.ticker}&market=threshold`} className="round-brand">
          <Image src={payer.logo} width={32} height={32} alt="" />
          <span>
            {payer.name} <span className="round-muted">Rounds</span>
          </span>
        </a>
        <ConnectButton showBalance={false} chainStatus="icon" />
      </header>
      <div className="round-content">
        <a className="round-current" href={`/rounds?brand=${payer.ticker}`}>
          ← Up/down Rounds
        </a>
        <div className="round-kicker">Onchain · Threshold · {data?.id ? `Round #${data.id}` : "Campaign"}</div>
        {payer.thresholdAddress === zeroAddress ? (
          <div className="round-state">
            <h1>Threshold Campaign not configured</h1>
            <p>Set this payer’s ThresholdPots address to connect the Campaign.</p>
          </div>
        ) : snapshot.isPending ? (
          <div className="round-state" role="status">
            Loading Round from the contract…
          </div>
        ) : snapshot.isError ? (
          <div className="round-state" role="alert">
            <h1>Round unavailable</h1>
            <p>Check the Campaign network and Round number.</p>
            <button onClick={() => void snapshot.refetch()}>Retry</button>
            <button onClick={() => setSelected(null)}>Current Round</button>
          </div>
        ) : !detail ? (
          <div className="round-state">
            <h1>No Round is trading</h1>
            <p>Find a previous Round below to claim.</p>
          </div>
        ) : (
          <div className="round-grid">
            <section className="round-market">
              <div className="round-title">
                <Image src={payer.logo} width={48} height={48} alt="" />
                <h1>
                  Will ${payer.ticker} {detail.round.metric === 0 ? "price" : "market cap"} be above{" "}
                  {readingLabel(detail.round.threshold)} {payer.quoteTicker}?
                </h1>
              </div>
              <div className="round-chance">
                <strong>{readingLabel(detail.value)}</strong>
                <span>
                  Current {detail.round.metric === 0 ? "price" : "market cap"} · {payer.quoteTicker}
                </span>
              </div>
              <p className="round-muted">
                Live pool TWAP comparison. Settlement uses the pinned end Reading.
                {detail.value === undefined ? " Waiting for a valid Reading…" : ""}
              </p>
              <div className="round-phase">
                <span className={detail.phase === 0 ? "round-dot" : "round-dot inactive"} />
                <strong>{phaseNames[detail.phase]}</strong>
                <span className="round-countdown">
                  {detail.phase === 0
                    ? `${detail.round.cutoff > data.block.timestamp ? detail.round.cutoff - data.block.timestamp : 0n}s to stake`
                    : refunded
                      ? thresholdResults[detail.round.result] === "Awaiting result"
                        ? "Refund available"
                        : thresholdResults[detail.round.result]
                      : detail.phase === 3
                        ? thresholdResults[detail.round.result]
                        : "Staking has ended"}
                </span>
              </div>
              {refunded && (
                <div className="round-state" role="status">
                  <h2>
                    {detail.round.result === 3 ? "Tie" : detail.round.result === 4 ? "Unmatched" : "Refund"} · every
                    stake is refunded
                  </h2>
                  <p>
                    {detail.round.result === 4
                      ? "Only one side held a stake. No Reading was needed."
                      : detail.round.result === 3
                        ? "The end value equals the threshold."
                        : "A valid settlement was unavailable."}
                  </p>
                </div>
              )}
              <dl className="round-rules">
                <div>
                  <dt>Threshold</dt>
                  <dd>
                    {readingLabel(detail.round.threshold)} {payer.quoteTicker}
                  </dd>
                </div>
                <div>
                  <dt>End value</dt>
                  <dd>
                    {detail.round.endBlock && detail.round.result >= 1 && detail.round.result <= 3
                      ? `${readingLabel(detail.round.endValue)} ${payer.quoteTicker}`
                      : "Not pinned yet"}
                  </dd>
                </div>
                <div>
                  <dt>Pot</dt>
                  <dd>
                    {units(detail.round.pot)} {detail.symbol}
                  </dd>
                </div>
                <div>
                  <dt>Yes stakes</dt>
                  <dd>
                    {units(detail.round.yesTotal)} {detail.symbol}
                  </dd>
                </div>
                <div>
                  <dt>No stakes</dt>
                  <dd>
                    {units(detail.round.noTotal)} {detail.symbol}
                  </dd>
                </div>
              </dl>
              {selected !== null && (
                <button className="round-current" onClick={() => setSelected(null)}>
                  Return to current Round{data.current ? ` #${data.current}` : ""} →
                </button>
              )}
            </section>
            <aside className="round-panel" aria-label="Stake on threshold Round">
              <h2>Stake on this Round</h2>
              <div className="round-sides">
                {([0, 1] as const).map(value => (
                  <button
                    key={value}
                    className={value === 0 ? "up" : "down"}
                    aria-pressed={side === value}
                    disabled={pending}
                    onClick={() => setSide(value)}
                  >
                    {value === 0 ? "Yes" : "No"}
                  </button>
                ))}
              </div>
              <label className="round-input-label" htmlFor="threshold-stake">
                Stake amount ({detail.symbol})
              </label>
              <input
                id="threshold-stake"
                className="round-input"
                inputMode="decimal"
                autoComplete="off"
                value={input}
                disabled={pending}
                onChange={event => setInput(event.target.value)}
                aria-describedby="threshold-validation"
              />
              <dl className="round-summary">
                <div>
                  <dt>You stake</dt>
                  <dd>
                    {units(stake)} {detail.symbol}
                  </dd>
                </div>
                <div>
                  <dt>Stake cap</dt>
                  <dd>
                    {units(detail.round.stakeCap)} {detail.symbol}
                  </dd>
                </div>
                <div>
                  <dt>Earlier stakes</dt>
                  <dd>
                    {units(detail.position.paid)} {detail.symbol}
                  </dd>
                </div>
                <div className="round-to-win">
                  <dt>To win{detail.phase !== 0 ? " (held position)" : ""}</dt>
                  <dd>
                    {units(detail.phase === 0 ? quote.data : detail.claimable)} {detail.symbol}
                  </dd>
                </div>
              </dl>
              <p className="round-muted">
                Payout at the current split, including your existing {side === 0 ? "Yes" : "No"} stake. Your payout
                shrinks if others join your side. Gas is extra.
              </p>
              <p id="threshold-validation" className="round-validation" aria-live="polite">
                {invalid ||
                  (quote.isFetching ? "Updating payout…" : "No selling. A Tie or Unmatched Round refunds every stake.")}
              </p>
              {address ? (
                <button
                  className={`round-cta ${side === 1 ? "down" : ""}`}
                  disabled={!!invalid || quote.data === undefined || quote.isFetching || pending}
                  onClick={() => void transact("stake")}
                >
                  {pending ? "Waiting for confirmation…" : `Stake ${side === 0 ? "Yes" : "No"}`}
                </button>
              ) : (
                <ConnectButton.Custom>
                  {({ openConnectModal }) => (
                    <button className="round-cta" onClick={openConnectModal}>
                      Connect to stake
                    </button>
                  )}
                </ConnectButton.Custom>
              )}
              <div className="round-position">
                <h2>Your position · #{String(data.id)}</h2>
                {address ? (
                  <>
                    <p>
                      Yes{" "}
                      <strong>
                        {units(detail.position.yes)} {detail.symbol}
                      </strong>
                    </p>
                    <p>
                      No{" "}
                      <strong>
                        {units(detail.position.no)} {detail.symbol}
                      </strong>
                    </p>
                    {detail.phase < 3 && (
                      <>
                        <p>
                          To win if Yes{" "}
                          <strong>
                            {units(detail.yesWin)} {detail.symbol}
                          </strong>
                        </p>
                        <p>
                          To win if No{" "}
                          <strong>
                            {units(detail.noWin)} {detail.symbol}
                          </strong>
                        </p>
                      </>
                    )}
                    {detail.position.claimed ? (
                      <p>Claimed</p>
                    ) : detail.claimable > 0n ? (
                      <button className="round-claim" disabled={pending} onClick={() => void transact("claim")}>
                        Claim {refunded ? "refund " : ""}
                        {units(detail.claimable)} {detail.symbol}
                      </button>
                    ) : (
                      <p className="round-muted">
                        {detail.phase < 3 ? "Claimable after settlement." : "Nothing to claim."}
                      </p>
                    )}
                  </>
                ) : (
                  <p className="round-muted">Connect your wallet to see your stakes.</p>
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
        <ShareBar payer={payer} market="threshold" roundId={data?.id || undefined} />
        <PoolBalance payer={payer} market="threshold" />
        {!!data?.current && (
          <section className="round-history">
            <h2>Recent threshold Rounds</h2>
            {history.isError ? (
              <p>
                Could not load recent Rounds. <button onClick={() => void history.refetch()}>Retry</button>
              </p>
            ) : !history.data?.length ? (
              <p className="round-muted">
                {history.isPending ? "Loading recent Rounds…" : "The first Round is trading."}
              </p>
            ) : (
              <table>
                <thead>
                  <tr>
                    <th>Round</th>
                    <th>Result</th>
                    <th>Threshold</th>
                    <th>End Reading</th>
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
                            ? thresholdResults[row.round.result]
                            : phaseNames[row.phase]}
                      </td>
                      <td>
                        {readingLabel(row.round.threshold)} {payer.quoteTicker}
                      </td>
                      <td>
                        {row.round.endReading.price ? `${readingLabel(row.round.endValue)} ${payer.quoteTicker}` : "—"}
                      </td>
                      <td>
                        <SettleTx
                          payer={payer}
                          settled={row.phase === 3 || row.phase === 4}
                          hash={proof.data?.[String(row.id)]}
                        />
                      </td>
                      <td>
                        <button onClick={() => setSelected(row.id)}>
                          {row.claimable > 0n ? "View claim" : "View"}
                          <span className="sr-only"> Round {String(row.id)}</span>
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </section>
        )}
        <form className="round-find" onSubmit={findRound}>
          <label htmlFor="find-threshold-round">Find a previous Round</label>
          <input
            id="find-threshold-round"
            name="round"
            type="number"
            min="1"
            step="1"
            required
            placeholder="Round number"
          />
          <button type="submit">View Round</button>
        </form>
        <footer className="round-footer">
          Operated by {payer.name}. Threshold Rounds settle from pinned onchain Readings. Tie and Unmatched refund every
          stake. Claims never expire.
        </footer>
      </div>
    </div>
  );
}
