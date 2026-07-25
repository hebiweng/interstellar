import type { NatalPoint } from "../../lib/interstellar-api";
import { pointGlyphs, pointNames, pointKindNames } from "../lib/chart-constants";
import { pointPlacementLabel, pointHouseLabel, pointMotionLabel } from "../lib/chart-utils";

export function PointResultTable({ title, points, dateLevelMode, onOpen }: { title: string; points: NatalPoint[]; dateLevelMode: boolean; onOpen: (point: NatalPoint) => void }) {
  if (!points.length) return null;
  return <>
    <h3 className="table-group-title">{title}</h3>
    <div className="data-table"><div className="table-head"><span>点位</span><span>星座度数</span><span>宫位</span><span>运动</span><span>类型</span><span>操作</span></div>{points.map((point) => <div className="table-row" key={point.point_id}><span className="point-name"><b>{pointGlyphs[point.point_id] ?? "•"}</b>{pointNames[point.point_id] ?? point.point_id}</span><span>{pointPlacementLabel(point, dateLevelMode)}</span><span>{pointHouseLabel(point)}</span><span className={point.retrograde ? "retrograde" : ""}>{pointMotionLabel(point, dateLevelMode)}</span><span>{pointKindNames[String(point.kind)] ?? "扩展点位"}</span><button onClick={() => onOpen(point)}>解读</button></div>)}</div>
  </>;
}
