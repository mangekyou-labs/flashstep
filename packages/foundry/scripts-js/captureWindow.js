// A sealed native block at B-0.200 can only be followed by blocks whose EVM
// timestamp is at least B. At B+0.800, no next block can still have timestamp B.
export function captureState(head, boundary, blockTimeMs) {
  const now = Number(head.timestamp);
  if (blockTimeMs === 2000)
    return now + 2 < boundary
      ? "early"
      : now + 2 === boundary
      ? "ready"
      : "expired";
  if (head.timestampMs != null) {
    const ms = Number(head.timestampMs);
    if (
      !Number.isSafeInteger(ms) ||
      ms % 200 !== 0 ||
      Math.floor(ms / 1000) !== now
    )
      return "invalid";
    return ms < boundary * 1000 - 200
      ? "early"
      : ms < boundary * 1000 + 800
      ? "ready"
      : "expired";
  }
  // Some compatible RPCs omit optional metadata. This cannot distinguish the
  // five native slots and provides less inclusion margin; expose that in logs.
  return now < boundary ? "early" : now === boundary ? "ready" : "expired";
}
