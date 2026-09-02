import type { NatalSnapshot } from '../../lib/interstellar-api';
import type { InterpretationTarget } from '../lib/chart-types';
import { structureCategoryNames, patternNames, pointNames, statusNames } from '../lib/chart-constants';
import { availabilityLabel } from '../lib/chart-labels';
import { asRecord, asRecords, asStrings, toPlain, pointList } from '../lib/chart-utils';
import { CalculationUnavailable } from './calculation-unavailable';

export function StructureResults({ snapshot, onOpen }: { snapshot: NatalSnapshot; onOpen: (target: InterpretationTarget) => void }) {
  const structure = asRecord(snapshot.result.structure);
  const categorical = [
    ["hemispheres", "半球分布"], ["quadrants", "象限分布"], ["house_modes", "角续果分布"],
  ] as const;
  const angularity = asRecord(structure.angularity);
  const angularFacts = asRecords(angularity.facts);
  const stelliums = asRecords(asRecord(structure.stelliums).facts);
  const patterns = asRecords(asRecord(structure.geometric_patterns).facts);
  const jones = asRecord(structure.jones_shape);
  return <>
    <div className="professional-grid">
      {categorical.map(([key, label]) => {
        const section = asRecord(structure[key]);
        const categories = asRecords(section.categories);
        return <article className="professional-card" key={key}><header><div><small>{availabilityLabel(section.availability)}</small><h3>{label}</h3></div><button onClick={() => onOpen({ type: "structure", id: key, title: label, fact: toPlain(section), resultPath: `/result/structure/${key}` })}>解读</button></header>{categories.length ? <ul className="fact-list">{categories.map((category) => <li key={String(category.category_id)}><span>{structureCategoryNames[String(category.category_id)] ?? String(category.category_id)}</span><b>{Number(category.count ?? 0)}</b><small>{pointList(category.point_ids)}</small></li>)}</ul> : <p className="empty-fact">没有可用分类事实。</p>}</article>;
      })}
    </div>

    <h3 className="table-group-title">角度性与宫位强度位置</h3>
    <div className="professional-table-wrap"><table className="professional-table"><thead><tr><th>点位</th><th>宫位</th><th>宫位类型</th><th>最近轴点</th><th>距离</th><th>带宽</th><th>操作</th></tr></thead><tbody>{angularFacts.map((fact, index) => <tr key={String(fact.point_id)}><td>{pointNames[String(fact.point_id)] ?? String(fact.point_id)}</td><td>{fact.house == null ? "—" : `第${String(fact.house)}宫`}</td><td>{structureCategoryNames[String(fact.house_mode)] ?? String(fact.house_mode ?? "—")}</td><td>{pointNames[String(fact.nearest_angle_id)] ?? String(fact.nearest_angle_id ?? "—")}</td><td>{fact.distance_to_angle_deg == null ? "—" : `${Number(fact.distance_to_angle_deg).toFixed(3)}°`}</td><td>{String(fact.band ?? "—")}</td><td><button onClick={() => onOpen({ type: "structure", id: `angularity.${String(fact.point_id)}`, title: `${pointNames[String(fact.point_id)] ?? String(fact.point_id)}的角度性`, fact: toPlain(fact), resultPath: `/result/structure/angularity/facts/${index}` })}>解读</button></td></tr>)}</tbody></table></div>

    <div className="professional-grid structure-patterns">
      <article className="professional-card"><header><div><small>STELLIUMS</small><h3>群星结构</h3></div><span>{stelliums.length}</span></header>{stelliums.length ? <ul className="fact-list">{stelliums.map((fact, index) => <li key={String(fact.stellium_id ?? index)}><span>{patternNames[String(fact.kind)] ?? String(fact.kind)}</span><b>{asStrings(fact.participant_ids).length} 点</b><small>{pointList(fact.participant_ids)}{fact.longitude_span_deg == null ? "" : ` · 跨度 ${Number(fact.longitude_span_deg).toFixed(3)}°`}</small><button onClick={() => onOpen({ type: "structure", id: String(fact.stellium_id ?? index), title: patternNames[String(fact.kind)] ?? "群星结构", fact: toPlain(fact), resultPath: `/result/structure/stelliums/facts/${index}` })}>解读</button></li>)}</ul> : <p className="empty-fact">当前参数未命中群星结构。</p>}</article>
      <article className="professional-card"><header><div><small>GEOMETRIC PATTERNS</small><h3>几何格局</h3></div><span>{patterns.length}</span></header>{patterns.length ? <ul className="fact-list">{patterns.map((fact, index) => <li key={String(fact.pattern_id ?? index)}><span>{patternNames[String(fact.pattern_type)] ?? String(fact.pattern_type)}</span><b>{asStrings(fact.participant_ids).length} 点</b><small>{pointList(fact.participant_ids)}</small><button onClick={() => onOpen({ type: "structure", id: String(fact.pattern_id ?? index), title: patternNames[String(fact.pattern_type)] ?? "几何格局", fact: toPlain(fact), resultPath: `/result/structure/geometric_patterns/facts/${index}` })}>解读</button></li>)}</ul> : <p className="empty-fact">当前参数未命中已发布几何格局。</p>}</article>
      <article className="professional-card"><header><div><small>盘型分类</small><h3>Jones 盘型</h3></div><span>{statusNames[String(jones.status ?? "")] ?? (jones.shape_id ? "已识别" : "不确定")}</span></header><p className="boundary-copy">{jones.shape_id ? String(jones.shape_id) : "当前没有通过验证的分类规则，因此保留为不确定，不用视觉猜测生成盘型。"}</p><button onClick={() => onOpen({ type: "structure", id: "jones_shape", title: "Jones 盘型边界", fact: toPlain(jones), resultPath: "/result/structure/jones_shape" })}>查看依据</button></article>
    </div>
  </>;
}
