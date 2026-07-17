"use client";

import { useMemo, useState, type CSSProperties, type ReactNode } from "react";

type InspectorTab = "input" | "params" | "result" | "evidence";
type DataTab = "positions" | "houses" | "aspects" | "strength";
type ChartMode = "natal" | "transit" | "synastry" | "return";

const subjects = [
  {
    id: "lin-che",
    initials: "澈",
    name: "林澈",
    meta: "1992.03.28 · 21:16",
    place: "杭州，中国",
    tag: "AA",
    kind: "人物",
    color: "blue",
  },
  {
    id: "yan",
    initials: "晏",
    name: "沈晏",
    meta: "1990.11.06 · 06:42",
    place: "成都，中国",
    tag: "A",
    kind: "人物",
    color: "amber",
  },
  {
    id: "orphic",
    initials: "O",
    name: "Orphic Studio",
    meta: "2024.08.19 · 10:30",
    place: "上海，中国",
    tag: "项目",
    kind: "项目",
    color: "green",
  },
  {
    id: "relationship",
    initials: "双",
    name: "林澈 × 沈晏",
    meta: "关系档案 · v3",
    place: "双向比较",
    tag: "关系",
    kind: "关系",
    color: "violet",
  },
];

const planets = [
  { symbol: "☉", name: "太阳", sign: "白羊", degree: "08° 14′", house: "5", angle: 8, tone: "warm" },
  { symbol: "☽", name: "月亮", sign: "水瓶", degree: "21° 03′", house: "3", angle: 321, tone: "cool" },
  { symbol: "☿", name: "水星", sign: "双鱼", degree: "27° 46′", house: "4", angle: 357, tone: "cool" },
  { symbol: "♀", name: "金星", sign: "金牛", degree: "13° 22′", house: "6", angle: 43, tone: "green" },
  { symbol: "♂", name: "火星", sign: "水瓶", degree: "05° 18′", house: "2", angle: 305, tone: "red" },
  { symbol: "♃", name: "木星", sign: "处女", degree: "06° 41′ R", house: "10", angle: 156, tone: "warm" },
  { symbol: "♄", name: "土星", sign: "水瓶", degree: "15° 32′", house: "3", angle: 315, tone: "cool" },
  { symbol: "♅", name: "天王", sign: "摩羯", degree: "17° 44′", house: "2", angle: 287, tone: "cool" },
  { symbol: "♆", name: "海王", sign: "摩羯", degree: "18° 21′", house: "2", angle: 288, tone: "violet" },
  { symbol: "♇", name: "冥王", sign: "天蝎", degree: "22° 51′ R", house: "12", angle: 232, tone: "red" },
];

const zodiac = ["♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐", "♑", "♒", "♓"];

const aspectLines = [
  { angle: 8, width: 117, type: "support" },
  { angle: 37, width: 144, type: "pressure" },
  { angle: 68, width: 132, type: "support" },
  { angle: 104, width: 152, type: "pressure" },
  { angle: 142, width: 122, type: "support" },
  { angle: 178, width: 139, type: "support" },
  { angle: 211, width: 151, type: "pressure" },
  { angle: 254, width: 128, type: "support" },
  { angle: 295, width: 148, type: "pressure" },
  { angle: 329, width: 116, type: "support" },
];

const chartModeLabels: Record<ChartMode, string> = {
  natal: "本命",
  transit: "行运",
  synastry: "比较",
  return: "太阳返照",
};

function GlyphIcon({ children }: { children: ReactNode }) {
  return <span className="glyph-icon" aria-hidden="true">{children}</span>;
}

