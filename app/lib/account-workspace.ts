import type { NatalCalculationSettings, NatalPersonInput, NatalSnapshot } from "./interstellar-api";

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

function accountApiBase(): string {
  const configured = process.env.NEXT_PUBLIC_INTERSTELLAR_API_URL?.trim();
  return configured ? configured.replace(/\/$/, "") : "/api/v1";
}

async function workspaceRequest<T>(init?: RequestInit): Promise<T> {
  const response = await fetch(`${accountApiBase()}/account/workspace`, {
    ...init,
    credentials: "include",
    headers: { "Content-Type": "application/json", ...(init?.headers ?? {}) },
  });
  const body = await response.json().catch(() => null) as { message?: string } | null;
  if (!response.ok) throw new Error(body?.message ?? `工作区请求失败（${response.status}）`);
  return body as T;
}

async function accountRequest<T>(path: string, input?: Record<string, string>): Promise<T> {
  const response = await fetch(`${accountApiBase()}/account/${path}`, {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: input ? JSON.stringify(input) : undefined,
  });
  const body = await response.json().catch(() => null) as { message?: string } | null;
  if (!response.ok) throw new Error(body?.message ?? `账户请求失败（${response.status}）`);
  return body as T;
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
