import type { NatalSnapshot } from '../../lib/interstellar-api';
import type { CalculationTab, CurrentSkyResultTab } from '../lib/chart-types';
import { pointNames, aspectNames, currentSkyResultTabs, currentSkySharedResultTabs } from '../lib/chart-constants';
import { aspectPhaseLabel, lunarPhaseLabel } from '../lib/chart-labels';
import { asRecord } from '../lib/chart-utils';
import { CalculationResults } from '../results/calculation-results';

export function CurrentSkyCalculationPanel({ snapshot, resultTab, setResultTab, onBack }: { snapshot: NatalSnapshot | null; resultTab: CurrentSkyResultTab; setResultTab: (tab: CurrentSkyResultTab) => void; onBack: () => void; }) {
  if (!snapshot) return null;
  const context = asRecord(snapshot.result.astronomical_context);
  const lunarPhase = asRecord(context.lunar_phase);
  const strongestAspects = [...snapshot.result.aspects].sort((a, b) => b.strength - a.strength).slice(0, 5);
  const stationaryPoints = snapshot.result.points.filter((p) => p.position.motion_state === "stationary");
  const retrogradePoints = snapshot.result.points.filter((p) => p.retrograde);
  return (
    <>
      <div className="calculation-view-toolbar"><button onClick={onBack}>← 返回轮盘</button><span>{snapshot.result.points.length} 点 · {snapshot.result.aspects.length} 相位</span></div>
      <nav className="calculation-result-tabs" aria-label="天象盘计算结果分类">{currentSkyResultTabs.map((item) => <button key={item.id} className={resultTab === item.id ? "active" : ""} onClick={() => setResultTab(item.id)}>{item.label}</button>)}</nav>
      {currentSkySharedResultTabs.has(resultTab) && <CalculationResults snapshot={snapshot} tab={resultTab as CalculationTab} />}
      {resultTab === "aspects" && <div className="calculation-result-content"><div className="aspect-table"><div className="aspect-head"><span>点位 A</span><span>相位</span><span>点位 B</span><span>实际角距</span><span>容许度</span><span>阶段</span><span>强度</span></div>{snapshot.result.aspects.map((aspect) => <div className="aspect-row" key={aspect.aspect_id}><span>{pointNames[aspect.point_a] ?? aspect.point_a}</span><b>{aspectNames[aspect.type] ?? aspect.type}</b><span>{pointNames[aspect.point_b] ?? aspect.point_b}</span><span>{aspect.actual_angle_deg.toFixed(3)}°</span><span>{aspect.orb_deg.toFixed(3)}°</span><span>{aspectPhaseLabel(aspect.applying_state) ?? "—"}</span><span>{Math.round(aspect.strength * 100)}%</span></div>)}</div></div>}
      {resultTab === "events" && <div className="calculation-result-content"><div className="section-copy"><div><small>EXACT MOMENT SKY FACTS</small><h2>目标时刻天象</h2><p>这里展示本次精确时刻已经成立的事实。</p></div></div><div className="fact-card-grid"><article className="professional-card"><h3>月相</h3><p>{lunarPhaseLabel(lunarPhase.phase)}；月龄约 {Number(lunarPhase.lunar_age_days ?? 0).toFixed(1)} 天，亮面约 {Math.round(Number(lunarPhase.illumination_fraction ?? 0) * 100)}%。</p></article><article className="professional-card"><h3>逆行行星</h3><p>{retrogradePoints.map((point) => pointNames[point.point_id] ?? point.point_id).join("、") || "当前所选点位中无逆行行星"}</p></article><article className="professional-card"><h3>停驻点位</h3><p>{stationaryPoints.map((point) => pointNames[point.point_id] ?? point.point_id).join("、") || "当前精确时刻没有点位处于停驻阈值内"}</p></article><article className="professional-card"><h3>最紧密相位</h3><p>{strongestAspects.slice(0, 3).map((aspect) => `${pointNames[aspect.point_a] ?? aspect.point_a}${aspectNames[aspect.type] ?? aspect.type}${pointNames[aspect.point_b] ?? aspect.point_b}（${aspect.orb_deg.toFixed(2)}°）`).join("；") || "当前相位集没有命中"}</p></article></div></div>}
    </>
  );
}
