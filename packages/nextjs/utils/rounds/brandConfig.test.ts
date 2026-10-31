// Run with: node --test packages/nextjs/utils/rounds/brandConfig.test.ts (Node 24 strips the types).
// Relative import: node --test cannot resolve the `~~` tsconfig alias.
import { parseBrandBook, selectPayer } from "./brandConfig.ts";
import assert from "node:assert/strict";
import { test } from "node:test";

type RawBook = Exclude<Parameters<typeof parseBrandBook>[0], string>;
type RawEntry = RawBook[string];

const invalid = (entry: unknown): RawEntry => entry as RawEntry;

const degen: RawEntry = {
  name: "Degen",
  ticker: "DEGEN",
  logo: "/rounds/degen.svg",
  accent: "#6d28d9",
  up: "#167349",
  down: "#b6333b",
  address: "0x1111111111111111111111111111111111111111",
  thresholdAddress: "0x2222222222222222222222222222222222222222",
  chainId: 31337,
  quoteTicker: "ETH",
  explorerUrl: "",
  fromBlock: "0",
};

const pilot: RawEntry = {
  name: "Pilot",
  ticker: "PILOT",
  logo: "/rounds/pilot.svg",
  accent: "#112233",
  up: "#445566",
  down: "#778899",
  address: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  thresholdAddress: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  chainId: 8453,
  quoteTicker: "USDC",
  explorerUrl: "https://basescan.org",
  fromBlock: "18000000",
};

test("parseBrandBook returns a payer from a valid book", () => {
  const book = parseBrandBook({ DEGEN: degen });
  const payer = book.DEGEN;
  assert.equal(payer.name, "Degen");
  assert.equal(payer.ticker, "DEGEN");
  assert.equal(payer.logo, "/rounds/degen.svg");
  assert.equal(payer.accent, "#6d28d9");
  assert.equal(payer.up, "#167349");
  assert.equal(payer.down, "#b6333b");
  assert.equal(payer.address, "0x1111111111111111111111111111111111111111");
  assert.equal(payer.thresholdAddress, "0x2222222222222222222222222222222222222222");
  assert.equal(payer.chainId, 31337);
  assert.equal(payer.quoteTicker, "ETH");
  assert.equal(payer.explorerUrl, "");
  assert.equal(payer.fromBlock, 0n);
});

test("parseBrandBook refuses a payer missing a required field", () => {
  const { name, ...missingName } = degen;
  assert.equal(name, "Degen");
  assert.throws(() => parseBrandBook({ DEGEN: invalid(missingName) }), /name/);
});

test("parseBrandBook refuses a bad address", () => {
  assert.throws(() => parseBrandBook({ DEGEN: invalid({ ...degen, address: "0x123" }) }), /address/);
  assert.throws(
    () => parseBrandBook({ DEGEN: invalid({ ...degen, thresholdAddress: "not-an-address" }) }),
    /thresholdAddress/,
  );
});

test("parseBrandBook refuses a bad chain id", () => {
  assert.throws(() => parseBrandBook({ DEGEN: invalid({ ...degen, chainId: "31337" }) }), /chain/);
  assert.throws(() => parseBrandBook({ DEGEN: invalid({ ...degen, chainId: 1.5 }) }), /chain/);
  assert.throws(() => parseBrandBook({ DEGEN: invalid({ ...degen, chainId: -1 }) }), /chain/);
});

test("parseBrandBook refuses a bad color", () => {
  assert.throws(() => parseBrandBook({ DEGEN: invalid({ ...degen, accent: "purple" }) }), /accent/);
  assert.throws(() => parseBrandBook({ DEGEN: invalid({ ...degen, up: "#fff" }) }), /up/);
  assert.throws(() => parseBrandBook({ DEGEN: invalid({ ...degen, down: "#b6333bff" }) }), /down/);
});

test("fromBlock is a decimal string", () => {
  const payer = { ...degen, fromBlock: "9007199254740993" };
  assert.equal(parseBrandBook({ DEGEN: payer }).DEGEN.fromBlock, 9007199254740993n);
  assert.throws(() => parseBrandBook({ DEGEN: invalid({ ...payer, fromBlock: 12 }) }), /fromBlock/);
  assert.throws(() => parseBrandBook({ DEGEN: invalid({ ...payer, fromBlock: "12.5" }) }), /fromBlock/);
  assert.throws(() => parseBrandBook({ DEGEN: invalid({ ...payer, fromBlock: "0x10" }) }), /fromBlock/);
});

test("a second brand entry changes name, ticker, colors, addresses, and chain", () => {
  const book = parseBrandBook(JSON.stringify({ DEGEN: degen, PILOT: pilot }));
  assert.equal(book.PILOT.name, "Pilot");
  assert.equal(book.PILOT.ticker, "PILOT");
  assert.equal(book.PILOT.accent, "#112233");
  assert.equal(book.PILOT.up, "#445566");
  assert.equal(book.PILOT.down, "#778899");
  assert.equal(book.PILOT.address, "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
  assert.equal(book.PILOT.thresholdAddress, "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb");
  assert.equal(book.PILOT.chainId, 8453);
  assert.equal(book.DEGEN.name, "Degen");
  assert.equal(book.DEGEN.address, "0x1111111111111111111111111111111111111111");
  assert.equal(book.DEGEN.chainId, 31337);
});

test("selectPayer uses DEGEN when the key is unknown", () => {
  const book = parseBrandBook({ DEGEN: degen, PILOT: pilot });
  assert.equal(selectPayer(book, null).ticker, "DEGEN");
  assert.equal(selectPayer(book, "nope").address, "0x1111111111111111111111111111111111111111");
  assert.equal(selectPayer(book, "pilot").ticker, "PILOT");
  assert.equal(selectPayer(book, "pilot").chainId, 8453);
});

test("a URL-like string is not a source of addresses", () => {
  const book = parseBrandBook({ DEGEN: degen, PILOT: pilot });
  const injected = "0x3333333333333333333333333333333333333333";
  const payer = selectPayer(book, `https://payer.example/rounds?brand=PILOT&address=${injected}`);
  assert.equal(payer.ticker, "DEGEN");
  assert.equal(payer.address, "0x1111111111111111111111111111111111111111");
  assert.equal(payer.thresholdAddress, "0x2222222222222222222222222222222222222222");
  assert.notEqual(payer.address, injected);
  assert.notEqual(payer.thresholdAddress, injected);
});
