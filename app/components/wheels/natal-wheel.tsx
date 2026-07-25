import { selectVisibleNatalAspects, type NatalRenderControls, type RenderSpec } from "../../lib/render-export";
import type { NatalSnapshot } from "../../lib/interstellar-api";
import { pointGroups, pointGlyphs, wheelPointLabels, pointNames, signNames, signGlyphs, signIds, aspectNames, aspectMarks } from "../lib/chart-constants";
import { formatDegree, isDateLevelSnapshot } from "../lib/chart-utils";

export function NatalWheel({ snapshot, renderSpec, controls }: { snapshot: NatalSnapshot; renderSpec: RenderSpec; controls: NatalRenderControls }) {
  const dateLevel = isDateLevelSnapshot(snapshot);
  const variant = renderSpec.options.variant;
  const professional = variant === "professional";
  const hasLayer = (layer: string) => renderSpec.layers.includes(layer);
  const compactPointIds = [...pointGroups.core, "asc", "dsc", "mc", "ic", "true_north_node", "chiron", "fortune", "spirit"];
  const visiblePointIds = new Set(controls.visiblePointIds);
  const points = snapshot.result.points
    .filter((point) => visiblePointIds.has(point.point_id))
    .filter((point) => professional || compactPointIds.includes(point.point_id))
    .sort((a, b) => a.position.ecliptic.longitude_deg - b.position.ecliptic.longitude_deg);
  const asc = snapshot.result.points.find((point) => point.point_id === "asc")?.position.ecliptic.longitude_deg
    ?? snapshot.result.houses[0]?.cusp_longitude_deg ?? 0;
  const angleFor = (longitude: number) => (180 - (longitude - asc)) * Math.PI / 180;
  const xy = (longitude: number, radius: number) => ({
    x: Number((320 + Math.cos(angleFor(longitude)) * radius).toFixed(6)),
    y: Number((320 - Math.sin(angleFor(longitude)) * radius).toFixed(6)),
  });
  const pointById = new Map(snapshot.result.points.map((point) => [point.point_id, point]));
  const angularDistance = (left: number, right: number) => Math.abs(((left - right + 540) % 360) - 180);
  const placed: Array<{ longitude: number; lane: number }> = [];
  const pointLayouts = points.map((point) => {
    const longitude = point.position.ecliptic.longitude_deg;
    const laneCount = professional ? 5 : 3;
    const lane = Array.from({ length: laneCount }, (_, index) => index).find((candidate) =>
      !placed.some((item) => item.lane === candidate && angularDistance(item.longitude, longitude) < (professional ? 6.5 : 10)),
    ) ?? placed.length % laneCount;
    placed.push({ longitude, lane });
    return {
      point,
      anchor: xy(longitude, professional ? 253 : 232),
      label: xy(longitude, professional ? 239 - lane * 11.5 : 207 - lane * 19),
      lane,
    };
  });
  const axes = [["asc", "ASC"], ["dsc", "DSC"], ["mc", "MC"], ["ic", "IC"]] as const;
  const majorAspectTypes = new Set(["conjunction", "opposition", "trine", "square", "sextile"]);
  const visibleAspects = selectVisibleNatalAspects(snapshot, controls);
  const aspectPointIds = new Set(visibleAspects.flatMap((aspect) => [aspect.point_a, aspect.point_b]));
  const aspectRadius = professional ? 143 : 156;
  const fixedStarContacts = new Set((snapshot.result.fixed_star_contacts ?? []).map((item) => item.star_id));
  const contactedFixedStars = (snapshot.result.fixed_stars ?? []).filter((star) => fixedStarContacts.has(star.star_id));
  return (
    <svg className={`natal-wheel ${professional ? "professional-wheel" : "compact-wheel"}`} viewBox="0 0 640 640" role="img" aria-label={renderSpec.accessibility.title} data-render-view={renderSpec.view_id} data-snapshot-id={snapshot.id}>
      <metadata>{JSON.stringify(renderSpec)}</metadata>
      <title>{renderSpec.accessibility.title}</title>
      <desc>{renderSpec.accessibility.description}</desc>
      <circle cx="320" cy="320" r="306" className="wheel-outer" />
      <circle cx="320" cy="320" r="292" className="wheel-ring degree-ring" />
      <circle cx="320" cy="320" r="257" className="wheel-ring zodiac-ring" />
      <circle cx="320" cy="320" r={professional ? "190" : "176"} className="wheel-ring point-band-ring" />
      <circle cx="320" cy="320" r={professional ? "154" : "166"} className="wheel-ring house-number-ring" />
      <circle cx="320" cy="320" r={aspectRadius} className="wheel-ring aspect-stage-ring" />
      {hasLayer("degree_ticks") && Array.from({ length: 360 }, (_, degree) => {
        if (!professional && degree % 5 !== 0) return null;
        const outer = xy(degree, 304);
        const tickLength = degree % 10 === 0 ? 11 : degree % 5 === 0 ? 7 : 3.5;
        const inner = xy(degree, 304 - tickLength);
        return <line key={`degree-tick-${degree}`} x1={inner.x} y1={inner.y} x2={outer.x} y2={outer.y} className={`degree-tick ${degree % 10 === 0 ? "major" : degree % 5 === 0 ? "medium" : "minor"}`} />;
      })}
      {hasLayer("zodiac") && Array.from({ length: 12 }, (_, index) => {
        const boundary = xy(index * 30, 304);
        const inner = xy(index * 30, 257);
        const label = xy(index * 30 + 15, professional ? 279 : 275);
        const name = xy(index * 30 + 15, 264);
        return <g key={`sign-${index}`}><line x1={inner.x} y1={inner.y} x2={boundary.x} y2={boundary.y} className="sign-line" /><text x={label.x} y={label.y} className="sign-glyph">{signGlyphs[index]}</text>{renderSpec.labels.zodiac_names && <text x={name.x} y={name.y} className="sign-name-label">{signNames[signIds[index]]}</text>}{renderSpec.labels.zodiac_degrees && [0, 10, 20].map((degree) => { const tickLabel = xy(index * 30 + degree + 1.3, 297); return <text key={degree} x={tickLabel.x} y={tickLabel.y} className="sign-degree-label">{degree}°</text>; })}</g>;
      })}
      {hasLayer("houses") && snapshot.result.houses.map((house) => {
        const end = xy(house.cusp_longitude_deg, 257);
        const start = xy(house.cusp_longitude_deg, professional ? 154 : 0);
        const number = xy(house.cusp_longitude_deg + house.span_deg / 2, professional ? 171 : 184);
        const isAxis = [1, 4, 7, 10].includes(house.number);
        return <g key={`house-${house.number}`}>{controls.showHouseLines && <line x1={professional ? start.x : 320} y1={professional ? start.y : 320} x2={end.x} y2={end.y} className={isAxis ? "house-line axis" : "house-line"} />}{renderSpec.labels.house_numbers && <text x={number.x} y={number.y} className="house-number">{house.number}</text>}</g>;
      })}
      {hasLayer("aspect_stage") && [...aspectPointIds].map((pointId) => {
        const point = pointById.get(pointId);
        if (!point) return null;
        const longitude = point.position.ecliptic.longitude_deg;
        const outer = xy(longitude, professional ? 154 : 166);
        const anchor = xy(longitude, aspectRadius);
        return <g key={`aspect-anchor-${pointId}`} className="aspect-anchor-group"><line x1={outer.x} y1={outer.y} x2={anchor.x} y2={anchor.y} className="aspect-anchor-spoke" /><circle cx={anchor.x} cy={anchor.y} r={professional ? "2.8" : "2.2"} className="aspect-anchor-dot" /></g>;
      })}
      {hasLayer("aspect_lines") && visibleAspects.map((aspect) => {
        const a = pointById.get(aspect.point_a); const b = pointById.get(aspect.point_b);
        if (!a || !b) return null;
        const start = xy(a.position.ecliptic.longitude_deg, aspectRadius); const end = xy(b.position.ecliptic.longitude_deg, aspectRadius);
        const hard = ["square", "opposition", "semisquare", "sesquisquare"].includes(aspect.type);
        const soft = ["trine", "sextile", "quintile", "biquintile"].includes(aspect.type);
        const className = `aspect-line ${hard ? "hard" : soft ? "soft" : "neutral"} ${majorAspectTypes.has(aspect.type) ? "major" : "minor"}`;
        return <line key={aspect.aspect_id} x1={start.x} y1={start.y} x2={end.x} y2={end.y} className={className} data-aspect={aspect.type} style={{ strokeWidth: majorAspectTypes.has(aspect.type) ? 1.05 + aspect.strength * 1.25 : .55 + aspect.strength * .55, opacity: majorAspectTypes.has(aspect.type) ? .5 + aspect.strength * .38 : .16 + aspect.strength * .2 }} />;
      })}
      {hasLayer("axes") && axes.map(([pointId, label]) => {
        const point = pointById.get(pointId);
        if (!point) return null;
        const end = xy(point.position.ecliptic.longitude_deg, 304);
        const tag = xy(point.position.ecliptic.longitude_deg, 316);
        return <g key={`axis-${pointId}`}><line x1="320" y1="320" x2={end.x} y2={end.y} className={`wheel-axis wheel-axis-${pointId}`} /><text x={tag.x} y={tag.y} className="wheel-axis-label">{label}</text></g>;
      })}
      {hasLayer("points") && pointLayouts.map(({ point, anchor, label, lane }) => {
        const glyph = pointGlyphs[point.point_id] ?? pointNames[point.point_id]?.slice(0, 1) ?? "•";
        const shortLabel = wheelPointLabels[point.point_id] ?? pointNames[point.point_id]?.slice(0, 1) ?? glyph;
        return <g key={point.point_id} className={`wheel-point wheel-point-${point.kind ?? "other"} wheel-point-id-${point.point_id}`} data-lane={lane}>{renderSpec.labels.point_leaders && <line x1={anchor.x} y1={anchor.y} x2={label.x} y2={label.y} className="point-leader" />}<circle cx={anchor.x} cy={anchor.y} r="2.5" className="point-anchor" />{professional ? <g transform={`translate(${label.x} ${label.y})`}><text className="professional-point-label" y="0">{shortLabel}</text>{point.retrograde && <text x="9" y="-8" className="point-retrograde">R</text>}{renderSpec.labels.point_degrees && <text x="0" y="10" className="point-degree-label">{Math.floor(point.degree_in_sign)}°{Math.round((point.degree_in_sign % 1) * 60).toString().padStart(2, "0")}′</text>}</g> : <g transform={`translate(${label.x} ${label.y})`}><circle r="13" className="planet-dot" /><text className="planet-glyph" y="1">{glyph}</text>{point.retrograde && <text x="13" y="-12" className="point-retrograde">R</text>}</g>}</g>;
      })}
      {hasLayer("fixed_star_contacts") && contactedFixedStars.map((star) => {
        const longitude = star.position.ecliptic.longitude_deg;
        const inner = xy(longitude, 191);
        const outer = xy(longitude, 201);
        const label = xy(longitude, 207);
        return <g key={`fixed-star-${star.star_id}`} className="wheel-fixed-star"><title>{star.label_zh} · {star.name} · {signNames[star.sign] ?? star.sign} {formatDegree(star.degree_in_sign)}</title><line x1={inner.x} y1={inner.y} x2={outer.x} y2={outer.y} /><text x={label.x} y={label.y}>★</text></g>;
      })}
      <circle cx="320" cy="320" r={professional ? "43" : "54"} className="wheel-core" />
      <text x="320" y={professional ? "316" : "306"} className="wheel-core-title">{dateLevel ? "DATE RANGE" : professional ? "本命" : "NATAL"}</text>
      <text x="320" y={professional ? "330" : "329"} className="wheel-core-sub">{dateLevel ? `${points.length} 点 · 时刻未知` : `${points.length} 点 · ${visibleAspects.length}/${snapshot.result.aspects.length} 相位线`}</text>
      {hasLayer("legend") && !dateLevel && professional && <g className="wheel-legend"><line x1="266" y1="371" x2="284" y2="371" className="aspect-line hard major" /><text x="288" y="374">张力</text><line x1="322" y1="371" x2="340" y2="371" className="aspect-line soft major" /><text x="344" y="374">支持</text></g>}
    </svg>
  );
}
