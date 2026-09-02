import type { ReactNode } from "react";
import type { NatalCalculationSettings, NatalPoint, NatalSnapshot } from "../../lib/interstellar-api";
import { pointGroups, pointNames, signNames } from "./chart-constants";
import type { NatalPointGroups } from "../../lib/natal-presets";

export function effectivePointIds(
  settings: NatalCalculationSettings,
  groups: Record<keyof typeof pointGroups, boolean>,
) {
  return (Object.entries(groups) as Array<[keyof typeof pointGroups, boolean]>)
    .filter(([, enabled]) => enabled)
    .flatMap(([group]) => [...pointGroups[group]])
    .filter((pointId) => {
      if (settings.disabledPointIds.includes(pointId)) return false;
      if (settings.nodeType === "true") return !pointId.startsWith("mean_north_node") && !pointId.startsWith("mean_south_node");
      if (settings.nodeType === "mean") return !pointId.startsWith("true_north_node") && !pointId.startsWith("true_south_node");
      return true;
    });
}

export function formatDegree(value: number) {
  const totalSeconds = Math.round(value * 3600);
  const degree = Math.floor(totalSeconds / 3600);
  const remainder = totalSeconds % 3600;
  const minute = Math.floor(remainder / 60);
  const second = remainder % 60;
  return `${degree}°${String(minute).padStart(2, "0")}′${String(second).padStart(2, "0")}″`;
}

export function pointPlacementLabel(point: NatalPoint, dateLevel: boolean) {
  return `${dateLevel ? "≈ " : ""}${signNames[point.sign] ?? point.sign} ${formatDegree(point.degree_in_sign)}`;
}

export function pointHouseLabel(point: NatalPoint) {
  return point.house == null ? "未计算（时刻未知）" : `第${point.house}宫`;
}

export function pointMotionLabel(point: NatalPoint, dateLevel: boolean) {
  if (dateLevel && point.status_refs?.some((item) => item.includes("motion_state_changes"))) return "日期内可能变化";
  if (point.motion_interpretation === "not_applicable") return "不适用";
  return point.retrograde ? "逆行" : "顺行";
}

export function pointUncertaintyLabel(point: NatalPoint) {
  if (point.position.uncertainty_arcsec == null) return "";
  return `日期范围 ±${(point.position.uncertainty_arcsec / 3600).toFixed(4)}°`;
}

export function toPlain(value: unknown): string {
  if (value === null || value === undefined) return "—";
  if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") return String(value);
  return JSON.stringify(value, null, 2);
}

export function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};
}

export function asRecords(value: unknown): Array<Record<string, unknown>> {
  return Array.isArray(value) ? value.map(asRecord) : [];
}

export function asStrings(value: unknown): string[] {
  return Array.isArray(value) ? value.map(String) : [];
}

export function renderGuideInline(value: string): ReactNode[] {
  return value.split(/(\*\*[^*]+\*\*)/g).filter(Boolean).map((part, index) =>
    part.startsWith("**") && part.endsWith("**")
      ? <strong key={`${index}:${part}`}>{part.slice(2, -2)}</strong>
      : part,
  );
}

export function isDateLevelSnapshot(snapshot: NatalSnapshot): boolean {
  return asRecord(asRecord(snapshot.result.astronomical_context).uncertainty).mode === "civil_day_range";
}

export function pointList(value: unknown): string {
  return asStrings(value).map((id) => pointNames[id] ?? id).join("、") || "—";
}

export type { NatalPointGroups };
