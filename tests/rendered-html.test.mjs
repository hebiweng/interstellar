import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("http://localhost/", { headers: { accept: "text/html" } }),
    { ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) } },
    { waitUntil() {}, passThroughOnException() {} },
  );
}

test("server-renders the Interstellar professional workspace", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>Interstellar · 专业占星研究工作台<\/title>/i);
  assert.match(html, /INTERSTELLAR/);
  assert.match(html, /PROFESSIONAL ASTROLOGY/);
  assert.match(html, /阿斯特拉/);
  assert.match(html, /虚拟示例/);
  assert.match(html, /开始新的分析/);
  assert.match(html, /六种入口/);
  assert.match(html, /图表中心 · 146/);
  assert.match(html, /本页未启动任何新计算/);
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape|react-loading-skeleton/i);
});

test("renders site-specific social metadata", async () => {
  const response = await render();
  const html = await response.text();
  assert.match(html, /og:image/);
  assert.match(html, /\/og\.png/);
  assert.match(html, /summary_large_image/);
});

test("renders six distinct analysis entry points and readable density controls", async () => {
  const response = await render();
  const html = await response.text();
  const expectedEntryPoints = [
    "entry.technique",
    "entry.topic_model",
    "entry.object_context",
    "entry.personal_dashboard",
    "entry.intent",
    "entry.context_shortcut",
  ];

  for (const entryPointId of expectedEntryPoints) {
    assert.match(html, new RegExp(`data-entry-point="${entryPointId.replace(".", "\\.")}"`));
  }
  assert.match(html, /density-comfortable/);
  assert.match(html, /工作台显示密度/);
  assert.match(html, /舒适/);
});

test("defines explicit desktop and mobile scroll ownership", async () => {
  const css = await readFile(new URL("../app/globals.css", import.meta.url), "utf8");
  assert.match(css, /\.app-shell\s*\{[^}]*height:\s*100vh;[^}]*overflow:\s*hidden;/s);
  assert.match(css, /\.workspace\s*\{[^}]*overflow:\s*auto;/s);
  assert.match(css, /@media \(max-width: 900px\)[\s\S]*\.app-shell\s*\{[^}]*height:\s*auto;[^}]*overflow:\s*visible;/s);
});

test("keeps the M4 prototype honest about implemented and planned interactions", async () => {
  const page = await readFile(new URL("../app/page.tsx", import.meta.url), "utf8");

  for (const family of ["基础轮盘", "多轮盘", "关系图", "表格与网格", "预测时间图", "地图", "高级技术图", "消费者扩展"]) {
    assert.match(page, new RegExp(`"${family}"\\s*:`));
  }

  assert.match(page, /146 项 V1 路线图 · 35 项已登记/);
  assert.match(page, /value=\{chartQuery\}[\s\S]*onChange=\{\(event\) => setChartQuery/);
  assert.match(page, /value=\{chartStatus\}[\s\S]*onChange=\{\(event\) => setChartStatus/);
  assert.match(page, /<button disabled title="真实对象输入、地点解析和 SubjectVersion 持久化将在 M5—M6 接通"/);
  assert.match(page, /className="parameter-grid read-only"/);
  assert.match(page, /className="output-columns read-only"/);
  assert.doesNotMatch(page, /setTimeout\(/);
});

test("defines a readable semantic type floor and unavailable-control state", async () => {
  const css = await readFile(new URL("../app/globals.css", import.meta.url), "utf8");
  assert.match(css, /--type-caption:\s*12px/);
  assert.match(css, /--type-small:\s*13px/);
  assert.match(css, /--type-body:\s*14px/);
  assert.match(css, /button\[disabled\]\s*\{[^}]*cursor:\s*not-allowed;/s);
});
