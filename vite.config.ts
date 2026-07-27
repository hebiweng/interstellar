import vinext from "vinext";
import { defineConfig } from "vite";
import hostingConfig from "./.openai/hosting.json";
import { sites } from "./build/sites-vite-plugin";

const SITE_CREATOR_PLACEHOLDER_DATABASE_ID =
  "00000000-0000-4000-8000-000000000000";

const { d1, r2 } = hostingConfig;

// macOS Seatbelt blocks FSEvents, so Codex previews need polling for HMR.
const isCodexSeatbeltSandbox = process.env.CODEX_SANDBOX === "seatbelt";
const apiProxyTarget = process.env.INTERSTELLAR_API_PROXY_TARGET?.trim();

const localBindingConfig = {
  main: "./worker/index.ts",
  compatibility_flags: ["nodejs_compat"],
  d1_databases: d1
    ? [
        {
          binding: d1,
          database_name: "site-creator-d1",
          database_id: SITE_CREATOR_PLACEHOLDER_DATABASE_ID,
        },
      ]
    : [],
  r2_buckets: r2
    ? [
        {
          binding: r2,
          bucket_name: "site-creator-r2",
        },
      ]
    : [],
};

export default defineConfig(async () => {
  // Keep Wrangler and Miniflare state project-local. These are non-secret tool
  // settings; application environment belongs in ignored `.env*` files.
  process.env.WRANGLER_WRITE_LOGS ??= "false";
  process.env.WRANGLER_LOG_PATH ??= ".wrangler/logs";
  process.env.MINIFLARE_REGISTRY_PATH ??= ".wrangler/registry";

  // Wrangler snapshots its log path while the Cloudflare plugin is imported.
  const { cloudflare } = await import("@cloudflare/vite-plugin");

  return {
    server:
      isCodexSeatbeltSandbox || apiProxyTarget
        ? {
            ...(isCodexSeatbeltSandbox
              ? { watch: { useFsEvents: false, usePolling: true } }
              : {}),
            ...(apiProxyTarget
              ? {
                  proxy: {
                    "/api/v1": {
                      target: apiProxyTarget,
                      changeOrigin: true,
                    },
                  },
                }
              : {}),
          }
        : undefined,
    // 生产构建禁用 source map，减小部署包体积。
    build: {
      sourcemap: false,
      rollupOptions: {
        // 排除 @vercel/og 死重依赖（vinext 传递依赖，项目未使用 OG 功能）
        external: [
          "@vercel/og",
          "satori",
          "@resvg/resvg-wasm",
          "yoga-layout",
          "@shuding/opentype.js",
        ],
      },
    },
    optimizeDeps: {
      exclude: [
        "@vercel/og",
        "satori",
        "@resvg/resvg-wasm",
        "yoga-layout",
        "@shuding/opentype.js",
      ],
    },
    plugins: [
      vinext(),
      sites(),
      cloudflare({
        viteEnvironment: { name: "rsc", childEnvironments: ["ssr"] },
        config: localBindingConfig,
      }),
    ],
  };
});
