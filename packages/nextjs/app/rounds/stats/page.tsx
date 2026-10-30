import { Suspense } from "react";
import "../rounds.css";
import { CampaignStatsPage } from "~~/components/rounds/CampaignStatsPage";

export const metadata = {
  title: "Campaign stats",
  description: "Per-Round volume, players and payer profit or loss for a Rounds Campaign.",
};
export default function CampaignStats() {
  return (
    <Suspense fallback={<div className="round-loading">Loading Campaign…</div>}>
      <CampaignStatsPage />
    </Suspense>
  );
}
