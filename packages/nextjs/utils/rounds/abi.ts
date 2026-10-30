import { parseAbi } from "viem";

// Narrow public interface; kept separate from the challenge's generated deployedContracts.ts.
export const roundsAbi = parseAbi([
  "struct Reading { uint256 blockNumber; uint256 timestamp; uint256 price; }",
  "struct Round { address reader; address payer; uint256 cutoff; uint256 windowEnd; uint256 stakeCap; uint256 seededLiquidity; uint256 sharesPerSide; uint256 upSold; uint256 downSold; uint256 startBlock; uint256 endBlock; uint256 collateral; uint256 upLiability; uint256 downLiability; uint256 refundLiability; uint8 result; Reading startReading; Reading endReading; }",
  "struct Position { uint256 up; uint256 down; uint256 paid; bool claimed; uint256 bought; uint256 proceeds; }",
  "function currentRound() view returns (uint256)",
  "function round(uint256 roundId) view returns (Round)",
  "function phase(uint256 roundId) view returns (uint8)",
  "function chanceCents(uint256 roundId) view returns (uint256)",
  "function positionOf(uint256 roundId, address player) view returns (Position)",
  "function claimable(uint256 roundId, address player) view returns (uint256)",
  "function quote(uint256 roundId, uint8 side, uint256 shares) view returns (uint256)",
  "function quoteSell(uint256 roundId, uint8 side, uint256 shares) view returns (uint256)",
  "function payoutFor(uint256 shares) view returns (uint256)",
  "function fundingBalance() view returns (uint256)",
  "function i_stakeToken() view returns (address)",
  "function buy(uint256 roundId, uint8 side, uint256 shares, uint256 maxCost) payable",
  "function sell(uint256 roundId, uint8 side, uint256 shares, uint256 minProceeds)",
  "function claim(uint256 roundId) returns (uint256)",
  "error StakeCapExceeded()",
  "error OutsideTrading()",
  "error InsufficientShares()",
  "error InsufficientReserve()",
  "error InsufficientFunding()",
  "error PayerCannotBuy()",
  "error SlippageExceeded()",
  "error NotSettled()",
]);
export const readerAbi = parseAbi([
  "function preview() view returns ((uint256 blockNumber, uint256 timestamp, uint256 price))",
  "function read(uint256 endBlock) view returns ((uint256 blockNumber, uint256 timestamp, uint256 price))",
]);
