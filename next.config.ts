import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Vinext emits a self-contained Node runtime for the Docker image instead
  // of requiring the complete build-time dependency tree in production.
  output: "standalone",
};

export default nextConfig;
