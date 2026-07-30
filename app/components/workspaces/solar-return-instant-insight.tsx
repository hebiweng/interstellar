import type { CSSProperties } from "react";
import type { ChartComparison, NatalSnapshot } from "../../lib/interstellar-api";
import type { SolarReturnRightPanel } from "../../lib/insight/solar-return";
import { displayCorpus } from "../../lib/insight/solar-return-corpus";

type SolarReturnInstantInsightProps = {
  comparison: ChartComparison | null;
  returnSnapshot: NatalSnapshot | null;
  rightPanel: SolarReturnRightPanel;
};

function compact(text: string): string {
  return text.split(/[。；]/)[0].replace(/：$/, "").trim();
}

const stateColors: Record<string, string> = {
  "背景": "#4b5563",
  "轻度": "#60a5fa",
  "活跃": "#3b82f6",
  "高活跃": "#f59e0b",
  "密集": "#ef4444",
};

// ─── Card A: 年度主轴罗盘 ─────────────────────────────────

function AnnualCompassCard({ card, topIndex }: { card: SolarReturnRightPanel["cards"][number]; topIndex: SolarReturnRightPanel["topIndex"] }) {
  const total = topIndex.career + topIndex.relationship + topIndex.resource + topIndex.inner;
  const maxVal = Math.max(topIndex.career, topIndex.relationship, topIndex.resource, topIndex.inner, 1);
  return <section className="insight-card-sp sr-card-compass">
    <header className="insight-card-sp-header">
      <span className="insight-card-sp-icon">{card.icon}</span>
      <div><b>{card.title}</b><span className="sr-index-badge" style={{ color: stateColors[topIndex.state] }}>{topIndex.score}/100 {topIndex.state} {topIndex.directionLabel}</span></div>
    </header>
    <div className="sr-compass-visual">
      <div className="sr-compass-ring" style={{ "--compass-angle": `${(topIndex.career / maxVal) * 90}deg` } as CSSProperties}>
        <div className="sr-compass-center">
          <span className="sr-compass-score">{topIndex.score}</span>
          <span className="sr-compass-label">年度主轴</span>
        </div>
        <div className="sr-compass-n" style={{ opacity: 0.3 + 0.7 * (topIndex.career / maxVal) }}>N · 事业 {topIndex.career}</div>
        <div className="sr-compass-e" style={{ opacity: 0.3 + 0.7 * (topIndex.resource / maxVal) }}>E · 资源 {topIndex.resource}</div>
        <div className="sr-compass-s" style={{ opacity: 0.3 + 0.7 * (topIndex.inner / maxVal) }}>S · 内在 {topIndex.inner}</div>
        <div className="sr-compass-w" style={{ opacity: 0.3 + 0.7 * (topIndex.relationship / maxVal) }}>W · 关系 {topIndex.relationship}</div>
      </div>
    </div>
    <div className="sr-compass-sub">
      <span>主题密度 {Math.round(topIndex.score * 0.55)}</span>
      <span>结构清晰 {Math.round(topIndex.score * 0.45)}</span>
    </div>
    <div className="sr-compass-signals">
      {topIndex.topSignals.map((sig, i) => <span key={i} className="sr-signal-tag">{'\u2460\u2461\u2462'[i] ?? ''} {sig}</span>)}
    </div>
    <p className="sr-card-summary">{compact(card.summary)}</p>
  </section>;
}

// ─── Card B: 12个月节律环 ─────────────────────────────────

function MonthlyRhythmCard({ card }: { card: SolarReturnRightPanel["cards"][number] }) {
  return <section className="insight-card-sp sr-card-rhythm">
    <header className="insight-card-sp-header">
      <span className="insight-card-sp-icon">{card.icon}</span>
      <div><b>{card.title}</b></div>
    </header>
    <div className="sr-rhythm-ring">
      <div className="sr-rhythm-inner">
        <span className="sr-rhythm-center-label">年度节律</span>
      </div>
      {Array.from({ length: 12 }, (_, i) => {
        const label = `${i + 1}月`;
        return <div key={i} className="sr-rhythm-month" style={{ transform: `rotate(${i * 30}deg)` }}>
          <span style={{ transform: `rotate(${-i * 30}deg)` }}>{label}</span>
        </div>;
      })}
    </div>
    <div className="sr-rhythm-details">
      {card.details.slice(0, 3).map((detail, i) => <span key={i} className="sr-rhythm-item">{compact(detail)}</span>)}
    </div>
    <p className="sr-card-summary">{compact(card.summary)}</p>
  </section>;
}

