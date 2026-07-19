export type AdminRole = "user" | "admin" | "super_admin";
export type UserStatus = "active" | "disabled" | "suspended" | "pending_deletion" | "deleted";

export type AdminOverview = {
  totalUsers: number;
  activeUsers30d: number;
  visitsToday: number;
  analysesToday: number;
  exportsToday: number;
  aiCallsToday: number;
  errorRate: number;
  averageLatencyMs: number | null;
  recentActivity: Array<{
    id: string;
    type: string;
    label: string;
    actor: string | null;
    createdAt: string;
  }>;
};

export type AdminUser = {
  email: string;
  displayName: string;
  role: AdminRole;
  status: UserStatus;
  createdAt: string;
  lastLoginAt: string | null;
  peopleCount: number;
  analysesCount: number;
  exportsCount: number;
  aiCallsCount: number;
};

export type AdminAccount = {
  email: string;
  displayName: string;
  role: Exclude<AdminRole, "user">;
  status: UserStatus;
  createdAt: string;
  lastLoginAt: string | null;
};

export type AdminAiModel = {
  id: string;
  modelId: string;
  displayName: string;
  purpose: string;
  enabled: boolean;
  isDefault: boolean;
  temperature: number | null;
  maxTokens: number | null;
  timeoutSeconds: number | null;
  promptOverride: string;
  promptVersion: string | null;
  promptUpdatedBy: string | null;
  promptUpdatedAt: string | null;
};

export type AdminAiProvider = {
  id: string;
  displayName: string;
  baseUrl: string;
  enabled: boolean;
  isDefault: boolean;
  timeoutSeconds: number;
  apiKeyConfigured: boolean;
  apiKeyLastFour: string | null;
  models: AdminAiModel[];
  updatedAt: string | null;
};

export type AdminAiPrompt = {
  platformPrompt: string;
  version: string;
  updatedBy: string | null;
  updatedAt: string | null;
  safetyBoundaryLabel: string;
};

export class AdminApiError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
    this.name = "AdminApiError";
  }
}

function apiBase(): string {
  const configured = process.env.NEXT_PUBLIC_INTERSTELLAR_API_URL?.trim();
  return configured ? configured.replace(/\/$/, "") : "/api/v1";
}

function camelize<T>(value: unknown): T {
  if (Array.isArray(value)) return value.map((item) => camelize(item)) as T;
  if (!value || typeof value !== "object") return value as T;
  return Object.fromEntries(Object.entries(value as Record<string, unknown>).map(([key, item]) => [
    key.replace(/_([a-z])/g, (_, letter: string) => letter.toUpperCase()),
    camelize(item),
  ])) as T;
}

