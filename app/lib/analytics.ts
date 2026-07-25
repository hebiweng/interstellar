import { apiBase } from "./api-client";

export type AnalyticsEventName =
  | "page_view"
  | "analysis_started"
  | "calculation_completed"
  | "calculation_failed"
  | "report_generated"
  | "report_exported"
  | "object_created"
  | "object_updated"
  | "object_deleted";

type AnalyticsPayload = {
  event_name: AnalyticsEventName;
  success?: boolean;
  duration_ms?: number;
  metadata?: Record<string, string | number | boolean>;
};

function analyticsEndpoint(): string {
  return `${apiBase()}/analytics/events`;
}

/**
 * Best-effort operational telemetry. Product actions must never fail because
 * analytics is unavailable, and payloads intentionally exclude chart facts,
 * names, birth data, free text, and exported document content.
 *
 * 使用 navigator.sendBeacon 优先（页面卸载时也能发出），失败时回退到
 * fetchWithTimeout 的 noRetry 模式。所有错误静默吞掉，保持 void 语义。
 */
export function recordAnalyticsEvent(payload: AnalyticsPayload): void {
  if (typeof window === "undefined") return;
  const url = analyticsEndpoint();
  const body = JSON.stringify(payload);

  if (typeof navigator !== "undefined" && typeof navigator.sendBeacon === "function") {
    const blob = new Blob([body], { type: "application/json" });
    try {
      if (navigator.sendBeacon(url, blob)) return;
    } catch {
      // sendBeacon 不可用或被拒绝，回退到 fetch
    }
  }

  void fetch(url, {
    method: "POST",
    credentials: "include",
    keepalive: true,
    headers: { "Content-Type": "application/json" },
    body,
  }).catch(() => undefined);
}
