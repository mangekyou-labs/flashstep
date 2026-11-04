import assert from "node:assert/strict";
import { createServer } from "node:http";
import { spawn } from "node:child_process";
import test from "node:test";
import { ethers } from "ethers";

for (const mode of [
  "duplicate ids",
  "missing member",
  "foreign id",
  "object envelope",
])
  test(`CLI rejects ${mode} before any transaction submission`, async () => {
    let sends = 0;
    let batches = 0;
    const server = createServer(async (req, res) => {
      let data = "";
      for await (const chunk of req) data += chunk;
      const calls = JSON.parse(data);
      assert.ok(Array.isArray(calls));
      batches++;
      sends += calls.filter(
        (call) => call.method === "eth_sendRawTransaction"
      ).length;
      const replies = calls.map((call) => ({
        jsonrpc: "2.0",
        id: call.id,
        result: "0x1",
      }));
      if (mode === "duplicate ids") replies[1].id = replies[0].id;
      if (mode === "missing member") replies.pop();
      if (mode === "foreign id") replies[0].id = 999999;
      res.setHeader("content-type", "application/json");
      res.end(
        JSON.stringify(mode === "object envelope" ? replies[0] : replies)
      );
    });
    await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
    try {
      const child = spawn(
        process.execPath,
        [new URL("settleBot.js", import.meta.url).pathname],
        {
          env: {
            ...process.env,
            SETTLE_RPC_URL: `http://127.0.0.1:${server.address().port}`,
            SETTLE_PRIVATE_KEY: ethers.Wallet.fromMnemonic(
              "test test test test test test test test test test test junk"
            ).privateKey,
            SETTLE_UPDOWN_ADDRESS: "0x0000000000000000000000000000000000000001",
            SETTLE_THRESHOLD_ADDRESS:
              "0x0000000000000000000000000000000000000002",
          },
          stdio: ["ignore", "pipe", "pipe"],
        }
      );
      let output = "";
      child.stdout.on("data", (chunk) => (output += chunk));
      child.stderr.on("data", (chunk) => (output += chunk));
      const timeout = setTimeout(() => child.kill("SIGKILL"), 10000);
      const code = await new Promise((resolve) => child.once("exit", resolve));
      clearTimeout(timeout);
      assert.equal(code, 1, output);
      assert.match(output, /Settle bot could not start/);
      assert.equal(batches, 1);
      assert.equal(sends, 0);
    } finally {
      await new Promise((resolve) => server.close(resolve));
    }
  });
