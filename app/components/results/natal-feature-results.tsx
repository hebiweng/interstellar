import type { NatalSnapshot } from '../../lib/interstellar-api';
import { pointNames, signNames, dignityNames } from '../lib/chart-constants';
import { asRecord, asRecords, formatDegree } from '../lib/chart-utils';
import { CalculationUnavailable } from './calculation-unavailable';

export function NatalFeatureResults({ snapshot }: { snapshot: NatalSnapshot }) {
  const result = asRecord(snapshot.result);
  const specialPoints = asRecords(asRecord(result.special_degrees).points);
  const mirrorResult = asRecord(result.mirror_points);
  const mirrorPoints = asRecords(mirrorResult.mirror_points);
  const mirrorContacts = asRecords(mirrorResult.contacts);
  const receptionDocument = asRecord(asRecord(snapshot.result.classical).receptions);
  const receptions = asRecords(receptionDocument.receptions);
  const mutualReceptions = asRecords(receptionDocument.mutual_receptions);
  return <>
    <h3 className="table-group-title">特征</h3>
    <div className="professional-grid consumer-feature-grid">
      <article className="professional-card"><header><div><small>RECEPTIONS</small><h3>接纳与互容</h3></div><span>{receptions.length + mutualReceptions.length}</span></header>{receptions.length || mutualReceptions.length ? <ul className="fact-list">{receptions.map((item, index) => <li key={`consumer-reception-${index}`}><span>{pointNames[String(item.host_point_id)] ?? String(item.host_point_id)} 接纳 {pointNames[String(item.guest_point_id)] ?? String(item.guest_point_id)}</span><b>{dignityNames[String(item.dignity_kind)] ?? String(item.dignity_kind)}</b></li>)}{mutualReceptions.map((item, index) => <li key={`consumer-mutual-${index}`}><span>{pointNames[String(item.point_a)] ?? String(item.point_a)} ↔ {pointNames[String(item.point_b)] ?? String(item.point_b)}</span><b>互容</b></li>)}</ul> : <p className="empty-fact">当前参数没有命中接纳或互容。</p>}</article>
      <article className="professional-card"><header><div><small>SPECIAL DEGREES</small><h3>特殊度数</h3></div><span>{specialPoints.length}</span></header>{specialPoints.length ? <ul className="fact-list">{specialPoints.map((item, index) => <li key={`consumer-degree-${String(item.point_id ?? index)}`}><span>{pointNames[String(item.point_id)] ?? String(item.point_id)}</span><b>{signNames[String(item.sign_id)] ?? String(item.sign_id)} {formatDegree(Number(item.degree_in_sign ?? 0))}</b><small>{[item.decan_index ? `第${String(item.decan_index)}面` : "", item.in_via_combusta ? "燃烧之路" : "", item.in_terminal_degree_29 ? "29 度区间" : ""].filter(Boolean).join(" · ") || "未命中特殊度数事实"}</small></li>)}</ul> : <p className="empty-fact">本次结果没有特殊度数信息。</p>}</article>
      <article className="professional-card"><header><div><small>MIRROR CONTACTS</small><h3>映点接触</h3></div><span>{mirrorContacts.length}</span></header>{mirrorContacts.length ? <ul className="fact-list">{mirrorContacts.map((item, index) => <li key={`consumer-mirror-contact-${index}`}><span>{pointNames[String(item.point_a)] ?? String(item.point_a)} 与 {pointNames[String(item.point_b)] ?? String(item.point_b)}</span><b>{item.contact_type === "antiscia" ? "映点" : "反映点"}</b><small>距精确位置 {Number(item.separation_from_exact_deg ?? 0).toFixed(3)}°</small></li>)}</ul> : <p className="empty-fact">当前容许度内没有映点或反映点接触。</p>}</article>
    </div>
    <h3 className="table-group-title">映点与反映点</h3>
    {mirrorPoints.length ? <div className="professional-table-wrap"><table className="professional-table mirror-consumer-table"><thead><tr><th>点位</th><th>自身黄经</th><th>映点</th><th>反映点</th></tr></thead><tbody>{mirrorPoints.map((item, index) => <tr key={`consumer-mirror-${String(item.point_id ?? index)}`}><td>{pointNames[String(item.point_id)] ?? String(item.point_id)}</td><td>{Number(item.longitude_deg ?? 0).toFixed(4)}°</td><td>{signNames[String(item.antiscia_sign_id)] ?? String(item.antiscia_sign_id)} {formatDegree(Number(item.antiscia_degree_in_sign ?? 0))}</td><td>{signNames[String(item.contra_antiscia_sign_id)] ?? String(item.contra_antiscia_sign_id)} {formatDegree(Number(item.contra_antiscia_degree_in_sign ?? 0))}</td></tr>)}</tbody></table></div> : <CalculationUnavailable title="映点尚未生成" detail="在左侧开启映点并按当前参数重新计算后，这里会逐点展示映点与反映点。" />}
  </>;
}
