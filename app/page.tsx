"use client";

import { useMemo, useState, type ReactNode } from "react";

type WorkspaceView = "dashboard" | "charts" | "reports" | "data";
type CatalogTab = "techniques" | "topics" | "intents";
type BuilderStep = 1 | 2 | 3 | 4 | 5;

const topicModels = [
  ["personality.modern.v1", "现代本命结构", "人格与本命", "Alpha"],
  ["personality.psychodynamic.v1", "心理动力与内在冲突", "人格与本命", "Pro"],
  ["personality.shadow_archetype.v1", "阴影与原型倾向", "人格与本命", "V1"],
  ["personality.dominant_signature.v1", "主导行星与星盘签名", "人格与本命", "Beta"],
  ["personality.classical.v1", "古典本命判断", "人格与本命", "Beta"],
  ["personality.hellenistic.v1", "希腊化本命结构", "人格与本命", "Pro"],
  ["personality.integrated.v1", "多流派本命综合", "人格与本命", "Pro"],
  ["topic.career_vocation.v1", "职业、天赋与使命", "人生主题", "Beta"],
  ["topic.money_resources.v1", "财富、资源与成功", "人生主题", "Beta"],
  ["topic.fixed_star_story.v1", "恒星与人生主题", "人生主题", "V1"],
  ["topic.parent_child.v1", "亲子互动与成长", "人生主题", "Pro"],
  ["topic.life_stage_midlife.v1", "人生阶段与中年周期", "人生主题", "V1"],
  ["timing.short_term.v1", "短期行运周期", "时间与预测", "Alpha"],
  ["timing.annual_integrated.v1", "年度综合周期", "时间与预测", "Pro"],
  ["timing.long_cycle.v1", "长期人生周期", "时间与预测", "V1"],
  ["timing.personal_eclipse.v1", "个人食相周期", "时间与预测", "Pro"],
  ["relationship.comparison.v1", "关系比较与双向影响", "关系", "Alpha"],
  ["relationship.entity.v1", "关系实体与共同方向", "关系", "Beta"],
  ["relationship.dynamic.v1", "动态关系周期", "关系", "V1"],
  ["special.project_event.v1", "项目与事件周期", "专项", "V1"],
  ["special.horary.v1", "卜卦判定", "专项", "Pro"],
  ["special.electional.v1", "择时约束优化", "专项", "Pro"],
  ["special.mundane.v1", "世运与组织周期", "专项", "V1"],
  ["geography.location.v1", "地理、迁移与地点比较", "地理", "Pro"],
] as const;

const intents = [
  "本命全貌", "核心人格动力", "优势、天赋与主导特征", "内在矛盾、阴影与成长课题", "人生阶段与中年周期",
  "职业方向与使命", "工作方式与能力结构", "当前事业周期", "职位变化与职业转型窗口", "财富与资源模式", "创业倾向与项目适配",
  "个人关系模式", "两人吸引与兼容", "关系作为独立实体", "关系当前与未来周期", "承诺、亲密与冲突结构", "亲子与家庭互动",
  "当前处于什么周期", "未来7、30或90天", "年度综合周期", "未来3、5或10年长期周期", "个人食相、返照与重要天象",
  "项目或事件本身", "项目发展周期与风险窗口", "具体问题的卜卦判断", "为行动选择时间", "比较多个候选日期",
  "迁移到某地的影响", "比较多个城市", "查看全球占星地理线", "Local Space与Paran分析",
  "公司或组织分析", "国家或城市周期", "四季进入盘、朔望与食相", "重大行星周期与世运事件",
] as const;

const techniques = [
  ["本命盘", "natal.standard", "单盘 · Alpha"],
  ["当前行运", "forecast.transit", "双轮 · Alpha"],
  ["太阳返照", "forecast.solar_return", "返照 · Alpha"],
  ["月亮返照", "forecast.lunar_return", "返照 · Alpha"],
  ["次限推运", "progression.secondary", "推运 · Beta"],
  ["太阳弧", "direction.solar_arc", "弧向 · Beta"],
  ["比较盘", "relationship.synastry", "关系 · Alpha"],
  ["组合盘", "relationship.composite", "关系 · Alpha"],
  ["戴维森盘", "relationship.davison", "关系 · Beta"],
  ["年度小限", "timelord.profection", "古典 · Pro"],
  ["黄道释放", "timelord.zodiacal_releasing", "古典 · Pro"],
  ["主限法", "direction.primary", "古典 · Pro"],
  ["卜卦占星", "horary.judgement", "专项 · Pro"],
  ["择时搜索", "electional.search", "专项 · Pro"],
  ["迁移盘", "geography.relocation", "地理 · Pro"],
  ["占星地理线", "geography.astrocartography", "地理 · Pro"],
] as const;

