import type { NextConfig } from "next"

const nextConfig: NextConfig = {
  // There's one red panda now, so the old pack maker sends visitors home.
  async redirects() {
    return [{ source: "/make", destination: "/", permanent: true }]
  },
}

export default nextConfig
