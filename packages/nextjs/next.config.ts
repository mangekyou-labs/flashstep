import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  devIndicators: false,
  // The Round page is built to be embedded. Payers can restrict hosts with ROUNDS_FRAME_ANCESTORS.
  async headers() {
    const ancestors = process.env.ROUNDS_FRAME_ANCESTORS || "*";
    return [
      {
        source: "/rounds",
        headers: [{ key: "Content-Security-Policy", value: `frame-ancestors ${ancestors}` }],
      },
    ];
  },
  typescript: {
    ignoreBuildErrors: true,
  },
};

const isIpfs = process.env.NEXT_PUBLIC_IPFS_BUILD === "true";

if (isIpfs) {
  nextConfig.output = "export";
  nextConfig.trailingSlash = true;
  nextConfig.images = {
    unoptimized: true,
  };
}

module.exports = nextConfig;
