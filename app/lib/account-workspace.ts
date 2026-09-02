import type { NatalCalculationSettings, NatalPersonInput, NatalSnapshot } from "./interstellar-api";
import { fetchWithTimeout, parseJsonErrorBody, type FetchOptions } from "./api-client";

export type LatestNatalRecord = {
  snapshotId: string;
  snapshot: NatalSnapshot;
  settings: NatalCalculationSettings;
  groups: Record<string, boolean>;
  analysisDocument: string;
  analysisDocumentHash: string;
  aiAnalysisText: string | null;
  aiModelId: string | null;
  calculatedAt: string;
};

export type WorkspacePerson = {
  id: string;
  person: NatalPersonInput;
  createdAt?: string;
  savedAt: string;
  latestNatal: LatestNatalRecord | null;
};

export type AccountWorkspace = {
  authenticated: boolean;
  user: {
    email: string;
    displayName: string;
    role?: "user" | "admin" | "super_admin";
    status?: "active" | "disabled" | "suspended" | "pending_deletion";
  } | null;
  people: WorkspacePerson[];
  preferences?: {
    defaultPersonId: string | null;
    sampleVisible: boolean;
  };
};

/** 账户工作区错误（替代原生 Error，保持 instanceof 兼容）。 */
export class AccountWorkspaceError extends Error {
  constructor(message: string, readonly status?: number) {
    super(message);
    this.name = "AccountWorkspaceError";
  }
}

const DEFAULT_TIMEOUT_MS = 30_000;

async function workspaceRequest<T>(init?: FetchOptions): Promise<T> {
  const response = await fetchWithTimeout("/account/workspace", {
    method: init?.method ?? "GET",
    body: init?.body,
    headers: init?.headers,
    timeoutMs: init?.timeoutMs ?? DEFAULT_TIMEOUT_MS,
    signal: init?.signal,
  });
  const errorBody = await parseJsonErrorBody(response);
  if (!response.ok) {
    throw new AccountWorkspaceError(
      errorBody?.message ?? `工作区请求失败（${response.status}）`,
      response.status,
    );
  }
  if (errorBody?.raw == null) {
    throw new AccountWorkspaceError("工作区返回了空响应。", response.status);
  }
  return errorBody.raw as T;
}

async function accountRequest<T>(path: string, input?: Record<string, string>): Promise<T> {
  const response = await fetchWithTimeout(`/account/${path}`, {
    method: "POST",
    body: input ? JSON.stringify(input) : undefined,
    hasBody: Boolean(input),
    timeoutMs: DEFAULT_TIMEOUT_MS,
  });
  const errorBody = await parseJsonErrorBody(response);
  if (!response.ok) {
    throw new AccountWorkspaceError(
      errorBody?.message ?? `账户请求失败（${response.status}）`,
      response.status,
    );
  }
  if (errorBody?.raw == null) {
    throw new AccountWorkspaceError("账户请求返回了空响应。", response.status);
  }
  return errorBody.raw as T;
}

export function registerAccount(input: { email: string; password: string; displayName: string }) {
  return accountRequest<{ authenticated: true; user: { email: string; displayName: string } }>("register", {
    email: input.email,
    password: input.password,
    display_name: input.displayName,
  });
}

export function loginAccount(input: { email: string; password: string }) {
  return accountRequest<{ authenticated: true; user: { email: string; displayName: string } }>("login", {
    email: input.email,
    password: input.password,
  });
}

export function logoutAccount() {
  return accountRequest<{ authenticated: false }>("logout");
}

export function getAccountWorkspace(): Promise<AccountWorkspace> {
  return workspaceRequest<AccountWorkspace>();
}

/**
 * 账户工作区写操作。
 *
 * 后端契约：所有写操作共用 POST /account/workspace + body.action 路由
 * （见后端 account workspace router）。虽然这不符合 REST 语义，但
 * 后端不支持独立的 RESTful 端点，前端必须遵循现有契约。
 */
export function saveAccountPerson(person: NatalPersonInput, personId?: string) {
  return workspaceRequest<{ id: string; savedAt: string }>({
    method: "POST",
    body: JSON.stringify({ action: "save_person", personId, person }),
  });
}

export function deleteAccountPerson(personId: string) {
  return workspaceRequest<{ personId: string; deleted: true }>({
    method: "POST",
    body: JSON.stringify({ action: "delete_person", personId }),
  });
}

export function setDefaultAccountPerson(personId: string | null) {
  return workspaceRequest<{ preferences: NonNullable<AccountWorkspace["preferences"]> }>({
    method: "POST",
    body: JSON.stringify({ action: "set_default_person", personId }),
  });
}

export function setAccountSampleVisibility(sampleVisible: boolean) {
  return workspaceRequest<{ preferences: NonNullable<AccountWorkspace["preferences"]> }>({
    method: "POST",
    body: JSON.stringify({ action: "set_sample_visibility", sampleVisible }),
  });
}

export function saveLatestNatal(input: {
  personId: string;
  snapshot: NatalSnapshot;
  settings: NatalCalculationSettings;
  groups: Record<string, boolean>;
  analysisDocument: string;
  analysisDocumentHash: string;
  aiAnalysisText?: string | null;
  aiModelId?: string | null;
}) {
  return workspaceRequest<{ personId: string; snapshotId: string; calculatedAt: string }>({
    method: "POST",
    body: JSON.stringify({ action: "save_latest_natal", ...input }),
  });
}

export function saveLatestAiAnalysis(personId: string, snapshotId: string, aiAnalysisText: string, aiModelId: string) {
  return workspaceRequest<{ personId: string; saved: boolean }>({
    method: "POST",
    body: JSON.stringify({ action: "save_ai_analysis", personId, snapshotId, aiAnalysisText, aiModelId }),
  });
}
