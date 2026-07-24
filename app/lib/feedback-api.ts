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

function apiBase(): string {
  const configured = process.env.NEXT_PUBLIC_INTERSTELLAR_API_URL?.trim();
  return configured ? configured.replace(/\/$/, "") : "/api/v1";
}

async function feedbackRequest<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${apiBase()}${path}`, {
    ...init,
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  });
  const body = (await response.json().catch(() => null)) as { message?: string; error?: string; detail?: string } | null;
  if (!response.ok) {
    throw new FeedbackApiError(
      body?.message ?? body?.detail ?? body?.error ?? `反馈请求失败（${response.status}）`,
      response.status,
    );
  }
  return body as T;
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