// ─── Card C: 四季度地形图 ─────────────────────────────────

function QuarterlyTerrainCard({ card, topIndex }: { card: SolarReturnRightPanel["cards"][number]; topIndex: SolarReturnRightPanel["topIndex"] }) {
  // 从details解析季度分数
  const quarters = card.details.map(d => {
    const match = d.match(/(Q\d)：.+（高度 (\d+)）/);
    return match ? { key: match[1], score: Number(match[2]) } : null;
  }).filter(Boolean) as { key: string; score: number }[];
  const maxQ = Math.max(...quarters.map(q => q.score), 1);
  const labels: Record<string, string> = { Q1: "建基", Q2: "推进", Q3: "峰值", Q4: "收束" };
  return <section className="insight-card-sp sr-card-terrain">
    <header className="insight-card-sp-header">
      <span className="insight-card-sp-icon">{card.icon}</span>
      <div><b>{card.title}</b><span className="sr-peak-badge">峰值: {quarters.reduce((a, b) => a.score > b.score ? a : b).key}</span></div>
    </header>
    <div className="sr-terrain-chart">
      {quarters.map((q, i) => <div key={i} className="sr-terrain-bar" style={{ height: `${Math.max(10, q.score / maxQ * 100)}%` }}>
        <span className="sr-terrain-value">{q.score}</span>
      </div>)}
      <div className="sr-terrain-labels">
        {quarters.map((q, i) => <span key={i}>{q.key}<br />{labels[q.key] ?? ""}</span>)}
      </div>
    </div>
    <p className="sr-card-summary">{compact(card.summary)}</p>
  </section>;
}

// ─── Card D: 年度领域天际线 ─────────────────────────────────

function DomainSkylineCard({ card }: { card: SolarReturnRightPanel["cards"][number] }) {
  const buildings = card.details.map(d => {
    const match = d.match(/(.+)：(.+)（(\d+)）/);
    return match ? { label: match[1], text: match[2], score: Number(match[3]) } : { label: "", text: d, score: 40 };
  });
  const maxB = Math.max(...buildings.map(b => b.score), 1);
  return <section className="insight-card-sp sr-card-skyline">
    <header className="insight-card-sp-header">
      <span className="insight-card-sp-icon">{card.icon}</span>
      <div><b>{card.title}</b></div>
    </header>
    <div className="sr-skyline-chart">
      {buildings.map((b, i) => <div key={i} className="sr-skyline-building" style={{ height: `${Math.max(15, b.score / maxB * 100)}%` }}>
        <span className="sr-skyline-label">{b.label}</span>
      </div>)}
    </div>
    <p className="sr-card-summary">{compact(card.summary)}</p>
  </section>;
}

// ─── Card E: 关系气候带 ─────────────────────────────────

function RelationshipClimateCard({ card }: { card: SolarReturnRightPanel["cards"][number] }) {
  return <section className="insight-card-sp sr-card-climate">
    <header className="insight-card-sp-header">
      <span className="insight-card-sp-icon">{card.icon}</span>
      <div><b>{card.title}</b></div>
    </header>
    <div className="sr-climate-band">
      <div className="sr-climate-gradient" />
    </div>
    <div className="sr-climate-details">
      {card.details.map((detail, i) => <span key={i} className="sr-climate-item">{compact(detail)}</span>)}
    </div>
    <p className="sr-card-summary">{compact(card.summary)}</p>
  </section>;
}

// ─── Card F: 事业定位阶梯 ─────────────────────────────────

