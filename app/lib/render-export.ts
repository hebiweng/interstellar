import type { NatalSnapshot } from "./interstellar-api";

export type NatalWheelVariant = "professional" | "compact";

export type NatalRenderControls = {
  visiblePointIds: string[];
  showDegreeTicks: boolean;
  showZodiacNames: boolean;
  showZodiacDegrees: boolean;
  showHouseLines: boolean;
  showHouseNumbers: boolean;
  showAxes: boolean;
  showPointLeaders: boolean;
  showPointDegrees: boolean;
  showAspectLines: boolean;
  showLegend: boolean;
  majorAspectsOnly: boolean;
  aspectFilterMode: "top_percent" | "minimum_strength";
  aspectTopPercent: number;
  aspectMinimumStrength: number;
};

export type RenderSpec = {
  view_id: "wheel.natal";
  locale: "zh-CN";
  theme: "dark" | "light" | "print_light";
  width: number;
  height: number;
  pixel_ratio: 1 | 2 | 4;
  layers: string[];
  labels: Record<string, boolean>;
  interaction: {
    zoom: boolean;
    pan: boolean;
    tooltips: boolean;
    selectable: boolean;
  };
  accessibility: {
    color_blind_safe: boolean;
    include_data_alternative: boolean;
    title: string;
    description: string;
  };
  options: {
    variant: NatalWheelVariant;
    snapshot_id: string;
    input_fingerprint: string;
    point_count: number;
    aspect_count: number;
    visible_point_ids: string[];
    visible_aspect_count: number;
    aspect_line_filter: {
      mode: NatalRenderControls["aspectFilterMode"];
      top_percent: number;
      minimum_strength: number;
      major_only: boolean;
    };
    date_level: boolean;
    background: string;
  };
};

const MAJOR_ASPECT_IDS = new Set(["conjunction", "opposition", "trine", "square", "sextile"]);

export function selectVisibleNatalAspects(
  snapshot: NatalSnapshot,
  controls: NatalRenderControls,
) {
  if (isDateLevelRenderSnapshot(snapshot) || !controls.showAspectLines) return [];
  const visiblePoints = new Set(controls.visiblePointIds);
  const candidates = snapshot.result.aspects
    .filter((aspect) => visiblePoints.has(aspect.point_a) && visiblePoints.has(aspect.point_b))
    .filter((aspect) => !controls.majorAspectsOnly || MAJOR_ASPECT_IDS.has(aspect.type))
    .sort((left, right) => right.strength - left.strength || left.orb_deg - right.orb_deg);
  if (controls.aspectFilterMode === "minimum_strength") {
    return candidates.filter((aspect) => aspect.strength >= controls.aspectMinimumStrength);
  }
  const percent = Math.min(100, Math.max(1, controls.aspectTopPercent));
  return candidates.slice(0, Math.max(1, Math.ceil(candidates.length * percent / 100)));
}

export function isDateLevelRenderSnapshot(snapshot: NatalSnapshot): boolean {
  return snapshot.result.houses.length === 0
    || snapshot.result.points.every((point) => point.house === null);
}

export function buildNatalRenderSpec(
  snapshot: NatalSnapshot,
  variant: NatalWheelVariant,
  theme: "dark" | "light",
  controls: NatalRenderControls,
): RenderSpec {
  const dateLevel = isDateLevelRenderSnapshot(snapshot);
  const requestedPointIds = new Set(controls.visiblePointIds);
  const visiblePointIds = snapshot.result.points
    .filter((point) => requestedPointIds.has(point.point_id))
    .map((point) => point.point_id);
  const visibleAspects = selectVisibleNatalAspects(snapshot, controls);
  return {
    view_id: "wheel.natal",
    locale: "zh-CN",
    theme,
    width: 1280,
    height: 1280,
    pixel_ratio: 2,
    layers: [
      ...(controls.showDegreeTicks ? ["degree_ticks"] : []),
      "zodiac",
      "point_band",
      "points",
      ...(!dateLevel && (controls.showHouseLines || controls.showHouseNumbers) ? ["houses"] : []),
      ...(!dateLevel && controls.showAxes ? ["axes"] : []),
      ...(!dateLevel && controls.showAspectLines ? ["aspect_stage", "aspect_lines"] : []),
      ...(controls.showLegend ? ["legend"] : []),
      "provenance_metadata",
    ],
    labels: {
      zodiac_glyphs: true,
      zodiac_names: variant === "professional" && controls.showZodiacNames,
      zodiac_degrees: variant === "professional" && controls.showZodiacDegrees,
      point_degrees: variant === "professional" && controls.showPointDegrees,
      point_leaders: controls.showPointLeaders,
      house_numbers: !dateLevel && controls.showHouseNumbers,
      axis_names: !dateLevel && controls.showAxes,
    },
    interaction: {
      zoom: true,
      pan: false,
      tooltips: true,
      selectable: true,
    },
    accessibility: {
      color_blind_safe: true,
      include_data_alternative: true,
      title: dateLevel ? "日期级星座位置图" : `${variant === "professional" ? "专业" : "简洁"}本命盘轮盘`,
      description: dateLevel
        ? "出生时刻未知，仅展示日期级天体位置，不生成宫位、轴点或相位。"
        : "包含黄道度数、星座、点位、十二宫、四轴、中心相位舞台和相位弦线。",
    },
    options: {
      variant,
      snapshot_id: snapshot.id,
      input_fingerprint: snapshot.input_fingerprint,
      point_count: snapshot.result.points.length,
      aspect_count: snapshot.result.aspects.length,
      visible_point_ids: visiblePointIds,
      visible_aspect_count: visibleAspects.length,
      aspect_line_filter: {
        mode: controls.aspectFilterMode,
        top_percent: controls.aspectTopPercent,
        minimum_strength: controls.aspectMinimumStrength,
        major_only: controls.majorAspectsOnly,
      },
      date_level: dateLevel,
      background: theme === "light" ? "#f3f6fa" : "#07111b",
    },
  };
}

