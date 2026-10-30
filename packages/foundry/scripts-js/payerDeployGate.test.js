import assert from "node:assert/strict";
import { test } from "node:test";
import { Readable } from "node:stream";
import {
  askHuman,
  canSkipConfirmation,
  checksum,
  isLoopback,
  parsePayerDeployArgs,
  priceGas,
  rpcHost,
} from "./payerDeployGate.js";

// Seam: the pure parts of the payer deploy driver. Everything else is covered by the local end-to-end run.

test("signing is by keystore account, ledger, or a local unlocked sender, one at a time", () => {
  assert.deepEqual(parsePayerDeployArgs(["--config", "c.json", "--network", "base", "--account", "payer"]).signer, {
    kind: "account",
    name: "payer",
  });
  assert.deepEqual(parsePayerDeployArgs(["--config", "c.json", "--network", "base", "--ledger"]).signer, {
    kind: "ledger",
  });
  assert.deepEqual(
    parsePayerDeployArgs([
      "--config",
      "c.json",
      "--network",
      "localhost",
      "--local-sender",
      "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    ]).signer,
    { kind: "local", address: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" },
  );
  assert.throws(
    () => parsePayerDeployArgs(["--config", "c.json", "--network", "base", "--account", "a", "--ledger"]),
    /exactly one/,
  );
  assert.throws(() => parsePayerDeployArgs(["--config", "c.json", "--network", "base"]), /exactly one/);
});

test("a raw private key is never accepted on the command line", () => {
  for (const flag of ["--private-key", "--private-keys", "--mnemonic", "--interactive"]) {
    assert.throws(
      () => parsePayerDeployArgs(["--config", "c.json", "--network", "base", "--account", "a", flag, "x"]),
      /never accepts/,
      flag,
    );
  }
});

test("the config and the network are required", () => {
  assert.throws(() => parsePayerDeployArgs(["--network", "base", "--account", "a"]), /--config/);
  assert.throws(() => parsePayerDeployArgs(["--config", "c.json", "--account", "a"]), /--network/);
});

test("the confirmation gate can be skipped only for a loopback RPC on chain 31337", () => {
  assert.equal(canSkipConfirmation({ chainId: 31337, rpcUrl: "http://127.0.0.1:8545" }), true);
  assert.equal(canSkipConfirmation({ chainId: 31337, rpcUrl: "http://localhost:8545" }), true);
  assert.equal(canSkipConfirmation({ chainId: 31337, rpcUrl: "http://[::1]:8545" }), true);
  assert.equal(canSkipConfirmation({ chainId: 8453, rpcUrl: "http://127.0.0.1:8545" }), false);
  assert.equal(canSkipConfirmation({ chainId: 31337, rpcUrl: "https://mainnet.base.org" }), false);
  // A look-alike host does not count as loopback.
  assert.equal(canSkipConfirmation({ chainId: 31337, rpcUrl: "https://127.0.0.1.evil.example" }), false);
  assert.equal(canSkipConfirmation({ chainId: 31337, rpcUrl: "https://localhost.evil.example" }), false);
  assert.equal(canSkipConfirmation({ chainId: 31337, rpcUrl: "not a url" }), false);
});

test("only a literal loopback host is loopback, for both the network resolver and the skip rule", () => {
  assert.equal(isLoopback("http://127.0.0.1:8545"), true);
  assert.equal(isLoopback("http://localhost:8545"), true);
  assert.equal(isLoopback("http://[::1]:8545"), true);
  assert.equal(isLoopback("https://127.0.0.1.evil.example"), false);
  assert.equal(isLoopback("https://mainnet.base.org"), false);
  assert.equal(isLoopback("not a url"), false);
});

test("only the host of an RPC URL is ever shown, because the path can carry an API key", () => {
  assert.equal(rpcHost("https://base-mainnet.g.alchemy.com/v2/SECRETKEY"), "base-mainnet.g.alchemy.com");
  assert.equal(rpcHost("https://user:pass@node.example:8545/path?key=SECRET"), "node.example:8545");
  assert.equal(rpcHost("not a url"), "(unparseable RPC URL)");
});

test("addresses are shown checksummed", () => {
  assert.equal(checksum("0x33128a8fc17869897dce68ed026d694621f6fdfd"), "0x33128a8fC17869897dcE68Ed026d694621f6FDfD");
  assert.throws(() => checksum("0x1234"));
});

test("gas cost is execution plus the L1 data fee plus the operator fee, priced in USD", () => {
  // 1,000,000 gas at 0.01 gwei = 1e13 wei; L1 fee 3e12; operator fee 1e12; total 1.4e13 wei = 0.000014 ETH.
  const cost = priceGas({
    gasUsed: 1_000_000n,
    gasPriceWei: 10_000_000n,
    l1FeeWei: 3_000_000_000_000n,
    operatorFeeWei: 1_000_000_000_000n,
    ethUsdCents: 400_000n, // 4000.00 USD per ETH
  });
  assert.equal(cost.totalWei, 14_000_000_000_000n);
  assert.equal(cost.executionWei, 10_000_000_000_000n);
  assert.equal(cost.totalEth, "0.000014");
  assert.equal(cost.usd, "0.056");
});

test("without an ETH price there is no USD figure, and a missing L1 fee counts as zero", () => {
  const cost = priceGas({ gasUsed: 21_000n, gasPriceWei: 1_000_000_000n });
  assert.equal(cost.totalWei, 21_000_000_000_000n);
  assert.equal(cost.usd, null);
});

test("only a typed yes opens the gate", async () => {
  const typed = text => Readable.from([text]);
  const out = { write() {} };
  assert.equal(await askHuman("Proceed?", { input: typed("yes\n"), output: out }), true);
  assert.equal(await askHuman("Proceed?", { input: typed("y\n"), output: out }), false);
  assert.equal(await askHuman("Proceed?", { input: typed("YES please\n"), output: out }), false);
  assert.equal(await askHuman("Proceed?", { input: typed("\n"), output: out }), false);
  assert.equal(await askHuman("Proceed?", { input: typed(""), output: out }), false);
});