const entryModes = [
  ["技法排盘", "直接选择本命、行运、推运、返照等方法", "techniques", "◫"],
  ["专题模型", "从24个已定义专题模型开始分析", "topics", "◇"],
  ["分析目的", "从35个现实问题反推模型与计算", "intents", "◎"],
  ["对象快捷", "人物、关系、项目、事件、组织或问题", "topics", "↗"],
  ["时间与周期", "7/30/90天、年度或长期周期", "intents", "⌁"],
  ["关系／项目／地点", "预填双人、项目或地点上下文", "intents", "⌖"],
] as const;

const baseModels = [
  ["natal.modern.v1", "现代本命", "Alpha目标"], ["natal.classical.v1", "古典本命", "Beta目标"],
  ["natal.hellenistic.v1", "希腊化本命", "Beta目标"], ["natal.integrated.v1", "综合本命", "Pro目标"],
  ["forecast.short_transit.v1", "短期行运", "Alpha目标"], ["forecast.annual_integrated.v1", "年度综合", "Pro目标"],
  ["forecast.long_cycle.v1", "长期周期", "V1目标"], ["relationship.comparison.v1", "关系比较", "Alpha目标"],
  ["relationship.entity.v1", "关系实体", "Beta目标"], ["special.project_event.v1", "项目事件", "V1目标"],
  ["special.question_action.v1", "卜卦择时", "Pro目标"], ["geography.location.v1", "地理迁移", "Pro目标"],
] as const;

const chartFamilies = [
  ["基础轮盘", 17, "本命、事件、项目、卜卦、迁移、谐波"],
  ["多轮盘", 14, "双轮、三轮、四轮与自定义叠盘"],
  ["关系图", 14, "比较、组合、戴维森与动态关系"],
  ["表格与网格", 28, "位置、宫位、相位、尊贵、中点"],
  ["预测时间图", 24, "行运甘特、图形星历与时间主星"],
  ["地图", 13, "Astrocartography、Local Space、Paran"],
  ["高级技术图", 18, "刻度盘、网络、赤纬与可见性"],
  ["消费者扩展", 18, "V1后：主题曲线、热力图与反馈"],
] as const;

const reports = [
  ["计算记录报告", "原始输入、参数、计算结果、版本和警告", "可用"],
  ["技法分析报告", "单一技法的配置、时间窗口与技术解释", "Alpha"],
  ["专题模型报告", "基线、优势、压力、矛盾、激活和证据", "Beta"],
  ["目的综合报告", "跨模型发现、时间窗口、反证和确定度", "Pro"],
  ["对象档案报告", "选择多个本命、预测、关系或项目模块", "Pro"],
  ["研究比较报告", "样本、方法、共同点、差异与可复现附录", "Pro"],
] as const;

const planets = [
  ["☉", "太阳", "白羊 08°14′", "5宫"], ["☽", "月亮", "水瓶 21°03′", "3宫"],
  ["☿", "水星", "双鱼 27°46′", "4宫"], ["♀", "金星", "金牛 13°22′", "6宫"],
  ["♂", "火星", "水瓶 05°18′", "2宫"], ["♃", "木星", "处女 06°41′ R", "10宫"],
] as const;

function IconButton({ children, label, onClick }: { children: ReactNode; label: string; onClick?: () => void }) {
  return <button className="icon-button" aria-label={label} onClick={onClick}>{children}</button>;
}

function AstrologyWheel() {
  const zodiac = ["♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐", "♑", "♒", "♓"];
  return (
    <div className="astro-wheel" role="img" aria-label="虚拟示例人物的缓存本命盘">
      <div className="wheel-ring wheel-ring-one" />
      <div className="wheel-ring wheel-ring-two" />
      <div className="wheel-cross wheel-cross-a" />
      <div className="wheel-cross wheel-cross-b" />
      <div className="aspect-web"><i /><i /><i /><i /><i /></div>
      {zodiac.map((symbol, index) => {
        const angle = index * 30 + 15;
        return <span key={symbol} className="zodiac" style={{ transform: `rotate(${angle}deg) translateY(-138px) rotate(${-angle}deg)` }}>{symbol}</span>;
      })}
      {planets.map((planet, index) => {
        const angle = [8, 321, 357, 43, 305, 156][index];
        return <span key={planet[0]} className="planet" style={{ transform: `rotate(${angle}deg) translateY(-106px) rotate(${-angle}deg)` }}>{planet[0]}</span>;
      })}
      <div className="wheel-center"><small>ASC</small><strong>19°07′</strong><span>天蝎</span></div>
      <span className="axis-label axis-asc">ASC 19°</span>
      <span className="axis-label axis-mc">MC 24°</span>
    </div>
  );
}

