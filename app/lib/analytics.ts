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
  const configured = process.env.NEXT_PUBLIC_INTERSTELLAR_API_URL?.trim();
  const apiBase = configured ? configured.replace(/\/$/, "") : "/api/v1";
  return `${apiBase}/analytics/events`;
}

/**
 * Best-effort operational telemetry. Product actions must never fail because
 * analytics is unavailable, and payloads intentionally exclude chart facts,
 * names, birth data, free text, and exported document content.
 */
export function recordAnalyticsEvent(payload: AnalyticsPayload): void {
  if (typeof window === "undefined") return;
  void fetch(analyticsEndpoint(), {
    method: "POST",
    credentials: "include",
    keepalive: true,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  }).catch(() => undefined);
}
