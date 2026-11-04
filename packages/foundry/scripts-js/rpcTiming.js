// Read-only provider diagnostics. Never imports a wallet or accesses a key.
const url = process.env.SETTLE_RPC_URL;
let validUrl = false;
try {
  validUrl = ["http:", "https:"].includes(new URL(url).protocol);
} catch {}
if (!validUrl) {
  console.error("Invalid SETTLE_RPC_URL");
  process.exit(1);
}
const samples = [];
try {
  for (let i = 0; i < 12; i++) {
    const started = Date.now();
    const response = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: i + 1,
        method: "eth_getBlockByNumber",
        params: ["latest", false],
      }),
      signal: AbortSignal.timeout(10000),
    });
    if (!response.ok) throw new Error("Unavailable");
    const body = await response.json();
    if (body.error || !body.result) throw new Error("Unavailable");
    const block = body.result;
    const ms = block.timestampMs == null ? null : Number(block.timestampMs);
    const row = {
      event: "rpc_sample",
      rpcMs: Date.now() - started,
      block: Number(block.number),
      timestamp: Number(block.timestamp),
      timestampMs: ms,
      approximateHeadAgeMs: ms == null ? null : Date.now() - ms,
    };
    samples.push(row);
    console.log(JSON.stringify(row));
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  const quantile = (values, p) =>
    values.sort((a, b) => a - b)[Math.ceil(values.length * p) - 1];
  console.log(
    JSON.stringify({
      event: "rpc_summary",
      samples: samples.length,
      rpcP50Ms: quantile(
        samples.map((r) => r.rpcMs),
        0.5
      ),
      rpcP95Ms: quantile(
        samples.map((r) => r.rpcMs),
        0.95
      ),
      nativeTimestampMs: samples.every((r) => r.timestampMs != null),
      headAdvanced: samples.at(-1).block > samples[0].block,
      note: "Read-only measurement; head age includes local clock skew and is not an inclusion guarantee",
    })
  );
} catch {
  console.error(
    "RPC timing check failed; check provider access and availability. No transactions were sent."
  );
  process.exitCode = 1;
}
