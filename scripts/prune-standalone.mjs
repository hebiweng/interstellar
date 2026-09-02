// 构建后清理 standalone 产物中的死重依赖。
// vinext standalone 会把传递依赖完整复制到 dist/standalone/node_modules，
// 其中很多是构建时工具（acorn、magic-string 等）或未使用的包（@vercel/og 等），
// 运行时不需要，可安全删除以减小部署包体积。
import { rm } from "node:fs/promises";
import { join } from "node:path";

const STANDALONE_NM = join(process.cwd(), "dist", "standalone", "node_modules");

// 已确认未使用的 OG 相关包（vinext 传递依赖，项目无 OG 功能）
const PRUNE_PACKAGES = [
  "@vercel/og",
  "satori",
  "@resvg/resvg-wasm",
  "yoga-layout",
  "@shuding/opentype.js",
];

// 构建时工具包（acorn/magic-string/es-module-lexer 是 JS 解析器，
// tsconfck/vite-plugin-* 是 Vite 插件，fast-glob/micromatch/braces 是文件匹配，
// 这些在运行时 standalone 中不需要）
const PRUNE_BUILD_TOOLS = [
  "acorn",
  "magic-string",
  "es-module-lexer",
  "tsconfck",
  "vite-plugin-commonjs",
  "vite-plugin-dynamic-import",
  "vite-tsconfig-paths",
  "fast-glob",
  "micromatch",
  "braces",
  "fill-range",
  "to-regex-range",
  "is-number",
  "is-extglob",
  "is-glob",
  "glob-parent",
  "globrex",
  "merge2",
  "picomatch",
  "@nodelib",
  "debug",
  "ms",
  "run-parallel",
  "queue-microtask",
  "reusify",
  "fastq",
];

// source map 文件（生产环境不需要）
const PRUNE_PATTERNS = [
  "**/*.js.map",
  "**/*.mjs.map",
  "**/*.cjs.map",
];

let removed = 0;
const removedSize = { bytes: 0 };

for (const pkg of [...PRUNE_PACKAGES, ...PRUNE_BUILD_TOOLS]) {
  const target = join(STANDALONE_NM, pkg);
  try {
    // 计算大小
    const { stat } = await import("node:fs/promises");
    // 简单删除，不计算大小
    await rm(target, { recursive: true, force: true });
    console.log(`[prune-standalone] removed ${pkg}`);
    removed++;
  } catch (err) {
    console.warn(`[prune-standalone] skip ${pkg}: ${err.message}`);
  }
}

// 删除所有 source map 文件
import { glob } from "node:fs/promises";
const standaloneRoot = join(process.cwd(), "dist", "standalone");
try {
  for await (const entry of glob("**/*.map", { cwd: standaloneRoot })) {
    const full = join(standaloneRoot, entry);
    try {
      await rm(full, { force: true });
      removedSize.bytes++;
    } catch {}
  }
  if (removedSize.bytes > 0) {
    console.log(`[prune-standalone] removed ${removedSize.bytes} source map file(s)`);
  }
} catch (err) {
  console.warn(`[prune-standalone] source map cleanup skipped: ${err.message}`);
}

console.log(`[prune-standalone] done, removed ${removed} package(s)`);
