import type { NatalSnapshot, ChartComparison } from '../../lib/interstellar-api';
import type { CalculationTab, TransitResultTab } from '../lib/chart-types';
import { pointNames, aspectNames, transitResultTabs, transitSharedResultTabs, houseDomains } from '../lib/chart-constants';
import { aspectPhaseLabel } from '../lib/chart-labels';
import { asRecord } from '../lib/chart-utils';
import { CalculationResults } from '../results/calculation-results';

export function TransitCalculationPanel({ comparison, movingLayer, resultTab, setResultTab, onBack }: { comparison: ChartComparison | null; movingLayer: NatalSnapshot | null; resultTab: TransitResultTab; setResultTab: (tab: TransitResultTab) => void; onBack: () => void; }) {
  if (!comparison || !movingLayer) return null;
  return (
    <>
      <div className="calculation-view-toolbar"><button onClick={onBack}>← 返回轮盘</button><span>{movingLayer.result.points.length} 点 · {comparison.result.cross_aspects.length} 跨盘相位</span></div>
      <nav className="calculation-result-tabs" aria-label="行运盘计算结果分类">{transitResultTabs.map((item) => <button key={item.id} className={resultTab === item.id ? "active" : ""} onClick={() => setResultTab(item.id)}>{item.label}</button>)}</nav>
      {resultTab === "overview" && <div className="calculation-result-content"><div className="calculation-summary-grid"><article><span>本命点位</span><b>{comparison.result.reference_snapshot_id ? "已加载" : "—"}</b><small>上一次已计算结果</small></article><article><span>行运点位</span><b>{movingLayer.result.points.length}</b><small>目标时刻天空</small></article><article><span>天象盘内相位</span><b>{movingLayer.result.aspects.length}</b><small>行运点位彼此关系</small></article><article><span>跨盘相位</span><b>{comparison.result.cross_aspects.length}</b><small>行运点对本命点</small></article></div></div>}
      {transitSharedResultTabs.has(resultTab) && <CalculationResults snapshot={movingLayer} tab={resultTab as CalculationTab} />}
      {resultTab === "aspects" && <div className="calculation-result-content"><div className="aspect-table"><div className="aspect-head"><span>行运点 A</span><span>相位</span><span>行运点 B</span><span>实际角距</span><span>容许度</span><span>阶段</span><span>强度</span></div>{movingLayer.result.aspects.map((aspect) => <div className="aspect-row" key={aspect.aspect_id}><span>{pointNames[aspect.point_a] ?? aspect.point_a}</span><b>{aspectNames[aspect.type] ?? aspect.type}</b><span>{pointNames[aspect.point_b] ?? aspect.point_b}</span><span>{aspect.actual_angle_deg.toFixed(3)}°</span><span>{aspect.orb_deg.toFixed(3)}°</span><span>{aspectPhaseLabel(aspect.applying_state) ?? "—"}</span><span>{Math.round(aspect.strength * 100)}%</span></div>)}</div></div>}
      {resultTab === "cross_aspects" && <div className="calculation-result-content"><div className="aspect-table"><div className="aspect-head"><span>行运点</span><span>相位</span><span>本命点</span><span>实际角距</span><span>偏差</span><span>阶段</span><span>强度</span></div>{comparison.result.cross_aspects.map((aspect) => <div className="aspect-row" key={aspect.aspect_id}><span>{pointNames[aspect.moving_point_id] ?? aspect.moving_point_id}</span><b>{aspectNames[aspect.type] ?? aspect.type}</b><span>{pointNames[aspect.reference_point_id] ?? aspect.reference_point_id}</span><span>{aspect.actual_angle_deg.toFixed(3)}°</span><span>{aspect.orb_deg.toFixed(3)}°</span><span>{aspectPhaseLabel(aspect.applying_state) ?? "—"}</span><span>{Math.round(aspect.strength * 100)}%</span></div>)}</div></div>}
      {resultTab === "reference_houses" && <div className="calculation-result-content"><div className="wide-result-table house-result-table"><div className="wide-result-head"><span>行运点</span><span>落入本命宫位</span><span>生活领域</span><span>是否贴近宫头</span><span>宫头编号</span></div>{comparison.result.moving_points_in_reference_houses.map((item) => <div className="wide-result-row" key={item.moving_point_id}><b>{pointNames[item.moving_point_id] ?? item.moving_point_id}</b><span>第{item.reference_house}宫</span><span>{houseDomains[item.reference_house - 1]}</span><span>{item.on_cusp ? "是" : "否"}</span><span>{item.cusp_number ?? "—"}</span></div>)}</div></div>}
    </>
  );
}
