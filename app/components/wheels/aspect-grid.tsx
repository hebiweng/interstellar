import type { NatalAspect, NatalPoint, NatalSnapshot } from "../../lib/interstellar-api";
import { pointGroups, pointGlyphs, pointNames, aspectNames, aspectMarks } from "../lib/chart-constants";

export function AspectGrid({ snapshot, onOpen }: { snapshot: NatalSnapshot; onOpen: (aspect: NatalAspect) => void }) {
  const preferred = [...pointGroups.core, "asc", "mc", "true_north_node", "fortune"];
  const points = preferred
    .map((id) => snapshot.result.points.find((point) => point.point_id === id))
    .filter((point): point is NatalPoint => Boolean(point));
  const aspects = new Map<string, NatalAspect>();
  snapshot.result.aspects.forEach((aspect) => {
    aspects.set(`${aspect.point_a}:${aspect.point_b}`, aspect);
    aspects.set(`${aspect.point_b}:${aspect.point_a}`, aspect);
  });
  return (
    <div className="aspect-matrix-wrap">
      <table className="aspect-matrix" aria-label="本命盘主要相位矩阵">
        <thead><tr><th scope="col">点位</th>{points.map((point) => <th key={point.point_id} scope="col" title={pointNames[point.point_id] ?? point.point_id}>{pointGlyphs[point.point_id] ?? "•"}</th>)}</tr></thead>
        <tbody>{points.map((rowPoint, rowIndex) => <tr key={rowPoint.point_id}><th scope="row"><b>{pointGlyphs[rowPoint.point_id] ?? "•"}</b><span>{pointNames[rowPoint.point_id] ?? rowPoint.point_id}</span></th>{points.map((columnPoint, columnIndex) => {
          if (columnIndex >= rowIndex) return <td key={columnPoint.point_id} className="matrix-empty">{columnIndex === rowIndex ? "—" : ""}</td>;
          const aspect = aspects.get(`${rowPoint.point_id}:${columnPoint.point_id}`);
          if (!aspect) return <td key={columnPoint.point_id} className="matrix-empty" />;
          const hard = ["square", "opposition", "semisquare", "sesquisquare"].includes(aspect.type);
          return <td key={columnPoint.point_id}><button className={hard ? "hard" : "soft"} onClick={() => onOpen(aspect)} title={`${pointNames[aspect.point_a] ?? aspect.point_a} ${aspectNames[aspect.type] ?? aspect.type} ${pointNames[aspect.point_b] ?? aspect.point_b}，容许度 ${aspect.orb_deg.toFixed(3)}°`}><b>{aspectMarks[aspect.type] ?? "·"}</b><small>{aspect.orb_deg.toFixed(1)}°</small></button></td>;
        })}</tr>)}</tbody>
      </table>
      <p>矩阵用于快速查看点位之间的相位关系；点击单元格可查看理论角度、实际角距、容许度、入相／出相和对应含义。</p>
    </div>
  );
}