function StatusPill({ children, tone = "neutral" }: { children: ReactNode; tone?: "neutral" | "green" | "amber" | "blue" | "violet" }) {
  return <span className={`status-pill ${tone}`}>{children}</span>;
}

export default function Home() {
  const [view, setView] = useState<WorkspaceView>("dashboard");
  const [analysisOpen, setAnalysisOpen] = useState(false);
  const [catalogTab, setCatalogTab] = useState<CatalogTab>("topics");
  const [builderStep, setBuilderStep] = useState<BuilderStep>(1);
  const [selectedItem, setSelectedItem] = useState("personality.modern.v1");
  const [search, setSearch] = useState("");
  const [subjectMode, setSubjectMode] = useState<"sample" | "new">("sample");
  const [running, setRunning] = useState(false);
  const [notice, setNotice] = useState("已加载 1 份虚拟示例缓存；本页未启动任何新计算");
  const [chartFamily, setChartFamily] = useState("基础轮盘");
  const [reportDensity, setReportDensity] = useState("标准");

  const catalogItems = useMemo(() => {
    const needle = search.trim().toLowerCase();
    if (catalogTab === "topics") {
      return topicModels.filter((item) => `${item[0]} ${item[1]} ${item[2]}`.toLowerCase().includes(needle));
    }
    if (catalogTab === "intents") {
      return intents
        .map((name, index) => [`intent.${index + 1}`, name, "分析目的", index < 12 ? "Beta" : "Pro"] as const)
        .filter((item) => item[1].toLowerCase().includes(needle));
    }
    return techniques
      .map((item) => [item[1], item[0], "计算技法", item[2]] as const)
      .filter((item) => `${item[0]} ${item[1]}`.toLowerCase().includes(needle));
  }, [catalogTab, search]);

  const openAnalysis = (tab: CatalogTab = "topics", item?: string) => {
    setCatalogTab(tab);
    setSelectedItem(item ?? (tab === "techniques" ? "natal.standard" : tab === "intents" ? "intent.1" : "personality.modern.v1"));
    setSearch("");
    setBuilderStep(1);
    setAnalysisOpen(true);
  };

  const runPrototype = () => {
    setRunning(true);
    setNotice("正在执行已确认的 Recipe（原型演示）");
    window.setTimeout(() => {
      setRunning(false);
      setAnalysisOpen(false);
      setView("dashboard");
      setNotice("原型演示完成：已创建 1 个模拟快照；未调用真实星历引擎");
    }, 1100);
  };

  return (
    <main className="app-shell">
      <header className="topbar">
        <button className="brand" onClick={() => setView("dashboard")} aria-label="返回工作台首页">
          <span className="brand-orbit">✦</span>
          <span><strong>INTERSTELLAR</strong><small>PROFESSIONAL ASTROLOGY</small></span>
        </button>
        <nav className="top-nav" aria-label="工作台主导航">
          {(["dashboard", "charts", "reports", "data"] as const).map((item) => (
            <button key={item} className={view === item ? "active" : ""} onClick={() => setView(item)}>
              {item === "dashboard" ? "工作台" : item === "charts" ? "图表中心 · 146" : item === "reports" ? "报告" : "能力与数据"}
            </button>
          ))}
        </nav>
        <div className="top-actions">
          <span className="dataset-lock"><i /> SE 2.10 · IANA 2026c</span>
          <button className="primary-button compact" onClick={() => openAnalysis()}>＋ 新建分析</button>
          <IconButton label="任务中心">⌁</IconButton>
          <IconButton label="账户">XG</IconButton>
        </div>
      </header>

      <aside className="sidebar">
        <div className="side-section">
          <div className="section-label"><span>对象库</span><button onClick={() => openAnalysis("topics")}>新增并分析</button></div>
          <button className="subject-card active">
            <span className="subject-avatar">A</span>
            <span><strong>阿斯特拉</strong><small>1992.03.28 · 21:16</small></span>
            <StatusPill tone="violet">虚拟</StatusPill>
          </button>
          <p className="side-hint">这里只预置一个明确标记的虚拟人物。真实用户对象会在新增并分析后出现。</p>
        </div>

        <div className="side-section grow">
          <div className="section-label"><span>从对象开始</span></div>
          <button className="side-link active" onClick={() => setView("dashboard")}><span>◉</span>个人仪表盘<em>缓存</em></button>
          <button className="side-link" onClick={() => openAnalysis("topics", "timing.short_term.v1")}><span>⌁</span>当前与短期周期<em>按需</em></button>
          <button className="side-link" onClick={() => openAnalysis("topics", "timing.annual_integrated.v1")}><span>□</span>年度与长期周期<em>按需</em></button>
          <button className="side-link" onClick={() => openAnalysis("topics", "relationship.comparison.v1")}><span>⇄</span>关系分析<em>需2人</em></button>
          <button className="side-link" onClick={() => openAnalysis("topics", "geography.location.v1")}><span>⌖</span>地理与迁移<em>需地点</em></button>
          <button className="side-link" onClick={() => setView("charts")}><span>▦</span>全部图表<em>146</em></button>
        </div>

        <div className="side-section registry-card">
          <div className="registry-row"><span>计算</span><strong>99</strong></div>
          <div className="registry-row"><span>基础模型</span><strong>12</strong></div>
          <div className="registry-row"><span>专题 / 目的</span><strong>24 / 35</strong></div>
          <div className="registry-row"><span>专业V1图</span><strong>128</strong></div>
          <small>目录已校验 · 不会打开即全算</small>
        </div>
      </aside>

      <section className="workspace">
        <div className="workspace-banner" role="status"><span>原型</span>{notice}</div>

        {view === "dashboard" && (
          <>
            <div className="subject-header">
              <div>
                <div className="subject-kicker"><StatusPill tone="violet">虚拟示例</StatusPill><StatusPill tone="green">时间质量 A</StatusPill><span>缓存快照 · CS-DEMO-001</span></div>
                <h1>阿斯特拉的专业占星工作台</h1>
                <p>杭州 · 1992年3月28日 21:16 · Asia/Shanghai · 现代本命预设</p>
              </div>
              <div className="subject-actions">
                <button className="secondary-button" onClick={() => setView("charts")}>查看 146 项图表目录</button>
                <button className="primary-button" onClick={() => openAnalysis()}>开始新的分析</button>
              </div>
            </div>

            <div className="dashboard-grid">
              <article className="panel natal-panel">
                <div className="panel-title">
                  <div><span className="eyebrow">CACHED RESULT</span><h2>现代本命 · 基础视图</h2></div>
                  <div className="segmented"><button className="active">轮盘</button><button onClick={() => setView("data")}>数据</button><button onClick={() => setView("reports")}>报告</button></div>
                </div>
                <div className="natal-content">
                  <AstrologyWheel />
                  <div className="planet-list">
                    <div className="list-head"><span>天体</span><span>位置</span><span>宫位</span></div>
                    {planets.map((planet) => <div className="planet-row" key={planet[1]}><b>{planet[0]}</b><strong>{planet[1]}</strong><span>{planet[2]}</span><em>{planet[3]}</em></div>)}
                    <button className="text-button" onClick={() => setView("data")}>打开完整位置、宫位、相位与证据 →</button>
                  </div>
                </div>
                <div className="snapshot-foot"><span>引擎：演示缓存</span><span>规则：official.modern_natal.v1</span><span>本页新增计算：0</span></div>
              </article>

              <aside className="panel current-plan">
                <div className="panel-title"><div><span className="eyebrow">CURRENT STATE</span><h2>当前没有分析任务</h2></div><StatusPill>空闲</StatusPill></div>
                <div className="plan-empty"><span>＋</span><strong>选择要分析的内容</strong><p>可以直接选技法，也可以按专题或现实目的进入。系统会先给出计算计划，不会立刻执行。</p><button className="primary-button wide" onClick={() => openAnalysis()}>打开统一分析中心</button></div>
                <div className="plan-rule"><b>运行前你会看到</b><span>必需且锁定</span><span>推荐默认</span><span>可选扩展</span><span>缺失与阻断</span><span>预计图表 / 报告 / 时间</span></div>
              </aside>
            </div>

            <section className="start-section">
              <div className="section-heading"><div><span className="eyebrow">SIX ENTRY PATHS</span><h2>你想从哪里开始？</h2><p>六种入口只负责预填上下文，最终都进入同一个 Recipe 预检和按需计算流程。</p></div><button className="text-button" onClick={() => openAnalysis("techniques")}>浏览全部能力 →</button></div>
              <div className="entry-grid">
                {entryModes.map((item) => <button key={item[0]} className="entry-card" onClick={() => openAnalysis(item[2] as CatalogTab)}><span className="entry-icon">{item[3]}</span><strong>{item[0]}</strong><p>{item[1]}</p><em>进入选择 →</em></button>)}
              </div>
            </section>

            <section className="model-strip">
              <div><span className="eyebrow">MODEL REGISTRY</span><h2>12 个后端分析模型</h2><p>它们是确定性能力编排，不是AI模型；卡片显示的是计划目标阶段，当前真实实现状态以能力矩阵为准。</p></div>
              <div className="model-chips">{baseModels.slice(0, 6).map((model) => <button key={model[0]} onClick={() => openAnalysis("topics")}><span>{model[1]}</span><small>{model[2]}</small></button>)}</div>
              <button className="secondary-button" onClick={() => setView("data")}>查看全部12个</button>
            </section>
          </>
        )}

        {view === "charts" && (
          <section className="catalog-page">
            <div className="page-heading"><div><span className="eyebrow">RENDER CATALOG</span><h1>146 项图表都在这里</h1><p>图表不是一次性全部生成；系统会根据当前快照判断可直接渲染、需要追加计算、不可用或未来能力。</p></div><button className="primary-button" onClick={() => openAnalysis("techniques")}>选择技法并生成图表</button></div>
            <div className="status-legend"><StatusPill tone="green">已有快照</StatusPill><StatusPill tone="blue">可直接渲染</StatusPill><StatusPill tone="amber">需追加计算</StatusPill><StatusPill>不可用</StatusPill><StatusPill tone="violet">V1后</StatusPill></div>
            <div className="chart-layout">
              <nav className="family-nav">{chartFamilies.map((family) => <button key={family[0]} className={chartFamily === family[0] ? "active" : ""} onClick={() => setChartFamily(family[0])}><span>{family[0]}<small>{family[2]}</small></span><strong>{family[1]}</strong></button>)}</nav>
              <div className="chart-results">
                <div className="result-toolbar"><div><h2>{chartFamily}</h2><span>{chartFamilies.find((item) => item[0] === chartFamily)?.[1]} 项</span></div><label>⌕ <input placeholder="按名称或 view_id 搜索" /></label><select aria-label="筛选图表状态"><option>全部状态</option><option>可直接渲染</option><option>需追加计算</option></select></div>
                <div className="chart-card-grid">
                  {Array.from({ length: 8 }).map((_, index) => {
                    const names = ["本命盘轮盘", "无出生时间盘", "当前天空盘", "事件盘", "项目启动盘", "公司盘", "国家盘", "问事盘"];
                    const status = index === 0 ? ["已有快照", "green"] : index < 3 ? ["可直接渲染", "blue"] : index < 6 ? ["需追加计算", "amber"] : ["尚未可用", "neutral"];
                    return <button key={index} className="chart-card" onClick={() => index === 0 ? setNotice("已打开缓存本命轮盘") : openAnalysis("techniques")}><div className="chart-thumb"><div className="mini-orbit" /><span>{index + 1}</span></div><strong>{names[index]}</strong><code>wheel.{["natal", "unknown_time", "current_sky", "event", "project_start", "organization", "country", "horary"][index]}</code><StatusPill tone={status[1] as "neutral" | "green" | "amber" | "blue"}>{status[0]}</StatusPill></button>;
                  })}
                </div>
                <div className="catalog-note"><strong>目录不是计算按钮集合</strong><p>点击“需追加计算”会带着目标 view_id 返回分析构建器，补齐依赖并重新预检；不会在后台静默计算。</p></div>
              </div>
            </div>
          </section>
        )}

        {view === "reports" && (
          <section className="catalog-page">
            <div className="page-heading"><div><span className="eyebrow">REPORT ENGINE</span><h1>报告从证据生成，不从AI生成</h1><p>同一份 ReportDocument 可以切换三种密度。正式解释必须有 ReportRulePack，缺失时只输出技术记录或结构化 Finding。</p></div><button className="primary-button" onClick={() => openAnalysis("topics")}>创建可报告的分析</button></div>
            <div className="report-layout">
              <div className="report-profile-list">{reports.map((report, index) => <button key={report[0]} className={index === 2 ? "active" : ""}><span className="report-number">0{index + 1}</span><span><strong>{report[0]}</strong><small>{report[1]}</small></span><StatusPill tone={index === 0 ? "green" : index < 3 ? "blue" : "amber"}>{report[2]}</StatusPill></button>)}</div>
              <article className="report-preview">
                <div className="report-toolbar"><div><StatusPill tone="violet">原型预览</StatusPill><h2>专题模型报告</h2></div><div className="density-switch">{["摘要", "标准", "完整技术版"].map((density) => <button className={reportDensity === density ? "active" : ""} onClick={() => setReportDensity(density)} key={density}>{density}</button>)}</div></div>
                <div className="report-paper"><div className="paper-meta"><span>阿斯特拉 · 虚拟示例</span><span>{reportDensity}密度</span></div><h1>现代本命结构</h1><p className="lead">这份页面展示报告的结构与证据下钻方式，不代表真实占星结论。切换密度不会重新计算，也不会改变底层 Finding。</p><h3>01 · 基线结构</h3><div className="finding"><span className="finding-index">F-01</span><div><strong>结构化 Finding 最小解释单元</strong><p>每条结论分别保存支持、压力与反证，不合并成单一“好运分”。</p><button>查看 3 条证据 →</button></div><StatusPill tone="blue">Beta</StatusPill></div><h3>02 · 激活与时间</h3><div className="timeline-placeholder"><i /><i /><i /><span>开始</span><span>精确</span><span>结束</span></div><h3>03 · 限制与来源</h3><p>规则包、模板、算法卡、数据版本、时间可信度和缺失章节都随报告保存。</p></div>
                <div className="evidence-chain"><span>RawFact</span><b>→</b><span>Evidence</span><b>→</b><span>Finding</span><b>→</b><span>Conclusion</span><b>→</b><span>Section</span><b>→</b><span>Document</span></div>
              </article>
            </div>
          </section>
        )}

        {view === "data" && (
          <section className="catalog-page">
            <div className="page-heading"><div><span className="eyebrow">CAPABILITIES & DATA</span><h1>计算、模型和数据来源一目了然</h1><p>所有计算都返回引擎、数据、规则和模型版本。免费官方数据覆盖 V1 确定性计算，专业解释与规则仍需自建和评审。</p></div><button className="secondary-button">导出目录 JSON</button></div>
            <div className="metric-grid"><div><strong>99</strong><span>登记计算</span><small>均有 calculation_id</small></div><div><strong>12</strong><span>基础分析模型</span><small>确定性编排</small></div><div><strong>24</strong><span>专题模型</span><small>可选产品卡</small></div><div><strong>35</strong><span>分析目的</span><small>映射到模型和Recipe</small></div><div><strong>146</strong><span>图形目录</span><small>专业V1为1—128</small></div></div>
            <div className="data-grid">
              <article className="panel model-registry"><div className="panel-title"><div><span className="eyebrow">ANALYSIS MODELS</span><h2>12 个基础模型</h2></div><StatusPill tone="green">目录有效</StatusPill></div>{baseModels.map((model, index) => <div className="registry-model" key={model[0]}><span>{String(index + 1).padStart(2, "0")}</span><div><strong>{model[1]}</strong><code>{model[0]}</code></div><StatusPill tone="blue">{model[2]}</StatusPill></div>)}</article>
              <article className="panel source-registry"><div className="panel-title"><div><span className="eyebrow">VERSIONED SOURCES</span><h2>数据来源与用途</h2></div></div>{[["Swiss Ephemeris", "主星历、宫位与天体位置", "AGPL 免费"], ["JPL DE/SPICE", "独立天文差异校验", "免费"], ["IANA tzdb", "历史时区与DST", "免费"], ["GeoNames", "地名、经纬度与时区ID", "CC BY"], ["Natural Earth", "全球底图与静态导出", "公有领域"], ["MPC / Gaia / IERS", "小行星、恒星与地球定向", "免费/署名"]].map((source) => <div className="source-row" key={source[0]}><span className="source-dot" /><div><strong>{source[0]}</strong><small>{source[1]}</small></div><em>{source[2]}</em></div>)}<div className="source-warning"><strong>明确缺口</strong><p>1970年前部分历史时区、精确公众人物出生时间、商业中文解释文本、行业统一主题权重和真实事件验证集不能由免费数据自动解决。</p></div></article>
            </div>
          </section>
        )}
      </section>

      {analysisOpen && (
        <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setAnalysisOpen(false); }}>
          <section className="analysis-modal" role="dialog" aria-modal="true" aria-labelledby="analysis-title">
            <header className="modal-header">
              <div><span className="eyebrow">UNIFIED ANALYSIS CENTER</span><h1 id="analysis-title">新建分析</h1><p>选择内容 → 对象与上下文 → 模型与参数 → 输出 → 预检</p></div>
              <button className="modal-close" onClick={() => setAnalysisOpen(false)} aria-label="关闭分析中心">×</button>
            </header>
            <div className="stepper">{["选择内容", "对象与输入", "模型与参数", "图表与报告", "预检并运行"].map((label, index) => <button key={label} className={builderStep === index + 1 ? "active" : builderStep > index + 1 ? "done" : ""} onClick={() => setBuilderStep((index + 1) as BuilderStep)}><span>{builderStep > index + 1 ? "✓" : index + 1}</span>{label}</button>)}</div>

            <div className="modal-body">
              {builderStep === 1 && <div className="catalog-selector">
                <div className="catalog-tabs"><button className={catalogTab === "techniques" ? "active" : ""} onClick={() => setCatalogTab("techniques")}>计算技法 <b>99项底层</b></button><button className={catalogTab === "topics" ? "active" : ""} onClick={() => setCatalogTab("topics")}>专题模型 <b>24</b></button><button className={catalogTab === "intents" ? "active" : ""} onClick={() => setCatalogTab("intents")}>分析目的 <b>35</b></button></div>
                <label className="catalog-search">⌕<input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="搜索名称、ID、领域或技法…" /></label>
                <div className="catalog-list">{catalogItems.map((item) => <button key={item[0]} className={selectedItem === item[0] ? "selected" : ""} onClick={() => setSelectedItem(item[0])}><span className="catalog-item-icon">{catalogTab === "techniques" ? "◫" : catalogTab === "topics" ? "◇" : "◎"}</span><span><strong>{item[1]}</strong><code>{item[0]}</code></span><span className="catalog-meta">{item[2]}<small>{item[3]}</small></span><i>{selectedItem === item[0] ? "✓" : "→"}</i></button>)}</div>
              </div>}

              {builderStep === 2 && <div className="builder-form"><div className="builder-copy"><span className="eyebrow">SUBJECT ROLES</span><h2>这次要分析谁或什么？</h2><p>你不是在单纯新增人物；对象资料会和本次分析内容一起进入Recipe。时间未知时保持未知。</p></div><div className="choice-row"><button className={subjectMode === "sample" ? "active" : ""} onClick={() => setSubjectMode("sample")}><span className="subject-avatar small">A</span><strong>使用虚拟示例</strong><small>已有缓存本命，可复用部分结果</small></button><button className={subjectMode === "new" ? "active" : ""} onClick={() => setSubjectMode("new")}><span className="subject-avatar small empty">＋</span><strong>新增真实对象</strong><small>人物、关系、项目、事件、组织或问题</small></button></div>{subjectMode === "new" && <div className="input-grid"><label>对象类型<select><option>人物</option><option>关系</option><option>事件</option><option>项目</option><option>组织</option><option>国家 / 城市</option><option>具体问题</option></select></label><label>显示名称<input placeholder="姓名或代号" /></label><label>出生 / 事件日期<input type="date" /></label><label>时间精度<select><option>精确到分钟</option><option>约一小时</option><option>上午 / 下午</option><option>只知道日期</option><option>未知</option></select></label><label>当地时间<input type="time" /></label><label>出生 / 事件地点<input placeholder="选择地点，不使用浏览器自动替代" /></label><label className="span-two">资料来源<select><option>出生证明 / 官方记录</option><option>本人或亲友提供</option><option>传记或公开来源</option><option>记忆 / 估计</option><option>未知</option></select></label></div>}</div>}

              {builderStep === 3 && <div className="builder-form"><div className="builder-copy"><span className="eyebrow">RESOLVED MODEL</span><h2>确认模型、技法与允许参数</h2><p>当前选择会解析为确定性模型。模型的核心组件不可随意删改；需要修改核心时另存为自定义配方。</p></div><div className="resolved-model"><div className="resolved-head"><span className="model-mark">M</span><div><strong>现代本命分析</strong><code>natal.modern.v1 · planned</code></div><StatusPill tone="amber">Alpha 目标 · 未实现</StatusPill></div><div className="component-flow"><span>时间与地点</span><b>→</b><span>Swiss星历</span><b>→</b><span>本命盘</span><b>→</b><span>相位与格局</span><b>→</b><span>快照</span></div></div><div className="parameter-grid"><label>官方预设<select><option>official.modern_natal.v1</option><option>official.classical_natal.v1</option><option>official.hellenistic_natal.v1</option></select></label><label>黄道<select><option>回归黄道 Tropical</option><option>恒星黄道 Sidereal</option></select></label><label>宫位制<select><option>Placidus</option><option>Whole Sign</option><option>Equal House</option><option>Koch</option></select></label><label>相位集<select><option>主要相位</option><option>主要 + 次要相位</option><option>自定义相位集</option></select></label></div><div className="locked-note"><span>锁</span><p><strong>核心组件将由服务端锁定</strong>：天体位置、宫位、相位和结果Schema不能从浏览器删除；当前原型尚未连接真实引擎。</p></div></div>}

              {builderStep === 4 && <div className="builder-form"><div className="builder-copy"><span className="eyebrow">OUTPUT MANIFEST</span><h2>选择这次需要的输出</h2><p>图表只是结果的不同视图。已存在的事实直接渲染；需要新事实的输出会在预检中增加计算节点。</p></div><div className="output-columns"><div><h3>主输出 · 默认选中</h3>{["本命盘轮盘", "行星位置表", "相位网格", "计算记录报告"].map((item) => <label className="check-row" key={item}><input type="checkbox" defaultChecked /><span>{item}</span><StatusPill tone="green">直接</StatusPill></label>)}</div><div><h3>推荐输出 · 可取消</h3>{["元素与模式", "格局表", "主导行星", "SVG / PNG 导出"].map((item) => <label className="check-row" key={item}><input type="checkbox" defaultChecked /><span>{item}</span><StatusPill tone="blue">推荐</StatusPill></label>)}</div><div><h3>可选扩展 · 不默认计算</h3>{["古典尊贵", "固定星接触", "未来一年行运", "专题模型报告"].map((item) => <label className="check-row" key={item}><input type="checkbox" /><span>{item}</span><StatusPill tone="amber">追加</StatusPill></label>)}</div></div><div className="output-total"><span>当前计划</span><strong>4 个主输出 · 4 个推荐 · 0 个扩展</strong><em>不会生成其余138项图表</em></div></div>}

              {builderStep === 5 && <div className="preflight"><div className="builder-copy"><span className="eyebrow">PREFLIGHT PLAN</span><h2>确认后才开始计算</h2><p>下面是原型按预定服务端契约展示的执行计划；真实服务接入后才会锁定版本、复用结果并执行。</p></div><div className="preflight-grid"><article><header><StatusPill tone="green">必需 · 4</StatusPill><span>计划锁定</span></header><ul><li><b>时间与地点规范化</b><small>TimeSpec + Location</small></li><li><b>天体位置</b><small>Swiss Ephemeris 2.10.x</small></li><li><b>宫位与四轴</b><small>Placidus · Tropical</small></li><li><b>主要相位</b><small>official.modern_major.v1</small></li></ul></article><article><header><StatusPill tone="blue">复用示意 · 3</StatusPill><span>演示数据</span></header><ul><li><b>对象版本</b><small>SV-DEMO-001</small></li><li><b>本命位置</b><small>CS-DEMO-001 / points</small></li><li><b>主要相位</b><small>CS-DEMO-001 / aspects</small></li></ul></article><article><header><StatusPill tone="amber">可选 · 4</StatusPill><span>未选择</span></header><ul><li><b>古典尊贵</b><small>计划中的追加计算</small></li><li><b>固定星接触</b><small>计划使用常用恒星目录</small></li><li><b>未来一年行运</b><small>计划转为异步任务</small></li><li><b>专题报告</b><small>需要 ReportRulePack</small></li></ul></article><article><header><StatusPill>阻断 · 1</StatusPill><span>不影响本次</span></header><ul><li><b>关系比较盘</b><small>缺少第二人物；本次不执行</small></li></ul></article></div><div className="recipe-summary"><div><span>Recipe</span><code>AR-DEMO · non-production</code></div><div><span>资源等级</span><strong>待真实后端预检</strong></div><div><span>将生成</span><strong>演示快照与视图，不含真实计算</strong></div><div><span>实现状态</span><strong>Foundation 原型 · 时间质量 A 示例</strong></div></div></div>}
            </div>

            <footer className="modal-footer"><button className="secondary-button" onClick={() => builderStep === 1 ? setAnalysisOpen(false) : setBuilderStep((builderStep - 1) as BuilderStep)}>{builderStep === 1 ? "取消" : "上一步"}</button><div><span>{builderStep} / 5</span>{builderStep < 5 ? <button className="primary-button" onClick={() => setBuilderStep((builderStep + 1) as BuilderStep)}>继续</button> : <button className={`primary-button ${running ? "loading" : ""}`} onClick={runPrototype} disabled={running}>{running ? "正在运行…" : "确认 Recipe 并运行"}</button>}</div></footer>
          </section>
        </div>
      )}
    </main>
  );
}
