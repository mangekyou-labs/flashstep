import { parseAbi } from "viem";

export const thresholdAbi = parseAbi([
  "struct Reading { uint256 blockNumber; uint256 timestamp; uint256 price; }",
  "struct Round { address reader; address marketCapReader; uint8 metric; uint256 threshold; uint256 cutoff; uint256 windowEnd; uint256 stakeCap; uint256 openingStake; address payer; uint256 yesTotal; uint256 noTotal; uint256 pot; uint256 collateral; uint256 endBlock; uint256 remainingWinningStake; uint256 dustReleased; uint8 result; Reading endReading; uint256 totalSupply; uint256 endValue; bool materialized; }",
  "struct Position { uint256 yes; uint256 no; uint256 paid; bool claimed; }",
  "function currentRound() view returns (uint256)",
  "function round(uint256 roundId) view returns (Round)",
  "function phase(uint256 roundId) view returns (uint8)",
  "function positionOf(uint256 roundId, address player) view returns (Position)",
  "function claimable(uint256 roundId, address player) view returns (uint256)",
  "function quoteStake(uint256 roundId, address player, uint8 side, uint256 amount) view returns (uint256)",
  "function currentValue(uint256 roundId) view returns (uint256)",
  "function i_stakeToken() view returns (address)",
  "function fundingBalance() view returns (uint256)",
  "function reservedBalance() view returns (uint256)",
  "event Settled(uint256 indexed roundId, uint8 result, uint256 endValue, uint256 threshold)",
  "event Refunded(uint256 indexed roundId)",
  "function stake(uint256 roundId, uint8 side, uint256 amount) payable",
  "function claim(uint256 roundId) returns (uint256)",
  "error StakeCapExceeded()",
  "error OutsideTrading()",
  "error InsufficientFunding()",
  "error InvalidAmount()",
  "error IncorrectPayment()",
  "error NotSettled()",
]);
export const thresholdResults = ["Awaiting result", "Yes", "No", "Tie · refund", "Unmatched · refund", "Refunded"];
