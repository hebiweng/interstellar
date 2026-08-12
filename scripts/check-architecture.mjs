import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import { join } from "node:path";

const root = process.cwd();

async function read(path) {
  return readFile(join(root, path), "utf8");
}

function lineCount(source) {
  return source.split(/\r?\n/).length;
}

async function assertLineBudget(path, maxLines, reason) {
  const source = await read(path);
  assert.ok(
    lineCount(source) <= maxLines,
    `${path} has ${lineCount(source)} lines; budget is ${maxLines}. ${reason}`,
  );
}

async function listFiles(dir) {
  const entries = await readdir(join(root, dir), { recursive: true, withFileTypes: true });
  return entries
    .filter((entry) => entry.isFile())
    .map((entry) => join(entry.parentPath, entry.name).replace(`${root}/`, ""));
}

async function assertRouteEntrypointsStayThin() {
  const page = await read("app/page.tsx");
  assert.equal(page.includes('"use client"'), false, "app/page.tsx must stay a route entry, not a client workspace.");
  assert.equal(page.includes("useState("), false, "app/page.tsx must not own React state.");
  assert.equal(page.includes("fetch("), false, "app/page.tsx must not perform data fetching directly.");
  await assertLineBudget("app/page.tsx", 80, "Route entries should delegate to workspace components.");
}

async function assertFileBudgetsAreRoleBased() {
  await assertLineBudget(
    "app/components/workspaces/home-workspace.tsx",
    900,
    "This transitional workspace may shrink over time, but must not grow.",
  );
  await assertLineBudget("app/lib/api-client.ts", 280, "Shared API infrastructure should remain reviewable.");
  await assertLineBudget("app/lib/insight/secondary.ts", 560, "Insight builders should stay focused and testable.");
  await assertLineBudget(
    "app/components/workspaces/secondary-progressions-workspace.tsx",
    520,
    "Workspace components should orchestrate UI and state, not absorb all panel logic.",
  );
}

async function assertApiRetryPolicy() {
  const apiClient = await read("app/lib/api-client.ts");
  assert.match(apiClient, /IDEMPOTENT_RETRY_METHODS = new Set\(\["GET", "HEAD"\]\)/);
  assert.match(apiClient, /retryUnsafeMethods\?: boolean/);
  assert.match(apiClient, /canRetry\(method, options\) \? MAX_RETRIES \+ 1 : 1/);
}

async function assertProductionApiBaseIsSameOrigin() {
  const files = [
    "infra/deploy/compose.production.yaml",
    "infra/deploy/Dockerfile.web",
    "compose.override.yml",
    ".env.example",
    "vite.config.ts",
  ];
  for (const file of files) {
    const source = await read(file);
    assert.equal(
      source.includes("NEXT_PUBLIC_INTERSTELLAR_API_URL: http://127.0.0.1"),
      false,
      `${file} must not bake localhost API URLs into browser code.`,
    );
  }
  const productionCompose = await read("infra/deploy/compose.production.yaml");
  assert.match(productionCompose, /NEXT_PUBLIC_INTERSTELLAR_API_URL:\s*\/api\/v1/);
  const viteConfig = await read("vite.config.ts");
  assert.match(viteConfig, /"\/api\/v1":\s*{/);
  assert.equal(
    viteConfig.includes("rewrite:"),
    false,
    "FastAPI routes are mounted under /api/v1; the same-origin proxy must not strip that prefix.",
  );
}

async function assertSecondaryInsightUsesCorpus() {
  const source = await read("app/lib/insight/secondary.ts");
  const forbiddenSnippets = [
    "次限盘正在推进",
    "次限盘描述内在变化节奏，不是事件预测",
    "当前没有特别集中的次限转折信号，内在节奏相对平稳。",
    "次限与本命互动平稳",
  ];
  for (const snippet of forbiddenSnippets) {
    assert.equal(source.includes(snippet), false, `secondary insight hard-codes corpus-like copy: ${snippet}`);
  }
}

async function assertCssIsMovingOutOfGlobals() {
  const styleFiles = await listFiles("app/styles");
  assert.ok(styleFiles.includes("app/styles/secondary.css"), "secondary styles must live in app/styles/secondary.css");
  const globals = await read("app/globals.css");
  assert.equal(
    globals.includes(".secondary-progressions-workspace"),
    false,
    "secondary-specific selectors belong in app/styles/secondary.css, not globals.css.",
  );
}

async function assertIOSColorsStaySemantic() {
  const files = (await listFiles("ios/App")).filter(
    (file) => file.endsWith(".swift") && file !== "ios/App/Theme.swift",
  );
  for (const file of files) {
    const source = await read(file);
    assert.equal(source.includes("Color(red:"), false, `${file} must use adaptive AppTheme colors.`);
    assert.equal(source.includes("Color.black"), false, `${file} must use adaptive AppTheme colors.`);
  }
}

async function assertIOSCardTypographyScales() {
  const files = (await listFiles("ios/App")).filter(
    (file) => file.endsWith(".swift")
      && file !== "ios/App/ChartRenderer.swift"
      && file !== "ios/App/ProfileView.swift",
  );
  for (const file of files) {
    const source = await read(file);
    assert.equal(
      source.includes(".font(.system(size:"),
      false,
      `${file} must use semantic or scaled Dynamic Type fonts instead of a fixed point size.`,
    );
  }
}

await assertRouteEntrypointsStayThin();
await assertFileBudgetsAreRoleBased();
await assertApiRetryPolicy();
await assertProductionApiBaseIsSameOrigin();
await assertSecondaryInsightUsesCorpus();
await assertCssIsMovingOutOfGlobals();
await assertIOSColorsStaySemantic();
await assertIOSCardTypographyScales();

console.log("[architecture] route, retry, corpus, CSS, and production API guards passed");
