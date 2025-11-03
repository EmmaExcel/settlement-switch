import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  images: {
    domains: ['assets.coingecko.com'], // Fixed: remove https:// protocol
  },
};

export default nextConfig;
