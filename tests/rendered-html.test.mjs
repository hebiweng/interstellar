import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import { join } from "node:path";
import test from "node:test";
import { Miniflare } from "miniflare";

async function render() {
  const serverRoot = new URL("../dist/server", import.meta.url).pathname;
  const workerPath = join(serverRoot, "index.js");
  const emittedModules = (await readdir(serverRoot, { recursive: true }))
    .filter((path) => path.endsWith(".js") || path.endsWith(".mjs"))
    .map((path) => join(serverRoot, path));
  const miniflare = new Miniflare({
    modules: [
      { type: "ESModule", path: workerPath },
      ...emittedModules.filter((path) => path !== workerPath).map((path) => ({ type: "ESModule", path })),
    ],
    compatibilityDate: "2026-05-15",
    compatibilityFlags: ["nodejs_compat"],
    d1Databases: { DB: `rendered-html-${process.pid}` },
    serviceBindings: {
      ASSETS: () => new Response("Not found", { status: 404 }),
    },
  });
  try {
    const response = await miniflare.dispatchFetch("http://localhost/", {
      headers: { accept: "text/html" },
    });
    return new Response(await response.arrayBuffer(), {
      status: response.status,
      headers: response.headers,
    });
  } finally {
    await miniflare.dispose();
  }
}

test("server-renders the natal-first Interstellar workspace", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);
  const html = await response.text();
  assert.match(html, /<title>Interstellar · 专业占星研究工作台<\/title>/i);
  assert.match(html, /PROFESSIONAL ASTROLOGY/);
  assert.match(html, /新建分析/);
  assert.match(html, /本命盘/);
  assert.match(html, /行运盘/);
  assert.match(html, /13分盘/);
  assert.match(html, /正在读取工作台/);
  assert.doesNotMatch(html, /技法排盘/);
  assert.doesNotMatch(html, /VIRTUAL FIXTURE|当前展示静态虚拟验收样例/);
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
  assert.match(page, /保存为当前账户可复用的人物资料；此动作不会自动计算/);
  assert.match(page, /计算完整本命盘/);
  assert.match(page, /14 种盘型/);
  assert.match(page, /label: "现代"/);
  assert.match(page, /label: "古典"/);
  assert.match(page, /label: "特殊"/);
  assert.match(page, /Tropical 回归黄道/);
  assert.match(page, /Sidereal 恒星黄道/);
  assert.match(page, /岁差体系 Ayanamsa/);
  assert.match(page, /Placidus 普拉西德/);
  assert.match(page, /Whole Sign 整宫制/);
  assert.match(page, /Koch 柯赫/);
  assert.match(page, /Regiomontanus 雷吉奥蒙塔努斯/);
  assert.match(page, /点位组/);
  assert.match(page, /相位计算（需重新计算）/);
  assert.match(page, /星座落点与表达方式/);
  assert.match(page, /主要相位矩阵/);
  assert.match(page, /本命轮盘/);
  assert.match(page, /查看结果/);
  assert.match(page, /本命盘计算结果/);
  assert.match(page, /chart-workspace-card/);
  assert.match(page, /朔望点/);
  assert.match(page, /紫炁/);
  assert.match(page, /wheelPointLabels/);
  assert.match(page, /professional-point-label/);
  assert.match(page, /sign-name-label/);
  assert.match(page, /getNatalItemInterpretation/);
  assert.match(page, /刷新 DeepSeek 分析/);
  assert.match(page, /只有点击右上角“刷新”时才会/);
  assert.match(page, /按当前参数重新计算/);
  assert.match(page, /复制数据/);
  assert.match(page, /导出 TXT/);
  assert.doesNotMatch(page, /导出 \.md|专业 JSON|导出所选 CSV/);
  assert.doesNotMatch(page, /dataset-audit/);
  assert.doesNotMatch(page, /结构化证据与原始高级结果/);
  assert.doesNotMatch(page, /定位星链/);
  assert.doesNotMatch(page, /预览将发送的载荷|本次载荷预览/);
  assert.doesNotMatch(page, /规则方案/);
});

test("separates subject creation, calculations, future methods, and theme choice", async () => {
  const page = await readFile(new URL("../app/page.tsx", import.meta.url), "utf8");
  assert.match(page, /保存人物/);
  assert.match(page, /此动作不会自动计算/);
  assert.match(page, /本命盘当前可运行；其他方法保留入口/);
  assert.match(page, /IANA 时区/);
  assert.match(page, /选择后自动填写经纬度、国家和 IANA 时区/);
  assert.match(page, /searchLocations/);
  assert.match(page, /地点数据未能唯一确认时区，必须人工确认/);
  assert.match(page, /Light/);
  assert.match(page, /Dark/);
  assert.doesNotMatch(page, />技术推演<\/button>/);
  assert.doesNotMatch(page, />计算设置<\/button>/);
});

test("keeps the object library limited to reusable fact records", async () => {
  const page = await readFile(new URL("../app/objects/page.tsx", import.meta.url), "utf8");
  assert.match(page, /对象库不发起计算，也不展示分析入口/);
  assert.match(page, /saveAccountPerson/);
  assert.match(page, /修改资料/);
  assert.match(page, /设为默认/);
  assert.match(page, /删除示例/);
  assert.doesNotMatch(page, />打开最新本命</);
  assert.doesNotMatch(page, />开始本命分析</);
  assert.doesNotMatch(page, />重新分析</);
  assert.doesNotMatch(page, /new-analysis=1/);
});

