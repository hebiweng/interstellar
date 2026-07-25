import type { ChartComparison, NatalSnapshot } from "../../lib/interstellar-api";
import type { NatalRenderControls, RenderSpec } from "../../lib/render-export";
import { pointGroups, pointNames, wheelPointLabels } from "../lib/chart-constants";
import { NatalWheel } from "./natal-wheel";

export function ComparisonWheel({
  natalSnapshot,
  movingSnapshot,
  comparison,
  renderSpec,
  controls,
  chartLabel,
  movingLabel,
}: {
  natalSnapshot: NatalSnapshot;
  movingSnapshot: NatalSnapshot;
  comparison: ChartComparison;
  renderSpec: RenderSpec;
  controls: NatalRenderControls;
  chartLabel: string;
  movingLabel: string;
}) {
  const asc = natalSnapshot.result.points.find((point) => point.point_id === "asc")?.position.ecliptic.longitude_deg
    ?? natalSnapshot.result.houses[0]?.cusp_longitude_deg ?? 0;
  const angleFor = (longitude: number) => (180 - (longitude - asc)) * Math.PI / 180;
  const xy = (longitude: number, radius: number) => ({
    x: Number((320 + Math.cos(angleFor(longitude)) * radius).toFixed(6)),
    y: Number((320 - Math.sin(angleFor(longitude)) * radius).toFixed(6)),
  });
  const natalPoints = new Map(natalSnapshot.result.points.map((point) => [point.point_id, point]));
  const movingPoints = new Map(movingSnapshot.result.points.map((point) => [point.point_id, point]));
  const movingVisible = movingSnapshot.result.points
    .filter((point) => controls.visiblePointIds.includes(point.point_id))
    .filter((point) => [...pointGroups.core, "true_north_node", "mean_north_node"].includes(point.point_id))
    .sort((left, right) => left.position.ecliptic.longitude_deg - right.position.ecliptic.longitude_deg);
  const strongestCrossAspects = [...comparison.result.cross_aspects]
    .sort((left, right) => right.strength - left.strength || left.orb_deg - right.orb_deg)
    .slice(0, Math.max(6, Math.ceil(comparison.result.cross_aspects.length * 0.15)));
  return <div className="transit-wheel-stack">
    <NatalWheel snapshot={natalSnapshot} renderSpec={renderSpec} controls={controls} />
    <svg className="transit-wheel-overlay" viewBox="0 0 640 640" role="img" aria-label={`${chartLabel}外圈与跨盘相位`}>
      <title>{chartLabel}外圈与跨盘相位</title>
      <desc>本命盘作为固定内层，{movingLabel}作为变化层，并连接最明显的跨盘相位。</desc>
      <circle cx="320" cy="320" r="220" className="transit-layer-ring" />
      {strongestCrossAspects.map((aspect) => {
        const moving = movingPoints.get(aspect.moving_point_id);
        const reference = natalPoints.get(aspect.reference_point_id);
        if (!moving || !reference) return null;
        const start = xy(moving.position.ecliptic.longitude_deg, 138);
        const end = xy(reference.position.ecliptic.longitude_deg, 138);
        const hard = ["square", "opposition", "semisquare", "sesquisquare"].includes(aspect.type);
        return <line key={aspect.aspect_id} x1={start.x} y1={start.y} x2={end.x} y2={end.y} className={`transit-cross-aspect ${hard ? "hard" : "soft"}`} style={{ opacity: .25 + aspect.strength * .55 }} />;
      })}
      {movingVisible.map((point) => {
        const longitude = point.position.ecliptic.longitude_deg;
        const anchor = xy(longitude, 220);
        const label = xy(longitude, 207);
        return <g key={`transit-${point.point_id}`} className="transit-moving-point"><line x1={anchor.x} y1={anchor.y} x2={label.x} y2={label.y} /><circle cx={label.x} cy={label.y} r="10" /><text x={label.x} y={label.y + 1}>{wheelPointLabels[point.point_id] ?? pointNames[point.point_id]?.slice(0, 1) ?? "•"}</text>{point.retrograde && <text x={label.x + 9} y={label.y - 9} className="point-retrograde">R</text>}</g>;
      })}
    </svg>
    <div className="transit-wheel-legend"><span><i className="natal-dot" />本命内层</span><span><i className="moving-dot" />{movingLabel}</span><span>{comparison.result.cross_aspects.length} 条跨盘相位</span></div>
  </div>;
}