function CareerLadderCard({ card }: { card: SolarReturnRightPanel["cards"][number] }) {
  const steps = ["①试探", "②定位", "③承担", "④被看见"];
  const currentDetail = card.details[0] ?? "";
  const currentLevelMatch = currentDetail.match(/当前阶段：(.+)/);
  const currentLevel = currentLevelMatch ? currentLevelMatch[1] : "①试探";
  const activeIndex = steps.findIndex(s => currentLevel.includes(s.substring(0, 2)));
  return <section className="insight-card-sp sr-card-ladder">
    <header className="insight-card-sp-header">
      <span className="insight-card-sp-icon">{card.icon}</span>
      <div><b>{card.title}</b><span className="sr-ladder-badge">当前层: {steps[Math.max(0, activeIndex)] ?? "①"}</span></div>
    </header>
    <div className="sr-ladder-visual">
      {steps.map((step, i) => <div key={i} className={`sr-ladder-step ${i <= Math.max(0, activeIndex) ? "active" : ""}`}>
        <span>{step}</span>
      </div>).reverse()}
    </div>
    <div className="sr-ladder-details">
      {card.details.slice(1).map((detail, i) => <span key={i}>{compact(detail)}</span>)}
    </div>
    <p className="sr-card-summary">{compact(card.summary)}</p>
  </section>;
}

// ─── Card G: 资源蓄水池 ─────────────────────────────────

function ResourcePoolCard({ card }: { card: SolarReturnRightPanel["cards"][number] }) {
  const netMatch = card.details[0]?.match(/净变化：(.+) 水位 (\d+)%/);
  const netLabel = netMatch ? netMatch[1] : "流动→";
  const waterLevel = netMatch ? Number(netMatch[2]) : 50;
  return <section className="insight-card-sp sr-card-pool">
    <header className="insight-card-sp-header">
      <span className="insight-card-sp-icon">{card.icon}</span>
      <div><b>{card.title}</b><span className="sr-pool-badge">净变化: {netLabel}</span></div>
    </header>
    <div className="sr-pool-visual">
      <div className="sr-pool-input">
        <span>收入</span><span>人脉</span><span>支持</span>
      </div>
      <div className="sr-pool-tank">
        <div className="sr-pool-water" style={{ height: `${waterLevel}%` }}>
          <span>{waterLevel}%</span>
        </div>
      </div>
      <div className="sr-pool-output">
        <span>支出</span><span>消耗</span>
      </div>
    </div>
    <p className="sr-card-summary">{compact(card.summary)}</p>
  </section>;
}

// ─── Card H: 压力—机会桥 ─────────────────────────────────

function PressureBridgeCard({ card }: { card: SolarReturnRightPanel["cards"][number] }) {
  return <section className="insight-card-sp sr-card-bridge">
    <header className="insight-card-sp-header">
      <span className="insight-card-sp-icon">{card.icon}</span>
      <div><b>{card.title}</b></div>
    </header>
    <div className="sr-bridge-visual">
      <div className="sr-bridge-left">
        <b>压力岸</b>
        {card.details[0]?.replace("压力岸：", "").split("；").map((s, i) => <span key={i}>·{s}</span>)}
      </div>
      <div className="sr-bridge-center">
        <span>转化桥</span>
        <span>调整打法</span>
        <span>建立流程</span>
        <span>设定边界</span>
      </div>
      <div className="sr-bridge-right">
        <b>机会岸</b>
        {card.details[2]?.replace("机会岸：", "").split("；").map((s, i) => <span key={i}>·{s}</span>)}
      </div>
    </div>
    <p className="sr-card-summary">{compact(card.summary)}</p>
  </section>;
}

// ─── Card I: 年度承诺追踪 ─────────────────────────────────

function CommitmentTrackerCard({ card }: { card: SolarReturnRightPanel["cards"][number] }) {
  return <section className="insight-card-sp sr-card-commitment">
    <header className="insight-card-sp-header">
      <span className="insight-card-sp-icon">{card.icon}</span>
      <div><b>{card.title}</b></div>
    </header>
    <div className="sr-commitment-list">
      {card.details.map((detail, i) => {
        const match = detail.match(/(\d+)\. (.+) \[(\d+)%\](?: — (.+))?/);
        if (!match) return null;
        return <div key={i} className="sr-commitment-item">
          <div className="sr-commitment-header">
            <span>{match[1]}. {match[2]}</span>
            <span>{match[3]}%</span>
          </div>
          <div className="sr-commitment-bar">
            <span style={{ width: `${match[3]}%` }} />
          </div>
          {match[4] && <small>{match[4]}</small>}
        </div>;
      })}
    </div>
    <p className="sr-card-summary">{compact(card.summary)}</p>
  </section>;
}

