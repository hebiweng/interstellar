import { aspectPhaseNames, lunarPhaseNames, availabilityNames, statusNames } from "./chart-constants";

export function aspectPhaseLabel(value: string) {
  return aspectPhaseNames[value];
}

export function lunarPhaseLabel(value: unknown) {
  const id = typeof value === "string" ? value : "";
  return lunarPhaseNames[id] ?? (id || "未提供");
}

export function availabilityLabel(value: unknown) {
  const key = String(value ?? "");
  return availabilityNames[key] ?? statusNames[key] ?? "计算结果";
}
