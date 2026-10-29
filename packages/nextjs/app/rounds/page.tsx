import { Suspense } from "react";
import "./rounds.css";
import { RoundPage } from "~~/components/rounds/RoundPage";

export const metadata = {
  title: "Token Rounds",
  description: "Back-to-back Rounds settled from onchain pool Readings.",
};
export default function Rounds() {
  return (
    <Suspense fallback={<div className="round-loading">Loading Campaign…</div>}>
      <RoundPage />
    </Suspense>
  );
}
