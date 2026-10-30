import { createInterface } from "node:readline";
import { ethers } from "ethers";

// The pure parts of the payer deploy driver: argument rules, the pre-funding gate and gas pricing.
// Nothing here touches the network or a key.

const REFUSED_FLAGS = ["--private-key", "--private-keys", "--mnemonic", "--mnemonics", "--interactive", "-i"];
const VALUE_FLAGS = ["--config", "--network", "--account", "--local-sender"];
const BOOLEAN_FLAGS = ["--ledger", "--skip-confirmation", "--help", "-h"];

/**
 * Signing is by encrypted keystore (--account), hardware wallet (--ledger) or, on a local chain only,
 * an unlocked node account (--local-sender). A raw private key is refused outright.
 */
export function parsePayerDeployArgs(argv) {
  const values = {};
  const flags = new Set();
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (REFUSED_FLAGS.includes(arg)) {
      throw new Error(
        `payerDeploy never accepts ${arg}. Sign with --account <keystore name> or --ledger so no key appears in a command, a file or shell history.`
      );
    }
    if (VALUE_FLAGS.includes(arg)) {
      const value = argv[++i];
      if (value === undefined || value.startsWith("--")) throw new Error(`${arg} needs a value`);
      values[arg] = value;
    } else if (BOOLEAN_FLAGS.includes(arg)) {
      flags.add(arg);
    } else {
      throw new Error(`Unknown argument ${arg}`);
    }
  }

  const help = flags.has("--help") || flags.has("-h");
  if (!help) {
    if (!values["--config"]) throw new Error("--config <path to the Campaign settings JSON> is required");
    if (!values["--network"]) throw new Error("--network <foundry.toml rpc alias or URL> is required");
  }
  const modes = [values["--account"] !== undefined, flags.has("--ledger"), values["--local-sender"] !== undefined];
  if (!help && modes.filter(Boolean).length !== 1) {
    throw new Error("Choose exactly one signer: --account <name>, --ledger or --local-sender <address> (local chain only)");
  }

  let signer = null;
  if (values["--account"] !== undefined) signer = { kind: "account", name: values["--account"] };
  else if (flags.has("--ledger")) signer = { kind: "ledger" };
  else if (values["--local-sender"] !== undefined) signer = { kind: "local", address: values["--local-sender"] };

  return {
    help,
    config: values["--config"],
    network: values["--network"],
    signer,
    skipConfirmation: flags.has("--skip-confirmation"),
  };
}

/** Host and port only: a path or query can carry an API key. */
export function rpcHost(rpcUrl) {
  try {
    return new URL(rpcUrl).host;
  } catch {
    return "(unparseable RPC URL)";
  }
}

/** The human gate may be skipped for a throwaway local chain and nowhere else. */
export function canSkipConfirmation({ chainId, rpcUrl }) {
  if (Number(chainId) !== 31337) return false;
  try {
    return ["127.0.0.1", "localhost", "[::1]"].includes(new URL(rpcUrl).hostname);
  } catch {
    return false;
  }
}

export function checksum(address) {
  return ethers.utils.getAddress(address);
}

/**
 * All amounts are BigInt wei. `ethUsdCents` is the ETH price in US cents (4000.00 USD = 400000n), or omitted
 * when there is no live price (testnets, local chains).
 */
export function priceGas({ gasUsed, gasPriceWei, l1FeeWei = 0n, operatorFeeWei = 0n, ethUsdCents = null }) {
  const executionWei = gasUsed * gasPriceWei;
  const totalWei = executionWei + l1FeeWei + operatorFeeWei;
  const usd =
    ethUsdCents === null
      ? null
      : ethers.utils.formatUnits(ethers.BigNumber.from((totalWei * ethUsdCents).toString()), 20);
  return {
    executionWei,
    l1FeeWei,
    operatorFeeWei,
    totalWei,
    totalEth: ethers.utils.formatUnits(totalWei.toString(), 18),
    usd,
  };
}

/** Resolves true only if the human types exactly `yes`. End of input, a blank line or anything else is no. */
export function askHuman(question, { input = process.stdin, output = process.stdout } = {}) {
  return new Promise((resolve) => {
    const rl = createInterface({ input, output, terminal: false });
    let answered = false;
    output.write(`${question} Type "yes" to continue: `);
    rl.once("line", (line) => {
      answered = true;
      rl.close();
      resolve(line.trim() === "yes");
    });
    rl.once("close", () => {
      if (!answered) resolve(false);
    });
  });
}
