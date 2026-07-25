import { fetchWithTimeout, parseJsonErrorBody, type FetchOptions } from "./api-client";

export type FeedbackType = "bug" | "feature" | "other";

export type FeedbackInput = {
  type: FeedbackType;
  content: string;
  contact?: string;
};

export type FeedbackRecord = {
  id: number;
  type: FeedbackType;
  content: string;
  contact: string | null;
  userEmail: string | null;
  status: "pending" | "resolved";
  createdAt: string;
  updatedAt: string;
};

export class FeedbackApiError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
    this.name = "FeedbackApiError";
  }
}

const DEFAULT_TIMEOUT_MS = 30_000;

async function feedbackRequest<T>(path: string, init?: FetchOptions): Promise<T> {
  const response = await fetchWithTimeout(path, {
    method: init?.method,
    body: init?.body,
    headers: init?.headers,
    timeoutMs: init?.timeoutMs ?? DEFAULT_TIMEOUT_MS,
    signal: init?.signal,
  });
  const errorBody = await parseJsonErrorBody(response);
  if (!response.ok) {
    throw new FeedbackApiError(
      errorBody?.message ?? errorBody?.detail ?? `反馈请求失败（${response.status}）`,
      response.status,
    );
  }
  if (errorBody?.raw == null) {
    throw new FeedbackApiError("反馈请求返回了空响应。", response.status);
  }
  return errorBody.raw as T;
}

export async function submitFeedback(input: FeedbackInput): Promise<{ ok: boolean; feedback: FeedbackRecord }> {
  return feedbackRequest<{ ok: boolean; feedback: FeedbackRecord }>("/feedback", {
    method: "POST",
    body: JSON.stringify({
      type: input.type,
      content: input.content,
      contact: input.contact || "",
    }),
  });
}

export type FeedbackListResponse = {
  total: number;
  limit: number;
  offset: number;
  items: FeedbackRecord[];
};

export async function listFeedback(status?: "pending" | "resolved", limit = 100, offset = 0): Promise<FeedbackListResponse> {
  const params = new URLSearchParams();
  if (status) params.set("status", status);
  params.set("limit", String(limit));
  params.set("offset", String(offset));
  return feedbackRequest<FeedbackListResponse>(`/admin/feedback?${params.toString()}`);
}

export async function updateFeedbackStatus(id: number, status: "pending" | "resolved"): Promise<{ ok: boolean; feedback: FeedbackRecord }> {
  return feedbackRequest<{ ok: boolean; feedback: FeedbackRecord }>(`/admin/feedback/${id}`, {
    method: "PATCH",
    body: JSON.stringify({ status }),
  });
}