// ─── Card J: 年度行动路线书 ─────────────────────────────────

function ActionRouteCard({ card }: { card: SolarReturnRightPanel["cards"][number] }) {
  const routeSteps = card.details.filter(d => !d.startsWith("⚠")).map(d => {
    const match = d.match(/（(.+?)）：(.+)/);
    return match ? { period: match[1], action: match[2] } : { period: "", action: d };
  });
  const warningItem = card.details.find(d => d.startsWith("\u26A0"));
  return <section className="insight-card-sp sr-card-route">
    <header className="insight-card-sp-header">
      <span className="insight-card-sp-icon">{card.icon}</span>
      <div><b>{card.title}</b></div>
    </header>
    <div className="sr-route-visual">
      <div className="sr-route-line">
        {routeSteps.map((step, i) => <div key={i} className="sr-route-node">
          <span className="sr-route-dot" />
          <div>
            <b>{step.period}</b>
            <span>{step.action}</span>
          </div>
        </div>)}
      </div>
    </div>
    {warningItem && <div className="sr-route-warning">{warningItem}</div>}
    <p className="sr-card-summary">{compact(card.summary)}</p>
  </section>;
}

// ─── 主组件 ─────────────────────────────────────────────────

export function SolarReturnInstantInsight({ rightPanel }: SolarReturnInstantInsightProps) {
  const cardById = new Map(rightPanel.cards.map(c => [c.id, c]));
  const get = (id: string) => cardById.get(id);

  return <article className="instant-insight sr-instant-insight">
    {/* 顶部固定区：年度主轴指数 */}
    <section className="sr-top-index" style={{ borderColor: stateColors[rightPanel.topIndex.state] }}>
      <div className="sr-top-index-score">
        <span className="sr-top-index-number">{rightPanel.topIndex.score}</span>
        <span className="sr-top-index-label">{rightPanel.topIndex.state}</span>
      </div>
      <div className="sr-top-index-direction">
        <b>力量指向【{rightPanel.topIndex.directionLabel}】</b>
        <span>▲+{rightPanel.topIndex.score > 50 ? Math.round(rightPanel.topIndex.score * 0.1) : 0}</span>
      </div>
      <div className="sr-top-index-signals">
        {rightPanel.topIndex.topSignals.map((sig, i) => <span key={i}>{'\u2460\u2461\u2462'[i]} {sig}</span>)}
      </div>
    </section>

    {/* Card A: 年度主轴罗盘 */}
    {get("annual-compass") && <AnnualCompassCard card={get("annual-compass")!} topIndex={rightPanel.topIndex} />}

    {/* Card B: 12个月节律环 */}
    {get("monthly-rhythm") && <MonthlyRhythmCard card={get("monthly-rhythm")!} />}

    {/* Card C: 四季度地形图 */}
    {get("quarterly-terrain") && <QuarterlyTerrainCard card={get("quarterly-terrain")!} topIndex={rightPanel.topIndex} />}

    {/* Card D: 年度领域天际线 */}
    {get("domain-skyline") && <DomainSkylineCard card={get("domain-skyline")!} />}

    {/* Card E: 关系气候带 */}
    {get("relationship-climate") && <RelationshipClimateCard card={get("relationship-climate")!} />}

    {/* Card F: 事业定位阶梯 */}
    {get("career-ladder") && <CareerLadderCard card={get("career-ladder")!} />}

    {/* Card G: 资源蓄水池 */}
    {get("resource-pool") && <ResourcePoolCard card={get("resource-pool")!} />}

    {/* Card H: 压力—机会桥 */}
    {get("pressure-bridge") && <PressureBridgeCard card={get("pressure-bridge")!} />}

    {/* Card I: 年度承诺追踪 */}
    {get("commitment-tracker") && <CommitmentTrackerCard card={get("commitment-tracker")!} />}

    {/* Card J: 年度行动路线书 */}
    {get("action-route") && <ActionRouteCard card={get("action-route")!} />}
  </article>;
}
