"use client";

import { type ReactNode } from "react";
import { useSearchParams } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { type Payer, parseBrandBook, selectPayer } from "~~/utils/rounds/brandConfig";

export function BrandGate({ children }: { children: (payer: Payer) => ReactNode }) {
  const brand = useSearchParams().get("brand");
  const book = useQuery({
    queryKey: ["brand-book"],
    staleTime: 0,
    enabled: typeof window !== "undefined",
    queryFn: async () => {
      const response = await fetch("/brand.json", { cache: "no-store" });
      if (!response.ok) throw new Error("brand book missing");
      return parseBrandBook(await response.json());
    },
  });

  if (book.isPending) {
    return (
      <div className="round-state" role="status">
        Loading Campaign…
      </div>
    );
  }
  if (book.isError) {
    const message = book.error instanceof Error ? book.error.message : "brand book missing";
    return (
      <div className="round-state" role="alert">
        {message}
      </div>
    );
  }

  let payer: Payer;
  try {
    payer = selectPayer(book.data, brand);
  } catch (error) {
    const message = error instanceof Error ? error.message : "missing DEGEN";
    return (
      <div className="round-state" role="alert">
        {message}
      </div>
    );
  }

  return children(payer);
}
