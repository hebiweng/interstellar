import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Vinext emits a self-contained Node runtime for the Docker image instead
  // of requiring the complete build-time dependency tree in production.
  output: "standalone",
  // 生产构建禁用 source map，减小部署包体积。
  productionBrowserSourceMaps: false,
  serverSourceMaps: false,
};

export default nextConfig;
