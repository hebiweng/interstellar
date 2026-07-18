import assert from "node:assert/strict";
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
