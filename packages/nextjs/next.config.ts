import type { NextConfig } from "next";

const isExport =
  process.env.NEXT_PUBLIC_IPFS_BUILD === "true" ||
  process.env.NEXT_PUBLIC_HANDOVER_BUILD === "true";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  devIndicators: false,
  typescript: {
    ignoreBuildErrors: true,
  },
};

if (!isExport) {
  // The Round page is built to be embedded. Payers can restrict hosts with ROUNDS_FRAME_ANCESTORS.
  nextConfig.headers = async function headers() {
    const ancestors = process.env.ROUNDS_FRAME_ANCESTORS || "*";
    return [
      {
        source: "/rounds",
        headers: [{ key: "Content-Security-Policy", value: `frame-ancestors ${ancestors}` }],
      },
    ];
  };
}

if (isExport) {
  nextConfig.output = "export";
  nextConfig.trailingSlash = true;
  nextConfig.images = {
    unoptimized: true,
  };
}

module.exports = nextConfig;