function ChartWheel({ compact = false }: { compact?: boolean }) {
  const sizeClass = compact ? "chart-wheel compact" : "chart-wheel";
  return (
    <div className={sizeClass} aria-label="林澈本命盘轮盘图">
      <div className="zodiac-ring" />
      <div className="house-ring" />
      <div className="inner-ring" />
      <div className="axis axis-horizontal" />
      <div className="axis axis-vertical" />
      {zodiac.map((symbol, index) => {
        const angle = index * 30 + 15;
        return (
          <span
            className="zodiac-symbol"
            key={symbol}
            style={{ transform: `rotate(${angle}deg) translateY(${compact ? -116 : -167}px) rotate(${-angle}deg)` }}
          >
            {symbol}
          </span>
        );
      })}
      {Array.from({ length: 12 }).map((_, index) => {
        const angle = index * 30 + 15;
        return (
          <span
            className="house-number"
            key={index}
            style={{ transform: `rotate(${angle}deg) translateY(${compact ? -82 : -119}px) rotate(${-angle}deg)` }}
          >
            {index + 1}
          </span>
        );
      })}
      <div className="aspect-field">
        {aspectLines.map((line, index) => (
          <span
            className={`aspect-line ${line.type}`}
            key={`${line.angle}-${index}`}
            style={{
              width: compact ? line.width * 0.68 : line.width,
              transform: `rotate(${line.angle}deg)`,
            }}
          />
        ))}
      </div>
      {planets.map((planet, index) => (
        <button
          className={`planet-marker ${planet.tone}`}
          key={`${planet.symbol}-${index}`}
          style={{ transform: `rotate(${planet.angle}deg) translateY(${compact ? -98 : -141}px) rotate(${-planet.angle}deg)` }}
          title={`${planet.name} · ${planet.sign} ${planet.degree} · 第${planet.house}宫`}
        >
          {planet.symbol}
        </button>
      ))}
      <div className="chart-core">
        <span className="core-label">ASC</span>
        <strong>19°07′</strong>
        <small>天蝎座</small>
      </div>
      <span className="axis-label asc">ASC 19°</span>
      <span className="axis-label mc">MC 24°</span>
    </div>
  );
}

function LibraryItem({
  subject,
  active,
  onClick,
}: {
  subject: (typeof subjects)[number];
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button className={`library-item ${active ? "active" : ""}`} onClick={onClick}>
      <span className={`subject-avatar ${subject.color}`}>{subject.initials}</span>
      <span className="library-copy">
        <strong>{subject.name}</strong>
        <small>{subject.meta}</small>
      </span>
      <span className="quality-tag">{subject.tag}</span>
    </button>
  );
}

