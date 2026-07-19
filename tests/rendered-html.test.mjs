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

test("server-renders the natal-first Interstellar workspace", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);
  const html = await response.text();
  assert.match(html, /<title>Interstellar · 专业占星研究工作台<\/title>/i);
  assert.match(html, /PROFESSIONAL ASTROLOGY/);
  assert.match(html, /阿斯特拉（虚拟验收样例）/);
  assert.match(html, /新建计算/);
  assert.match(html, /计算方法/);
  assert.match(html, /合盘/);
  assert.match(html, /行运盘/);
  assert.match(html, /本命轮盘/);
  assert.match(html, /星座、度数、宫位与运动状态/);
  assert.match(html, /完整技术推演/);
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape|react-loading-skeleton/i);
});

test("renders site-specific social metadata", async () => {
  const response = await render();
  const html = await response.text();
  assert.match(html, /og:image/);
  assert.match(html, /\/og\.png/);
  assert.match(html, /summary_large_image/);
});

test("defines real natal input, deterministic settings, item interpretations, and AI boundary", async () => {
  const page = await readFile(new URL("../app/page.tsx", import.meta.url), "utf8");
  assert.match(page, /这里只保存可复用的人物资料，不启动本命盘或任何其他计算/);
  assert.match(page, /计算完整本命盘/);
  assert.match(page, /六种分析入口/);
  assert.match(page, /专业综合本命 v1/);
  assert.match(page, /回归黄道 Tropical（当前可用）/);
  assert.match(page, /Placidus 普拉西德/);
  assert.match(page, /Whole Sign 整宫制/);
  assert.match(page, /Koch 柯赫/);
  assert.match(page, /Regiomontanus 雷吉奥蒙塔努斯/);
  assert.match(page, /点位组/);
  assert.match(page, /相位展示与计算/);
  assert.match(page, /星座落点与表达方式/);
  assert.match(page, /主要相位矩阵/);
  assert.match(page, /getNatalItemInterpretation/);
  assert.match(page, /提交至 AI 分析/);
  assert.match(page, /AI 只接收已算好的技术文档/);
  assert.match(page, /复制全文/);
  assert.match(page, /导出 \.md/);
  assert.match(page, /导出 \.txt/);
});

test("separates subject creation, calculations, future methods, and theme choice", async () => {
  const page = await readFile(new URL("../app/page.tsx", import.meta.url), "utf8");
  assert.match(page, /保存人物/);
  assert.match(page, /未启动任何计算/);
  assert.match(page, /本命盘当前可运行；其他方法保留入口/);
  assert.match(page, /IANA 时区/);
  assert.match(page, /选择候选会自动填写经纬度、国家和时区/);
  assert.match(page, /Light/);
  assert.match(page, /Dark/);
  assert.doesNotMatch(page, />技术推演<\/button>/);
  assert.doesNotMatch(page, />计算设置<\/button>/);
});

test("keeps scroll ownership readable on desktop and mobile", async () => {
  const css = await readFile(new URL("../app/globals.css", import.meta.url), "utf8");
  assert.match(css, /body\s*\{[^}]*min-height:\s*100%;/s);
  assert.match(css, /\.person-sidebar\s*\{[^}]*overflow-y:\s*auto;/s);
  assert.match(css, /\.result-content:has\(\.data-table\)[^}]*overflow-x:\s*auto;/s);
  assert.match(css, /@media \(max-width: 900px\)[\s\S]*\.person-sidebar\s*\{[^}]*position:\s*static;/s);
  assert.match(css, /\.modal-backdrop[^}]*overflow:\s*auto;/s);
});

test("defines a readable semantic type floor and unavailable-control state", async () => {
  const css = await readFile(new URL("../app/globals.css", import.meta.url), "utf8");
  assert.match(css, /--type-caption:\s*12px/);
  assert.match(css, /--type-small:\s*13px/);
  assert.match(css, /--type-body:\s*14px/);
  assert.match(css, /button\[disabled\]\s*\{[^}]*cursor:\s*not-allowed;/s);
  assert.match(css, /:root\[data-theme="light"\]/);
  assert.match(css, /\.theme-toggle/);
});