async function adminRequest<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${apiBase()}/admin${path}`, {
    ...init,
    credentials: "include",
    headers: { "Content-Type": "application/json", ...(init?.headers ?? {}) },
  });
  const body = await response.json().catch(() => null) as { message?: string; detail?: string } | null;
  if (!response.ok) {
    const defaults: Record<number, string> = {
      401: "请先登录管理员账户。",
      403: "当前账户没有后台管理权限。",
      404: "后台管理接口尚未启用。",
    };
    throw new AdminApiError(body?.message ?? body?.detail ?? defaults[response.status] ?? `后台请求失败（${response.status}）`, response.status);
  }
  return camelize<T>(body);
}

type EventAggregate = { count?: number; succeeded?: number; failed?: number; averageDurationMs?: number | null };

export async function getAdminOverview(): Promise<AdminOverview> {
  const [today, period, audit] = await Promise.all([
    adminRequest<{ accounts?: { totalUsers?: number }; analytics?: { pageViews?: number; activeUsers?: number; events?: Record<string, EventAggregate> } }>("/overview?days=1"),
    adminRequest<{ analytics?: { activeUsers?: number } }>("/overview?days=30"),
    adminRequest<{ items?: Array<{ id: string | number; actorEmail?: string; action?: string; targetType?: string; targetId?: string; createdAt?: string }> }>("/audit-log?limit=20"),
  ]);
  const events = today.analytics?.events ?? {};
  const count = (...ids: string[]) => ids.reduce((sum, id) => sum + (events[id]?.count ?? 0), 0);
  const totalEvents = Object.values(events).reduce((sum, item) => sum + (item.count ?? 0), 0);
  const failedEvents = Object.values(events).reduce((sum, item) => sum + (item.failed ?? 0), 0);
  const durations = Object.values(events).map((item) => item.averageDurationMs).filter((item): item is number => typeof item === "number");
  return {
    totalUsers: today.accounts?.totalUsers ?? 0,
    activeUsers30d: period.analytics?.activeUsers ?? 0,
    visitsToday: today.analytics?.pageViews ?? 0,
    analysesToday: count("analysis_started", "calculation_completed"),
    exportsToday: count("report_generated", "report_exported"),
    aiCallsToday: count("ai_requested"),
    errorRate: totalEvents ? failedEvents / totalEvents : 0,
    averageLatencyMs: durations.length ? durations.reduce((sum, item) => sum + item, 0) / durations.length : null,
    recentActivity: (audit.items ?? []).map((item) => ({
      id: String(item.id),
      type: item.targetType ?? "admin",
      label: `${item.action ?? "后台操作"}${item.targetId ? ` · ${item.targetId}` : ""}`,
      actor: item.actorEmail ?? null,
      createdAt: item.createdAt ?? "",
    })),
  };
}

type UserWire = Omit<AdminUser, "peopleCount" | "analysesCount" | "exportsCount" | "aiCallsCount"> & {
  usage?: { objects?: number; calculations?: number; aiCalls?: number };
};

function userFromWire(item: UserWire): AdminUser {
  return {
    ...item,
    peopleCount: item.usage?.objects ?? 0,
    analysesCount: item.usage?.calculations ?? 0,
    exportsCount: 0,
    aiCallsCount: item.usage?.aiCalls ?? 0,
  };
}

export function getAdminUsers(query = "") {
  const params = query.trim() ? `?query=${encodeURIComponent(query.trim())}` : "";
  return adminRequest<{ items?: UserWire[] }>(`/users${params.replace("query=", "q=")}`).then((body) => ({
    users: (body.items ?? []).map(userFromWire),
  }));
}

export function createAdminUser(input: { email: string; displayName: string; password: string }) {
  return adminRequest<{ user: UserWire }>("/users", {
    method: "POST",
    body: JSON.stringify({ email: input.email, display_name: input.displayName, password: input.password }),
  }).then((body) => userFromWire(body.user));
}

export function updateAdminUser(email: string, input: { status?: UserStatus; suspendedUntil?: string | null; reason?: string }) {
  return adminRequest<UserWire>("/users", {
    method: "PATCH",
    body: JSON.stringify({ email, status: input.status, suspended_until: input.suspendedUntil, reason: input.reason }),
  }).then(userFromWire);
}

export function deleteAdminUser(email: string) {
  return adminRequest<{ deleted: boolean }>(`/users/${encodeURIComponent(email)}`, { method: "DELETE" });
}

export function getAdmins() {
  return adminRequest<{ items?: AdminAccount[] }>("/admins").then((body) => ({ admins: body.items ?? [] }));
}

export function addAdmin(input: { email: string; role: "admin" | "super_admin" }) {
  return adminRequest<AdminAccount>("/admins", {
    method: "PATCH",
    body: JSON.stringify(input),
  });
}

export function updateAdmin(email: string, role: "admin" | "super_admin") {
  return adminRequest<AdminAccount>("/admins", {
    method: "PATCH",
    body: JSON.stringify({ email, role }),
  });
}

export function removeAdmin(email: string) {
  return adminRequest<AdminAccount>("/admins", { method: "PATCH", body: JSON.stringify({ email, role: "user" }) }).then(() => ({ removed: true }));
}

type ModelWire = {
  modelId: string;
  displayName: string;
  purpose: string;
  enabled: boolean;
  default: boolean;
  options?: Record<string, unknown>;
  preAnalysisPrompt?: string | null;
  promptVersion?: string | null;
  updatedBy?: string | null;
  updatedAt?: string | null;
};

type ProviderWire = {
  providerId: string;
  displayName: string;
  baseUrl: string;
  enabled: boolean;
  default?: boolean;
  timeout: number;
  keyConfigured: boolean;
  keyLast4: string | null;
  updatedAt: string | null;
  models?: ModelWire[];
};

function providerFromWire(item: ProviderWire): AdminAiProvider {
  return {
    id: item.providerId,
    displayName: item.displayName,
    baseUrl: item.baseUrl,
    enabled: item.enabled,
    isDefault: Boolean(item.default),
    timeoutSeconds: item.timeout,
    apiKeyConfigured: item.keyConfigured,
    apiKeyLastFour: item.keyLast4,
    updatedAt: item.updatedAt,
    models: (item.models ?? []).map((model) => ({
      id: model.modelId,
      modelId: model.modelId,
      displayName: model.displayName,
      purpose: model.purpose,
      enabled: model.enabled,
      isDefault: model.default,
      temperature: typeof model.options?.temperature === "number" ? model.options.temperature : null,
      maxTokens: typeof model.options?.max_tokens === "number" ? model.options.max_tokens : null,
      timeoutSeconds: typeof model.options?.timeout_seconds === "number" ? model.options.timeout_seconds : null,
      promptOverride: model.preAnalysisPrompt ?? "",
      promptVersion: model.promptVersion ?? null,
      promptUpdatedBy: model.updatedBy ?? null,
      promptUpdatedAt: model.updatedAt ?? null,
    })),
  };
}

function providerToWire(input: Partial<AdminAiProvider> & { displayName: string; baseUrl: string; apiKey?: string }) {
  return {
    provider_id: input.id,
    display_name: input.displayName,
    base_url: input.baseUrl,
    enabled: input.enabled ?? false,
    default: input.isDefault ?? false,
    api_key: input.apiKey || undefined,
    timeout: input.timeoutSeconds ?? 90,
    models: (input.models ?? []).map((model) => ({
      model_id: model.modelId,
      display_name: model.displayName,
      purpose: model.purpose,
      enabled: model.enabled,
      default: model.isDefault,
      options: { temperature: model.temperature, max_tokens: model.maxTokens, timeout_seconds: model.timeoutSeconds },
      prompt_override: model.promptOverride || null,
      prompt_version: model.promptVersion,
    })),
  };
}

export function getAiProviders() {
  return adminRequest<{ items?: ProviderWire[] }>("/providers").then((body) => ({ providers: (body.items ?? []).map(providerFromWire) }));
}

export function saveAiProvider(input: Partial<AdminAiProvider> & { displayName: string; baseUrl: string; apiKey?: string }) {
  return adminRequest<ProviderWire>("/providers", {
    method: input.id ? "PATCH" : "POST",
    body: JSON.stringify(providerToWire(input)),
  }).then(providerFromWire);
}

export function rotateAiProviderKey(provider: AdminAiProvider, apiKey: string) {
  return saveAiProvider({ ...provider, apiKey });
}

export function testAiProvider(id: string) {
  return adminRequest<{ ok: boolean; error?: string; durationMs?: number | null }>(`/providers/${encodeURIComponent(id)}/test`, { method: "POST" }).then((body) => ({
    ok: body.ok,
    message: body.ok ? "连接成功" : `连接失败${body.error ? `：${body.error}` : ""}`,
    latencyMs: body.durationMs ?? null,
  }));
}

export function saveAiModel(providerId: string, input: Partial<AdminAiModel> & { modelId: string; displayName: string }) {
  return adminRequest<ModelWire>(`/providers/${encodeURIComponent(providerId)}/models`, {
    method: "POST",
    body: JSON.stringify({
      model_id: input.modelId,
      display_name: input.displayName,
      purpose: input.purpose,
      enabled: input.enabled,
      default: input.isDefault,
      options: { temperature: input.temperature, max_tokens: input.maxTokens, timeout_seconds: input.timeoutSeconds },
      prompt_override: input.promptOverride,
      prompt_version: input.promptVersion,
    }),
  }).then((wire) => providerFromWire({ providerId, displayName: "", baseUrl: "", enabled: true, timeout: 90, keyConfigured: false, keyLast4: null, updatedAt: null, models: [wire] }).models[0]);
}

export function getAiPrompt() {
  return adminRequest<Omit<AdminAiPrompt, "safetyBoundaryLabel">>("/ai-prompt").then((body) => ({ ...body, safetyBoundaryLabel: "服务端不可覆盖安全边界" }));
}

export function saveAiPrompt(platformPrompt: string) {
  const version = `platform-${new Date().toISOString()}`;
  return adminRequest<Omit<AdminAiPrompt, "safetyBoundaryLabel">>("/ai-prompt", {
    method: "PATCH",
    body: JSON.stringify({ platform_prompt: platformPrompt, version }),
  }).then((body) => ({ ...body, safetyBoundaryLabel: "服务端不可覆盖安全边界" }));
}

export function restoreDefaultAiPrompt() {
  return adminRequest<Omit<AdminAiPrompt, "safetyBoundaryLabel">>("/ai-prompt", {
    method: "PATCH",
    body: JSON.stringify({ platform_prompt: "", version: "platform-default" }),
  }).then((body) => ({ ...body, safetyBoundaryLabel: "服务端不可覆盖安全边界" }));
}