function concatBytes(chunks: Uint8Array[]): Uint8Array {
  const length = chunks.reduce((total, chunk) => total + chunk.length, 0);
  const output = new Uint8Array(length);
  let offset = 0;
  chunks.forEach((chunk) => {
    output.set(chunk, offset);
    offset += chunk.length;
  });
  return output;
}

function ascii(value: string): Uint8Array {
  return new TextEncoder().encode(value);
}

/** Build a deterministic one-page PDF containing the JPEG rendered from the same SVG. */
export function buildSingleImagePdf(
  jpegBytes: Uint8Array,
  imageWidth: number,
  imageHeight: number,
): Uint8Array {
  const pageWidth = 720;
  const pageHeight = Number((pageWidth * imageHeight / imageWidth).toFixed(4));
  const content = ascii(`q\n${pageWidth} 0 0 ${pageHeight} 0 0 cm\n/Im0 Do\nQ\n`);
  const objects: Uint8Array[] = [
    ascii("<< /Type /Catalog /Pages 2 0 R >>"),
    ascii("<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
    ascii(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${pageWidth} ${pageHeight}] /Resources << /XObject << /Im0 5 0 R >> >> /Contents 4 0 R >>`),
    concatBytes([ascii(`<< /Length ${content.length} >>\nstream\n`), content, ascii("endstream")]),
    concatBytes([
      ascii(`<< /Type /XObject /Subtype /Image /Width ${imageWidth} /Height ${imageHeight} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${jpegBytes.length} >>\nstream\n`),
      jpegBytes,
      ascii("\nendstream"),
    ]),
  ];
  const header = ascii("%PDF-1.4\n%Interstellar\n");
  const chunks: Uint8Array[] = [header];
  const offsets: number[] = [0];
  let cursor = header.length;
  objects.forEach((object, index) => {
    const prefix = ascii(`${index + 1} 0 obj\n`);
    const suffix = ascii("\nendobj\n");
    offsets.push(cursor);
    chunks.push(prefix, object, suffix);
    cursor += prefix.length + object.length + suffix.length;
  });
  const xrefOffset = cursor;
  const xref = [
    `xref\n0 ${objects.length + 1}\n`,
    "0000000000 65535 f \n",
    ...offsets.slice(1).map((offset) => `${offset.toString().padStart(10, "0")} 00000 n \n`),
    `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF\n`,
  ].join("");
  chunks.push(ascii(xref));
  return concatBytes(chunks);
}

const SVG_STYLE_PROPERTIES = [
  "fill", "fill-opacity", "stroke", "stroke-width", "stroke-opacity", "stroke-dasharray",
  "stroke-linecap", "stroke-linejoin", "opacity", "font-family", "font-size", "font-weight",
  "font-style", "letter-spacing", "text-anchor", "dominant-baseline", "paint-order", "display",
];

export function serializeSvgWithComputedStyles(svg: SVGSVGElement, renderSpec: RenderSpec): string {
  const clone = svg.cloneNode(true) as SVGSVGElement;
  const sourceNodes = [svg, ...Array.from(svg.querySelectorAll<SVGElement>("*"))];
  const cloneNodes = [clone, ...Array.from(clone.querySelectorAll<SVGElement>("*"))];
  sourceNodes.forEach((source, index) => {
    const target = cloneNodes[index];
    if (!target) return;
    const computed = window.getComputedStyle(source);
    const inline = SVG_STYLE_PROPERTIES
      .map((property) => `${property}:${computed.getPropertyValue(property)}`)
      .join(";");
    target.setAttribute("style", inline);
  });
  clone.setAttribute("xmlns", "http://www.w3.org/2000/svg");
  clone.setAttribute("width", String(renderSpec.width));
  clone.setAttribute("height", String(renderSpec.height));
  clone.setAttribute("viewBox", svg.getAttribute("viewBox") ?? "0 0 640 640");
  clone.dataset.renderView = renderSpec.view_id;
  clone.dataset.snapshotId = renderSpec.options.snapshot_id;
  clone.querySelector("metadata")?.remove();
  const metadata = document.createElementNS("http://www.w3.org/2000/svg", "metadata");
  metadata.textContent = JSON.stringify(renderSpec);
  clone.insertBefore(metadata, clone.firstChild);
  return new XMLSerializer().serializeToString(clone);
}

export function downloadBlob(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 0);
}

export async function rasterizeSerializedSvg(
  serializedSvg: string,
  renderSpec: RenderSpec,
  mimeType: "image/png" | "image/jpeg",
): Promise<Blob> {
  const svgBlob = new Blob([serializedSvg], { type: "image/svg+xml;charset=utf-8" });
  const url = URL.createObjectURL(svgBlob);
  try {
    const image = new Image();
    image.decoding = "async";
    image.src = url;
    await image.decode();
    const canvas = document.createElement("canvas");
    canvas.width = renderSpec.width;
    canvas.height = renderSpec.height;
    const context = canvas.getContext("2d");
    if (!context) throw new Error("Canvas 2D context is unavailable.");
    context.fillStyle = renderSpec.options.background;
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.drawImage(image, 0, 0, canvas.width, canvas.height);
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, mimeType, mimeType === "image/jpeg" ? 0.96 : undefined));
    if (!blob) throw new Error(`${mimeType} export failed.`);
    return blob;
  } finally {
    URL.revokeObjectURL(url);
  }
}
