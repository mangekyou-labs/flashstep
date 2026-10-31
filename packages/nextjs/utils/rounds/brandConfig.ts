export type Payer = {
  name: string;
  ticker: string;
  logo: string;
  accent: string;
  up: string;
  down: string;
  address: `0x${string}`;
  thresholdAddress: `0x${string}`;
  chainId: number;
  quoteTicker: string;
  explorerUrl: string;
  campaignCost?: string;
  fromBlock: bigint;
};

export type BrandBook = Record<string, Payer>;

type RawPayer = Omit<Payer, "fromBlock" | "address" | "thresholdAddress"> & {
  address: `0x${string}`;
  thresholdAddress: `0x${string}`;
  fromBlock: string;
};

const requiredText = ["name", "ticker", "logo", "quoteTicker"] as const;
const colorFields = ["accent", "up", "down"] as const;
const ADDRESS = /^0x[0-9a-fA-F]{40}$/;
const COLOR = /^#[0-9a-fA-F]{6}$/;

function requiredString(entry: Record<string, unknown>, key: string, field: string, allowEmpty = false): string {
  const value = entry[field];
  if (typeof value !== "string" || (!allowEmpty && value.trim() === "")) {
    throw new Error(`${key}: missing ${field}`);
  }
  return value;
}

function fromBlockField(entry: Record<string, unknown>, key: string): bigint {
  const value = entry.fromBlock;
  if (typeof value !== "string" || !/^[0-9]+$/.test(value)) {
    throw new Error(`${key}: bad fromBlock`);
  }
  return BigInt(value);
}

function colorField(entry: Record<string, unknown>, key: string, field: string): string {
  const value = requiredString(entry, key, field);
  if (!COLOR.test(value)) throw new Error(`${key}: bad ${field}`);
  return value;
}

function chainIdField(entry: Record<string, unknown>, key: string): number {
  const value = entry.chainId;
  if (typeof value !== "number" || !Number.isInteger(value) || value <= 0 || value > Number.MAX_SAFE_INTEGER) {
    throw new Error(`${key}: bad chain id`);
  }
  return value;
}

function addressField(entry: Record<string, unknown>, key: string, field: string): `0x${string}` {
  const value = requiredString(entry, key, field);
  if (!ADDRESS.test(value)) throw new Error(`${key}: bad ${field}`);
  return value as `0x${string}`;
}

/** A brand book is runtime JSON. `fromBlock` stays a decimal string until parse. */
export function parseBrandBook(input: string | Record<string, RawPayer>): BrandBook {
  const raw = (typeof input === "string" ? JSON.parse(input) : input) as Record<string, Record<string, unknown>>;
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) {
    throw new Error("brand book must be an object");
  }
  const book: BrandBook = {};
  for (const [key, entry] of Object.entries(raw)) {
    if (entry === null || typeof entry !== "object" || Array.isArray(entry)) {
      throw new Error(`${key}: missing name`);
    }
    const text: Record<string, string> = {};
    for (const field of requiredText) text[field] = requiredString(entry, key, field);
    const colors: Record<string, string> = {};
    for (const field of colorFields) colors[field] = colorField(entry, key, field);
    book[key] = {
      name: text.name,
      ticker: text.ticker,
      logo: text.logo,
      accent: colors.accent,
      up: colors.up,
      down: colors.down,
      address: addressField(entry, key, "address"),
      thresholdAddress: addressField(entry, key, "thresholdAddress"),
      chainId: chainIdField(entry, key),
      quoteTicker: text.quoteTicker,
      explorerUrl: requiredString(entry, key, "explorerUrl", true),
      fromBlock: fromBlockField(entry, key),
      ...(entry.campaignCost !== undefined ? { campaignCost: String(entry.campaignCost) } : {}),
    };
  }
  return book;
}

/** Unknown keys, including a URL or query string, use DEGEN. The key is never parsed for an address. */
export function selectPayer(book: BrandBook, key: string | null | undefined): Payer {
  const chosen = typeof key === "string" ? book[key.toUpperCase()] : undefined;
  if (chosen) return chosen;
  const fallback = book.DEGEN;
  if (!fallback) throw new Error("missing DEGEN");
  return fallback;
}