export default function Home() {
  const [activeSubjectId, setActiveSubjectId] = useState(subjects[0].id);
  const [inspectorTab, setInspectorTab] = useState<InspectorTab>("evidence");
  const [dataTab, setDataTab] = useState<DataTab>("positions");
  const [chartMode, setChartMode] = useState<ChartMode>("natal");
  const [splitView, setSplitView] = useState(false);
  const [theme, setTheme] = useState<"dark" | "light">("dark");
  const [running, setRunning] = useState(false);
  const [exportOpen, setExportOpen] = useState(false);
  const [toast, setToast] = useState("计算快照 #C-208 已加载");
  const [leftOpen, setLeftOpen] = useState(false);
  const [rightOpen, setRightOpen] = useState(false);

  const activeSubject = useMemo(
    () => subjects.find((subject) => subject.id === activeSubjectId) ?? subjects[0],
    [activeSubjectId],
  );

  const handleRun = () => {
    if (running) return;
    setRunning(true);
    setToast("正在标准化输入并计算…");
    window.setTimeout(() => {
      setRunning(false);
      setToast("计算完成 · 184 ms · 新快照 #C-209");
    }, 1250);
  };

  const handleSubject = (id: string) => {
    setActiveSubjectId(id);
    setToast("已切换对象版本，等待重新计算");
    setLeftOpen(false);
  };

  const handleExport = (format: string) => {
    setExportOpen(false);
    setToast(`${format} 导出任务已创建`);
  };

  return (
    <main className="app-shell" data-theme={theme}>
      <header className="topbar">
        <div className="brand-block">
          <div className="brand-mark" aria-hidden="true"><span>✦</span></div>
          <div>
            <strong>INTERSTELLAR</strong>
            <span>RESEARCH WORKSPACE</span>
          </div>
        </div>

        <div className="topbar-center">
          <button className="top-action primary" onClick={() => { setInspectorTab("input"); setRightOpen(true); }}>
            <GlyphIcon>＋</GlyphIcon>
            新建计算
          </button>
          <span className="toolbar-divider" />
          <button className="subject-crumb" onClick={() => setLeftOpen(true)}>
            <span className="status-dot" />
            {activeSubject.name}
            <span className="crumb-version">v4</span>
          </button>
          <span className="crumb-separator">/</span>
          <button className="mode-crumb">{chartModeLabels[chartMode]}</button>
        </div>

        <div className="topbar-actions">
          <button className="icon-button mobile-only" onClick={() => setLeftOpen(true)} aria-label="打开对象库">☰</button>
          <button className="icon-button" onClick={() => setTheme(theme === "dark" ? "light" : "dark")} aria-label="切换明暗主题">
            {theme === "dark" ? "☼" : "◐"}
          </button>
          <button className={`icon-button ${splitView ? "active" : ""}`} onClick={() => setSplitView(!splitView)} aria-pressed={splitView} aria-label="切换分屏">
            ◫
          </button>
          <div className="export-wrap">
            <button className="top-action" onClick={() => setExportOpen(!exportOpen)} aria-expanded={exportOpen}>
              导出 <span>⌄</span>
            </button>
            {exportOpen && (
              <div className="export-menu">
                {["SVG 图表", "PNG 2×", "PDF 报告", "JSON 快照", "项目归档"].map((item) => (
                  <button key={item} onClick={() => handleExport(item)}>{item}</button>
                ))}
              </div>
            )}
          </div>
          <button className={`run-button ${running ? "running" : ""}`} onClick={handleRun}>
            <span>{running ? "↻" : "▶"}</span>{running ? "计算中" : "运行"}
          </button>
          <button className="profile-button" aria-label="账户菜单">XG</button>
        </div>
      </header>

      <aside className={`library-panel ${leftOpen ? "mobile-open" : ""}`}>
        <div className="panel-heading">
          <div>
            <span className="eyebrow">WORKSPACE</span>
            <h2>研究对象</h2>
          </div>
          <button className="icon-button small mobile-close" onClick={() => setLeftOpen(false)} aria-label="关闭对象库">×</button>
        </div>
        <label className="search-box">
          <span>⌕</span>
          <input aria-label="搜索对象" placeholder="搜索人物、关系、项目…" />
          <kbd>⌘K</kbd>
        </label>

        <nav className="library-nav" aria-label="对象分类">
          <button className="active"><span>◉</span> 全部对象 <b>17</b></button>
          <button><span>♙</span> 人物 <b>5</b></button>
          <button><span>⇄</span> 关系 <b>2</b></button>
          <button><span>◇</span> 事件与项目 <b>9</b></button>
          <button><span>?</span> 问事盘 <b>1</b></button>
        </nav>

        <div className="list-section-heading">
          <span>最近使用</span>
          <button>排序 ↕</button>
        </div>
        <div className="library-list">
          {subjects.map((subject) => (
            <LibraryItem
              subject={subject}
              active={subject.id === activeSubjectId}
              onClick={() => handleSubject(subject.id)}
              key={subject.id}
            />
          ))}
        </div>

        <div className="saved-view-section">
          <div className="list-section-heading">
            <span>已存视图</span>
            <button>＋</button>
          </div>
          <button className="saved-view active"><span className="view-grid">▦</span> 本命研究台 <kbd>1</kbd></button>
          <button className="saved-view"><span className="view-grid">▥</span> 年度预测 <kbd>2</kbd></button>
          <button className="saved-view"><span className="view-grid">▦</span> 关系双盘 <kbd>3</kbd></button>
        </div>

        <div className="dataset-card">
          <div className="dataset-title"><span className="status-dot green" /> 数据集已锁定</div>
          <strong>SE 2.10 · IANA 2026c</strong>
          <small>规则包 official.modern.v1</small>
          <button onClick={() => setToast("已打开可复现性信息")}>查看版本详情 →</button>
        </div>
      </aside>

      <section className="workspace">
        <div className="workspace-header">
          <div className="subject-title-group">
            <span className={`subject-avatar large ${activeSubject.color}`}>{activeSubject.initials}</span>
            <div>
              <div className="title-row">
                <h1>{activeSubject.name}</h1>
                <span className="version-pill">版本 4</span>
                <span className="maturity-pill stable">STABLE</span>
              </div>
              <p>{activeSubject.meta} · {activeSubject.place} · <span>UTC+08:00</span></p>
            </div>
          </div>
          <div className="snapshot-meta">
            <span>快照</span>
            <strong>#C-208</strong>
            <small>14:32:08</small>
          </div>
        </div>

        <div className="technique-bar" role="tablist" aria-label="技法">
          {(Object.keys(chartModeLabels) as ChartMode[]).map((mode) => (
            <button
              key={mode}
              role="tab"
              aria-selected={chartMode === mode}
              className={chartMode === mode ? "active" : ""}
              onClick={() => { setChartMode(mode); setToast(`已切换到${chartModeLabels[mode]}技法`); }}
            >
              {chartModeLabels[mode]}
            </button>
          ))}
          <span className="technique-spacer" />
          <button className="parameter-chip"><span>宫位</span> Placidus⌄</button>
          <button className="parameter-chip"><span>黄道</span> Tropical⌄</button>
          <button className="parameter-chip icon-chip">•••</button>
        </div>

        <div className={`canvas-area ${splitView ? "split" : ""}`}>
          <article className="chart-card primary-chart">
            <div className="chart-card-heading">
              <div>
                <span className="eyebrow">PRIMARY VIEW · {chartMode.toUpperCase()}</span>
                <h2>{chartModeLabels[chartMode]}盘轮盘</h2>
              </div>
              <div className="chart-tools">
                <button title="居中">⌖</button>
                <button title="缩放">⌕</button>
                <button title="图层">▱</button>
              </div>
            </div>
            <div className="chart-stage">
              <div className="chart-index left-index">
                <span>ASC</span><strong>♏ 19°07′</strong>
                <span>MC</span><strong>♌ 24°38′</strong>
              </div>
              <ChartWheel compact={splitView} />
              <div className="chart-index right-index">
                <span>日月相位</span><strong>六分 · 2°49′</strong>
                <span>盘型</span><strong>束型</strong>
              </div>
              {running && (
                <div className="calculating-overlay">
                  <div className="orbital-loader"><span /></div>
                  <strong>正在计算</strong>
                  <small>规则命中与证据聚合</small>
                </div>
              )}
            </div>
            <footer className="chart-footer">
              <span><i className="legend-line support" /> 支持相位 9</span>
              <span><i className="legend-line pressure" /> 压力相位 6</span>
              <span><i className="legend-dot" /> 容许度 ≤ 6°</span>
              <button onClick={() => setInspectorTab("evidence")}>查看全部证据 →</button>
            </footer>
          </article>

          {splitView && (
            <article className="chart-card comparison-chart">
              <div className="chart-card-heading">
                <div>
                  <span className="eyebrow">SECONDARY VIEW · TRANSIT</span>
                  <h2>当前行运</h2>
                </div>
                <button className="close-split" onClick={() => setSplitView(false)}>×</button>
              </div>
              <div className="chart-stage compact-stage">
                <ChartWheel compact />
              </div>
              <footer className="chart-footer compact-footer">
                <span><i className="legend-dot amber" /> 精确命中 3</span>
                <span>2026.07.17 14:32</span>
              </footer>
            </article>
          )}
        </div>

        <section className="data-dock">
          <div className="data-tabs" role="tablist" aria-label="结构化数据">
            {([
              ["positions", "行星位置", 14],
              ["houses", "宫位", 12],
              ["aspects", "相位", 18],
              ["strength", "力量与尊贵", 8],
            ] as [DataTab, string, number][]).map(([key, label, count]) => (
              <button
                key={key}
                role="tab"
                aria-selected={dataTab === key}
                onClick={() => setDataTab(key)}
                className={dataTab === key ? "active" : ""}
              >
                {label}<span>{count}</span>
              </button>
            ))}
            <span className="data-spacer" />
            <button className="dock-control">筛选⌄</button>
            <button className="dock-control">↥</button>
          </div>
          <div className="table-wrap">
            {dataTab === "positions" && (
              <table>
                <thead><tr><th>天体</th><th>黄经</th><th>星座位置</th><th>宫位</th><th>速度</th><th>状态</th></tr></thead>
                <tbody>
                  {planets.slice(0, 6).map((planet) => (
                    <tr key={planet.name}>
                      <td><span className={`table-symbol ${planet.tone}`}>{planet.symbol}</span><strong>{planet.name}</strong></td>
                      <td>{planet.angle.toFixed(4)}°</td>
                      <td>{planet.sign} <b>{planet.degree}</b></td>
                      <td>第 {planet.house} 宫</td>
                      <td className="mono">+0.{planet.angle.toString().padStart(4, "0")}°/d</td>
                      <td><span className={`motion-state ${planet.degree.includes("R") ? "retro" : ""}`}>{planet.degree.includes("R") ? "逆行" : "顺行"}</span></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
            {dataTab === "houses" && <DockMessage title="宫位与宫主星" copy="12个宫头、宫主星落座、落宫和定位星链已载入。" values={["ASC ♏ 19°07′", "MC ♌ 24°38′", "2宫 ♐ 18°12′"]} />}
            {dataTab === "aspects" && <DockMessage title="18条本命相位" copy="按容许度排序；支持、压力和中性证据分别保留。" values={["☉ ✶ ☽ 2°49′", "♀ △ ♃ 6°41′", "♂ □ ♇ 2°27′"]} />}
            {dataTab === "strength" && <DockMessage title="行星力量与尊贵" copy="当前使用 official.modern.v1；古典尊贵保持Beta标签。" values={["土星 82", "火星 74", "金星 68"]} />}
          </div>
        </section>
      </section>

      <aside className={`inspector-panel ${rightOpen ? "mobile-open" : ""}`}>
        <div className="inspector-tabs" role="tablist" aria-label="检查器">
          {([
            ["input", "输入"],
            ["params", "参数"],
            ["result", "结果"],
            ["evidence", "证据"],
          ] as [InspectorTab, string][]).map(([key, label]) => (
            <button key={key} role="tab" aria-selected={inspectorTab === key} className={inspectorTab === key ? "active" : ""} onClick={() => setInspectorTab(key)}>{label}</button>
          ))}
          <button className="mobile-close inspector-close" onClick={() => setRightOpen(false)} aria-label="关闭检查器">×</button>
        </div>
        <div className="inspector-content">
          {inspectorTab === "input" && <InputPanel subject={activeSubject} onRun={handleRun} />}
          {inspectorTab === "params" && <ParameterPanel />}
          {inspectorTab === "result" && <ResultPanel />}
          {inspectorTab === "evidence" && <EvidencePanel />}
        </div>
        <footer className="inspector-footer">
          <span className="status-dot green" />
          <div><strong>结果可复现</strong><small>输入、引擎、数据和规则版本已锁定</small></div>
          <button aria-label="查看可复现性信息">›</button>
        </footer>
      </aside>

      <div className="mobile-bottom-bar">
        <button onClick={() => setLeftOpen(true)}><span>☰</span>对象</button>
        <button className="active"><span>◎</span>星盘</button>
        <button onClick={handleRun}><span>▶</span>运行</button>
        <button onClick={() => { setInspectorTab("evidence"); setRightOpen(true); }}><span>≡</span>证据</button>
      </div>

      {(leftOpen || rightOpen) && <button className="mobile-scrim" aria-label="关闭面板" onClick={() => { setLeftOpen(false); setRightOpen(false); }} />}
      <div className="status-toast" role="status"><span className={running ? "pulse-dot" : "status-dot green"} />{toast}</div>
    </main>
  );
}

function DockMessage({ title, copy, values }: { title: string; copy: string; values: string[] }) {
  return (
    <div className="dock-message">
      <div><span className="eyebrow">STRUCTURED DATA</span><h3>{title}</h3><p>{copy}</p></div>
      <div className="dock-values">{values.map((value) => <span key={value}>{value}</span>)}</div>
    </div>
  );
}

function InputPanel({ subject, onRun }: { subject: (typeof subjects)[number]; onRun: () => void }) {
  return (
    <div className="panel-stack">
      <div className="inspector-heading"><span className="eyebrow">SOURCE DATA</span><h2>输入资料</h2><p>修改后将创建新的对象版本，不会覆盖历史快照。</p></div>
      <label className="field"><span>对象名称</span><input defaultValue={subject.name} /></label>
      <div className="field-row">
        <label className="field"><span>日期</span><input defaultValue="1992-03-28" /></label>
        <label className="field"><span>当地时间</span><input defaultValue="21:16" /></label>
      </div>
      <label className="field"><span>时间精度</span><select defaultValue="minute"><option value="minute">精确到分钟</option><option value="hour">约一小时</option><option value="unknown">未知</option></select></label>
      <label className="field"><span>出生地点</span><input defaultValue={subject.place} /><small>31.2304° N · 121.4737° E</small></label>
      <div className="validation-card success"><span>✓</span><div><strong>时间转换无歧义</strong><small>1992-03-28 13:16:00 UTC · IANA 2026c</small></div></div>
      <button className="panel-primary-button" onClick={onRun}>创建新版本并运行</button>
    </div>
  );
}

function ParameterPanel() {
  return (
    <div className="panel-stack">
      <div className="inspector-heading"><span className="eyebrow">CALCULATION</span><h2>计算参数</h2><p>所有默认值都会写入请求指纹和计算快照。</p></div>
      <label className="field"><span>宫位制</span><select defaultValue="placidus"><option value="placidus">Placidus</option><option value="whole">Whole Sign</option><option value="equal">Equal House</option></select></label>
      <label className="field"><span>黄道体系</span><select defaultValue="tropical"><option value="tropical">Tropical</option><option value="sidereal">Sidereal</option></select></label>
      <label className="field"><span>月交点</span><select defaultValue="true"><option value="true">True Node</option><option value="mean">Mean Node</option></select></label>
      <fieldset className="toggle-group"><legend>显示图层</legend>{["主要相位", "次要相位", "小行星", "固定星"].map((item, index) => <label key={item}><input type="checkbox" defaultChecked={index < 2} /><span>{item}</span></label>)}</fieldset>
      <div className="parameter-summary"><span>规则包</span><strong>official.modern.v1</strong><small>sha256 · b82f…98a1</small></div>
    </div>
  );
}

function ResultPanel() {
  return (
    <div className="panel-stack">
      <div className="inspector-heading"><span className="eyebrow">RESULT SUMMARY</span><h2>结构化结果</h2><p>结果只描述盘面事实与主题活跃度，不输出确定性事件概率。</p></div>
      <div className="metric-grid">
        <Metric value="76" label="事业活跃" tone="blue" />
        <Metric value="62" label="关系活跃" tone="amber" />
        <Metric value="71" label="当前压力" tone="red" />
        <Metric value="84" label="证据确定度" tone="green" />
      </div>
      <div className="result-block"><span className="block-kicker">核心结构</span><h3>固定能量集中，行动与控制议题明显</h3><p>土星、水瓶座与第三宫重复出现；火星—冥王星压力相位提高表达与执行的强度。</p></div>
      <div className="result-block"><span className="block-kicker">当前周期</span><h3>职业可见度进入扩张窗口</h3><p>木星触发MC，同时太阳返照与年度小限指向第十宫主题。</p></div>
    </div>
  );
}

function Metric({ value, label, tone }: { value: string; label: string; tone: string }) {
  return <div className={`metric-card ${tone}`}><strong>{value}</strong><span>{label}</span><i style={{ "--metric": `${value}%` } as CSSProperties} /></div>;
}

function EvidencePanel() {
  return (
    <div className="panel-stack evidence-stack">
      <div className="inspector-heading"><span className="eyebrow">EVIDENCE CHAIN</span><h2>结构与证据</h2><p>每条结论均可回溯到配置、规则、时间窗口和算法来源。</p></div>
      <div className="confidence-card">
        <div className="confidence-ring"><strong>84</strong><small>/100</small></div>
        <div><span>证据确定度</span><strong>多技法同向</strong><small>4条支持 · 2条压力 · 1条反证</small></div>
      </div>
      <div className="evidence-section">
        <div className="section-label"><span>当前重点</span><small>按权重排序</small></div>
        <EvidenceItem tone="support" icon="♃" title="事业可见度上升" meta="行运木星 合 MC · 0°18′" weight="0.92" tags={["行运", "第10宫"]} />
        <EvidenceItem tone="support" icon="☉" title="年度主题聚焦事业" meta="太阳返照 · 木星落第10宫" weight="0.81" tags={["返照", "年度"]} />
        <EvidenceItem tone="pressure" icon="♄" title="责任与延迟并存" meta="行运土星 刑 本命太阳 · 1°04′" weight="0.78" tags={["压力", "长期"]} />
        <EvidenceItem tone="counter" icon="♀" title="合作条件提供缓冲" meta="金星 拱 木星 · 出相 2°12′" weight="0.54" tags={["反证", "关系"]} />
      </div>
      <button className="outline-button">展开全部 18 条证据</button>
      <div className="provenance-block"><span>算法来源</span><strong>ALG-TRN-001 · v1.2.0</strong><small>Swiss Ephemeris 2.10 · 已通过金标准</small></div>
    </div>
  );
}

function EvidenceItem({ tone, icon, title, meta, weight, tags }: { tone: string; icon: string; title: string; meta: string; weight: string; tags: string[] }) {
  return (
    <article className={`evidence-item ${tone}`}>
      <span className="evidence-icon">{icon}</span>
      <div className="evidence-copy"><strong>{title}</strong><small>{meta}</small><div>{tags.map((tag) => <span key={tag}>{tag}</span>)}</div></div>
      <span className="evidence-weight">{weight}</span>
    </article>
  );
}