test("keeps scroll ownership readable on desktop and mobile", async () => {
  const css = await readFile(new URL("../app/globals.css", import.meta.url), "utf8");
  assert.match(css, /body\s*\{[^}]*min-height:\s*100%;/s);
  assert.match(css, /\.settings-panel\s*\{[^}]*overflow-y:\s*auto;/s);
  assert.match(css, /\.workbench-grid\s*\{[^}]*grid-template-columns:/s);
  assert.match(css, /\.workbench-grid > \.settings-panel\s*\{[^}]*order:\s*1;/s);
  assert.match(css, /\.result-content:has\(\.data-table\)[^}]*overflow-x:\s*auto;/s);
  assert.match(css, /@media \(max-width: 900px\)[\s\S]*\.settings-panel, \.chart-workspace-card, \.ai-insight-panel\s*\{[^}]*position:\s*static;/s);
  assert.match(css, /\.modal-backdrop[^}]*overflow:\s*auto;/s);
});

test("defines a layered professional natal wheel and compact alternate view", async () => {
  const page = await readFile(new URL("../app/page.tsx", import.meta.url), "utf8");
  const css = await readFile(new URL("../app/globals.css", import.meta.url), "utf8");
  assert.match(page, /360/);
  assert.match(page, /point-band-ring/);
  assert.match(page, /house-number-ring/);
  assert.match(page, /aspect-stage-ring/);
  assert.match(page, /aspect-anchor-dot/);
  assert.match(page, /sampleAspectDefinitions/);
  assert.match(page, /signNames\[signIds\[index\]\]/);
  assert.match(page, /wheelPointLabels\[point\.point_id\]/);
  assert.match(css, /\.professional-point-label/);
  assert.match(css, /\.sign-name-label/);
  assert.match(css, /\.aspect-stage-ring/);
  assert.doesNotMatch(css, /perspective:|rotateY\(|backface-visibility/);
});

test("keeps user-facing analysis data portable and developer metadata out of the report", async () => {
  const page = await readFile(new URL("../app/page.tsx", import.meta.url), "utf8");
  const api = await readFile(new URL("../app/lib/interstellar-api.ts", import.meta.url), "utf8");
  assert.match(page, /本命盘分析数据/);
  assert.match(page, /可复制给占星师或外部模型继续分析/);
  assert.match(page, /复制数据/);
  assert.match(page, /导出 TXT/);
  assert.doesNotMatch(page, /RESULT DISCLOSURE & COVERAGE/);
  assert.doesNotMatch(page, /任何没有视图或导出映射的新结果都会标记为发布阻塞/);
  assert.match(api, /output_manifest\?: Array/);
  assert.match(api, /evidence\?: Array/);
});

test("uses one RenderSpec on screen without exposing wheel export controls", async () => {
  const page = await readFile(new URL("../app/page.tsx", import.meta.url), "utf8");
  const exporter = await readFile(new URL("../app/lib/render-export.ts", import.meta.url), "utf8");
  assert.match(page, /buildNatalRenderSpec/);
  assert.match(page, /renderSpec=\{natalRenderSpec\}/);
  assert.doesNotMatch(page, /同源导出|downloadNatalGraphic|导出 SVG|导出 PNG|导出 PDF/);
  assert.match(exporter, /view_id: "wheel\.natal"/);
  assert.match(exporter, /serializeSvgWithComputedStyles/);
  assert.match(exporter, /rasterizeSerializedSvg/);
  assert.match(exporter, /buildSingleImagePdf/);
  assert.match(exporter, /\/Filter \/DCTDecode/);
  assert.match(exporter, /provenance_metadata/);
});

test("renders versioned item interpretation layers without generic fallback", async () => {
  const page = await readFile(new URL("../app/page.tsx", import.meta.url), "utf8");
  const api = await readFile(new URL("../app/lib/interstellar-api.ts", import.meta.url), "utf8");
  const css = await readFile(new URL("../app/globals.css", import.meta.url), "utf8");
  assert.match(page, /计算事实/);
  assert.match(page, /解读内容准备中/);
  assert.match(page, /出生资料不足/);
  assert.match(page, /此项不适用/);
  assert.doesNotMatch(page, /组合阅读边界|只展示当前已发布且适用于这份出生资料的解释|尚无解读/);
  assert.doesNotMatch(api, /JSON\.stringify\(item\.fact/);
  assert.match(page, /Reference fixture/);
  assert.doesNotMatch(page, /value\.status === ["']available["']/);
  assert.match(api, /blocked_by_input_quality/);
  assert.match(api, /point_in_house/);
  assert.match(api, /content_hash/);
  assert.match(css, /\.interpretation-layers/);
  assert.match(css, /\.interpretation-layer\.status-blocked_by_input_quality/);
});

test("connects every released structure and classical result to an exact snapshot path", async () => {
  const page = await readFile(new URL("../app/page.tsx", import.meta.url), "utf8");
  assert.match(page, /`\/result\/structure\/\$\{key\}`/);
  assert.match(page, /`\/result\/structure\/angularity\/facts\/\$\{index\}`/);
  assert.match(page, /`\/result\/structure\/stelliums\/facts\/\$\{index\}`/);
  assert.match(page, /`\/result\/structure\/geometric_patterns\/facts\/\$\{index\}`/);
  assert.match(page, /"\/result\/structure\/jones_shape"/);
  assert.match(page, /"\/result\/classical\/sect"/);
  assert.match(page, /`\/result\/dignities\/\$\{index\}`/);
  assert.match(page, /`\/result\/classical\/solar_conditions\/\$\{index\}`/);
  assert.match(page, /"\/result\/classical\/receptions"/);
  assert.match(page, /`\/result\/lots\/\$\{index\}`/);
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
