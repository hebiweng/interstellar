import type { NextConfig } from "next";

// serverSourceMaps exists in newer Next.js but is not yet in the shipped type definition.
const nextConfig = {
  // Vinext emits a self-contained Node runtime for the Docker image instead
  // of requiring the complete build-time dependency tree in production.
  output: "standalone" as const,
  // 生产构建禁用 source map，减小部署包体积。
  productionBrowserSourceMaps: false,
  serverSourceMaps: false,
} as NextConfig;

export default nextConfig;
